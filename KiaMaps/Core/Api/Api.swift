//
//  Api.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 28.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

class Api {
    let configuration: ApiConfiguration

    var authorization: AuthorizationData? {
        get {
            provider.authorization
        }
        set {
            provider.authorization = newValue
        }
    }

    private let provider: ApiRequestProvider

    init(configuration: ApiConfiguration) {
        self.configuration = configuration
        provider = ApiRequestProvider(configuration: configuration)
    }

    func login(username: String, password: String) async throws -> AuthorizationData {
        let stamp = AuthorizationData.generateStamp(for: configuration)
        cleanCookies()

        let (userId, page) = try await loginPage()
        guard let loginUrlQuery = extractLoginUrlQuery(from: page) else {
            throw URLError(.cannotDecodeContentData)
        }
        let referalUrl = try await loginAction(username: username, password: password, loginUrlQuery: loginUrlQuery)
        let deviceId = try await deviceId(stamp: stamp)
        try await authorization()
        // try await userSession()
        try await setLanguage()
        // try await userSession()
        let userIntegration = try await userIntegration()
        try await provider.data(url: referalUrl)

        let code = try await signIn(userId: userId)
        let token = try await authorizationToken(serviceId: userIntegration.serviceId, code: code)

        let authorizationData = AuthorizationData(
            stamp: stamp,
            deviceId: deviceId,
            accessToken: token.accessToken,
            expiresIn: token.expiresIn,
            refreshToken: token.refreshToken,
            isCcuCCS2Supported: true
        )
        provider.authorization = authorizationData
        try await notificationRegister(deviceId: deviceId)
        return authorizationData
    }

    func logout() async throws {
        do {
            try await provider.request(endpoint: .logout).empty()
            print("Successfully logout")
        } catch {
            print("Failed to logout: " + error.localizedDescription)
        }
        provider.authorization = nil
        cleanCookies()
    }

    func vehicles() async throws -> VehicleResponse {
        try await provider.request(endpoint: .vehicles).response()
    }

    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID {
        let endpoint: ApiEndpoint = authorization?.isCcuCCS2Supported == true ? .refreshCCS2Vehicle(vehicleId) : .refreshVehicle(vehicleId)
        return try await provider.request(endpoint: endpoint).responseEmpty().resultId
    }

    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusResponse {
        let endpoint: ApiEndpoint = authorization?.isCcuCCS2Supported == true ? .vehicleCachedCCS2Status(vehicleId) : .vehicleCachedStatus(vehicleId)
        return try await provider.request(endpoint: endpoint).response()
    }

    func profile() async throws -> String {
        try await provider.request(endpoint: .userProfile).string()
    }
}

private extension Api {
    func loginPage() async throws -> (userId: UUID, body: String) {
        let userId = UUID()
        let queryItems: [URLQueryItem] = try [
            .init(name: "client_id", value: configuration.authClientId),
            .init(name: "scope", value: "openid profile email phone"),
            .init(name: "response_type", value: "code"),
            .init(name: "hkid_session_reset", value: "true"),
            .init(name: "redirect_uri", value: ApiRequest.url(for: .loginRedirect, configuration: configuration).absoluteString),
            .init(name: "ui_locales", value: "en"),
            .init(name: "state", value: (configuration.serviceId + ":" + userId.uuidString).lowercased()),
        ]
        let headers = [
            "Accept": configuration.acceptHeader,
            "Sec-Fetch-Site": "same-site",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Dest": "document",
        ]
        let body = try await provider.request(
            endpoint: .loginPage,
            queryItems: queryItems,
            headers: headers
        ).string()

        return (userId, body)
    }

    func loginAction(username: String, password: String, loginUrlQuery: String) async throws -> URL {
        let headers = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-Mode": "navigate",
            "Origin": "null",
        ]
        let form: ApiRequest.Form = [
            "username": username,
            "password": password,
            "rememberMe": "on",
            "credentialId": "",
        ]

