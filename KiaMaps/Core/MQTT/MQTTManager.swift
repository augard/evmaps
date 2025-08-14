//
//  MQTTManager.swift
//  KiaMaps
//
//  Created by Claude on 12.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import CocoaMQTT
import os

enum MQTTError: LocalizedError {
    case noAuthorization
    case noVehicleSelected
    case incompleteSetup
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAuthorization:
            return "No valid authorization token available"
        case .noVehicleSelected:
            return "No vehicle selected for MQTT communication"
        case .incompleteSetup:
            return "MQTT setup incomplete - missing device info or vehicle metadata"
        case .connectionFailed(let reason):
            return "MQTT connection failed: \(reason)"
        }
    }
}

/**
 * MQTTManager - Handles real-time MQTT 5.0 communication with Kia/Hyundai vehicles
 * 
 * This class implements the vehicle MQTT communication sequence using MQTT 5.0:
 * 1. Get device host information (HTTP/MQTT broker details)
 * 2. Register mobile device and get clientId/deviceId
 * 3. Retrieve vehicle metadata and supported protocols
 * 4. Subscribe to real-time data protocols via MQTT 5.0
 * 5. Verify connection state is ONLINE with MQTT 5.0
 * 
 * ## MQTT 5.0 Communication Flow
 * Based on documented sequence from MQTT Raw folder:
 * - Step 60: GET /api/v3/servicehub/device/host → MQTT broker info
 * - Step 61: POST /api/v3/servicehub/device/register → Device registration
 * - Step 63: GET /api/v3/servicehub/vehicles/metadatalist → Vehicle protocols
 * - Step 64: POST /api/v3/servicehub/device/protocol → Protocol subscription
 * - Step 67: GET /api/v3/vstatus/connstate → Connection state verification
 * 
 * ## Real-time Data Protocols (MQTT 5.0)
 * Key protocols for live vehicle data:
 * - "statesync.vehicle.ccu.update" - Vehicle status updates
 * - "vtwin.ccu.data.streaming" - Streaming telemetry data
 * - "vpush.mrc.ccu.remotecontrol" - Remote control commands
 * 
 * ## MQTT 5.0 Features
 * - Enhanced error reporting and reason codes
 * - User properties for metadata
 * - Improved authentication and security
 * - Better flow control and message expiry
 */
@MainActor
class MQTTManager: ObservableObject {

    // MARK: - Published Properties
    
    @Published var connectionStatus: MQTTConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var receivedMessageCount: Int = 0
    @Published var latestVehicleData: [String: Any]?
    
    // MARK: - Private Properties

    private let api: Api
    private var mqttClient: CocoaMQTT5?
    private var deviceInfo: MQTTDeviceInfo?
    private var vehicleMetadata: [MQTTVehicleMetadata]?
    private var test: Bool = false
    
    // Continuation for waiting on MQTT connection
    private var connectionContinuation: CheckedContinuation<CocoaMQTTCONNACKReasonCode, Error>?
    private var subscriptionContinuation: CheckedContinuation<Void, Error>?
    
    // Track pending topic subscriptions
    private var pendingSubscriptions: Set<String> = []
    private var subscribedTopics: Set<String> = []

    // MARK: - MQTT Configuration
    
    private struct MQTTConfig {
        let host: String
        let port: Int
        let ssl: Bool
        let clientId: String
        let deviceId: String
    }
    
    private var mqttConfig: MQTTConfig?
    
    // MARK: - Initialization
    
    init(api: Api) {
        self.api = api
    }
    
    // MARK: - Public Methods
    
