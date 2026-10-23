//
//  Api.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 28.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

typealias AuthorizationCallback = (code: String, state: String, loginSuccess: Bool)

protocol VehicleApiProvider {
    func webLoginUrl() throws -> URL?
    /// Parses a web-login navigation. Returns nil when the URL is not this provider's OAuth callback.
    func authorizationCallback(from url: URL) throws -> AuthorizationCallback?
    func login(username: String, password: String, recaptchaToken: String?) async throws -> AuthorizationData
    func login(authorizationCode: String) async throws -> AuthorizationData
    func refreshAuthorization(_ authorization: AuthorizationData) async throws -> AuthorizationData
    func logout() async throws
    func vehicles() async throws -> VehicleResponse
    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID
    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusSnapshot
    func profile() async throws -> String
    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin: String) async throws -> UUID
    func stopClimate(_ vehicleId: UUID) async throws -> UUID
}

enum VehicleApiProviderFactory {
    static func provider(for api: Api) -> VehicleApiProvider {
        switch api.configuration.apiProviderKind {
        case .hmg:
            HMGVehicleApiProvider(api: api)
        case .porsche:
            PorscheVehicleApiProvider(api: api)
        }
    }
}

final class HMGVehicleApiProvider: VehicleApiProvider {
    private unowned let api: Api
    private let authClient: HMGAuthClient
    private let vehicleClient: HMGVehicleClient
    private let kiaLogin: KiaOneAppAuthentication?

    init(api: Api) {
        self.api = api
        authClient = api.hmgAuthClient
        vehicleClient = HMGVehicleClient(provider: api.provider)
        kiaLogin = api.configuration.key == "kia"
            ? KiaOneAppAuthentication(configuration: api.configuration, rsaService: api.rsaService) : nil
    }

    func webLoginUrl() throws -> URL? {
        if let kiaLogin { return try kiaLogin.authorizationURL() }
        return try authClient.makeAuthorizeURL()
    }
    func authorizationCallback(from url: URL) throws -> AuthorizationCallback? {
        if let kiaLogin {
            guard kiaLogin.isCallback(url) else { return nil }
            return (try kiaLogin.authorizationCode(from: url), kiaLogin.state, true)
        }
        return try authClient.authorizationCallback(from: url)
    }
    func login(username: String, password: String, recaptchaToken: String?) async throws -> AuthorizationData {
        if let kiaLogin {
            let authorization = try await kiaLogin.login(username: username, password: password)
            api.authorization = authorization
            return authorization
        }
        return try await authClient.authenticate(username: username, password: password, recaptchaToken: recaptchaToken)
    }

    func login(authorizationCode: String) async throws -> AuthorizationData {
        if let kiaLogin {
            let authorization = try await kiaLogin.login(authorizationCode: authorizationCode)
            api.authorization = authorization
            return authorization
        }
        return try await authClient.exchangeAuthorizationCode(authorizationCode)
    }

    func refreshAuthorization(_ authorization: AuthorizationData) async throws -> AuthorizationData {
        // CCI refresh requires its complete token set; never send its refresh token to legacy OAuth.
        guard authorization.effectiveSource != .oneApp else { throw KiaLoginError.reauthenticationRequired }
        return try await authClient.refreshAuthorization(authorization)
    }

    func logout() async throws { try await authClient.logout() }
    func vehicles() async throws -> VehicleResponse { try await vehicleClient.vehicles() }
    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID { try await vehicleClient.refreshVehicle(vehicleId) }
    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusSnapshot { try await vehicleClient.vehicleCachedStatus(vehicleId) }
    func profile() async throws -> String { try await vehicleClient.profile() }
    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin: String) async throws -> UUID {
        try await vehicleClient.startClimate(vehicleId, options: options, pin: pin)
    }

    func stopClimate(_ vehicleId: UUID) async throws -> UUID {
        try await vehicleClient.stopClimate(vehicleId)
    }
}

final class PorscheVehicleApiProvider: VehicleApiProvider {
    private unowned let api: Api
    private let authClient: PorscheAuthClient
    private let commandPollIntervalNanoseconds: UInt64
    private let storeAuthorization: (AuthorizationData) -> Void
    private var vinByVehicleID: [UUID: String] = [:]

    init(
        api: Api,
        authClient: PorscheAuthClient? = nil,
        commandPollIntervalNanoseconds: UInt64 = 1_000_000_000,
        storeAuthorization: @escaping (AuthorizationData) -> Void = { Authorization.store(data: $0) }
    ) {
        self.api = api
        self.commandPollIntervalNanoseconds = commandPollIntervalNanoseconds
        self.storeAuthorization = storeAuthorization
        if let authClient {
            self.authClient = authClient
        } else {
            self.authClient = PorscheAuthClient(configuration: Self.configuration(for: api))
        }
    }

