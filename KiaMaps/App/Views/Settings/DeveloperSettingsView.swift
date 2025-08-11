//
//  DeveloperSettingsView.swift
//  KiaMaps
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import SwiftUI

struct DeveloperSettingsView: View {
    @AppStorage("ShowDeveloperMenu") private var showDeveloperMenu = false
    @AppStorage("RemoteLoggingEnabled") private var remoteLoggingEnabled = false
    @State private var showingDebugLogs = false
    @State private var tapCount = 0
    
    var body: some View {
        NavigationView {
            List {
                // Developer menu toggle (hidden by default, enabled by tapping version 7 times)
                if showDeveloperMenu {
                    developerSection
                }
                
                // App info section
                appInfoSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDebugLogs) {
                DebugLogsView()
            }
        }
    }
    
    private var developerSection: some View {
        Section("Developer") {
            // Remote logging toggle
            Toggle("Remote Logging", isOn: $remoteLoggingEnabled)
                .onChange(of: remoteLoggingEnabled) { _, enabled in
                    // This will enable/disable remote logging in extensions
                    UserDefaults.standard.set(enabled, forKey: "RemoteLoggingEnabled")
                    
                    // Start/stop server in main app
                    if enabled {
                        RemoteLoggingServer.shared.start()
                    } else {
                        RemoteLoggingServer.shared.stop()
                    }
                }
            
            // Debug logs viewer
            Button {
                showingDebugLogs = true
            } label: {
                HStack {
                    Label("Debug Logs", systemImage: "doc.text.magnifyingglass")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Clear keychain (useful for testing)
            Button {
                clearKeychain()
            } label: {
                Label("Clear Keychain", systemImage: "key.slash")
                    .foregroundStyle(.red)
            }
            
            // Force crash (for testing crash reporting)
            #if DEBUG
            Button {
                fatalError("Force crash for testing")
            } label: {
                Label("Force Crash", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            #endif
        }
    }
    
    private var appInfoSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        handleVersionTap()
                    }
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
            
            if showDeveloperMenu {
                HStack {
                    Text("Device ID")
                    Spacer()
                    Text(deviceID)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
    }
    
    private func handleVersionTap() {
        tapCount += 1
        
        if tapCount >= 7 {
            showDeveloperMenu = true
            tapCount = 0
            
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        // Reset tap count after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            tapCount = 0
        }
    }
    
    private func clearKeychain() {
        // Clear all keychain items
        Authorization.remove()
        LoginCredentialManager.clearCredentials()
        
        // Show confirmation
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}