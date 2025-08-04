//
//  Api.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 28.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

/**
 * Api - Main interface for Kia/Hyundai/Genesis vehicle API communication
 * 
 * This class handles all aspects of vehicle API interaction including:
 * - Multi-step OAuth2 authentication flow
 * - Vehicle status retrieval (cached and live refresh)
 * - Climate control operations with PIN protection
 * - User profile and session management
 * - Device registration for push notifications
 * 
 * ## Authentication Flow
 * The API uses a complex multi-step authentication process:
 * 1. Login page retrieval and form submission
 * 2. Device ID registration with push notification setup
 * 3. OAuth2 authorization code exchange
 * 4. Access token retrieval and validation
 * 5. User integration setup
 * 
 * ## CCS2 Support
 * The API automatically detects and uses CCS2 endpoints when supported by the vehicle,
 * falling back to standard endpoints for older vehicles.
 * 
 * ## Thread Safety
 * This class is designed to be used from async contexts and is not thread-safe.
 * Use a single instance per authentication session.
 */
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

    /// Authenticate user and establish session with vehicle API
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    func login(username: String, password: String) async throws -> AuthorizationData {
        // Try enhanced authentication first if available
        if shouldUseEnhancedAuth() {
            do {
                return try await loginEnhanced(username: username, password: password)
            } catch {
                print("Enhanced authentication failed, falling back to legacy: \(error)")
                return try await loginLegacy(username: username, password: password)
            }
        } else {
            return try await loginLegacy(username: username, password: password)
        }
    }
    
    /// Enhanced authentication with RSA encryption support
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    func loginEnhanced(username: String, password: String) async throws -> AuthorizationData {
        cleanCookies()
        let authAPI = NewAuthenticationAPI(configuration: configuration)
        
        // Step 0: Get connector authorization (handles 302 redirect to get nxt_uri)
        let nextUri = try await authAPI.getConnectorAuthorization()
        print("Retrieved next_uri: \(nextUri)")

        // Step 1: Get client configuration
        let clientConfig = try await authAPI.getClientConfiguration(referer: nextUri)
        print("Client configured for: \(clientConfig.clientName)")
        
        // Step 2: Check if password encryption is enabled
        let encryptionSettings = try await authAPI.getPasswordEncryptionSettings(referer: nextUri)
        guard encryptionSettings.useEnabled && encryptionSettings.value1 == "true" else {
            throw NewAuthenticationError.encryptionSettingsFailed
        }
        
        // Step 3: Get RSA certificate for password encryption
        let rsaKey = try await authAPI.getRSACertificate(referer: nextUri)

        // Step 4: Initialize OAuth2 flow
        let oauth2Result = try await authAPI.initializeOAuth2(referer: nextUri)

        // Step 5: Sign in with encrypted password
        let authCodeResult = try await authAPI.signIn(
            referer: nextUri,
            username: username,
            password: password,
            rsaKey: rsaKey,
            oauth2Result: oauth2Result
        )
        
        // Step 6: Exchange authorization code for tokens
        let tokenResponse = try await authAPI.exchangeCodeForTokens(
            authorizationCode: authCodeResult.code
        )
        
        // Generate device ID and stamp for compatibility
        let stamp = AuthorizationData.generateStamp(for: configuration)
        let deviceId = try await deviceId(stamp: stamp)
        
        // Convert to existing AuthorizationData format
        let authorizationData = AuthorizationData(
            stamp: stamp,
            deviceId: deviceId,
            accessToken: tokenResponse.accessToken,
            expiresIn: tokenResponse.expiresIn,
            refreshToken: tokenResponse.refreshToken,
            isCcuCCS2Supported: true
        )
        
        provider.authorization = authorizationData
        try await notificationRegister(deviceId: deviceId)
        return authorizationData
    }
    
    /// Legacy authentication method (original implementation)
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    private func loginLegacy(username: String, password: String) async throws -> AuthorizationData {
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
    
    /// Determine whether to use enhanced authentication
    /// - Returns: True if enhanced authentication should be used
    private func shouldUseEnhancedAuth() -> Bool {
        // For now, always try enhanced auth first
        // In production, this could be controlled by a feature flag
        return true
    }

    /// Logout user and clean up session data
    /// - Throws: Network errors (non-critical - cleanup continues regardless)
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

    /// Retrieve list of vehicles associated with the user account
    /// - Returns: Complete vehicle response containing all registered vehicles
    /// - Throws: Network errors or authentication failures
    func vehicles() async throws -> VehicleResponse {
        try await provider.request(endpoint: .vehicles).response()
    }

    /// Request fresh vehicle status update from the vehicle
    /// - Parameter vehicleId: The vehicle's unique identifier
    /// - Returns: Operation result ID for tracking the refresh request
    /// - Note: Uses CCS2 endpoint if supported, fallback to standard endpoint
    /// - Throws: Network errors or vehicle communication failures
    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID {
        let endpoint: ApiEndpoint = authorization?.isCcuCCS2Supported == true ? .refreshCCS2Vehicle(vehicleId) : .refreshVehicle(vehicleId)
        return try await provider.request(endpoint: endpoint).responseEmpty().resultId
    }

    /// Retrieve cached vehicle status (last known state)
    /// - Parameter vehicleId: The vehicle's unique identifier
    /// - Returns: Complete vehicle status including battery, location, and system states
    /// - Note: Uses CCS2 endpoint if supported, fallback to standard endpoint
    /// - Throws: Network errors or data parsing failures
    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusResponse {
        let endpoint: ApiEndpoint = authorization?.isCcuCCS2Supported == true ? .vehicleCachedCCS2Status(vehicleId) : .vehicleCachedStatus(vehicleId)
        return try await provider.request(endpoint: endpoint).response()
    }

    /// Retrieve user profile information
    /// - Returns: User profile data as JSON string
    /// - Throws: Network errors or authentication failures
    func profile() async throws -> String {
        try await provider.request(endpoint: .userProfile).string()
    }
    
    // MARK: - Climate Control
    
    /// Start climate control with specified options
    /// - Parameters:
    ///   - vehicleId: The vehicle ID
    ///   - options: Climate control configuration options
    ///   - pin: Vehicle PIN (required for climate control)
    /// - Returns: Operation result ID for tracking
    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin: String) async throws -> UUID {
        guard !pin.isEmpty else {
            throw ClimateControlError.missingPin
        }
        
        guard options.isValid else {
            if !options.isTemperatureValid {
                throw ClimateControlError.invalidTemperature(options.temperature)
            }
            if !options.areSeatLevelsValid {
                let invalidLevel = [options.driverSeatLevel, options.passengerSeatLevel, 
                                 options.rearLeftSeatLevel, options.rearRightSeatLevel]
                    .first { $0 < 0 || $0 > 3 } ?? -1
                throw ClimateControlError.invalidSeatLevel(invalidLevel)
            }
            if !options.isDurationValid {
                throw ClimateControlError.invalidDuration(options.duration)
            }
            throw ClimateControlError.vehicleNotReady
        }
        
        let request = options.toClimateControlRequest(pin: pin)
        let headers = authorization?.authorizatioHeaders(for: configuration) ?? [:]
        
        return try await provider.request(
            with: .post,
            endpoint: .startClimate(vehicleId),
            headers: headers,
            encodable: request
        ).responseEmpty().resultId
    }
    
    /// Stop climate control
    /// - Parameter vehicleId: The vehicle ID
    /// - Returns: Operation result ID for tracking
    func stopClimate(_ vehicleId: UUID) async throws -> UUID {
        let headers = authorization?.authorizatioHeaders(for: configuration) ?? [:]
        
        return try await provider.request(
            with: .post,
            endpoint: .stopClimate(vehicleId),
            headers: headers
        ).responseEmpty().resultId
    }
}

