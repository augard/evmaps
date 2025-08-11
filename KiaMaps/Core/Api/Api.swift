//
//  Api.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 28.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/**
 * Api - Main interface for Kia/Hyundai/Genesis vehicle API communication
 * 
 * This class handles all aspects of vehicle API interaction including:
 * - RSA-encrypted OAuth2 authentication flow
 * - Vehicle status retrieval (cached and live refresh)
 * - Climate control operations with PIN protection
 * - User profile and session management
 * - Device registration for push notifications
 * 
 * ## Authentication Flow
 * The API uses a secure RSA-encrypted authentication process:
 * 1. Connector authorization with CSRF protection
 * 2. Client configuration retrieval
 * 3. Password encryption settings validation
 * 4. RSA certificate retrieval for password encryption
 * 5. OAuth2 flow initialization
 * 6. Encrypted sign-in with RSA-encrypted password
 * 7. Authorization code exchange for access tokens
 * 8. Device registration for push notifications
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

    private let rsaService: RSAEncryptionService
    private let provider: ApiRequestProvider

    init(configuration: ApiConfiguration, rsaService: RSAEncryptionService) {
        self.configuration = configuration
        self.rsaService = rsaService
        provider = ApiRequestProvider(configuration: configuration)
    }

    init(configuration: ApiConfiguration, rsaService: RSAEncryptionService, provider: ApiRequestProvider) {
        self.configuration = configuration
        self.rsaService = rsaService
        self.provider = provider
    }

    /// Authenticate user and establish session with vehicle API using RSA-encrypted authentication
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    func login(username: String, password: String) async throws -> AuthorizationData {
        cleanCookies()
        // Step 0: Get connector authorization (handles 302 redirect to get next_uri)
        let referer: String
        do {
            referer = try await fetchConnectorAuthorization()
            os_log(.info, log: Logger.api, "Retrieved referer: %{public}@", referer)
        } catch {
            os_log(.error, log: Logger.api, "Client connector authorization failed: %{public}@", error.localizedDescription)
            throw AuthenticationError.clientConfigurationFailed
        }

        // Step 1: Get client configuration
        let clientConfig = try await fetchClientConfiguration(referer: referer)
        os_log(.info, log: Logger.api, "Client configured for: %{public}@", clientConfig.clientName)
        
        // Step 2: Check if password encryption is enabled
        let encryptionSettings = try await fetchPasswordEncryptionSettings(referer: referer)
        guard encryptionSettings.useEnabled && encryptionSettings.value1 == "true" else {
            throw AuthenticationError.encryptionSettingsFailed
        }
        
        // Step 3: Get RSA certificate for password encryption
        let rsaKey: RSAEncryptionService.RSAKeyData
        do {
            rsaKey = try await fetchRSACertificate(referer: referer)
        } catch {
            os_log(.error, log: Logger.api, "Fetch RSA Certificate failed: %{public}@", error.localizedDescription)
            throw AuthenticationError.certificateRetrievalFailed
        }
        // Step 4: Initialize OAuth2 flow
        let csrfToken = try await initializeOAuth2(referer: referer)

        // Step 5: Sign in with encrypted password
        let authorizationCode = try await signIn(
            referer: referer,
            username: username,
            password: password,
            rsaKey: rsaKey,
            csrfToken: csrfToken
        )
        
        // Step 6: Exchange authorization code for tokens
        let tokenResponse: TokenResponse
        do {
            tokenResponse = try await exchangeCodeForTokens(authorizationCode: authorizationCode)
        } catch {
            os_log(.error, log: Logger.api, "Exchange code for token failed: %{public}@", error.localizedDescription)
            throw AuthenticationError.tokenExchangeFailed
        }

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

    /// Logout user and clean up session data
    /// - Throws: Network errors (non-critical - cleanup continues regardless)
    func logout() async throws {
        do {
            try await provider.request(with: .post, endpoint: .logout).empty()
            os_log(.info, log: Logger.auth, "Successfully logout")
        } catch {
            os_log(.error, log: Logger.auth, "Failed to logout: %{public}@", error.localizedDescription)
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
    func signIn(referer: String, username: String, password: String, rsaKey: RSAEncryptionService.RSAKeyData, csrfToken: String) async throws -> String {
        // Encrypt password
        let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKey)

        guard let connectorSessionKey = extractConnectorSessionKey(from: referer) else {
            throw AuthenticationError.sessionKeyNotFound
        }

        // Prepare form data
        let form: [String: String] = [
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