    func webLoginUrl() throws -> URL? {
        try authClient.makeAuthorizeURL()
    }

    func authorizationCallback(from url: URL) throws -> AuthorizationCallback? {
        try authClient.authorizationCallback(from: url)
    }

    func login(username: String, password: String, recaptchaToken _: String?) async throws -> AuthorizationData {
        let tokenSet = try await authClient.authenticate(username: username, password: password)
        let authorization = authorizationData(from: tokenSet, existing: api.authorization)
        api.authorization = authorization
        return authorization
    }

    func login(authorizationCode: String) async throws -> AuthorizationData {
        let tokenSet = try await authClient.exchangeAuthorizationCode(authorizationCode)
        let authorization = authorizationData(from: tokenSet, existing: api.authorization)
        api.authorization = authorization
        return authorization
    }

    func refreshAuthorization(_ authorization: AuthorizationData) async throws -> AuthorizationData {
        let tokenSet = try await authClient.refreshToken(authorization.refreshToken)
        return authorizationData(from: tokenSet, existing: authorization)
    }

    func logout() async throws {
        api.authorization = nil
        vinByVehicleID.removeAll()
    }

    func vehicles() async throws -> VehicleResponse {
        let payload = try await authorizedJSONObject(endpoint: .vehicles)
        guard let vehiclesPayload = payload as? [PorscheVehicleMapper.JSONObject] else {
            throw PorscheApiError.decodingFailed("vehicle list payload")
        }
        let response = try PorscheVehicleMapper.mapVehicles(from: vehiclesPayload)
        vinByVehicleID = Dictionary(uniqueKeysWithValues: response.vehicles.map { ($0.vehicleId, $0.vin) })
        return response
    }

    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID {
        let vin = try await resolveVIN(for: vehicleId)
        _ = try await authorizedJSONObject(
            endpoint: .vehicle(vin),
            queryItems: measurementQueryItems(wakeUp: true)
        )
        return vehicleId
    }

    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusSnapshot {
        let vin = try await resolveVIN(for: vehicleId)
        let payload = try await authorizedJSONObject(
            endpoint: .vehicle(vin),
            queryItems: measurementQueryItems(wakeUp: false)
        )
        guard let statusPayload = payload as? PorscheVehicleMapper.JSONObject else {
            throw PorscheApiError.decodingFailed("vehicle status payload")
        }
        return try PorscheVehicleMapper.mapVehicleState(from: statusPayload)
    }

    func profile() async throws -> String {
        let payload = try await authorizedJSONObject(endpoint: .profile)
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin _: String) async throws -> UUID {
        guard options.isValid else {
            if !options.isTemperatureValid {
                throw ClimateControlError.invalidTemperature(options.temperature)
            }
            if !options.areSeatLevelsValid {
                throw ClimateControlError.invalidSeatLevel(-1)
            }
            throw ClimateControlError.invalidDuration(options.duration)
        }
        let vin = try await resolveVIN(for: vehicleId)
        return try await sendCommand(.climateOn(vin: vin, temperatureC: Double(options.temperature)))
    }

    func stopClimate(_ vehicleId: UUID) async throws -> UUID {
        let vin = try await resolveVIN(for: vehicleId)
        return try await sendCommand(.climateOff(vin: vin))
    }

    private static func configuration(for api: Api) -> PorscheApiConfiguration {
        guard let configuration = api.configuration as? PorscheApiConfiguration else {
            fatalError("Porsche provider requires PorscheApiConfiguration")
        }
        return configuration
    }

    private var configuration: PorscheApiConfiguration {
        Self.configuration(for: api)
    }

    private func authorizationData(from tokenSet: PorscheTokenSet, existing: AuthorizationData?) -> AuthorizationData {
        AuthorizationData(
            stamp: existing?.stamp ?? "porsche",
            deviceId: existing?.deviceId ?? UUID(),
            accessToken: tokenSet.accessToken,
            expiresIn: tokenSet.expiresIn,
            refreshToken: tokenSet.refreshToken,
            isCcuCCS2Supported: true,
            providerKind: "porsche",
            tokenIssuer: configuration.loginHost,
            tokenAudience: configuration.audience,
            tokenScope: tokenSet.scope ?? configuration.scope,
            source: existing?.source
        )
    }

    private func resolveVIN(for vehicleId: UUID) async throws -> String {
        if let vin = vinByVehicleID[vehicleId] {
            return vin
        }
        let vehicles = try await self.vehicles()
        guard let vehicle = vehicles.vehicles.first(where: { $0.vehicleId == vehicleId }) else {
            throw PorscheApiError.missingVehicle(vehicleId.uuidString)
        }
        return vehicle.vin
    }

