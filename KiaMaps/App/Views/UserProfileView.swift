//
//  UserProfileView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired user profile screen with account management and preferences
//

import SwiftUI

/// Simple user profile screen with account information and app preferences
struct UserProfileView: View {
    let api: Api
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogoutAlert = false
    @State private var showingDebugScreen = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: KiaDesign.Spacing.xl) {
                    // Profile Header
                    profileHeader
                    
                    // Account Information
                    accountInformationSection
                    
                    // App Preferences
                    preferencesSection
                    
                    // Debug & Support
                    debugSupportSection
                    
                    // Sign Out
                    signOutSection
                }
                .padding(KiaDesign.Spacing.large)
            }
            .background(KiaDesign.Colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(KiaDesign.Colors.primary)
                }
            }
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to log in again to access your vehicle.")
        }
        .sheet(isPresented: $showingDebugScreen) {
            DebugScreenView()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // User Avatar
            ZStack {
                Circle()
                    .fill(KiaDesign.Colors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.primary)
            }
            
            // User Info
            VStack(spacing: 4) {
                Text("User Account")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("Connected to \(api.configuration.name)")
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
        }
        .padding(.vertical, KiaDesign.Spacing.medium)
    }
    
    // MARK: - Account Information
    
    private var accountInformationSection: some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "Account Information", icon: "person.circle")
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    accountInfoRow(
                        title: "Service",
                        value: api.configuration.name,
                        icon: "car.circle"
                    )
                    
                    accountInfoRow(
                        title: "Username",
                        value: LoginCredentialManager.retrieveCredentials()?.username ?? "Not Set",
                        icon: "person"
                    )
                    
                    accountInfoRow(
                        title: "Vehicle VIN",
                        value: AppConfiguration.vehicleVin ?? "Auto-detect",
                        icon: "barcode"
                    )
                    
                    accountInfoRow(
                        title: "Connection Status",
                        value: Authorization.isAuthorized ? "Connected" : "Disconnected",
                        icon: "wifi",
                        valueColor: Authorization.isAuthorized ? KiaDesign.Colors.success : KiaDesign.Colors.error
                    )
                }
            }
        }
    }
    
    // MARK: - Preferences
    
    private var preferencesSection: some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "App Preferences", icon: "gearshape")
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    preferenceRow(
                        title: "Temperature Unit",
                        value: "Celsius",
                        icon: "thermometer"
                    ) {
                        // Temperature unit selection
                    }
                    
                    preferenceRow(
                        title: "Distance Unit",
                        value: "Kilometers",
                        icon: "speedometer"
                    ) {
                        // Distance unit selection
                    }
                    
                    preferenceRow(
                        title: "Notifications",
                        value: "Enabled",
                        icon: "bell"
                    ) {
                        // Notification settings
                    }
                    
                    preferenceRow(
                        title: "Auto-Refresh",
                        value: "Every 5 minutes",
                        icon: "arrow.clockwise"
                    ) {
                        // Auto-refresh settings
                    }
                }
            }
        }
    }
    
    // MARK: - Debug & Support
    
    private var debugSupportSection: some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.medium) {
                sectionHeader(title: "Debug & Support", icon: "wrench.and.screwdriver")
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    actionRow(
                        title: "Debug Screen",
                        subtitle: "Access legacy UI and debug information",
                        icon: "ladybug",
                        action: {
                            showingDebugScreen = true
                        }
                    )
                    
                    actionRow(
                        title: "App Version",
                        subtitle: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                        icon: "info.circle"
                    )
                    
                    actionRow(
                        title: "Privacy Policy",
                        subtitle: "View our privacy policy",
                        icon: "hand.raised",
                        action: {
                            // Open privacy policy
                        }
                    )
                    
                    actionRow(
                        title: "Contact Support",
                        subtitle: "Get help with your account",
                        icon: "questionmark.circle",
                        action: {
                            // Open support
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Sign Out
    
    private var signOutSection: some View {
        KiaButton(
            "Sign Out",
            icon: "arrow.right.square",
            style: .secondary,
            size: .large
        ) {
            showingLogoutAlert = true
        }
        .padding(.top, KiaDesign.Spacing.large)
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
    
    private func accountInfoRow(
        title: String,
        value: String,
        icon: String,
        valueColor: Color = KiaDesign.Colors.textPrimary
    ) -> some View {
        HStack(spacing: KiaDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(KiaDesign.Typography.body)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 2)
    }
    
    private func preferenceRow(
        title: String,
        value: String,
        icon: String,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Spacer()
                
                Text(value)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
    
    private func actionRow(
        title: String,
        subtitle: String? = nil,
        icon: String,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                if action as AnyObject !== {} as AnyObject {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(KiaDesign.Colors.textTertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func signOut() async {
        do {
            try await api.logoutWithAutoRefresh()
            Authorization.remove()
            LoginCredentialManager.clearCredentials()
            
            // Dismiss the profile view
            dismiss()
            
            // The app will automatically return to login screen
            // since Authorization.isAuthorized is now false
        } catch {
            // Handle error - for now just dismiss
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("User Profile") {
    UserProfileView(
        api: Api(configuration: AppConfiguration.apiConfiguration)
    )
}
