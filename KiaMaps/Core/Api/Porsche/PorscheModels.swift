//
//  PorscheModels.swift
//  KiaMaps
//
//  Created by Codex on 06.03.2026.
//

import Foundation

struct PorscheTokenSet: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String?
    let obtainedAt: Date

    var expiresAt: Date {
        obtainedAt.addingTimeInterval(TimeInterval(expiresIn))
    }

    func isExpired(leeway: TimeInterval = 60) -> Bool {
        Date().addingTimeInterval(leeway) >= expiresAt
    }
}

struct PorscheTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }

    func tokenSet(obtainedAt: Date) -> PorscheTokenSet {
        PorscheTokenSet(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            obtainedAt: obtainedAt
        )
    }
}

struct PorscheMFAChallenge: Codable, Equatable {
    let state: String
    let challengeType: String
}

enum PorscheAuthorizationCallback: Equatable {
    case authorizationCode(String)
    case mfaRequired(PorscheMFAChallenge)
}

struct PorscheVehicleSummary: Codable {
    struct Capabilities: Codable {
        let canLock: Bool?
        let canClimatise: Bool?
        let canCharge: Bool?
    }

    let vin: String
    let displayName: String
    let model: String
    let modelYear: Int?
    let batterySoc: Double?
    let rangeKm: Double?
    let charging: Bool?
    let locked: Bool?
    let latitude: Double?
    let longitude: Double?
    let odometerKm: Double?
    let climateActive: Bool?
    let chargingPowerKw: Double?
    let capabilities: Capabilities?
}

struct PorscheVehicleSnapshot: Equatable {
    struct Capabilities: Equatable {
        let canLock: Bool
        let canClimatise: Bool
        let canCharge: Bool
    }

    let vin: String
    let batterySoc: Double
    let rangeKm: Double
    let charging: Bool
    let locked: Bool
    let latitude: Double?
    let longitude: Double?
    let odometerKm: Double
    let climateActive: Bool
    let chargingPowerKw: Double
    let capabilities: Capabilities
}

enum PorscheCommandRequest {
    case lock(vin: String)
    case climateOn(vin: String, temperatureC: Double)
    case climateOff(vin: String)
    case startCharging(vin: String)
    case stopCharging(vin: String)

    var vin: String {
        switch self {
        case let .lock(vin),
             let .climateOn(vin, _),
             let .climateOff(vin),
             let .startCharging(vin),
             let .stopCharging(vin):
            vin
        }
    }

    var commandKey: String {
        switch self {
        case .lock:
            "LOCK"
        case .climateOn:
            "REMOTE_CLIMATIZER_START"
        case .climateOff:
            "REMOTE_CLIMATIZER_STOP"
        case .startCharging:
            "DIRECT_CHARGING_START"
        case .stopCharging:
            "DIRECT_CHARGING_STOP"
        }
    }
}

struct PorscheCommandResult: Equatable {
    let requestId: UUID
}

enum PorscheAuthError: LocalizedError, Equatable {
    case mfaRequired(PorscheMFAChallenge)
    case invalidMFACode
    case invalidCredentials
    case missingAuthorizationCode
    case invalidRedirect
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case let .mfaRequired(challenge):
            "MFA required (\(challenge.challengeType))."
        case .invalidMFACode:
            "Invalid MFA code."
        case .invalidCredentials:
            "Invalid Porsche credentials."
        case .missingAuthorizationCode:
            "Authorization code not present in callback."
        case .invalidRedirect:
            "Invalid redirect callback URL."
        case let .backendError(message):
            "Porsche auth backend error: \(message)"
        }
    }
}

