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

struct MQTTVehicleMetadata: Codable {
    let protocols: [String]
    let id: String
    let clientId: String
    let unit: String
    let vehicleId: String

    enum CodingKeys: String, CodingKey {
        case protocols, clientId, unit, vehicleId
        case id = "_id"
    }
}

protocol MQTTProtocol: RawRepresentable, Codable where RawValue == String {
    var subscriptionName: String { get }
    init?(topicName: String)
}

extension MQTTProtocol {
    var subscriptionName: String {
        let parts = rawValue.split(separator: ".")
        if parts.count > 2 {
            let prefix = parts[0...1].joined(separator: "/")
            let suffix = parts.dropFirst(2).joined(separator: "/")
            return prefix + "/_/" + suffix
        } else {
            return parts.joined(separator: "/")
        }
    }

    init?(topicName: String) {
        self.init(rawValue: Self.topicNameToRawValue(topicName))
    }

    fileprivate static func topicNameToRawValue(_ topicName: String) -> String {
        var parts = topicName.replacingOccurrences(of: "/_/", with: "/").split(separator: "/")
        parts = parts.dropLast()
        return parts.joined(separator: ".")
    }
}

let MQTTTProtocols: [any MQTTProtocol.Type] = [
    MQTTBaseProtocolIds.self,
    MQTTSpeedEventProtocolIds.self,
    MQTTRemoteControllerProtocolIds.self,
    MQTTCloseRemoteProtocolIds.self
]

/// Base protocol IDs that are always registered
enum MQTTBaseProtocolIds: String, MQTTProtocol {
    /// Get information about car
    case vss = "service.phone.vss"
    /// Get status update if car is connected
    case connection = "service.phone.connection"
    case res = "service.phone.res"
    case vehicleCcuUpdate = "statesync.vehicle.ccu.update"
}

/// Speed event protocol ID
enum MQTTSpeedEventProtocolIds: String, MQTTProtocol {
    /// Get car location updates and speed
    case location = "service.phone.location"
}

/// Remote controller protocol IDs
enum MQTTRemoteControllerProtocolIds: String, MQTTProtocol {
    case vehicleCommand = "vehicle.remotecontroller.command"
    case vehicleConnect = "vehicle.remotecontroller.connect"
    case vehicleMobileClose = "vehicle.remotecontroller.mobileclose"
    case vehicleVehicleClose = "vehicle.remotecontroller.vehicleclose"
    case vehicleConnectCheck = "vehicle.remotecontroller.connectcheck"
    case deviceCommand = "device.remotecontroller.command"
    case deviceConnect = "device.remotecontroller.connect"
    case deviceMobileClose = "device.remotecontroller.mobileclose"
    case deviceVehicleClose = "device.remotecontroller.vehicleclose"
    case deviceConnectCheck = "device.remotecontroller.connectcheck"
}

/// Close remote (HVAC/Media) protocol IDs
enum MQTTCloseRemoteProtocolIds: String, MQTTProtocol {
    case hvacPreconditionReq = "vehicle.closeremote.precondition.req"
    case hvacPrecondition = "device.closeremote.precondition"
    case hvacRemoteReq = "vehicle.closeremote.remote.req"
    case hvacRemoteRes = "device.closeremote.remote.res"
    case hvacVehicleStatusReq = "vehicle.closeremote.vehiclestatus.req"
    case hvacVehicleStatus = "device.closeremote.vehiclestatus"
    case hvacConnectionStatusReq = "vehicle.closeremote.connectionstatus.req"
    case hvacConnectionStatusRes = "device.closeremote.connectionstatus.res"
    case hvacMediaStatus = "device.closeremote.media.vehiclestatus"
}

// MARK: - API Request/Response Models

struct MQTTHostResponse: Decodable {
    let http: HTTPInfo
    let mqtt: MQTTInfo

    struct HTTPInfo: Decodable {
        let name: String
        let `protocol`: String  // Escaped Swift keyword
        let host: String
        let port: Int
        let ssl: Bool
    }

    struct MQTTInfo: Decodable {
        let name: String
        let `protocol`: String  // Escaped Swift keyword
        let host: String
        let port: Int
        let ssl: Bool
    }
}

struct DeviceRegisterRequest: Encodable {
    let unit: String
    let uuid: String
}

struct DeviceRegisterResponse: Decodable {
    let clientId: String
    let deviceId: String
}

struct VehicleMetadataResponse: Decodable {
    let vehicles: [MQTTVehicleMetadata]
}

struct ProtocolSubscriptionRequest: Encodable {
    let protocols: [any MQTTProtocol]
    let protocolId: any MQTTProtocol
    let carId: String
    let brand: String

    enum CodingKeys: String, CodingKey {
        case protocols, protocolId, carId, brand
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(protocols.compactMap { $0.rawValue }, forKey: .protocols)
        try container.encode(protocolId.rawValue, forKey: .protocolId)
        try container.encode(carId, forKey: .carId)
        try container.encode(brand, forKey: .brand)
    }
}

struct EmptyResponse: Codable {}

struct ConnectionStateResponse: Codable {
    enum State: String, Codable {
        case online = "ONLINE"
        case offline = "OFFLINE"
        case unknown = "UNKNOWN"
    }

    enum CodingKeys: String, CodingKey {
        case state
        case mqttProtoVer = "mqtt_proto_ver"
        case modifiedAt
    }

    let state: State
    let mqttProtoVer: Int?
    let modifiedAt: String?
}
