//
//  MainLoginView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Login state view for MainView
//

import SwiftUI

/// Login view displayed when user is not authenticated
struct MainLoginView: View {
    let onLogin: () -> Void
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Brand icon/logo area
            Image(systemName: "car.circle.fill")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(KiaDesign.Colors.primary)
            
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Welcome to KiaMaps")
                    .font(KiaDesign.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("Connect to your vehicle to get started")
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            KiaButton(
                "Connect Vehicle",
                icon: "car.circle",
                style: .primary,
                size: .large
            ) {
                onLogin()
            }
            .accessibilityLabel("Connect your vehicle")
            .accessibilityHint("Tap to log in with your vehicle account credentials")
        }
        .padding(KiaDesign.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiaDesign.Colors.background)
    }
}

// MARK: - Preview

#Preview("Main Login View") {
    MainLoginView(onLogin: {
        print("Login tapped")
    })
}