//
//  HMGAuthClient.swift
//  KiaMaps
//
//  Created by Codex on 09.03.2026.
//

import Foundation

struct HMGAuthClient {
    let configuration: ApiConfiguration
    let provider: ApiRequestProvider
    let rsaService: RSAEncryptionService

    func makeAuthorizeURL() throws -> URL? {
        let queryItems = [
            URLQueryItem(name: "client_id", value: configuration.serviceId),
            URLQueryItem(name: "redirect_uri", value: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: "ccsp"),
        ]

        return try provider.request(
            endpoint: KiaApiEndpoint.oauth2UserAuthorize,
            queryItems: queryItems,
            headers: commonNavigationHeaders()
        ).urlRequest.url
    }

    func authenticate(username: String, password: String, recaptchaToken: String? = nil) async throws -> AuthorizationData {
        cleanCookies()

        let referer: String
        do {
            referer = try await fetchConnectorAuthorization()
            logInfo("Retrieved referer: \(referer)", category: .api)
        } catch {
            logError("Client connector authorization failed: \(error.localizedDescription)", category: .api)
            throw AuthenticationError.clientConfigurationFailed
        }

        let clientConfig = try await fetchClientConfiguration(referer: referer)
        logInfo("Client configured for: \(clientConfig.clientName)", category: .api)

        let encryptionSettings = try await fetchPasswordEncryptionSettings(referer: referer)
        guard encryptionSettings.useEnabled && encryptionSettings.value1 == "true" else {
            throw AuthenticationError.encryptionSettingsFailed
        }

        let rsaKey: RSAEncryptionService.RSAKeyData
        do {
            rsaKey = try await fetchRSACertificate(referer: referer)
        } catch {
            logError("Fetch RSA Certificate failed: \(error.localizedDescription)", category: .api)
            throw AuthenticationError.certificateRetrievalFailed
        }

        let csrfToken = try await initializeOAuth2(referer: referer)
        let authorizationCode = try await signIn(
            referer: referer,
            username: username,
            password: password,
            rsaKey: rsaKey,
            csrfToken: csrfToken,
            recaptchaToken: recaptchaToken
        )

        return try await exchangeAuthorizationCode(authorizationCode)
    }

    func exchangeAuthorizationCode(_ authorizationCode: String) async throws -> AuthorizationData {
        let tokenResponse: TokenResponse
        do {
            tokenResponse = try await exchangeCodeForTokens(authorizationCode: authorizationCode)
        } catch {
            logError("Exchange code for token failed: \(error.localizedDescription)", category: .api)
            throw AuthenticationError.tokenExchangeFailed
        }

        let stamp = AuthorizationData.generateStamp(for: configuration)
        let deviceId = try await registerDeviceId(stamp: stamp)
        let authorizationData = AuthorizationData(
            stamp: stamp,
            deviceId: deviceId,
            accessToken: tokenResponse.accessToken,
            expiresIn: tokenResponse.expiresIn,
            refreshToken: tokenResponse.refreshToken ?? "",
            isCcuCCS2Supported: true
        )

        provider.authorization = authorizationData
        try await notificationRegister(deviceId: deviceId)
        return authorizationData
    }

    func refreshAuthorization(_ authorization: AuthorizationData) async throws -> AuthorizationData {
        let form: [String: String] = [
            "client_id": configuration.serviceId,
            "client_secret": "secret",
            "grant_type": "refresh_token",
            "refresh_token": authorization.refreshToken,
        ]

        let tokenResponse: TokenResponse = try await provider.request(
            with: .post,
            endpoint: KiaApiEndpoint.loginToken,
            form: form,
            authorization: false
        ).data()

        return AuthorizationData(
            stamp: authorization.stamp,
            deviceId: authorization.deviceId,
            accessToken: tokenResponse.accessToken,
            expiresIn: tokenResponse.expiresIn,
            refreshToken: tokenResponse.refreshToken ?? authorization.refreshToken,
            isCcuCCS2Supported: authorization.isCcuCCS2Supported,
            source: authorization.source
        )
    }

