//
//  DebugScreenView.swift
//  KiaMaps
//
//  Created by Claude on 21.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import SwiftUI

/// Debug screen for testing credential sharing and other development features
struct DebugScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var showingVehicleStatus = false
    @State private var showingDebugLogs = false
    @AppStorage("RemoteLoggingEnabled") private var remoteLoggingEnabled = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.large) {
                    // Header
                    headerSection
                    
                    // Configuration Info
                    configurationSection

                    // Remote logger info
                    remoteLoggerSection

                    // UI Debug
                    uiDebugSection
                    
                    // Credential Tests
                    credentialTestsSection
                    
                    // Test Results
                    if !testResults.isEmpty {
                        testResultsSection
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(KiaDesign.Spacing.large)
            }
            .background(KiaDesign.Colors.background)
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(KiaDesign.Colors.primary)
                }
            }
            .sheet(isPresented: $showingVehicleStatus) {
                NavigationView {
                    // Create mock data for the legacy view
                    VehicleStatusView(
                        brand: AppConfiguration.apiConfiguration.name,
                        vehicle: MockVehicleData.mockVehicle,
                        vehicleStatus: MockVehicleData.standard,
                        lastUpdateTime: Date()
                    )
                    .navigationTitle("Legacy Vehicle Status")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingVehicleStatus = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDebugLogs) {
                DebugLogsView()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
            Text("🧪 Debug & Testing")
                .font(KiaDesign.Typography.title1)
                .fontWeight(.bold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
            
            Text("Test credential sharing between app and extensions, view configuration, and debug app functionality.")
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
        }
    }
    
    // MARK: - Configuration Section
    
    private var configurationSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "Configuration", icon: "gearshape")
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    configRow(title: "Access Group ID", value: AppConfiguration.accessGroupId)
                    configRow(title: "API Brand", value: AppConfiguration.apiConfiguration.name)
                    configRow(title: "Authorization Status", 
                             value: Authorization.isAuthorized ? "✅ Authorized" : "❌ Not Authorized")
                    configRow(title: "Device ID", value: UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")

                    if let auth = Authorization.authorization {
                        configRow(title: "Auth Device ID", value: String(auth.deviceId.uuidString.prefix(20)) + "...")
                        configRow(title: "CCS2 Support", value: auth.isCcuCCS2Supported ? "✅ Enabled" : "❌ Disabled")
                        configRow(title: "Access Token", value: String(auth.accessToken.prefix(20)) + "...")
                    }
                }
            }
        }
    }

    // MARK: - Developer Section

    private var remoteLoggerSection: some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "Remote Logging", icon: "hammer")

                VStack(spacing: KiaDesign.Spacing.small) {
                    // Remote logging toggle
                    HStack(spacing: KiaDesign.Spacing.medium) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(KiaDesign.Colors.kiaLimeGreen)
                            .frame(width: 20)

                        Text("Remote Logging")
                            .font(KiaDesign.Typography.body)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)

                        Spacer()

                        Toggle("", isOn: $remoteLoggingEnabled)
                            .labelsHidden()
                            .onChange(of: remoteLoggingEnabled) { _, enabled in
                                // Enable/disable remote logging in extensions
                                UserDefaults.standard.set(enabled, forKey: "RemoteLoggingEnabled")

                                // Start/stop server in main app
                                enabled ? RemoteLoggingServer.shared.start() : RemoteLoggingServer.shared.stop()
                            }
                    }
                    .padding(.vertical, 2)

                    // Debug logs viewer
                    testButton(
                        title: "Debug Logs",
                        subtitle: "Open the original vehicle status interface",
                        icon: "car.2",
                        action: {
                            showingDebugLogs = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - UI Debug Section
    
    private var uiDebugSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "UI Debug", icon: "paintbrush")
                
                Text("Access legacy UI components and test views")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    testButton(
                        title: "Legacy Vehicle Status View",
                        subtitle: "Open the original vehicle status interface",
                        icon: "car.2",
                        action: {
                            showingVehicleStatus = true
                        }
                    )
                    
                    testButton(
                        title: "Loading View Demo",
                        subtitle: "Test various loading animations",
                        icon: "arrow.clockwise.circle",
                        action: {
                            // Future: Add loading view demo
                            testResults.append("Loading view demo not yet implemented")
                        }
                    )
                    
                    NavigationLink(destination: BluetoothDevicesView()) {
                        HStack(spacing: KiaDesign.Spacing.medium) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(KiaDesign.Colors.primary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bluetooth Devices")
                                    .font(KiaDesign.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                                
                                Text("View connected automotive Bluetooth devices")
                                    .font(KiaDesign.Typography.caption)
                                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(KiaDesign.Colors.textTertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Credential Tests Section
    
    private var credentialTestsSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "Credential Sharing Tests", icon: "key")
                
                Text("Test the keychain access groups and Darwin notification system used for sharing credentials between the main app and extensions.")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    testButton(
                        title: "Run All Tests",
                        subtitle: "Execute all credential sharing tests",
                        icon: "play.circle.fill",
                        action: runAllTests
                    )
                    
                    testButton(
                        title: "Test Darwin Notifications",
                        subtitle: "Verify IPC notification system",
                        icon: "bell.and.waves.left.and.right",
                        action: testDarwinNotifications
                    )
                    
                    testButton(
                        title: "Test Credential Storage",
                        subtitle: "Test storing and retrieving credentials",
                        icon: "externaldrive.connected.to.line.below",
                        action: testCredentialStorage
                    )
                    
                    testButton(
                        title: "Clear Test Results",
                        subtitle: "Clear the test output log",
                        icon: "trash",
                        action: clearTestResults
                    )
                }
            }
        }
    }
    
    // MARK: - Test Results Section
    
    private var testResultsSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "Test Results", icon: "doc.text")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(
                                    result.contains("✅") || result.contains("✓") ? KiaDesign.Colors.success :
                                    result.contains("❌") ? KiaDesign.Colors.error :
                                    result.contains("⚠️") ? KiaDesign.Colors.warning :
                                    KiaDesign.Colors.textSecondary
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(KiaDesign.Spacing.small)
                .background(KiaDesign.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(KiaDesign.Colors.primary)
            
            Text(title)
                .font(KiaDesign.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
            
            Spacer()
        }
    }
    
    private func configRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(KiaDesign.Colors.textPrimary)
        }
    }
    
    private func testButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                if isRunningTests {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(KiaDesign.Colors.textTertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(isRunningTests)
    }
    
    // MARK: - Test Actions
    
    private func runAllTests() {
        guard !isRunningTests else { return }
        
        isRunningTests = true
        testResults.removeAll()
        
        // Capture test output will be done by adding results directly
        
        Task {
            // Run tests and add results
            addTestResult("🧪 Starting credential sharing tests...")
            addTestResult("⚙️ Access Group ID: \(AppConfiguration.accessGroupId)")
            addTestResult("📡 API Brand: \(AppConfiguration.apiConfiguration.name)")
            addTestResult("🔐 Authorization Status: \(Authorization.isAuthorized ? "✅ Authorized" : "❌ Not Authorized")")

            // Test Darwin notifications
            addTestResult("📡 Testing Darwin notifications...")
            let notificationTest = testDarwinNotificationSync()
            addTestResult(notificationTest)
            
            addTestResult("✅ All tests completed!")
            isRunningTests = false
        }
    }
    
    private func testDarwinNotifications() {
        guard !isRunningTests else { return }
        
        isRunningTests = true
        addTestResult("📡 Testing Darwin notifications...")
        
        // Test Darwin notification posting and receiving
        var receivedTest = false
        
        DarwinNotificationHelper.observe(name: "com.kiamaps.test.notification") {
            receivedTest = true
            addTestResult("✅ Darwin notification received successfully")
        }
        
        addTestResult("📤 Posting test Darwin notification...")
        DarwinNotificationHelper.post(name: "com.kiamaps.test.notification")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !receivedTest {
                addTestResult("❌ Darwin notification was not received")
            }
            addTestResult("✅ Darwin notification test completed")
            isRunningTests = false
        }
    }
    
    private func testCredentialStorage() {
        guard !isRunningTests else { return }
        
        isRunningTests = true
        addTestResult("💾 Testing credential storage...")
        
        Task {
            // Test credential storage and retrieval
            let originalAuth = Authorization.authorization
            
            // Create test credentials
            let testAuth = AuthorizationData(
                stamp: "debug_test_\(Date().timeIntervalSince1970)",
                deviceId: UUID(),
                accessToken: "debug_test_token",
                expiresIn: 3600,
                refreshToken: "debug_test_refresh",
                isCcuCCS2Supported: false
            )
            
            addTestResult("📝 Storing test credentials...")
            Authorization.store(data: testAuth)
            
            addTestResult("📖 Retrieving stored credentials...")
            if let retrievedAuth = Authorization.authorization,
               retrievedAuth.accessToken == testAuth.accessToken {
                addTestResult("✅ Credentials stored and retrieved successfully")
            } else {
                addTestResult("❌ Failed to retrieve stored credentials")
            }
            
            // Restore original credentials if they existed
            if let originalAuth = originalAuth {
                addTestResult("♻️ Restoring original credentials...")
                Authorization.store(data: originalAuth)
            } else {
                addTestResult("🧹 Clearing test credentials...")
                Authorization.remove()
            }
            
            addTestResult("✅ Credential storage test completed")
            isRunningTests = false
        }
    }
    
    private func clearTestResults() {
        testResults.removeAll()
    }
    
    private func addTestResult(_ result: String) {
        DispatchQueue.main.async {
            testResults.append(result)
        }
    }
    
    private func testDarwinNotificationSync() -> String {
        var received = false
        let testName = "com.kiamaps.debug.test.\(UUID().uuidString)"
        
        DarwinNotificationHelper.observe(name: testName) {
            received = true
        }
        
        DarwinNotificationHelper.post(name: testName)
        
        // Small delay to allow notification processing
        Thread.sleep(forTimeInterval: 0.1)
        
        return received ? "✅ Darwin notifications working" : "❌ Darwin notifications failed"
    }
}

// MARK: - Preview

#Preview("Debug Screen") {
    DebugScreenView()
}
