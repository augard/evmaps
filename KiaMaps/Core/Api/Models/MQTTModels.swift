//
//  MQTTModels.swift
//  KiaMaps
//
//  Created by Lukáš Foldýna on 14/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

// MARK: - Data Models

enum MQTTConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }
}

struct MQTTHostInfo {
    let host: String
    let port: Int
    let ssl: Bool
}

struct MQTTDeviceInfo {
    let clientId: String
    let deviceId: String
    let uuid: String
}

struct MQTTVehicleMetadata {
    let id: String
    let clientId: String
    let unit: String
    let vehicleId: String
    let protocols: [String]
}

// MARK: - API Request/Response Models

struct MQTTHostResponse: Codable {
    let http: HTTPInfo
    let mqtt: MQTTInfo

    struct HTTPInfo: Codable {
        let name: String
        let `protocol`: String  // Escaped Swift keyword
        let host: String
        let port: Int
        let ssl: Bool
    }

    struct MQTTInfo: Codable {
        let name: String
        let `protocol`: String  // Escaped Swift keyword
        let host: String
        let port: Int
        let ssl: Bool
    }
}

struct DeviceRegisterRequest: Codable {
    let unit: String
    let uuid: String
}

struct DeviceRegisterResponse: Codable {
    let clientId: String
    let deviceId: String
}

struct VehicleMetadataResponse: Codable {
    let vehicles: [VehicleMetadata]

    struct VehicleMetadata: Codable {
        let protocols: [String]
        let _id: String
        let clientId: String
        let unit: String
        let vehicleId: String
    }
}

struct ProtocolSubscriptionRequest: Codable {
    let protocols: [String]
    let protocolId: String
    let carId: String
    let brand: String
}

struct EmptyResponse: Codable {}

struct ConnectionStateResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case state
        case mqttProtoVer = "mqtt_proto_ver"
        case modifiedAt
    }

    let state: String
    let mqttProtoVer: Int
    let modifiedAt: String
}