        return try await provider.request(
            endpoint: .loginAction(query: loginUrlQuery),
            headers: headers,
            form: form
        ).referalUrl()
    }

    func loginRedirect(userId: UUID, userIntegration: UserIntegrationResponse, sessionState _: UUID) async throws {
        let queryItems: [URLQueryItem] = [
            .init(name: "user_id", value: userId.uuidString.lowercased()),
            .init(name: "locale", value: "en"),
            .init(name: "state", value: (userIntegration.serviceId.uuidString + ":" + userIntegration.userId.uuidString).lowercased()),
            .init(name: "session_state", value: ""),
            .init(name: "code", value: "en"),
        ]
        let headers = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Dest": "document",
        ]

        let body = try await provider.request(
            endpoint: .loginRedirect,
            queryItems: queryItems,
            headers: headers
        ).string(acceptStatusCode: 302)

        guard !body.isEmpty else {
            throw ApiError.noData
        }
    }

    func authorization() async throws {
        let queryItems: [URLQueryItem] = [
            .init(name: "response_type", value: "code"),
            .init(name: "state", value: "test"),
            .init(name: "client_id", value: configuration.serviceId),
            .init(name: "redirect_uri", value: "\(configuration.baseUrl):\(configuration.port)/api/v1/user/oauth2/redirect"),
            .init(name: "lang", value: "en"),
        ]
        let headers = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Dest": "document",
        ]

        let body = try await provider.request(
            endpoint: .authorization,
            queryItems: queryItems,
            headers: headers
        ).string(acceptStatusCode: 302)

        guard !body.isEmpty else {
            throw ApiError.noData
        }
    }

    func authorizationToken(serviceId: UUID, code: String) async throws -> AuthorizationResponse {
        let authorization = "\(serviceId.uuidString.lowercased()):secret".data(using: .utf8)?.base64EncodedString() ?? ""
        let headers = [
            "Authorization": "Basic \(authorization)",
        ]
        let form: ApiRequest.Form = [
            "client_id": serviceId.uuidString.lowercased(),
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": "\(configuration.baseUrl):\(configuration.port)/api/v1/user/oauth2/redirect",
        ]

        return try await provider.request(endpoint: .authorizationToken, headers: headers, form: form).data()
    }

    func userSession() async throws {
        let headers: ApiRequest.Headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": "\(configuration.baseUrl):\(configuration.port)/web/v1/user/authorize?lang=en&cache=reset",
        ]
        try await provider.request(endpoint: .userSession, headers: headers).empty()
    }

    func userIntegration() async throws -> UserIntegrationResponse {
        let headers: ApiRequest.Headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": "\(configuration.baseUrl):\(configuration.port)/web/v1/user/intgmain",
        ]
        return try await provider.request(endpoint: .userIntegrationInfo, headers: headers).data()
    }

    func setLanguage(languageCode: String = "en") async throws {
        let payload = ["language": languageCode]
        try await provider.request(endpoint: .language, encodable: payload).empty()
    }

    @discardableResult
    func signIn(userId _: UUID) async throws -> String {
        let headers: ApiRequest.Headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Content-Type": "text/plain;charset=UTF-8",
            "Referer": "\(configuration.baseUrl):\(configuration.port)/web/v1/user/integration/auth?&locale=en",
        ]
        let payload = ["intUserId": ""]
        let result: SignInResponse = try await provider.request(endpoint: .signIn, headers: headers, encodable: payload).data()
        guard let code = result.code else {
            throw URLError(.cannotDecodeContentData)
        }
        return code
    }

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
        ).response(acceptStatusCode: 302)
        return response.deviceId
    }

    func notificationRegister(deviceId: UUID) async throws {
        var headers: ApiRequest.Headers = provider.authorization?.authorizatioHeaders(for: configuration) ?? [:]
        headers["Content-Type"] = "application/json; charset=UTF-8"
        headers["offset"] = "2"
        try await provider.request(with: .post, endpoint: .notificationRegisterWithDeviceId(deviceId), headers: headers).empty(acceptStatusCode: 200)
    }

    func extractLoginUrlQuery(from htmlString: String) -> String? {
        // Define the regular expression pattern
        let pattern = "eu-account\\.kia\\.com\\/auth\\/realms\\/eukiaidm\\/login-actions\\/authenticate?([^\"]+)"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])

            let nsString = htmlString as NSString
            let results = regex.matches(in: htmlString, options: [], range: NSRange(location: 0, length: nsString.length))

            if let match = results.first, let range = Range(match.range(at: 1), in: htmlString) {
                return String(htmlString[range]).replacingOccurrences(of: "&amp;", with: "&")
            }
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
        }
        return nil
    }

    func cleanCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