    /**
     * Activates MQTT communication following the documented sequence
     */
    func activateMQTTCommunication(for vehicle: Vehicle) async throws {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 activation sequence started")
        connectionStatus = .connecting
        lastError = nil

        do {
            // Step 1: Get device host information
            let hostInfo = try await getDeviceHost()
            
            // Step 2: Register device
            let deviceInfo = try await registerDevice()
            self.deviceInfo = deviceInfo
            
            // Step 3: Get vehicle metadata and protocols
            let vehicleMetadata = try await getVehicleMetadata(for: vehicle)
            self.vehicleMetadata = vehicleMetadata

            // Step 4: Subscribe to vehicle protocols via HTTP
            try await subscribeToVehicleProtocols(for: vehicle)

            // Step 5: Configure and connect MQTT client
            let ackCode = try await configureMQTTClient(hostInfo: hostInfo, deviceInfo: deviceInfo, vehicleMetadata: vehicleMetadata[0])
            os_log(.info, log: Logger.mqtt, "MQTT connected with ACK code: \(String(describing: ackCode))")
            
            // Step 6: Subscribe to MQTT topics for real-time data
            try await subscribeToMQTTTopics(vehicleMetadata: vehicleMetadata[0])
            os_log(.info, log: Logger.mqtt, "MQTT topics subscribed successfully")
            
            // Step 7: Check connection state
            let connectionState = try await checkConnectionState(clientId: deviceInfo.clientId)
            os_log(.info, log: Logger.mqtt, "MQTT Connection State: \(connectionState.state) - Protocol Version: \(connectionState.mqttProtoVer)")

            if connectionState.state == "ONLINE" {
                connectionStatus = .connected
                os_log(.debug, log: Logger.mqtt, "MQTT 5.0 activation sequence complete")
            } else {
                throw MQTTError.connectionFailed(connectionState.state)
            }
        } catch {
            disconnect()
            lastError = error.localizedDescription
            connectionStatus = .error
            os_log(.debug, log: Logger.mqtt, "MQTT 5.0 activation sequence failed \(error.localizedDescription)")
            throw error
        }

    }
    
    /**
     * Disconnects from MQTT broker
     */
    func disconnect() {
        mqttClient?.disconnect()
        connectionStatus = .disconnected
        deviceInfo = nil
        vehicleMetadata = nil
        mqttConfig = nil
        pendingSubscriptions.removeAll()
        subscribedTopics.removeAll()
    }
    
    // MARK: - Private Methods - HTTP API Sequence

    /**
     * Step 1: Get device host information
     * GET /api/v3/servicehub/device/host
     */
    private func getDeviceHost() async throws -> MQTTHostInfo {
        guard let authorization = api.authorization?.accessToken else {
            throw MQTTError.noAuthorization
        }
        
        // Direct HTTP request to ServiceHub endpoint (different host)
        let url = URL(string: "https://egw-svchub-ccs-k-eu.eu-central.hmgmobility.com:31010/api/v3/servicehub/device/host")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(MQTTHostResponse.self, from: data)
        
        return MQTTHostInfo(
            host: response.mqtt.host,
            port: response.mqtt.port,
            ssl: response.mqtt.ssl
        )
    }
    
    /**
     * Step 2: Register device as mobile unit
     * POST /api/v3/servicehub/device/register
     */
    private func registerDevice() async throws -> MQTTDeviceInfo {
        guard let authorization = api.authorization?.accessToken else {
            throw MQTTError.noAuthorization
        }
        
        let deviceUUID = "\(UUID().uuidString)_UVO"
        let registerRequest = DeviceRegisterRequest(unit: "mobile", uuid: deviceUUID)
        let requestBody = try JSONEncoder().encode(registerRequest)
        
        let url = URL(string: "https://egw-svchub-ccs-k-eu.eu-central.hmgmobility.com:31010/api/v3/servicehub/device/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = requestBody
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DeviceRegisterResponse.self, from: data)
        
        return MQTTDeviceInfo(
            clientId: response.clientId,
            deviceId: response.deviceId,
            uuid: deviceUUID
        )
    }
    
    /**
     * Step 3: Get vehicle metadata and supported protocols
     * GET /api/v3/servicehub/vehicles/metadatalist?carId=<carId>&brand=K
     */
    private func getVehicleMetadata(for vehicle: Vehicle) async throws -> [MQTTVehicleMetadata] {
        guard let authorization = api.authorization?.accessToken,
              let deviceInfo = self.deviceInfo else {
            throw MQTTError.noAuthorization
        }
        
        let urlString = "https://egw-svchub-ccs-k-eu.eu-central.hmgmobility.com:31010/api/v3/servicehub/vehicles/metadatalist?carId=\(vehicle.vehicleId)&brand=K"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceInfo.clientId, forHTTPHeaderField: "client-id")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(VehicleMetadataResponse.self, from: data)
        
