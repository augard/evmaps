//
//  ApiEndpoints.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

enum ApiEndpoint: CustomStringConvertible {
    enum RelativeTo {
        case base
        case login
        case spa
        case user
    }

    case oauth2ConnectorAuthorize
    case oauth2UserAuthorize
    case oauth2Redirect

    case loginConnectorClients(_ clinetId: String)
    case loginCodes
    case loginCertificates
    case loginSignin
    case loginToken
    case loginRedirect

    case logout
    case notificationRegister
    case notificationRegisterWithDeviceId(UUID)

    case userProfile

    case vehicles
    case refreshVehicle(UUID)
    case refreshCCS2Vehicle(UUID)
    case vehicleCachedStatus(UUID)
    case vehicleCachedCCS2Status(UUID)
    
    // Climate control endpoints
    case startClimate(UUID)
    case stopClimate(UUID)

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
        }
    }

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
        }
    }
}

private extension UUID {
    var formatted: String {
        uuidString.lowercased()
    }
}