    private func measurementQueryItems(wakeUp: Bool) -> [URLQueryItem] {
        var items = PorscheMeasurementCatalog.overview.map { URLQueryItem(name: "mf", value: $0) }
        if wakeUp {
            items.append(URLQueryItem(name: "wakeUpJob", value: UUID().uuidString))
        }
        return items
    }

    private func authorizedJSONObject(
        endpoint: PorscheApiEndpoint,
        method: ApiMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> Any {
        guard let authorization = api.authorization else {
            throw ApiError.unauthorized
        }

        do {
            let responseData = try await api.provider.request(
                with: method,
                endpoint: endpoint,
                queryItems: queryItems,
                body: body
            ).rawData(acceptStatusCodes: [200, 202])

            if responseData.isEmpty {
                return [:]
            }
            return try JSONSerialization.jsonObject(with: responseData)
        } catch ApiError.unauthorized {
            guard retryOnUnauthorized else {
                throw ApiError.unauthorized
            }
            let refreshedTokens = try await authClient.refreshToken(authorization.refreshToken)
            let refreshedAuthorization = authorizationData(from: refreshedTokens, existing: authorization)
            api.authorization = refreshedAuthorization
            storeAuthorization(refreshedAuthorization)
            return try await authorizedJSONObject(
                endpoint: endpoint,
                method: method,
                queryItems: queryItems,
                body: body,
                retryOnUnauthorized: false
            )
        }
    }

    private func sendCommand(_ request: PorscheCommandRequest) async throws -> UUID {
        let payload = try await authorizedJSONObject(
            endpoint: .commands(request.vin),
            method: .post,
            body: PorscheVehicleMapper.commandBody(for: request)
        )

        guard let json = payload as? PorscheVehicleMapper.JSONObject,
              let status = json["status"] as? PorscheVehicleMapper.JSONObject,
              let identifier = status["id"] as? String,
              let requestID = UUID(uuidString: identifier)
        else {
            throw PorscheApiError.missingCommandRequestId
        }

        let resultString = (status["result"] as? String) ?? "UNKNOWN"
        switch PorscheCommandExecutionState(rawValue: resultString) ?? .unknown {
        case .performed:
            break
        case .error:
            throw PorscheApiError.commandFailed(resultString)
        case .accepted, .unknown:
            try await pollCommand(vin: request.vin, requestID: requestID)
        }
        return requestID
    }

    private func pollCommand(vin: String, requestID: UUID) async throws {
        for _ in 0..<10 {
            if commandPollIntervalNanoseconds > 0 {
                try await Task.sleep(nanoseconds: commandPollIntervalNanoseconds)
            }
            let payload = try await authorizedJSONObject(endpoint: .commandStatus(vin: vin, requestId: requestID.uuidString))
            guard let json = payload as? PorscheVehicleMapper.JSONObject else {
                continue
            }
            let resultString = ((json["status"] as? PorscheVehicleMapper.JSONObject)?["result"] as? String) ?? "UNKNOWN"
            switch PorscheCommandExecutionState(rawValue: resultString) ?? .unknown {
            case .performed:
                return
            case .error:
                throw PorscheApiError.commandFailed(resultString)
            case .accepted, .unknown:
                continue
            }
        }
        throw PorscheApiError.commandFailed("timeout")
    }

}

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
    private lazy var vehicleApiProvider: VehicleApiProvider = VehicleApiProviderFactory.provider(for: self)
    fileprivate lazy var hmgAuthClient = HMGAuthClient(configuration: configuration, provider: provider, rsaService: rsaService)
    private lazy var hmgMQTTClient = HMGMQTTClient(configuration: configuration, provider: provider)

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
        try vehicleApiProvider.webLoginUrl()
    }

    /// Authenticate user and establish session with vehicle API using RSA-encrypted authentication
    /// - Parameters:
    ///   - username: User's login username/email
    ///   - password: User's login password
    ///   - recaptchaToken: Optional reCAPTCHA verification token
    /// - Returns: Complete authorization data including tokens and device ID
    /// - Throws: Authentication errors, network errors, or validation failures
    func login(username: String, password: String, recaptchaToken: String? = nil) async throws -> AuthorizationData {
        try await vehicleApiProvider.login(username: username, password: password, recaptchaToken: recaptchaToken)
    }

    func login(authorizationCode: String) async throws -> AuthorizationData {
        try await vehicleApiProvider.login(authorizationCode: authorizationCode)
    }

    /// Exchange the stored refresh token for a new access token
    /// - Parameter authorization: Current authorization containing the refresh token
    /// - Returns: Authorization data with refreshed tokens; device ID and stamp are preserved
    func refreshAuthorization(_ authorization: AuthorizationData) async throws -> AuthorizationData {
        try await vehicleApiProvider.refreshAuthorization(authorization)
    }

    func extractAuthorizationCode(from location: URL) throws -> (code: String, state: String, loginSuccess: Bool) {
        try hmgAuthClient.extractAuthorizationCode(from: location)
    }

    func authorizationCallback(from url: URL) throws -> AuthorizationCallback? {
        try vehicleApiProvider.authorizationCallback(from: url)
    }

    /// Logout user and clean up session data
    /// - Throws: Network errors (non-critical - cleanup continues regardless)
    func logout() async throws {
        try await vehicleApiProvider.logout()
    }

    /// Retrieve list of vehicles associated with the user account
    /// - Returns: Complete vehicle response containing all registered vehicles
    /// - Throws: Network errors or authentication failures
    func vehicles() async throws -> VehicleResponse {
        try await vehicleApiProvider.vehicles()
    }

    /// Request fresh vehicle status update from the vehicle
    /// - Parameter vehicleId: The vehicle's unique identifier
    /// - Returns: Operation result ID for tracking the refresh request
    /// - Note: Uses CCS2 endpoint if supported, fallback to standard endpoint
    /// - Throws: Network errors or vehicle communication failures
    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID {
        try await vehicleApiProvider.refreshVehicle(vehicleId)
    }

    /// Retrieve cached vehicle status (last known state)
    /// - Parameter vehicleId: The vehicle's unique identifier
    /// - Returns: Complete vehicle status including battery, location, and system states
    /// - Note: Uses CCS2 endpoint if supported, fallback to standard endpoint
    /// - Throws: Network errors or data parsing failures
    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusSnapshot {
        try await vehicleApiProvider.vehicleCachedStatus(vehicleId)
    }

    /// Retrieve user profile information
    /// - Returns: User profile data as JSON string
    /// - Throws: Network errors or authentication failures
    func profile() async throws -> String {
        try await vehicleApiProvider.profile()
    }
    
    // MARK: - Climate Control
    
    /// Start climate control with specified options
    /// - Parameters:
    ///   - vehicleId: The vehicle ID
    ///   - options: Climate control configuration options
    ///   - pin: Vehicle PIN (required for climate control)
    /// - Returns: Operation result ID for tracking
    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin: String) async throws -> UUID {
        try await vehicleApiProvider.startClimate(vehicleId, options: options, pin: pin)
    }
    
    /// Stop climate control
    /// - Parameter vehicleId: The vehicle ID
    /// - Returns: Operation result ID for tracking
    func stopClimate(_ vehicleId: UUID) async throws -> UUID {
        try await vehicleApiProvider.stopClimate(vehicleId)
    }
}