        return response.vehicles.map { vehicle in
            MQTTVehicleMetadata(
                id: vehicle._id,
                clientId: vehicle.clientId,
                unit: vehicle.unit,
                vehicleId: vehicle.vehicleId,
                protocols: vehicle.protocols
            )
        }
    }
    
    /**
     * Step 4: Subscribe to specific vehicle protocols
     * POST /api/v3/servicehub/device/protocol
     */
    private func subscribeToVehicleProtocols(for vehicle: Vehicle) async throws {
        guard let authorization = api.authorization?.accessToken,
              let deviceInfo = self.deviceInfo,
              let _ = self.vehicleMetadata else {
            throw MQTTError.incompleteSetup
        }
        
        // Subscribe to CCU (Car Control Unit) real-time updates
        let protocolRequest = ProtocolSubscriptionRequest(
            protocols: ["service.phone.vss", "service.phone.connection", "service.phone.res"],
            protocolId: "statesync.vehicle.ccu.update",
            carId: vehicle.vehicleId.uuidString,
            brand: "K"
        )
        
        let requestBody = try JSONEncoder().encode(protocolRequest)
        
        let url = URL(string: "https://egw-svchub-ccs-k-eu.eu-central.hmgmobility.com:31010/api/v3/servicehub/device/protocol")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceInfo.clientId, forHTTPHeaderField: "client-id")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = requestBody
        
        let (_, _) = try await URLSession.shared.data(for: request)
        // Response should be 200 OK with empty body
    }
    
    /**
     * Step 6: Check connection state after protocol subscription
     * GET /api/v3/vstatus/connstate?clientId=<clientId>
     */
    private func checkConnectionState(clientId: String) async throws -> ConnectionStateResponse {
        guard let authorization = api.authorization?.accessToken else {
            throw MQTTError.noAuthorization
        }
        
        let urlString = "https://egw-svchub-ccs-k-eu.eu-central.hmgmobility.com:31010/api/v3/vstatus/connstate?clientId=\(clientId)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        request.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response headers for connection state
        if let httpResponse = response as? HTTPURLResponse {
            if let resMsg = httpResponse.allHeaderFields["res-msg"] as? String {
                os_log(.debug, log: Logger.mqtt, "Connection State Response: \(resMsg)")
            }
        }
        
        let connectionState = try JSONDecoder().decode(ConnectionStateResponse.self, from: data)
        return connectionState
    }
    
    // MARK: - Private Methods - MQTT Client Configuration
    
    /**
     * Configure and connect MQTT client, waiting for connection acknowledgment
     */
    private func configureMQTTClient(hostInfo: MQTTHostInfo, deviceInfo: MQTTDeviceInfo, vehicleMetadata: MQTTVehicleMetadata) async throws -> CocoaMQTTCONNACKReasonCode {
        guard let authorization = api.authorization?.accessToken else {
            throw MQTTError.noAuthorization
        }
        
        // Create MQTT client configuration
        mqttConfig = MQTTConfig(
            host: hostInfo.host,
            port: hostInfo.port,
            ssl: hostInfo.ssl,
            clientId: deviceInfo.clientId,
            deviceId: deviceInfo.deviceId
        )

        let mqtt = CocoaMQTT5(clientID: deviceInfo.clientId, host: hostInfo.host, port: UInt16(hostInfo.port))
        mqtt.username = deviceInfo.clientId
        mqtt.password = authorization // Access token as password
        mqtt.deliverTimeout = 10
        mqtt.keepAlive = 60
        mqtt.delegate = self
        mqtt.autoReconnect = true
        mqtt.cleanSession = true

        if hostInfo.ssl {
            mqtt.enableSSL = true
            mqtt.allowUntrustCACertificate = true
        }
        #if DEBUG
        mqtt.logLevel = .debug
        #else
        mqtt.logLevel = .warning
        #endif

        mqttClient = mqtt
        
        // Use continuation to wait for connection callback
        return try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            
            let result = mqtt.connect()
            if !result {
                continuation.resume(throwing: MQTTError.connectionFailed("Failed to connect to MQTT broker"))
                self.connectionContinuation = nil
            } else {
                os_log(.info, log: Logger.mqtt, "MQTT 5.0 Connection initiated: \(result)")
                os_log(.debug, log: Logger.mqtt, "- Host: \(hostInfo.host):\(hostInfo.port)")
                os_log(.debug, log: Logger.mqtt, "- SSL: \(hostInfo.ssl)")
                os_log(.debug, log: Logger.mqtt, "- MQTT Version: 5.0")
                os_log(.debug, log: Logger.mqtt, "- Client ID: \(deviceInfo.clientId)")
                os_log(.debug, log: Logger.mqtt, "- Device ID: \(deviceInfo.deviceId)")
                
                // Set a timeout for connection
                Task {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                    guard self.connectionContinuation != nil else { return }
                    self.connectionContinuation?.resume(throwing: MQTTError.connectionFailed("Connection timeout to MQTT broker"))
                    self.connectionContinuation = nil
                }
            }
        }
    }
    
    // MARK: - MQTT Topic Subscription
    
    /**
     * Subscribe to MQTT topics and wait for all subscription acknowledgments
     */
    private func subscribeToMQTTTopics(vehicleMetadata: MQTTVehicleMetadata) async throws {
        guard let mqtt = mqttClient else {
            throw MQTTError.incompleteSetup
        }
        
        // Define the topics we need to subscribe to
        let topics = [
            "service/phone/_/connection/" + vehicleMetadata.vehicleId,
            "service/phone/_/vss/" + vehicleMetadata.vehicleId,
            //"service/phone/_/res/" + vehicleMetadata.vehicleId
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            self.subscriptionContinuation = continuation
            
            // Clear previous state and set pending subscriptions
            self.pendingSubscriptions = Set(topics)
            self.subscribedTopics.removeAll()
            
            os_log(.debug, log: Logger.mqtt, "Subscribing to MQTT topics: \(topics.joined(separator: ", "))")
            
            // Subscribe to all topics
            for topic in topics {
                mqtt.subscribe(topic)
            }
            
            // Set a timeout for subscription
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds timeout
                if self.subscriptionContinuation != nil {
                    let missingTopics = self.pendingSubscriptions.subtracting(self.subscribedTopics)
                    if !missingTopics.isEmpty {
                        os_log(.error, log: Logger.mqtt, "Subscription timeout. Missing topics: \(missingTopics.joined(separator: ", "))")
                        self.subscriptionContinuation?.resume(throwing: MQTTError.connectionFailed("Subscription timeout. Failed to subscribe to: \(missingTopics.joined(separator: ", "))"))
                    }
                    self.subscriptionContinuation = nil
                    self.pendingSubscriptions.removeAll()
                }
            }
        }
    }
}

