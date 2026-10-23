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
    /// The API configuration containing endpoints, credentials, and service identifiers
    let configuration: ApiConfiguration

    /// Current authorization data including access tokens and device information
    /// Managed through the provider for consistent state management
    var authorization: AuthorizationData? {
        get {
            provider.authorization
        }
        set {
            provider.authorization = newValue
        }
    }

    /// Service for RSA encryption operations, used for password encryption during authentication
    let rsaService: RSAEncryptionService
    
    /// Provider that handles actual API request execution and token management
    let provider: ApiRequestProvider

    lazy var kiaLogin = KiaOneAppAuthentication(configuration: configuration, rsaService: rsaService)

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

    func webLoginUrl() throws -> URL? {
        if configuration.key == "kia" {
            return try kiaLogin.authorizationURL()
        }
        let queryItems = [
            URLQueryItem(name: "client_id", value: configuration.serviceId),
            URLQueryItem(name: "redirect_uri", value: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: "ccsp"),
        ]

        return try provider.request(
            endpoint: .oauth2UserAuthorize,
            queryItems: queryItems,
            headers: commonNavigationHeaders()
        ).urlRequest.url
    }

    /// Authenticate user and establish session with vehicle API using RSA-encrypted authentication
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    ///   - recaptchaToken: Optional reCAPTCHA verification token
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    func login(username: String, password: String, recaptchaToken: String? = nil) async throws -> AuthorizationData {
        if configuration.key == "kia" {
            let authorization = try await kiaLogin.login(username: username, password: password)
            provider.authorization = authorization
            return authorization
        }
        cleanCookies()
        // Step 0: Get connector authorization (handles 302 redirect to get next_uri)
        let referer: String
        do {
            referer = try await fetchConnectorAuthorization()
            logInfo("Retrieved referer: \(referer)", category: .api)
        } catch {
            logError("Client connector authorization failed: \(error.localizedDescription)", category: .api)
            throw AuthenticationError.clientConfigurationFailed
        }

        // Step 1: Get client configuration
        let clientConfig = try await fetchClientConfiguration(referer: referer)
        logInfo("Client configured for: \(clientConfig.clientName)", category: .api)
        
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
            logError("Fetch RSA Certificate failed: \(error.localizedDescription)", category: .api)
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
            csrfToken: csrfToken,
            recaptchaToken: recaptchaToken
        )

        // Step 6: Exchange authorization code for tokens
        return try await login(authorizationCode: authorizationCode)
    }

    func login(authorizationCode: String) async throws -> AuthorizationData {
        if configuration.key == "kia" {
            let authorization = try await kiaLogin.login(authorizationCode: authorizationCode)
            provider.authorization = authorization
            return authorization
        }
        // Step 6: Exchange authorization code for tokens
        let tokenResponse: TokenResponse
        do {
            tokenResponse = try await exchangeCodeForTokens(authorizationCode: authorizationCode)
        } catch {
            logError("Exchange code for token failed: \(error.localizedDescription)", category: .api)
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
            logInfo("Successfully logout", category: .auth)
        } catch {
            logError("Failed to logout: \(error.localizedDescription)", category: .auth)
        }
        provider.authorization = nil
        cleanCookies()
    }

    /// Retrieve list of vehicles associated with the user account
    /// - Returns: Complete vehicle response containing all registered vehicles
    /// - Throws: Network errors or authentication failures
    func vehicles() async throws -> VehicleResponse {
        guard authorization != nil else {
            throw ApiError.unauthorized
        }
        return try await provider.request(endpoint: .vehicles).response()
    }

    /// Request fresh vehicle status update from the vehicle
    /// - Parameter vehicleId: The vehicle's unique identifier
    /// - Returns: Operation result ID for tracking the refresh request
    /// - Note: Uses CCS2 endpoint if supported, fallback to standard endpoint
    /// - Throws: Network errors or vehicle communication failures
    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID {
        guard let authorization = authorization else {
            throw ApiError.unauthorized
        }
        let endpoint: ApiEndpoint = authorization.isCcuCCS2Supported == true ? .refreshCCS2Vehicle(vehicleId) : .refreshVehicle(vehicleId)
        return try await provider.request(endpoint: endpoint).responseEmpty().resultId
    }

    /// Retrieve cached vehicle status (last known state)
    /// - Parameter vehicleId: The vehicle's unique identifier
    /// - Returns: Complete vehicle status including battery, location, and system states
    /// - Note: Uses CCS2 endpoint if supported, fallback to standard endpoint
    /// - Throws: Network errors or data parsing failures
    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStateResponse {
        guard let authorization = authorization else {
            throw ApiError.unauthorized
        }
        let endpoint: ApiEndpoint = authorization.isCcuCCS2Supported == true ? .vehicleCachedCCS2Status(vehicleId) : .vehicleCachedStatus(vehicleId)
        return try await provider.request(endpoint: endpoint).response()
    }

    /// Retrieve user profile information
    /// - Returns: User profile data as JSON string
    /// - Throws: Network errors or authentication failures
    func profile() async throws -> String {
        guard authorization != nil else {
            throw ApiError.unauthorized
        }
        return try await provider.request(endpoint: .userProfile).string()
    }
    
    // MARK: - Climate Control
    
    /// Start climate control with specified options
    /// - Parameters:
    ///   - vehicleId: The vehicle ID
    ///   - options: Climate control configuration options
    ///   - pin: Vehicle PIN (required for climate control)
    /// - Returns: Operation result ID for tracking
    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin: String) async throws -> UUID {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }
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
        
        return try await provider.request(
            with: .post,
            endpoint: .startClimate(vehicleId),
            encodable: request
        ).responseEmpty().resultId
    }
    
    /// Stop climate control
    /// - Parameter vehicleId: The vehicle ID
    /// - Returns: Operation result ID for tracking
    func stopClimate(_ vehicleId: UUID) async throws -> UUID {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }
        return try await provider.request(
            with: .post,
            endpoint: .stopClimate(vehicleId)
        ).responseEmpty().resultId
    }
}