private extension Api {
    /// Retrieve the login page and generate a new user session ID
    /// - Returns: Tuple containing generated user ID and login page HTML content
    /// - Throws: Network errors or HTML parsing failures
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
            "Referer": "https://prd.eu-ccapi.\(configuration.key).com:8080"
        ]
        let body = try await provider.request(
            endpoint: .loginPage,
            queryItems: queryItems,
            headers: headers
        ).string()

        return (userId, body)
    }

    /// Submit login credentials to authenticate with the vehicle service
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    ///   - loginUrlQuery: Query parameters extracted from login page
    /// - Returns: Redirect URL for next authentication step
    /// - Throws: Authentication failures or network errors
    func loginAction(username: String, password: String, loginUrlQuery: String) async throws -> URL {
        let headers = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Dest": "document",
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

    /// Handle login redirect with user integration data
    /// - Parameters:
    ///   - userId: Generated user session ID
    ///   - userIntegration: User integration response from previous step
    ///   - sessionState: Session state UUID (currently unused)
    /// - Throws: Network errors or redirect handling failures
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

    /// Initialize OAuth2 authorization flow
    /// - Throws: Network errors or OAuth2 setup failures
    func authorization() async throws {
        let queryItems: [URLQueryItem] = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: configuration.serviceId),
            .init(name: "redirect_uri", value: "\(configuration.baseUrl):\(configuration.port)/api/v1/user/oauth2/redirect")
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

    /// Exchange authorization code for access token
    /// - Parameters:
    ///   - serviceId: Service identifier UUID
    ///   - code: Authorization code from OAuth2 flow
    /// - Returns: Authorization response containing access token and refresh token
    /// - Throws: Token exchange failures or network errors
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

    /// Establish user session after authentication
    /// - Throws: Network errors or session establishment failures
    func userSession() async throws {
        let headers: ApiRequest.Headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": "\(configuration.baseUrl):\(configuration.port)/web/v1/user/authorize?lang=en&cache=reset",
        ]
        try await provider.request(endpoint: .userSession, headers: headers).empty()
    }

    /// Retrieve user integration information for service setup
    /// - Returns: User integration response containing service and user IDs
    /// - Throws: Network errors or integration setup failures
    func userIntegration() async throws -> UserIntegrationResponse {
        let headers: ApiRequest.Headers = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": "\(configuration.baseUrl):\(configuration.port)/web/v1/user/intgmain",
        ]
        return try await provider.request(endpoint: .userIntegrationInfo, headers: headers).data()
    }

    /// Set user interface language preference
    /// - Parameter languageCode: Language code (default: "en")
    /// - Throws: Network errors or language setting failures
    func setLanguage(languageCode: String = "en") async throws {
        let payload = ["language": languageCode]
        try await provider.request(endpoint: .language, encodable: payload).empty()
    }

    /// Complete sign-in process and retrieve authorization code
    /// - Parameter userId: User ID (currently unused but kept for API compatibility)
    /// - Returns: Authorization code for token exchange
    /// - Throws: Sign-in failures or network errors
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
        ).response(acceptStatusCode: 302)
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

    /// Extract login URL query parameters from HTML response
    /// - Parameter htmlString: HTML content from login page
    /// - Returns: Query string for login action, or nil if not found
    func extractLoginUrlQuery(from htmlString: String) -> String? {
        // Define the regular expression pattern
        let pattern = "eu-account\\.\(configuration.key)\\.com\\/auth\\/realms\\/eu\(configuration.key)idm\\/login-actions\\/authenticate?([^\"]+)"

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

    /// Clear all HTTP cookies to ensure clean authentication state
    func cleanCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