enum PorscheApiError: LocalizedError, Equatable {
    case unsupportedOperation(String)
    case blockedByCaptchaOrDeviceBinding
    case decodingFailed(String)
    case missingVehicle(String)
    case missingCommandRequestId
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedOperation(operation):
            "Unsupported Porsche operation in current implementation: \(operation)."
        case .blockedByCaptchaOrDeviceBinding:
            "Porsche account requires captcha/device-binding; complete login in My Porsche app and retry."
        case let .decodingFailed(message):
            "Failed to decode Porsche API response: \(message)"
        case let .missingVehicle(identifier):
            "Missing Porsche vehicle for identifier: \(identifier)."
        case .missingCommandRequestId:
            "Porsche command did not return a request identifier."
        case let .commandFailed(message):
            "Porsche command failed: \(message)"
        }
    }
}

enum PorscheMFASubmitResult {
    case success
    case invalidCode
}

enum PorscheCommandExecutionState: String {
    case accepted = "ACCEPTED"
    case performed = "PERFORMED"
    case error = "ERROR"
    case unknown = "UNKNOWN"
}

enum PorscheMeasurementCatalog {
    static let overview = [
        "ACV_STATE",
        "ALARM_STATE",
        "BATTERY_CHARGING_STATE",
        "BATTERY_LEVEL",
        "BLEID_DDADATA",
        "CHARGING_PROFILES",
        "CHARGING_RATE",
        "CHARGING_SETTINGS",
        "CHARGING_SUMMARY",
        "CLIMATIZER_STATE",
        "DEPARTURES",
        "E_RANGE",
        "FUEL_LEVEL",
        "FUEL_RESERVE",
        "GLOBAL_PRIVACY_MODE",
        "GPS_LOCATION",
        "HEATING_STATE",
        "HVAC_STATE",
        "INTERMEDIATE_SERVICE_RANGE",
        "INTERMEDIATE_SERVICE_TIME",
        "LOCK_STATE_VEHICLE",
        "MAIN_SERVICE_RANGE",
        "MAIN_SERVICE_TIME",
        "MILEAGE",
        "OIL_LEVEL_CURRENT",
        "OIL_LEVEL_MAX",
        "OIL_LEVEL_MIN_WARNING",
        "OIL_SERVICE_RANGE",
        "OIL_SERVICE_TIME",
        "OPEN_STATE_CHARGE_FLAP_LEFT",
        "OPEN_STATE_CHARGE_FLAP_RIGHT",
        "OPEN_STATE_DOOR_FRONT_LEFT",
        "OPEN_STATE_DOOR_FRONT_RIGHT",
        "OPEN_STATE_DOOR_REAR_LEFT",
        "OPEN_STATE_DOOR_REAR_RIGHT",
        "OPEN_STATE_LID_FRONT",
        "OPEN_STATE_LID_REAR",
        "OPEN_STATE_SERVICE_FLAP",
        "OPEN_STATE_SPOILER",
        "OPEN_STATE_SUNROOF",
        "OPEN_STATE_SUNROOF_REAR",
        "OPEN_STATE_TOP",
        "OPEN_STATE_WINDOW_FRONT_LEFT",
        "OPEN_STATE_WINDOW_FRONT_RIGHT",
        "OPEN_STATE_WINDOW_REAR_LEFT",
        "OPEN_STATE_WINDOW_REAR_RIGHT",
        "PAIRING_CODE",
        "PARKING_BRAKE",
        "PARKING_LIGHT",
        "PRED_PRECON_LOCATION_EXCEPTIONS",
        "PRED_PRECON_USER_SETTINGS",
        "RANGE",
        "REMOTE_ACCESS_AUTHORIZATION",
        "SERVICE_PREDICTIONS",
        "THEFT_STATE",
        "TIMERS",
        "TIRE_PRESSURE",
        "VTS_MODES",
    ]

    static let commandCapabilities = [
        "CHARGING_STOP",
        "DIRECT_CHARGING_START",
        "DIRECT_CHARGING_STOP",
        "LOCK",
        "REMOTE_CLIMATIZER_START",
        "REMOTE_CLIMATIZER_STOP",
        "SPIN_CHALLENGE",
        "UNLOCK",
    ]
}

extension UUID {
    static func porscheVehicleID(for vin: String) -> UUID {
        let source = Array("porsche:\(vin.uppercased())".utf8)
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in source.enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
