import Foundation

extension Api {
    /// Login - Step 0: Get Connector Authorization
    func fetchConnectorAuthorization() async throws -> String {
        // Build the state parameter (base64 encoded JSON)
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

        let referalUrl = try await provider.request(
            endpoint: .oauth2ConnectorAuthorize,
            queryItems: queryItems,
            headers: commonNavigationHeaders()
        ).referalUrl()

        // Extract next_uri from Location header
        guard let nextUri = extractNextUri(from: referalUrl) else {
            throw AuthenticationError.oauth2InitializationFailed
        }
        return nextUri
    }

    /// Login - Step 1: Get Client Configuration
    func fetchClientConfiguration(referer: String) async throws -> ClientConfiguration {
        try await provider.request(
            endpoint: .loginConnectorClients(configuration.serviceId),
            headers: commonJSONHeaders()
        ).responseValue()
    }

    /// Login - Step 2: Check Password Encryption Settings
    func fetchPasswordEncryptionSettings(referer: String) async throws -> PasswordEncryptionSettings {
        try await provider.request(
            endpoint: .loginCodes,
            headers: commonJSONHeaders(referer: referer)
        ).responseValue()
    }

    /// Login - Step 3: Get RSA Certificate
    func fetchRSACertificate(referer: String) async throws -> RSAEncryptionService.RSAKeyData {
        let certificate: RSACertificateResponse = try await provider.request(
            endpoint: .loginCertificates,
            headers: commonJSONHeaders(referer: referer)
        ).responseValue()

        return RSAEncryptionService.RSAKeyData(
            keyType: certificate.kty,
            exponent: certificate.e,
            keyId: certificate.kid,
            modulus: certificate.n
        )
    }

    /// Login - Step 4: Initialize OAuth2 Flow
    func initializeOAuth2(referer: String) async throws -> String {
        let queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.serviceId),
            URLQueryItem(name: "redirect_uri", value: try makeRedirectUri().absoluteString),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: "ccsp")
        ]

        _ = try await provider.request(
            endpoint: .oauth2UserAuthorize,
            queryItems: queryItems,
            headers: commonNavigationHeaders(referer: referer)
        ).empty(acceptStatusCode: 302)

        let cookies = HTTPCookieStorage.shared.cookies

        // Parse HTML response to extract CSRF token and session key
        guard let cookie = cookies?.first(where: { $0.name == "account" }) else {
            throw AuthenticationError.csrfTokenNotFound
        }
        return cookie.value
    }

    /// Login - Step 5: Encrypted Sign-In
    func signIn(referer: String, username: String, password: String, rsaKey: RSAEncryptionService.RSAKeyData, csrfToken: String, recaptchaToken: String? = nil) async throws -> String {
        // Encrypt password
        let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKey)

        guard let connectorSessionKey = extractConnectorSessionKey(from: referer) else {
            throw AuthenticationError.sessionKeyNotFound
        }

        // Prepare form data
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
        
        // Add reCAPTCHA token if provided
        if let recaptchaToken = recaptchaToken {
            form["g-recaptcha-response"] = recaptchaToken
            logInfo("Including reCAPTCHA token in sign-in request", category: .auth)
        }

        let referalUrl = try await provider.request(
            with: .post,
            endpoint: .loginSignin,
            headers: [
                "Sec-Fetch-Site": "same-origin",
                "Sec-Fetch-Mode": "navigate",
                "Sec-Fetch-Dest": "document",
                "Origin": "https://idpconnect-eu.\(configuration.key).com",
                "Referer": referer
            ],
            form: form
        ).referalUrl()

        let (code, _, loginSuccess) = try extractAuthorizationCode(from: referalUrl)
        guard loginSuccess else {
            throw AuthenticationError.signInFailed
        }
        return code
    }

    /// Login - Step 6: Exchange Authorization Code for Tokens
    func exchangeCodeForTokens(authorizationCode: String) async throws -> TokenResponse {
        let form: [String: String] = [
            "client_id": configuration.serviceId,
            "client_secret": "secret", // TODO: something generated
            "code": authorizationCode,
            "grant_type": "authorization_code",
            "redirect_uri": try makeRedirectUri().absoluteString
        ]

        return try await provider.request(
            with: .post,
            endpoint: .loginToken,
            form: form
        ).data()
    }

    /// Register device and retrieve device ID for push notifications
    /// - Parameter stamp: Authorization stamp for device registration
    /// - Returns: Unique device ID for this installation
    /// - Throws: Device registration failures or network errors
    func deviceId(stamp: String) async throws -> UUID {
        /* let number = Int.random(in: 80_000_000_000...100_000_000_000)
         let myHex = String(format: "%064x", number)
         String(myHex.prefix(64)) */
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
            endpoint: .notificationRegister,
            headers: headers,
            encodable: payload
        ).response()
        return response.deviceId
    }

    /// Register device for push notifications with vehicle service
    /// - Parameter deviceId: Device ID obtained from device registration
    /// - Throws: Notification registration failures or network errors
    func notificationRegister(deviceId: UUID) async throws {
        var headers: ApiRequest.Headers = provider.authorization?.authorizatioHeaders(for: configuration) ?? [:]
        headers["Content-Type"] = "application/json; charset=UTF-8"
        headers["offset"] = "2"
        try await provider.request(with: .post, endpoint: .notificationRegisterWithDeviceId(deviceId), headers: headers).empty(acceptStatusCode: 200)
    }

    // MARK: - Helpers

    func makeRedirectUri(endpoint: ApiEndpoint = .oauth2Redirect) throws -> URL {
        try provider.configuration.url(for: endpoint)
    }

    func extractNextUri(from location: URL) -> String? {
        guard let components = URLComponents(url: location, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        // Look for next_uri parameters
        return queryItems.first(where: {  $0.name == "next_uri" })?.value
    }

    func extractConnectorSessionKey(from location: String) -> String? {
        guard let url = URL(string: location),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        // Look for both next_uri parameters
        return queryItems.first(where: { $0.name == "connector_session_key" })?.value
    }

    func extractAuthorizationCode(from location: URL) throws -> (code: String, state: String, loginSuccess: Bool) {
        if configuration.key == "kia" {
            return (try kiaLogin.authorizationCode(from: location), kiaLogin.state, true)
        }
        guard let components = URLComponents(url: location, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw AuthenticationError.authorizationCodeNotFound
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw AuthenticationError.authorizationCodeNotFound
        }

        let state = queryItems.first(where: { $0.name == "state" })?.value ?? "ccsp"
        let loginSuccess = queryItems.first(where: { $0.name == "login_success" })?.value == "y"

        return (code: code, state: state, loginSuccess: loginSuccess)
    }

    func isLoginCallback(_ url: URL) -> Bool {
        if configuration.key == "kia" {
            return kiaLogin.isCallback(url)
        }
        guard let redirect = try? makeRedirectUri() else { return false }
        return url.scheme == redirect.scheme && url.host == redirect.host && url.path == redirect.path
    }

    func commonJSONHeaders(referer: String? = nil) -> [String: String] {
        var headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
        ]
        if let referer = referer {
            headers["Referer"] = referer
        }
        return headers
    }

    func commonNavigationHeaders(referer: String? = nil) -> [String: String] {
        var headers = [
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Dest": "document",

        ]
        if let referer = referer {
            headers["Referer"] = referer
        }
        return headers
    }

    /// Clear all HTTP cookies to ensure clean authentication state
    func cleanCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