    func logout() async throws {
        do {
            try await provider.request(with: .post, endpoint: KiaApiEndpoint.logout).empty()
            logInfo("Successfully logout", category: .auth)
        } catch {
            logError("Failed to logout: \(error.localizedDescription)", category: .auth)
        }
        provider.authorization = nil
        cleanCookies()
    }

    private func fetchConnectorAuthorization() async throws -> String {
        let stateObject = ConnectorAuthorizationState(
            scope: nil,
            state: nil,
            lang: nil,
            cert: "",
            action: "idpc_auth_endpoint",
            clientId: configuration.serviceId,
            redirectUri: try makeRedirectUri(endpoint: .loginRedirect),
            responseType: "code",
            signupLink: nil,
            hmgid2ClientId: configuration.authClientId,
            hmgid2RedirectUri: try makeRedirectUri(),
            hmgid2Scope: nil,
            hmgid2State: "ccsp",
            hmgid2UiLocales: nil
        )
        let stateData = try JSONEncoder().encode(stateObject)

        let queryItems = [
            URLQueryItem(name: "client_id", value: configuration.serviceId),
            URLQueryItem(name: "redirect_uri", value: try makeRedirectUri(endpoint: .loginRedirect).absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: stateData.base64EncodedString()),
            URLQueryItem(name: "cert", value: ""),
            URLQueryItem(name: "action", value: "idpc_auth_endpoint"),
            URLQueryItem(name: "sso_session_reset", value: "true")
        ]

        let referralURL = try await provider.request(
            endpoint: KiaApiEndpoint.oauth2ConnectorAuthorize,
            queryItems: queryItems,
            headers: commonNavigationHeaders()
        ).referalUrl()

        guard let nextURI = extractNextURI(from: referralURL) else {
            throw AuthenticationError.oauth2InitializationFailed
        }
        return nextURI
    }

    private func fetchClientConfiguration(referer _: String) async throws -> ClientConfiguration {
        try await provider.request(
            endpoint: KiaApiEndpoint.loginConnectorClients(configuration.serviceId),
            headers: commonJSONHeaders()
        ).responseValue()
    }

    private func fetchPasswordEncryptionSettings(referer: String) async throws -> PasswordEncryptionSettings {
        try await provider.request(
            endpoint: KiaApiEndpoint.loginCodes,
            headers: commonJSONHeaders(referer: referer)
        ).responseValue()
    }

    private func fetchRSACertificate(referer: String) async throws -> RSAEncryptionService.RSAKeyData {
        let certificate: RSACertificateResponse = try await provider.request(
            endpoint: KiaApiEndpoint.loginCertificates,
            headers: commonJSONHeaders(referer: referer)
        ).responseValue()

        return RSAEncryptionService.RSAKeyData(
            keyType: certificate.kty,
            exponent: certificate.e,
            keyId: certificate.kid,
            modulus: certificate.n
        )
    }

