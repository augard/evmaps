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
    typealias VehicleStatusCallback = (VehicleMQTTStatusResponse) -> Void

    // MARK: - Published Properties
    
    @Published var connectionStatus: MQTTConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var receivedMessageCount: Int = 0
    @Published var latestData: [String: Any]?

    var vehicleStatusCallback: VehicleStatusCallback?

    // MARK: - Private Properties

    private let api: Api
    private var mqttClient: CocoaMQTT5?
    private var deviceInfo: MQTTDeviceInfo?
    private var vehicleMetadata: [MQTTVehicleMetadata]?
    
    // Continuation for waiting on MQTT connection
    private var connectionContinuation: CheckedContinuation<CocoaMQTTCONNACKReasonCode, Error>?
    private var subscriptionContinuation: CheckedContinuation<Void, Error>?
    
    // Track pending topic subscriptions
    private var pendingSubscriptions: Set<String> = []
    private var subscribedTopics: Set<String> = []
    
    // MARK: - Initialization
    
    init(api: Api) {
        self.api = api
    }
    
    // MARK: - Public Methods
    
    /**
     * Activates MQTT communication following the documented sequence
     */
    func activateMQTTCommunication(for vehicle: Vehicle) async throws {
        logDebug("MQTT 5.0 activation sequence started", category: .mqtt)
        connectionStatus = .connecting
        lastError = nil

        do {
            // Step 1: Get device host information
            let hostInfo = try await api.fetchMQTTDeviceHost()
            
            // Step 2: Register device
            let deviceInfo = try await api.registerMQTTDevice()
            self.deviceInfo = deviceInfo
            
            // Step 3: Get vehicle metadata and protocols
            let vehicleMetadata = try await api.fetchMQTTVehicleMetadata(for: vehicle, clientId: deviceInfo.clientId)
            self.vehicleMetadata = vehicleMetadata

            let protocols: [any MQTTProtocol] = [MQTTBaseProtocolIds.connection, MQTTBaseProtocolIds.vss]

            // Step 4: Subscribe to vehicle protocols via HTTP
            try await api.subscribeMQTTVehicleProtocols(
                for: vehicle,
                clientId: deviceInfo.clientId,
                protocolId: MQTTBaseProtocolIds.vehicleCcuUpdate,
                protocols: protocols
            )

            // Step 5: Configure and connect MQTT client
            let ackCode = try await configureMQTTClient(hostInfo: hostInfo, deviceInfo: deviceInfo, vehicleMetadata: vehicleMetadata[0])
            logInfo("MQTT connected with ACK code: \(String(describing: ackCode))", category: .mqtt)
            
            // Step 6: Subscribe to MQTT topics for real-time data
            try await subscribeToMQTTTopics(vehicleMetadata: vehicleMetadata[0], protocols: protocols)
            logInfo("MQTT topics subscribed successfully", category: .mqtt)
            
            // Step 7: Check connection state
            let connectionState = try await api.checkMQTTConnectionState(clientId: deviceInfo.clientId)
            logInfo("MQTT Connection State: \(connectionState.state.rawValue) - Protocol Version: \(connectionState.mqttProtoVer ?? 0)", category: .mqtt)

            if connectionState.state == .online {
                connectionStatus = .connected
                logDebug("MQTT 5.0 activation sequence complete", category: .mqtt)
            } else {
                throw MQTTError.connectionFailed(connectionState.state.rawValue)
            }
        } catch {
            disconnect()
            lastError = error.localizedDescription
            connectionStatus = .error
            logError("MQTT 5.0 activation sequence failed \(error.localizedDescription)", category: .mqtt)
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
        pendingSubscriptions.removeAll()
        subscribedTopics.removeAll()
    }
    
    
    // MARK: - Private Methods - MQTT Client Configuration
    
    /**
     * Configure and connect MQTT client, waiting for connection acknowledgment
     */
    private func configureMQTTClient(hostInfo: MQTTHostInfo, deviceInfo: MQTTDeviceInfo, vehicleMetadata: MQTTVehicleMetadata) async throws -> CocoaMQTTCONNACKReasonCode {
        guard let authorization = api.authorization?.accessToken else {
            throw MQTTError.noAuthorization
        }

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
                logInfo("MQTT 5.0 Connection initiated: \(result)", category: .mqtt)
                logDebug("- Host: \(hostInfo.host):\(hostInfo.port)", category: .mqtt)
                logDebug("- SSL: \(hostInfo.ssl)", category: .mqtt)
                logDebug("- MQTT Version: 5.0", category: .mqtt)
                logDebug("- Client ID: \(deviceInfo.clientId)", category: .mqtt)
                logDebug("- Device ID: \(deviceInfo.deviceId)", category: .mqtt)
                
                // Set a timeout for connection
                Task {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                    guard let continuation = self.connectionContinuation else { return }
                    self.connectionContinuation = nil
                    continuation.resume(throwing: MQTTError.connectionFailed("Connection timeout to MQTT broker"))
                }
            }
        }
    }
    
    // MARK: - MQTT Topic Subscription
    
    /**
     * Subscribe to MQTT topics and wait for all subscription acknowledgments
     */
    private func subscribeToMQTTTopics(vehicleMetadata: MQTTVehicleMetadata, protocols: [any MQTTProtocol]) async throws {
        guard let mqtt = mqttClient else {
            throw MQTTError.incompleteSetup
        }
        
        // Define the topics we need to subscribe to
        let topics = protocols.map { [$0.subscriptionName, vehicleMetadata.vehicleId].joined(separator: "/") }

        return try await withCheckedThrowingContinuation { continuation in
            self.subscriptionContinuation = continuation
            
            // Clear previous state and set pending subscriptions
            self.pendingSubscriptions = Set(topics)
            self.subscribedTopics.removeAll()
            
            logDebug("Subscribing to MQTT topics: \(topics.joined(separator: ", "))", category: .mqtt)
            
            // Subscribe to all topics
            for topic in topics {
                mqtt.subscribe(topic)
            }
            
            // Set a timeout for subscription
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds timeout
                guard let continuation = self.subscriptionContinuation else { return }
                self.subscriptionContinuation = nil
                let missingTopics = self.pendingSubscriptions.subtracting(self.subscribedTopics)
                if !missingTopics.isEmpty {
                    logError("Subscription timeout. Missing topics: \(missingTopics.joined(separator: ", "))", category: .mqtt)
                    continuation.resume(throwing: MQTTError.connectionFailed("Subscription timeout. Failed to subscribe to: \(missingTopics.joined(separator: ", "))"))
                }
                self.pendingSubscriptions.removeAll()
            }
        }
    }
}