// MARK: - CocoaMQTT5 Delegate

extension MQTTManager: @preconcurrency CocoaMQTT5Delegate {
    func mqtt5(_ mqtt: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        os_log(.info, log: Logger.mqtt, "MQTT 5.0 Connected with reason code: \(ack.description)")
        if let connAckData = connAckData {
            os_log(.debug, log: Logger.mqtt, "Connection ACK data: \(connAckData)")
        }
        
        // Resume the continuation if waiting for connection
        if let continuation = connectionContinuation {
            if ack == .success {
                continuation.resume(returning: ack)
            } else {
                continuation.resume(throwing: MQTTError.connectionFailed("Connection rejected with code: \(ack.description)"))
            }
            connectionContinuation = nil
        }
        
        connectionStatus = .connected
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Published message: \(message.string ?? "")")
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Publish acknowledged: \(id)")
        if let pubAckData = pubAckData {
            os_log(.debug, log: Logger.mqtt, "Publish ACK data: \(pubAckData)")
        }
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Publish received: \(id)")
        if let pubRecData = pubRecData {
            os_log(.debug, log: Logger.mqtt, "Publish REC data: \(pubRecData)")
        }
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        os_log(.info, log: Logger.mqtt, "MQTT 5.0 Received message on topic: \(message.topic)")
        os_log(.debug, log: Logger.mqtt, "Message content: \(message.string ?? "")")
        
        receivedMessageCount += 1
        
        // Parse vehicle data from message
        if let messageString = message.string,
           let data = messageString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            latestVehicleData = json
        }
        
