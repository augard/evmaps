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
    private let loginRedirectUri: String
    private let provider: ApiRequestProvider

    init(configuration: ApiConfiguration, rsaService: RSAEncryptionService) {
        self.configuration = configuration
        self.rsaService = rsaService
        self.loginRedirectUri = "\(configuration.baseUrl):\(configuration.port)/api/v1/user/oauth2/redirect"
        provider = ApiRequestProvider(configuration: configuration)
    }

    /// Authenticate user and establish session with vehicle API using RSA-encrypted authentication
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    func login(username: String, password: String) async throws -> AuthorizationData {
        cleanCookies()
        let authAPI = NewAuthenticationAPI(configuration: configuration)
        
        // Step 0: Get connector authorization (handles 302 redirect to get next_uri)
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


    /// Clear all HTTP cookies to ensure clean authentication state
    func cleanCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
