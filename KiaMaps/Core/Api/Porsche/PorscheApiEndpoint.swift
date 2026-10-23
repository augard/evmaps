//
//  PorscheApiEndpoint.swift
//  KiaMaps
//
//  Created by Codex on 06.03.2026.
//

import Foundation

enum PorscheApiEndpoint: ApiEndpointProtocol {
    case authorize
    case loginIdentifier
    case loginPassword
    case mfaOTP
    case token
    case vehicles
    case vehicle(String)
    case commands(String)
    case commandStatus(vin: String, requestId: String)
    case profile

    var path: (String, ApiEndpointBase.RelativeTo) {
        switch self {
        case .authorize:
            ("authorize", .user)
        case .loginIdentifier:
            ("u/login/identifier", .user)
        case .loginPassword:
            ("u/login/password", .user)
        case .mfaOTP:
            ("u/mfa-otp-challenge", .user)
        case .token:
            ("oauth/token", .user)
        case .vehicles:
            ("connect/v1/vehicles", .base)
        case let .vehicle(vin):
            ("connect/v1/vehicles/\(vin)", .base)
        case let .commands(vin):
            ("connect/v1/vehicles/\(vin)/commands", .base)
        case let .commandStatus(vin, requestId):
            ("connect/v1/vehicles/\(vin)/commands/\(requestId)", .base)
        case .profile:
            ("account/v1/profile", .base)
        }
    }

    var description: String {
        switch self {
        case .authorize:
            "porscheAuthorize"
        case .loginIdentifier:
            "porscheLoginIdentifier"
        case .loginPassword:
            "porscheLoginPassword"
        case .mfaOTP:
            "porscheMfaOtp"
        case .token:
            "porscheToken"
        case .vehicles:
            "porscheVehicles"
        case .vehicle:
            "porscheVehicle"
        case .commands:
            "porscheCommands"
        case .commandStatus:
            "porscheCommandStatus"
        case .profile:
            "porscheProfile"
        }
    }
}