extension Api {
    // MARK: - MQTT Service Hub Methods

    /**
     * MQTT Step 1: Get device host information for MQTT connection
     * GET /api/v3/servicehub/device/host
     */
    func fetchMQTTDeviceHost() async throws -> MQTTHostInfo {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let response: MQTTHostResponse = try await provider.request(endpoint: .mqttDeviceHost).data()
        return MQTTHostInfo(
            host: response.mqtt.host,
            port: response.mqtt.port,
            ssl: response.mqtt.ssl
        )
    }

    /**
     * MQTT Step 2: Register device as mobile unit for MQTT communication
     * POST /api/v3/servicehub/device/register
     */
    func registerMQTTDevice() async throws -> MQTTDeviceInfo {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let deviceUUID = "\(UUID().uuidString)_UVO"
        let request = DeviceRegisterRequest(unit: "mobile", uuid: deviceUUID)
        let response: DeviceRegisterResponse = try await provider.request(endpoint: .mqttRegisterDevice, encodable: request).data()

        return MQTTDeviceInfo(
            clientId: response.clientId,
            deviceId: response.deviceId,
            uuid: deviceUUID
        )
    }

    /**
     * MQTT Step 3: Get vehicle metadata and supported protocols for MQTT
     * GET /api/v3/servicehub/vehicles/metadatalist?carId=<carId>&brand=K
     */
    func fetchMQTTVehicleMetadata(for vehicleId: UUID, clientId: String) async throws -> [MQTTVehicleMetadata] {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let response: VehicleMetadataResponse = try await provider.request(
            endpoint: .mqttVehicleMetadata,
            queryItems: [
                URLQueryItem(name: "carId", value: vehicleId.uuidString),
                URLQueryItem(name: "brand", value: configuration.brandCode)
            ],
            headers: [
                "client-id": clientId
            ]
        ).data()

        return response.vehicles
    }

    /**
     * MQTT Step 4: Subscribe to specific vehicle protocols for MQTT communication
     * POST /api/v3/servicehub/device/protocol
     */
    func subscribeMQTTVehicleProtocols(for vehicleId: UUID, clientId: String, protocolId: any MQTTProtocol, protocols: [any MQTTProtocol]) async throws {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        // Subscribe to CCU (Car Control Unit) real-time updates
        let request = ProtocolSubscriptionRequest(
            protocols: protocols,
            protocolId: protocolId,
            carId: vehicleId,
            brand: configuration.brandCode
        )

        try await provider.request(
            endpoint: .mqttDeviceProtocol,
            headers: [
                "client-id": clientId
            ],
            encodable: request
        ).empty()
    }

    /**
     * MQTT Step 5: Check MQTT connection state after protocol subscription
     * GET /api/v3/vstatus/connstate?clientId=<clientId>
     */
    func checkMQTTConnectionState(clientId: String) async throws -> ConnectionStateResponse {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        return try await provider.request(
            endpoint: .mqttConnectionState,
            queryItems: [
                URLQueryItem(name: "clientId", value: clientId),
            ],
            headers: [
                "client-id": clientId
            ]
        ).data()
    }
}

