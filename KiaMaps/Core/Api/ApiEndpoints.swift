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

    case language
    case signIn
    case authorization
    case authorizationToken
    case loginPage
    case loginAction(query: String)
    case loginRedirect
    case logout
    case notificationRegister
    case notificationRegisterWithDeviceId(UUID)

    case userIntegrationInfo
    case userSession
    case userProfile

    case vehicles
    case refreshVehicle(UUID)
    case refreshCCS2Vehicle(UUID)
    case vehicleCachedStatus(UUID)
    case vehicleCachedCCS2Status(UUID)

    var path: (String, RelativeTo) {
        switch self {
        case .language:
            ("language", .user)
        case .signIn:
            ("silentsignin", .user)
        case .authorization:
            ("oauth2/authorize", .user)
        case .authorizationToken:
            ("oauth2/token", .user)
        case .notificationRegister:
            ("notifications/register", .spa)
        case let .notificationRegisterWithDeviceId(deviceId):
            ("notifications/\(deviceId.formatted)/register", .spa)
        case .loginPage:
            ("protocol/openid-connect/auth", .login)
        case let .loginAction(query):
            ("login-actions/authenticate\(query)", .login)
        case .loginRedirect:
            ("integration/redirect/login", .user)
        case .logout:
            ("devices/logout", .spa)
        case .userIntegrationInfo:
            ("integrationinfo", .user)
        case .userProfile:
            ("profile", .user)
        case .userSession:
            ("session", .user)
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
        }
    }

    var description: String {
        switch self {
        case .language:
            "language"
        case .signIn:
            "signIn"
        case .authorization:
            "authorization"
        case .authorizationToken:
            "authorizationToken"
        case .loginPage:
            "loginPage"
        case .loginAction:
            "loginAction"
        case .loginRedirect:
            "loginRedirect"
        case .logout:
            "logout"
        case .notificationRegister:
            "notificationRegister"
        case .notificationRegisterWithDeviceId:
            "notificationRegisterWithDeviceId"
        case .userIntegrationInfo:
            "userIntegrationInfo"
        case .userSession:
            "userSession"
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
        }
    }
}

private extension UUID {
    var formatted: String {
        uuidString.lowercased()
    }
}