extension Api {
    // MARK: - MQTT Service Hub Methods

    /**
     * MQTT Step 1: Get device host information for MQTT connection
     * GET /api/v3/servicehub/device/host
     */
    func fetchMQTTDeviceHost() async throws -> MQTTHostInfo {
        try await hmgMQTTClient.fetchDeviceHost()
    }

    /**
     * MQTT Step 2: Register device as mobile unit for MQTT communication
     * POST /api/v3/servicehub/device/register
     */
    func registerMQTTDevice() async throws -> MQTTDeviceInfo {
        try await hmgMQTTClient.registerDevice()
    }

    /**
     * MQTT Step 3: Get vehicle metadata and supported protocols for MQTT
     * GET /api/v3/servicehub/vehicles/metadatalist?carId=<carId>&brand=K
     */
    func fetchMQTTVehicleMetadata(for vehicleId: UUID, clientId: String) async throws -> [MQTTVehicleMetadata] {
        try await hmgMQTTClient.fetchVehicleMetadata(for: vehicleId, clientId: clientId)
    }

    /**
     * MQTT Step 4: Subscribe to specific vehicle protocols for MQTT communication
     * POST /api/v3/servicehub/device/protocol
     */
    func subscribeMQTTVehicleProtocols(for vehicleId: UUID, clientId: String, protocolId: any MQTTProtocol, protocols: [any MQTTProtocol]) async throws {
        try await hmgMQTTClient.subscribeVehicleProtocols(
            for: vehicleId,
            clientId: clientId,
            protocolId: protocolId,
            protocols: protocols
        )
    }

    /**
     * MQTT Step 5: Check MQTT connection state after protocol subscription
     * GET /api/v3/vstatus/connstate?clientId=<clientId>
     */
    func checkMQTTConnectionState(clientId: String) async throws -> ConnectionStateResponse {
        try await hmgMQTTClient.checkConnectionState(clientId: clientId)
    }
}