        if let publishData = publishData {
            os_log(.debug, log: Logger.mqtt, "Publish data: \(publishData)")
        }
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        os_log(.info, log: Logger.mqtt, "MQTT 5.0 Subscribed to topics: \(success)")
        if !failed.isEmpty {
            os_log(.error, log: Logger.mqtt, "MQTT 5.0 Failed to subscribe to: \(failed)")
        }
        if let subAckData = subAckData {
            os_log(.debug, log: Logger.mqtt, "Subscribe ACK data: \(subAckData)")
        }
        
        // Track successful subscriptions
        for (topic, _) in success {
            if let topicString = topic as? String {
                subscribedTopics.insert(topicString)
                pendingSubscriptions.remove(topicString)
            }
        }
        
        // Track failed subscriptions
        for topic in failed {
            pendingSubscriptions.remove(topic)
        }
        
        os_log(.debug, log: Logger.mqtt, "Subscription status - Pending: \(self.pendingSubscriptions.count), Subscribed: \(self.subscribedTopics.count), Failed: \(failed.count)")
        
        // Check if all subscriptions are complete
        if pendingSubscriptions.isEmpty {
            // All topics have been processed (either success or failure)
            if let continuation = subscriptionContinuation {
                if failed.isEmpty {
                    os_log(.info, log: Logger.mqtt, "All MQTT topics subscribed successfully")
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MQTTError.connectionFailed("Failed to subscribe to topics: \(failed.joined(separator: ", "))"))
                }
                subscriptionContinuation = nil
            }
        }
        // If there are still pending subscriptions, wait for more callbacks
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Unsubscribed from topics: \(topics)")
        if let unsubAckData = unsubAckData {
            os_log(.debug, log: Logger.mqtt, "Unsubscribe ACK data: \(unsubAckData)")
        }
    }
    
    func mqtt5DidPing(_ mqtt: CocoaMQTT5) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Ping")
    }
    
    func mqtt5DidReceivePong(_ mqtt: CocoaMQTT5) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Pong")
    }
    
    func mqtt5DidDisconnect(_ mqtt: CocoaMQTT5, withError error: Error?) {
        os_log(.info, log: Logger.mqtt, "MQTT 5.0 Disconnected: \(error?.localizedDescription ?? "No error")")
        connectionStatus = .disconnected
        if let error = error {
            lastError = error.localizedDescription
            connectionStatus = .error
        }
        
        // Clean up subscription tracking
        pendingSubscriptions.removeAll()
        subscribedTopics.removeAll()
        
        // Clean up any pending continuations
        if let continuation = connectionContinuation {
            continuation.resume(throwing: error ?? MQTTError.connectionFailed("Disconnected"))
            connectionContinuation = nil
        }
        if let continuation = subscriptionContinuation {
            continuation.resume(throwing: error ?? MQTTError.connectionFailed("Disconnected"))
            subscriptionContinuation = nil
        }
    }
    
    // MQTT 5.0 specific delegate methods
    func mqtt5(_ mqtt: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {
        os_log(.info, log: Logger.mqtt, "MQTT 5.0 Disconnect reason code: \(reasonCode.description)")
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 Auth reason code: \(reasonCode.description)")
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didStateChangeTo state: CocoaMQTTConnState) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 State: \(state)")
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishComplete id: UInt16, pubCompData: MqttDecodePubComp?) {
        os_log(.debug, log: Logger.mqtt, "MQTT 5.0 pubCompData: \(String(describing: pubCompData))")
    }
}

