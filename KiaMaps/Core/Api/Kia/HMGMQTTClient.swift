//
//  HMGMQTTClient.swift
//  KiaMaps
//
//  Created by Codex on 09.03.2026.
//

import Foundation

struct HMGMQTTClient {
    let configuration: ApiConfiguration
    let provider: ApiRequestProvider

    func fetchDeviceHost() async throws -> MQTTHostInfo {
        try ensureSupported()
        guard provider.authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let response: MQTTHostResponse = try await provider.request(endpoint: KiaApiEndpoint.mqttDeviceHost).data()
        return MQTTHostInfo(host: response.mqtt.host, port: response.mqtt.port, ssl: response.mqtt.ssl)
    }

    func registerDevice() async throws -> MQTTDeviceInfo {
        try ensureSupported()
        guard provider.authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let deviceUUID = "\(UUID().uuidString)_UVO"
        let request = DeviceRegisterRequest(unit: "mobile", uuid: deviceUUID)
        let response: DeviceRegisterResponse = try await provider.request(
            endpoint: KiaApiEndpoint.mqttRegisterDevice,
            encodable: request
        ).data()

        return MQTTDeviceInfo(clientId: response.clientId, deviceId: response.deviceId, uuid: deviceUUID)
    }

    func fetchVehicleMetadata(for vehicleId: UUID, clientId: String) async throws -> [MQTTVehicleMetadata] {
        try ensureSupported()
        guard provider.authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let response: VehicleMetadataResponse = try await provider.request(
            endpoint: KiaApiEndpoint.mqttVehicleMetadata,
            queryItems: [
                URLQueryItem(name: "carId", value: vehicleId.uuidString),
                URLQueryItem(name: "brand", value: configuration.brandCode)
            ],
            headers: [
                "client-id": clientId
            ]
        ).data()

        return response.vehicles
    }

    func subscribeVehicleProtocols(
        for vehicleId: UUID,
        clientId: String,
        protocolId: any MQTTProtocol,
        protocols: [any MQTTProtocol]
    ) async throws {
        try ensureSupported()
        guard provider.authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        let request = ProtocolSubscriptionRequest(
            protocols: protocols,
            protocolId: protocolId,
            carId: vehicleId,
            brand: configuration.brandCode
        )

        try await provider.request(
            endpoint: KiaApiEndpoint.mqttDeviceProtocol,
            headers: [
                "client-id": clientId
            ],
            encodable: request
        ).empty()
    }

    func checkConnectionState(clientId: String) async throws -> ConnectionStateResponse {
        try ensureSupported()
        guard provider.authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }

        return try await provider.request(
            endpoint: KiaApiEndpoint.mqttConnectionState,
            queryItems: [
                URLQueryItem(name: "clientId", value: clientId),
            ],
            headers: [
                "client-id": clientId
            ]
        ).data()
    }

    private func ensureSupported() throws {
        guard configuration.apiProviderKind == .hmg else {
            throw ApiError.unsupported("MQTT is not supported for Porsche.")
        }
    }
}