// MARK: - CocoaMQTT5 Delegate

extension MQTTManager: @preconcurrency CocoaMQTT5Delegate {
    func mqtt5(_ mqtt: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        logInfo("MQTT 5.0 Connected with reason code: \(ack.description)", category: .mqtt)
        if let connAckData = connAckData {
            logDebug("Connection ACK data: \(connAckData)", category: .mqtt)
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
        logDebug("MQTT 5.0 Published message: \(message.string ?? "")", category: .mqtt)
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        logDebug("MQTT 5.0 Publish acknowledged: \(id)", category: .mqtt)
        if let pubAckData = pubAckData {
            logDebug("Publish ACK data: \(pubAckData)", category: .mqtt)
        }
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {
        logDebug("MQTT 5.0 Publish received: \(id)", category: .mqtt)
        if let pubRecData = pubRecData {
            logDebug("Publish REC data: \(pubRecData)", category: .mqtt)
        }
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        logInfo("MQTT 5.0 Received message on topic: \(message.topic)", category: .mqtt)
        logDebug("Message content: \(message.string ?? "")", category: .mqtt)

        receivedMessageCount += 1

        // Parse vehicle data from message
        var data: Data?
        if let messageString = message.string,
           let messageData = messageString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {
            latestData = json
            data = messageData
        }

        if let publishData = publishData {
            logDebug("Publish data: \(publishData)", category: .mqtt)
        }

        guard let protocolId = MQTTTProtocols.compactMap({ $0.init(topicName: message.topic) }).first else {
            return
        }
        if let protocolId = protocolId as? MQTTBaseProtocolIds {
            switch protocolId {
            case .vss, .connection:
                guard let data = data else {
                    logDebug("No data for topic: \(message.topic)", category: .mqtt)
                    return
                }
                let decoder = JSONDecoder()
                do {
                    if protocolId == .vss {
                        let vehicleStatus = try decoder.decode(VehicleMQTTStatusResponse.self, from: data)
                        logInfo("Last vehicle data update received at: \(vehicleStatus.lastUpdateTime)", category: .mqtt)
                        vehicleStatusCallback?(vehicleStatus)
                    } else if protocolId == .connection {
                        let connectionStatus = try decoder.decode(ConnectionStateResponse.self, from: data)
                        logDebug("Connection state changed to: \(connectionStatus.state.rawValue)", category: .mqtt)
                        if connectionStatus.state == .offline {
                            disconnect()
                        }
                    }
                } catch {
                    logError("Failed to decode data for topic: \(message.topic), error: \(error.localizedDescription)", category: .mqtt)
                }
            case .res, .vehicleCcuUpdate:
                break
            }
        }
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        logInfo("MQTT 5.0 Subscribed to topics: \(success)", category: .mqtt)
        if !failed.isEmpty {
            logError("MQTT 5.0 Failed to subscribe to: \(failed)", category: .mqtt)
        }
        if let subAckData = subAckData {
            logDebug("Subscribe ACK data: \(subAckData)", category: .mqtt)
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
        
        logDebug("Subscription status - Pending: \(self.pendingSubscriptions.count), Subscribed: \(self.subscribedTopics.count), Failed: \(failed.count)", category: .mqtt)
        
        // Check if all subscriptions are complete
        if pendingSubscriptions.isEmpty {
            // All topics have been processed (either success or failure)
            if let continuation = subscriptionContinuation {
                if failed.isEmpty {
                    logInfo("All MQTT topics subscribed successfully", category: .mqtt)
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
        logDebug("MQTT 5.0 Unsubscribed from topics: \(topics)", category: .mqtt)
        if let unsubAckData = unsubAckData {
            logDebug("Unsubscribe ACK data: \(unsubAckData)", category: .mqtt)
        }
    }
    
    func mqtt5DidPing(_ mqtt: CocoaMQTT5) {
        logDebug("MQTT 5.0 Ping", category: .mqtt)
    }
    
    func mqtt5DidReceivePong(_ mqtt: CocoaMQTT5) {
        logDebug("MQTT 5.0 Pong", category: .mqtt)
    }
    
    func mqtt5DidDisconnect(_ mqtt: CocoaMQTT5, withError error: Error?) {
        logDebug("MQTT 5.0 Disconnected: \(error?.localizedDescription ?? "No error")", category: .mqtt)

        if subscriptionContinuation == nil, connectionContinuation == nil, connectionStatus == .connected {
            logDebug("MQTT 5.0, Keeping connected as we finished connection and subscriotion, will do reconnect", category: .mqtt)
            return
        }

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
        logInfo("MQTT 5.0 Disconnect reason code: \(reasonCode.description)", category: .mqtt)
    }
    
    func mqtt5(_ mqtt: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        logDebug("MQTT 5.0 Auth reason code: \(reasonCode.description)", category: .mqtt)
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didStateChangeTo state: CocoaMQTTConnState) {
        logDebug("MQTT 5.0 State: \(state)", category: .mqtt)
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishComplete id: UInt16, pubCompData: MqttDecodePubComp?) {
        logDebug("MQTT 5.0 pubCompData: \(String(describing: pubCompData))", category: .mqtt)
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