// MARK: - CocoaMQTT Reason Code Extensions

extension CocoaMQTTCONNACKReasonCode: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .success:
            return "Success"
        case .unspecifiedError:
            return "Unspecified Error"
        case .malformedPacket:
            return "Malformed Packet"
        case .protocolError:
            return "Protocol Error"
        case .implementationSpecificError:
            return "Implementation Specific Error"
        case .unsupportedProtocolVersion:
            return "Unsupported Protocol Version"
        case .clientIdentifierNotValid:
            return "Client Identifier Not Valid"
        case .badUsernameOrPassword:
            return "Bad Username or Password"
        case .notAuthorized:
            return "Not Authorized"
        case .serverUnavailable:
            return "Server Unavailable"
        case .serverBusy:
            return "Server Busy"
        case .banned:
            return "Banned"
        case .badAuthenticationMethod:
            return "Bad Authentication Method"
        case .topicNameInvalid:
            return "Topic Name Invalid"
        case .packetTooLarge:
            return "Packet Too Large"
        case .quotaExceeded:
            return "Quota Exceeded"
        case .payloadFormatInvalid:
            return "Payload Format Invalid"
        case .retainNotSupported:
            return "Retain Not Supported"
        case .qosNotSupported:
            return "QoS Not Supported"
        case .useAnotherServer:
            return "Use Another Server"
        case .serverMoved:
            return "Server Moved"
        case .connectionRateExceeded:
            return "Connection Rate Exceeded"
        @unknown default:
            return "Unknown Reason Code"
        }
    }
}

extension CocoaMQTTDISCONNECTReasonCode: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .normalDisconnection:
            return "Normal Disconnection"
        case .disconnectWithWillMessage:
            return "Disconnect with Will Message"
        case .unspecifiedError:
            return "Unspecified Error"
        case .malformedPacket:
            return "Malformed Packet"
        case .protocolError:
            return "Protocol Error"
        case .implementationSpecificError:
            return "Implementation Specific Error"
        case .notAuthorized:
            return "Not Authorized"
        case .serverBusy:
            return "Server Busy"
        case .serverShuttingDown:
            return "Server Shutting Down"
        case .keepAliveTimeout:
            return "Keep Alive Timeout"
        case .sessionTakenOver:
            return "Session Taken Over"
        case .topicFilterInvalid:
            return "Topic Filter Invalid"
        case .topicNameInvalid:
            return "Topic Name Invalid"
        case .receiveMaximumExceeded:
            return "Receive Maximum Exceeded"
        case .topicAliasInvalid:
            return "Topic Alias Invalid"
        case .packetTooLarge:
            return "Packet Too Large"
        case .messageRateTooHigh:
            return "Message Rate Too High"
        case .quotaExceeded:
            return "Quota Exceeded"
        case .administrativeAction:
            return "Administrative Action"
        case .payloadFormatInvalid:
            return "Payload Format Invalid"
        case .retainNotSupported:
            return "Retain Not Supported"
        case .qosNotSupported:
            return "QoS Not Supported"
        case .useAnotherServer:
            return "Use Another Server"
        case .serverMoved:
            return "Server Moved"
        case .sharedSubscriptionsNotSupported:
            return "Shared Subscriptions Not Supported"
        case .connectionRateExceeded:
            return "Connection Rate Exceeded"
        case .maximumConnectTime:
            return "Maximum Connect Time"
        case .subscriptionIdentifiersNotSupported:
            return "Subscription Identifiers Not Supported"
        case .wildcardSubscriptionsNotSupported:
            return "Wildcard Subscriptions Not Supported"
        @unknown default:
            return "Unknown Disconnect Reason Code"
        }
    }
}

extension CocoaMQTTAUTHReasonCode: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .success:
            return "Success"
        case .continueAuthentication:
            return "Continue Authentication"
        case .ReAuthenticate:
            return "Re Authentication"
        @unknown default:
            return "Unknown Auth Reason Code"
        }
    }
}