    private func initializeOAuth2(referer: String) async throws -> String {
        let queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.serviceId),
            URLQueryItem(name: "redirect_uri", value: try makeRedirectUri().absoluteString),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: "ccsp")
        ]

        _ = try await provider.request(
            endpoint: KiaApiEndpoint.oauth2UserAuthorize,
            queryItems: queryItems,
            headers: commonNavigationHeaders(referer: referer)
        ).empty(acceptStatusCode: 302)

        guard let cookie = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "account" }) else {
            throw AuthenticationError.csrfTokenNotFound
        }
        return cookie.value
    }

    private func signIn(
        referer: String,
        username: String,
        password: String,
        rsaKey: RSAEncryptionService.RSAKeyData,
        csrfToken: String,
        recaptchaToken: String? = nil
    ) async throws -> String {
        let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKey)

        guard let connectorSessionKey = extractConnectorSessionKey(from: referer) else {
            throw AuthenticationError.sessionKeyNotFound
        }

        var form: [String: String] = [
            "client_id": configuration.serviceId,
            "encryptedPassword": "true",
            "orgHmgSid": "",
            "password": encryptedPassword,
            "kid": rsaKey.keyId,
            "redirect_uri": try makeRedirectUri().absoluteString,
            "scope": "",
            "nonce": "",
            "state": "ccsp",
            "username": username,
            "remember_me": "false",
            "connector_session_key": connectorSessionKey,
            "_csrf": csrfToken
        ]

        if let recaptchaToken {
            form["g-recaptcha-response"] = recaptchaToken
            logInfo("Including reCAPTCHA token in sign-in request", category: .auth)
        }

        let referralURL = try await provider.request(
            with: .post,
            endpoint: KiaApiEndpoint.loginSignin,
            headers: [
                "Sec-Fetch-Site": "same-origin",
                "Sec-Fetch-Mode": "navigate",
                "Sec-Fetch-Dest": "document",
                "Origin": "https://idpconnect-eu.\(configuration.key).com",
                "Referer": referer
            ],
            form: form
        ).referalUrl()

        let (code, _, loginSuccess) = try extractAuthorizationCode(from: referralURL)
        guard loginSuccess else {
            throw AuthenticationError.signInFailed
        }
        return code
    }

    private func exchangeCodeForTokens(authorizationCode: String) async throws -> TokenResponse {
        let form: [String: String] = [
            "client_id": configuration.serviceId,
            "client_secret": "secret",
            "code": authorizationCode,
            "grant_type": "authorization_code",
            "redirect_uri": try makeRedirectUri().absoluteString
        ]

        return try await provider.request(
            with: .post,
            endpoint: KiaApiEndpoint.loginToken,
            form: form
        ).data()
    }

    private func registerDeviceId(stamp: String) async throws -> UUID {
        let registrationId = "60a0cce8de8b3b51745f10bc35fe07cb000000ef"
        let uuid = UUID().uuidString

        let headers = [
            "ccsp-service-id": configuration.serviceId,
            "ccsp-application-id": configuration.appId,
            "Stamp": stamp,
        ]
        let payload: [String: String] = [
            "pushRegId": registrationId,
            "pushType": configuration.pushType,
            "uuid": uuid,
        ]

        let response: NotificationRegistrationResponse = try await provider.request(
            endpoint: KiaApiEndpoint.notificationRegister,
            headers: headers,
            encodable: payload
        ).response(acceptStatusCode: 302)
        return response.deviceId
    }

    private func notificationRegister(deviceId: UUID) async throws {
        var headers = provider.authorization?.authorizatioHeaders(for: configuration) ?? [:]
        headers["Content-Type"] = "application/json; charset=UTF-8"
        headers["offset"] = "2"
        try await provider.request(
            with: .post,
            endpoint: KiaApiEndpoint.notificationRegisterWithDeviceId(deviceId),
            headers: headers
        ).empty(acceptStatusCode: 200)
    }

    private func makeRedirectUri(endpoint: KiaApiEndpoint = .oauth2Redirect) throws -> URL {
        try provider.configuration.url(for: endpoint)
    }

    private func extractNextURI(from location: URL) -> String? {
        guard let components = URLComponents(url: location, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "next_uri" })?.value
    }

    private func extractConnectorSessionKey(from location: String) -> String? {
        guard let url = URL(string: location),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "connector_session_key" })?.value
    }

    func extractAuthorizationCode(from location: URL) throws -> (code: String, state: String, loginSuccess: Bool) {
        guard let components = URLComponents(url: location, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value
        else {
            throw AuthenticationError.authorizationCodeNotFound
        }

        let state = queryItems.first(where: { $0.name == "state" })?.value ?? "ccsp"
        let loginSuccess = queryItems.first(where: { $0.name == "login_success" })?.value == "y"
        return (code, state, loginSuccess)
    }

    private func commonJSONHeaders(referer: String? = nil) -> [String: String] {
        var headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
        ]
        if let referer {
            headers["Referer"] = referer
        }
        return headers
    }

    private func commonNavigationHeaders(referer: String? = nil) -> [String: String] {
        var headers = [
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Dest": "document",
        ]
        if let referer {
            headers["Referer"] = referer
        }
        return headers
    }

    private func cleanCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
