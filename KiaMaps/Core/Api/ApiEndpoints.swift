//
//  ApiEndpoints.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

/// Defines all API endpoints for vehicle communication
/// Organized by endpoint type and relative base URL
enum ApiEndpoint: CustomStringConvertible {
    /// Specifies which base URL an endpoint is relative to
    enum RelativeTo {
        case base    // Main API base host
        case login   // Authentication host
        case spa     // Single Page Application API host
        case user    // User profile host
        case mqtt    // MQTT host
    }

    // MARK: - OAuth2 Authentication Endpoints
    case oauth2ConnectorAuthorize       // Initial OAuth2 authorization with connector
    case oauth2UserAuthorize           // User-specific OAuth2 authorization
    case oauth2Redirect               // OAuth2 redirect callback handler

    // MARK: - Login and Authentication Endpoints
    case loginConnectorClients(_ clinetId: String)  // Fetch client configuration for authentication
    case loginCodes                                 // Get password encryption settings
    case loginCertificates                         // Retrieve RSA certificate for password encryption
    case loginSignin                              // Submit login credentials
    case loginToken                              // Exchange authorization code for access token
    case loginRedirect                          // Handle login redirect

    // MARK: - Session Management
    case logout                                   // End user session
    case notificationRegister                    // Register device for push notifications
    case notificationRegisterWithDeviceId(UUID) // Register with specific device ID

    // MARK: - User Profile
    case userProfile                             // Retrieve user profile information

    // MARK: - Vehicle Data Endpoints
    case vehicles                               // List all user vehicles
    case refreshVehicle(UUID)                  // Request fresh vehicle status update
    case refreshCCS2Vehicle(UUID)             // Request fresh status (CCS2 protocol)
    case vehicleCachedStatus(UUID)           // Get cached vehicle status
    case vehicleCachedCCS2Status(UUID)      // Get cached status (CCS2 protocol)
    
    // MARK: - Climate Control Endpoints
    case startClimate(UUID)                   // Start climate control with settings
    case stopClimate(UUID)                   // Stop climate control

    // MARK: - MQTT Endpoints
    case mqttDeviceHost                    // Get address for MQTT broker
    case mqttRegisterDevice               // To Register device for MQTT broker
    case mqttVehicleMetadata             // Get vehicle metadata for MQTT broker
    case mqttDeviceProtocol             // Set what protocols are allowed in MQTT broker
    case mqttConnectionState           // To get connection state with MQTT broker

    /// Returns the endpoint path and its relative base URL
    /// - Returns: Tuple containing the path string and which base URL it's relative to
    var path: (String, RelativeTo) {
        switch self {
        case .oauth2ConnectorAuthorize:
            ("api/v1/user/oauth2/connector/common/authorize", .base)
        case .oauth2UserAuthorize:
            ("auth/api/v2/user/oauth2/authorize", .login)
        case .oauth2Redirect:
            ("api/v1/user/oauth2/redirect", .base)
        case let .loginConnectorClients(clientId):
            ("api/v1/clients/\(clientId)", .login)
        case .loginCodes:
            ("api/v1/commons/codes/HMG_DYNAMIC_CODE/details/PASSWORD_ENCRYPTION", .login)
        case .loginCertificates:
            ("auth/api/v1/accounts/certs", .login)
        case .loginSignin:
            ("auth/account/signin", .login)
        case .loginToken:
            ("auth/api/v2/user/oauth2/token", .login)
        case .loginRedirect:
            ("auth/redirect", .login)
        case .notificationRegister:
            ("notifications/register", .spa)
        case let .notificationRegisterWithDeviceId(deviceId):
            ("notifications/\(deviceId.formatted)/register", .spa)
        case .logout:
            ("devices/logout", .spa)
        case .userProfile:
            ("profile", .user)
        case .vehicles:
            ("vehicles", .spa)
        case let .refreshVehicle(vehicleId):
            ("vehicles/\(vehicleId.formatted)/status", .spa)
        case let .vehicleCachedStatus(vehicleId):
            ("vehicles/\(vehicleId.formatted)/status/latest", .spa)
        case let .refreshCCS2Vehicle(vehicleId):
            ("vehicles/\(vehicleId.formatted)/ccs2/carstatus", .spa)
        case let .vehicleCachedCCS2Status(vehicleId):
            ("vehicles/\(vehicleId.formatted)/ccs2/carstatus/latest", .spa)
        case let .startClimate(vehicleId):
            ("vehicles/\(vehicleId.formatted)/control/temperature", .spa)
        case let .stopClimate(vehicleId):
            ("vehicles/\(vehicleId.formatted)/control/temperature/off", .spa)
        case .mqttDeviceHost:
            ("api/v3/servicehub/device/host", .mqtt)
        case .mqttRegisterDevice:
            ("api/v3/servicehub/device/register", .mqtt)
        case .mqttVehicleMetadata:
            ("api/v3/servicehub/vehicles/metadatalist", .mqtt)
        case .mqttDeviceProtocol:
            ("api/v3/servicehub/device/protocol", .mqtt)
        case .mqttConnectionState:
            ("api/v3/vstatus/connstate", .mqtt)
        }
    }

    /// Human-readable description of the endpoint for logging and debugging
    var description: String {
        switch self {
        case .oauth2ConnectorAuthorize:
            "oauth2Authorize"
        case .oauth2UserAuthorize:
            "oauth2UserAuthorize"
        case .oauth2Redirect:
            "oauth2Authorize"
        case .loginConnectorClients:
            "loginConnectorClients"
        case .loginCodes:
            "loginCodes"
        case .loginCertificates:
            "loginCertificates"
        case .loginSignin:
            "loginSignin"
        case .loginToken:
            "loginToken"
        case .loginRedirect:
            "loginRedirect"
        case .logout:
            "logout"
        case .notificationRegister:
            "notificationRegister"
        case .notificationRegisterWithDeviceId:
            "notificationRegisterWithDeviceId"
        case .userProfile:
            "userProfile"
        case .vehicles:
            "vehicles"
        case .refreshVehicle:
            "refreshVehicle"
        case .vehicleCachedStatus:
            "vehicleCachedStatus"
        case .refreshCCS2Vehicle:
            "refreshCCS2Vehicle"
        case .vehicleCachedCCS2Status:
            "vehicleCachedCCS2Status"
        case .startClimate:
            "startClimate"
        case .stopClimate:
            "stopClimate"
        case .mqttDeviceHost:
            "mqttDeviceHost"
        case .mqttRegisterDevice:
            "mqttDeviceHost"
        case .mqttVehicleMetadata:
            "mqttVehicleMetadata"
        case .mqttDeviceProtocol:
            "mqttDeviceProtocol"
        case .mqttConnectionState:
            "mqttConnectionState"
        }
    }
}

private extension UUID {
    /// Formats UUID for use in API endpoints (lowercase string representation)
    var formatted: String {
        uuidString.lowercased()
    }
}
