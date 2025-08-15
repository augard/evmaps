//
//  ApiConfiguration.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import UIKit

/// Enumeration representing supported vehicle brands
enum ApiBrand: String {
    case kia
    case hyundai
    case genesis

    /// Returns the appropriate API configuration for the brand and region combination
    /// - Parameter region: The geographic region for API endpoints
    /// - Returns: Region-specific API configuration for the brand
    func configuration(for region: ApiRegion) -> ApiConfiguration {
        switch self {
        case .kia, .hyundai, .genesis:
            switch region {
            case .europe:
                guard let configuration = ApiConfigurationEurope(rawValue: rawValue) else {
                    fatalError("Api region not supported")
                }
                return configuration
            case .usa, .canada, .china, .korea:
                fatalError("Api region not supported")
            }
        }
    }
}

/// Protocol defining required configuration properties for API communication
protocol ApiConfiguration {
    /// Brand identifier key (e.g., "kia", "hyundai", "genesis")
    var key: String { get }
    
    /// Human-readable brand name
    var name: String { get }
    
    /// API port number for connections
    var port: Int { get }
    
    /// Service agent string for API requests
    var serviceAgent: String { get }
    
    /// User agent string identifying the client application
    var userAgent: String { get }
    
    /// Accept header for HTTP content negotiation
    var acceptHeader: String { get }
    
    /// Base API host URL for vehicle data endpoints
    var baseHost: String { get }
    
    /// Authentication host URL for login and OAuth2 flow
    var loginHost: String { get }

    /// MQTT host URL for broker
    var mqttHost: String { get }

    /// Unique service identifier for API authentication
    var serviceId: String { get }
    
    /// Application identifier for API access
    var appId: String { get }
    
    /// Sender ID for push notification registration
    var senderId: Int { get }
    
    /// OAuth2 client ID for authentication flow
    var authClientId: String { get }
    
    /// Encrypted configuration token for API requests
    var cfb: String { get }

    /// Short character name for brand used for API
    var brandCode: String { get }

    /// Push notification type ("APNS" for iOS, "GCM" for Android)
    var pushType: String { get }
}

/// European region API configuration for supported vehicle brands
/// Provides brand-specific endpoints, credentials, and service identifiers for EU market
enum ApiConfigurationEurope: String, ApiConfiguration {
    case kia
    case hyundai
    case genesis

    var key: String {
        switch self {
        case .kia:
            "kia"
        case .hyundai:
            "hyundai"
        case .genesis:
            "genesis"
        }
    }

    var name: String {
        switch self {
        case .kia:
            "Kia"
        case .hyundai:
            "Hyundai"
        case .genesis:
            "Genesis"
        }
    }

    var port: Int {
        switch self {
        case .kia:
            8080
        case .hyundai, .genesis:
            443
        }
    }

    var serviceAgent: String {
        "okhttp/3.12.0"
    }

    var userAgent: String {
        let device = UIDevice.current
        return "EU_BlueLink/2.1.18 (com.kia.connect.eu; build:10560; \(device.systemName) \(device.systemVersion)) Alamofire/5.8.0"
    }

    var acceptHeader: String {
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
    }

    var baseHost: String {
        switch self {
        case .kia:
            "https://prd.eu-ccapi.kia.com"
        case .hyundai:
            "https://prd.eu-ccapi.hyundai.com"
        case .genesis:
            "https://prd-eu-ccapi.genesis.com"
        }
    }

    var loginHost: String {
        "https://idpconnect-eu.\(key).com"
    }

    var mqttHost: String {
        "https://egw-svchub-ccs-\(brandCode.lowercased())-eu.eu-central.hmgmobility.com:31010"
    }

    var serviceId: String {
        switch self {
        case .kia:
            "fdc85c00-0a2f-4c64-bcb4-2cfb1500730a"
        case .hyundai:
            "6d477c38-3ca4-4cf3-9557-2a1929a94654"
        case .genesis:
            "3020afa2-30ff-412a-aa51-d28fbe901e10"
        }
    }

    var appId: String {
        switch self {
        case .kia:
            "a2b8469b-30a3-4361-8e13-6fceea8fbe74"
        case .hyundai:
            "014d2225-8495-4735-812d-2616334fd15d"
        case .genesis:
            "f11f2b86-e0e7-4851-90df-5600b01d8b70"
        }
    }

    var senderId: Int {
        199_360_397_125
    }

    var authClientId: String {
        switch self {
        case .kia:
            "572e0304-5f8d-4b4c-9dd5-41aa84eed160"
        case .hyundai:
            "64621b96-0f0d-11ec-82a8-0242ac130003"
        case .genesis:
            "3020afa2-30ff-412a-aa51-d28fbe901e10"
        }
    }

    var cfb: String {
        switch self {
        case .kia:
            "wLTVxwidmH8CfJYBWSnHD6E0huk0ozdiuygB4hLkM5XCgzAL1Dk5sE36d/bx5PFMbZs="
        case .hyundai:
            "RFtoRq/vDXJmRndoZaZQyfOot7OrIqGVFj96iY2WL3yyH5Z/pUvlUhqmCxD2t+D65SQ="
        case .genesis:
            "RFtoRq/vDXJmRndoZaZQyYo3/qFLtVReW8P7utRPcc0ZxOzOELm9mexvviBk/qqIp4A="
        }
    }

    var brandCode: String {
        switch self {
        case .kia:
            "K"
        case .hyundai:
            "H"
        case .genesis:
            "G"
        }
    }

    var pushType: String {
        if self == .kia {
            "APNS"
        } else {
            "GCM"
        }
    }
}

/// Geographic regions where the API is available
/// Currently only Europe is fully supported
enum ApiRegion {
    case europe
    case usa
    case canada
    case china
    case korea
}

// MARK: - Mock Configuration for Testing

extension ApiConfiguration where Self == MockApiConfiguration {
    static var mock: MockApiConfiguration {
        MockApiConfiguration()
    }
}

/// Mock API configuration for unit testing and development
/// Provides test-safe values that don't connect to real services
struct MockApiConfiguration: ApiConfiguration {
    var key: String = "mock"
    var name: String = "Mock Configuration"
    var port: Int = 8080
    var serviceAgent: String = "MockAgent/1.0.0"
    var userAgent: String = "MockUserAgent/1.0.0 (com.test.mock; build:1; iOS 17.0) Test/1.0"
    var acceptHeader: String = "application/json, text/html"
    var baseHost: String = "https://mock.test.com"
    var loginHost: String = "https://idpconnect-mock.test.com"
    var mqttHost: String = "https://mock.hmgmobility.com:31010"
    var serviceId: String = "mock-service-id-123"
    var appId: String = "mock-app-id-456"
    var senderId: Int = 123456789
    var authClientId: String = "mock-auth-client-789"
    var cfb: String = "mockCfbToken123="
    var brandCode: String = "M"
    var pushType: String = "MOCK"
}
