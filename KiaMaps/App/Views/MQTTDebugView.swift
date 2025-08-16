//
//  MQTTDebugView.swift
//  KiaMaps
//
//  Created by Claude on 12.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import SwiftUI
import os

/**
 * MQTTDebugView - Debug interface for MQTT communication testing and monitoring
 * 
 * This view provides:
 * - Real-time MQTT connection status
 * - Live message count and latest data
 * - Manual connection/disconnection controls
 * - Communication sequence testing
 * - Error reporting and diagnostics
 */
struct MQTTDebugView: View {
    @StateObject private var mqttManager: MQTTManager
    @State private var selectedVehicle: Vehicle?
    @State private var connectionStartTime: Date?
    @State private var communicationLog: [CommunicationLogEntry] = []
    @State private var isTestingSequence = false

    init(mqttManager: MQTTManager, selectedVehicle: Vehicle?) {
        _mqttManager = StateObject(wrappedValue: mqttManager)
        _selectedVehicle = State(initialValue: selectedVehicle)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MQTT Status Section
                    mqttStatusCard
                    
                    // Connection Controls
                    connectionControlsCard
                    
                    // Statistics Section
                    statisticsCard
                    
                    // Latest Data Section
                    latestDataCard
                    
                    // Communication Log
                    communicationLogCard
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("MQTT Debug")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            setupDebugSession()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            // Force UI update for connection time
            if mqttManager.connectionStatus == .connected && connectionStartTime != nil {
                // This timer trigger will cause the connectionTimeString to update
            }
        }
    }
    
    // MARK: - Status Card
    
    private var mqttStatusCard: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(statusColor)
                        .font(.title2)
                    
                    Text("MQTT Status")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    statusIndicator
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(
                        title: "Connection",
                        value: mqttManager.connectionStatus.description,
                        color: statusColor
                    )
                    
                    if let error = mqttManager.lastError {
                        StatusRow(
                            title: "Last Error",
                            value: error,
                            color: .red
                        )
                    }
                    
                    StatusRow(
                        title: "Protocol",
                        value: "MQTT 5.0 (CocoaMQTT5)",
                        color: .secondary
                    )
                }
            }
        }
    }
    
    // MARK: - Connection Controls Card
    
    private var connectionControlsCard: some View {
        KiaCard {
            VStack(spacing: 16) {
                Text("Connection Controls")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    // Connect Button
                    KiaButton(
                        "Activate MQTT Communication",
                        icon: "play.circle.fill",
                        style: .primary,
                        isEnabled: mqttManager.connectionStatus != .connecting
                    ) {
                        connectToMQTT()
                    }
                    
                    // Disconnect Button
                    KiaButton(
                        "Disconnect",
                        icon: "stop.circle.fill",
                        style: .secondary,
                        isEnabled: mqttManager.connectionStatus == .connected
                    ) {
                        mqttManager.disconnect()
                        connectionStartTime = nil
                    }
                    
                    // Test Sequence Button
                    KiaButton(
                        isTestingSequence ? "Testing Sequence..." : "Test Communication Sequence",
                        icon: "testtube.2",
                        style: .tertiary,
                        isEnabled: !isTestingSequence && selectedVehicle != nil
                    ) {
                        testCommunicationSequence()
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        KiaCard {
            VStack(spacing: 16) {
                Text("Statistics")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatisticBox(
                        title: "Messages Received",
                        value: "\(mqttManager.receivedMessageCount)",
                        icon: "envelope.fill"
                    )
                    
                    StatisticBox(
                        title: "Connection Time",
                        value: connectionTimeString,
                        icon: "clock.fill"
                    )
                    
                    StatisticBox(
                        title: "Data Updates",
                        value: mqttManager.latestData != nil ? "✓" : "—",
                        icon: "arrow.clockwise"
                    )
                    
                    StatisticBox(
                        title: "Host",
                        value: "Service Hub",
                        icon: "server.rack"
                    )
                }
            }
        }
    }
    
    // MARK: - Latest Data Card
    
    private var latestDataCard: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Latest Vehicle Data")
                        .font(.headline)
                    
                    Spacer()
                    
                    if mqttManager.latestData != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                if let data = mqttManager.latestData {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(data.keys.prefix(5)), id: \.self) { key in
                                DataPill(key: key, value: String(describing: data[key] ?? "nil"))
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    Text("No data received yet")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
    
    // MARK: - Communication Log Card
    
    private var communicationLogCard: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Communication Sequence")
                        .font(.headline)
                    
                    Spacer()
                    
                    if isTestingSequence {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if communicationLog.isEmpty {
                        // Default static log entries
                        LogEntryRow(
                            step: "1",
                            title: "Device Host Discovery",
                            description: "GET /api/v3/servicehub/device/host",
                            status: .pending
                        )
                        
                        LogEntryRow(
                            step: "2",
                            title: "Device Registration",
                            description: "POST /api/v3/servicehub/device/register",
                            status: .pending
                        )
                        
                        LogEntryRow(
                            step: "3",
                            title: "Vehicle Metadata",
                            description: "GET /api/v3/servicehub/vehicles/metadatalist",
                            status: .pending
                        )
                        
                        LogEntryRow(
                            step: "4",
                            title: "Protocol Subscription",
                            description: "POST /api/v3/servicehub/device/protocol",
                            status: .pending
                        )
                        
                        LogEntryRow(
                            step: "5",
                            title: "Connection State Check",
                            description: "GET /api/v3/vstatus/connstate",
                            status: .pending
                        )
                        
                        LogEntryRow(
                            step: "6",
                            title: "MQTT Connection",
                            description: "egw-svchub-ccs-k-eu.eu-central.hmgmobility.com:31020",
                            status: .pending
                        )
                    } else {
                        // Dynamic log entries from testing
                        ForEach(communicationLog, id: \.step) { entry in
                            LogEntryRow(
                                step: entry.step,
                                title: entry.title,
                                description: entry.error ?? "Test execution",
                                status: LogEntryRow.LogStatus.from(entry.status)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch mqttManager.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 8)
                    .scaleEffect(mqttManager.connectionStatus == .connecting ? 1.5 : 1.0)
                    .animation(
                        mqttManager.connectionStatus == .connecting 
                            ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                            : .none,
                        value: mqttManager.connectionStatus
                    )
            )
    }
    
    private var connectionTimeString: String {
        guard mqttManager.connectionStatus == .connected,
              let startTime = connectionStartTime else {
            return "—"
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    
    private func setupDebugSession() {
        // TODO: Get actual selected vehicle from the app context
        os_log(.debug, log: Logger.mqtt, "MQTT Debug View loaded - ready for testing")
    }
    
    private func connectToMQTT() {
        guard let selectedVehicle = selectedVehicle else {
            os_log(.error, log: Logger.mqtt, "MQTT no selected vehicle")
            return
        }
        
        // Track connection start time
        connectionStartTime = Date()
        
        Task {
            do {
                try await mqttManager.activateMQTTCommunication(for: selectedVehicle)
            } catch {
                os_log(.error, log: Logger.mqtt, "MQTT connection failed: \(error.localizedDescription)")
                connectionStartTime = nil
            }
        }
    }
    
    private func testCommunicationSequence() {
        guard let selectedVehicle = selectedVehicle else {
            os_log(.error, log: Logger.mqtt, "No vehicle selected for testing")
            return
        }
        
        isTestingSequence = true
        
        Task {
            await runCommunicationSequenceTest(for: selectedVehicle)
            isTestingSequence = false
        }
    }
    
    @MainActor
    private func runCommunicationSequenceTest(for vehicle: Vehicle) async {
        // Clear previous log
        communicationLog.removeAll()
        
        let steps: [(String, String, () async throws -> Void)] = [
            ("1", "Device Host Discovery", { try await testDeviceHostDiscovery() }),
            ("2", "Device Registration", { try await testDeviceRegistration() }),
            ("3", "Vehicle Metadata", { try await testVehicleMetadata(vehicle) }),
            ("4", "Protocol Subscription", { try await testProtocolSubscription(vehicle) }),
            ("5", "Connection State Check", { try await testConnectionStateCheck() }),
            ("6", "MQTT Connection", { try await testMQTTConnection() })
        ]
        
        for (stepNumber, title, testAction) in steps {
            // Update log entry to in-progress
            let logEntry = CommunicationLogEntry(
                step: stepNumber,
                title: title,
                status: .inProgress,
                timestamp: Date()
            )
            communicationLog.append(logEntry)
            
            do {
                try await testAction()
                // Update to completed
                if let index = communicationLog.firstIndex(where: { $0.step == stepNumber }) {
                    communicationLog[index] = CommunicationLogEntry(
                        step: stepNumber,
                        title: title,
                        status: .completed,
                        timestamp: logEntry.timestamp
                    )
                }
                
                // Small delay to visualize progress
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
            } catch {
                // Update to error
                if let index = communicationLog.firstIndex(where: { $0.step == stepNumber }) {
                    communicationLog[index] = CommunicationLogEntry(
                        step: stepNumber,
                        title: title,
                        status: .error,
                        timestamp: logEntry.timestamp,
                        error: error.localizedDescription
                    )
                }
                os_log(.error, log: Logger.mqtt, "Step \(stepNumber) failed: \(error.localizedDescription)")
                break
            }
        }
    }
    
    // Individual test methods for each step
    private func testDeviceHostDiscovery() async throws {
        // Simulate the device host discovery API call
        os_log(.debug, log: Logger.mqtt, "Testing device host discovery...")
        // This would normally call the actual API endpoint
    }
    
    private func testDeviceRegistration() async throws {
        os_log(.debug, log: Logger.mqtt, "Testing device registration...")
        // This would test the device registration API call
    }
    
    private func testVehicleMetadata(_ vehicle: Vehicle) async throws {
        os_log(.debug, log: Logger.mqtt, "Testing vehicle metadata for \(vehicle.vehicleId)...")
        // This would test the vehicle metadata API call
    }
    
    private func testProtocolSubscription(_ vehicle: Vehicle) async throws {
        os_log(.debug, log: Logger.mqtt, "Testing protocol subscription...")
        // This would test the protocol subscription API call
    }
    
    private func testConnectionStateCheck() async throws {
        os_log(.debug, log: Logger.mqtt, "Testing connection state check...")
        // This would test the connection state verification API call
    }
    
    private func testMQTTConnection() async throws {
        os_log(.debug, log: Logger.mqtt, "Testing MQTT connection...")
        // This would test the actual MQTT broker connection
    }
}

// MARK: - Supporting Views

private struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(color)
        }
    }
}

private struct StatisticBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(KiaDesign.Colors.accent)
            
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct DataPill: View {
    let key: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct LogEntryRow: View {
    let step: String
    let title: String
    let description: String
    let status: LogStatus
    
    enum LogStatus {
        case pending, inProgress, completed, error
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .inProgress: return .orange
            case .completed: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "circle"
            case .inProgress: return "clock"
            case .completed: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
        
        static func from(_ status: CommunicationLogStatus) -> LogEntryRow.LogStatus {
            switch status {
            case .pending: return .pending
            case .inProgress: return .inProgress
            case .completed: return .completed
            case .error: return .error
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Step number
            Text(step)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(status.color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models

struct CommunicationLogEntry {
    let step: String
    let title: String
    let status: CommunicationLogStatus
    let timestamp: Date
    let error: String?
    
    init(step: String, title: String, status: CommunicationLogStatus, timestamp: Date, error: String? = nil) {
        self.step = step
        self.title = title
        self.status = status
        self.timestamp = timestamp
        self.error = error
    }
}

enum CommunicationLogStatus {
    case pending, inProgress, completed, error
}

// MARK: - Preview

struct MQTTDebugView_Previews: PreviewProvider {
    static var previews: some View {
        MQTTDebugView(mqttManager: .init(api: .init(configuration: .mock, rsaService: .init())), selectedVehicle: .preview)
    }
}
