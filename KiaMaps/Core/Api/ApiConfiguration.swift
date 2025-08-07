//
//  ApiConfiguration.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

enum ApiBrand: String {
    case kia
    case hyundai
    case genesis

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

protocol ApiConfiguration {
    var key: String { get }
    var name: String { get }
    var port: Int { get }
    var serviceAgent: String { get }
    var userAgent: String { get }
    var acceptHeader: String { get }
    var baseUrl: String { get }
    var loginUrl: String { get }
    var serviceId: String { get }
    var appId: String { get }
    var senderId: Int { get }
    var authClientId: String { get }
    var cfb: String { get }
    var pushType: String { get }
}

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
        "EU_BlueLink/2.1.18 (com.kia.connect.eu; build:10560; iOS 17.5.1) Alamofire/5.8.0"
    }

    var acceptHeader: String {
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
    }

    var baseUrl: String {
        switch self {
        case .kia:
            "https://prd.eu-ccapi.kia.com"
        case .hyundai:
            "https://prd.eu-ccapi.hyundai.com"
        case .genesis:
            "https://prd-eu-ccapi.genesis.com"
        }
    }

    var loginUrl: String {
        "https://idpconnect-eu.\(key).com"
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

    var pushType: String {
        if self == .kia {
            "APNS"
        } else {
            "GCM"
        }
    }
}

enum ApiRegion {
    case europe
    case usa
    case canada
    case china
    case korea
}
