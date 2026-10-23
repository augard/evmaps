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
    case porsche

    /// Returns the appropriate API configuration for the brand and region combination
    /// - Parameter region: The geographic region for API endpoints
    /// - Returns: Region-specific API configuration for the brand
    func configuration(for region: ApiRegion) -> ApiConfiguration {
        switch self {
        case .kia, .hyundai, .genesis:
            switch region {
            case .europe:
                guard let configuration = KiaApiConfigurationEurope(rawValue: rawValue) else {
                    fatalError("Api region not supported")
                }
                return configuration
            case .usa, .canada, .china, .korea:
                fatalError("Api region not supported")
            }
        case .porsche:
            switch region {
            case .europe:
                return PorscheApiConfiguration.europe
            case .usa:
                return PorscheApiConfiguration.usa
            case .canada, .china, .korea:
                fatalError("Api region not supported")
            }
        }
    }
}

enum ApiProviderKind {
    case hmg
    case porsche
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

    /// Name for brand
    var brandName: String { get }

    /// Push notification type ("APNS" for iOS, "GCM" for Android)
    var pushType: String { get }

    /// Backend provider kind.
    var apiProviderKind: ApiProviderKind { get }
}

enum PorscheApiConfiguration: String, ApiConfiguration {
    case europe
    case usa

    var key: String {
        "porsche"
    }

    var name: String {
        "Porsche"
    }

    var port: Int {
        443
    }

    var serviceAgent: String {
        "PorscheConnect/1.0"
    }

    var userAgent: String {
        let device = UIDevice.current
        return "MyPorscheApp/1.0 (\(device.systemName) \(device.systemVersion))"
    }

    var acceptHeader: String {
        "application/json"
    }

    // HMG-only host fields; kept for protocol compatibility.
    var baseHost: String {
        switch self {
        case .europe:
            "https://api.ppa.porsche.com"
        case .usa:
            "https://api.ppa.porsche.com"
        }
    }

    var loginHost: String {
        "https://identity.porsche.com"
    }

    var mqttHost: String {
        "https://api.ppa.porsche.com"
    }

    var serviceId: String {
        switch self {
        case .europe:
            "porsche-eu-service"
        case .usa:
            "porsche-us-service"
        }
    }

    var appId: String {
        "porsche-app-id"
    }

    var senderId: Int {
        0
    }

    var authClientId: String {
        "XhygisuebbrqQ80byOuU5VncxLIm8E6H"
    }

    var xClientId: String {
        "41843fb4-691d-4970-85c7-2673e8ecef40"
    }

    var cfb: String {
        // No HMG-style stamp for Porsche.
        "cG9yc2NoZS1tb2NrLWNmYi10b2tlbi0xMjM0NTY3ODkwMTIzNA=="
    }

    var brandCode: String {
        "P"
    }

    var brandName: String {
        "Porsche"
    }

    var pushType: String {
        "APNS"
    }

    var apiProviderKind: ApiProviderKind {
        .porsche
    }

    var audience: String {
        "https://api.porsche.com"
    }

    var redirectUri: String {
        "my-porsche-app://auth0/callback"
    }

    var scope: String {
        [
            "openid",
            "profile",
            "email",
            "offline_access",
            "mbb",
            "ssodb",
            "badge",
            "vin",
            "dealers",
            "cars",
            "charging",
            "manageCharging",
            "plugAndCharge",
            "climatisation",
            "manageClimatisation",
            "pid:user_profile.porscheid:read",
            "pid:user_profile.name:read",
            "pid:user_profile.vehicles:read",
            "pid:user_profile.dealers:read",
            "pid:user_profile.emails:read",
            "pid:user_profile.phones:read",
            "pid:user_profile.addresses:read",
            "pid:user_profile.birthdate:read",
            "pid:user_profile.locale:read",
            "pid:user_profile.legal:read",
        ].joined(separator: " ")
    }

    var appApiBaseURL: String {
        switch self {
        case .europe:
            "https://api.ppa.porsche.com/app"
        case .usa:
            "https://api.ppa.porsche.com/app"
        }
    }

    var locale: String {
        switch self {
        case .europe:
            "de_DE"
        case .usa:
            "en_US"
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
    var brandName: String = "Mocker"
    var pushType: String = "MOCK"
    var apiProviderKind: ApiProviderKind = .hmg
}
