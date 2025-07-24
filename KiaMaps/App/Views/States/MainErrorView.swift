//
//  MainErrorView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Error state view for MainView
//

import SwiftUI

/// Error view displayed when connection or other errors occur
struct MainErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Error icon
            ZStack {
                Circle()
                    .fill(KiaDesign.Colors.error.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.error)
            }
            
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Connection Error")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text(error.localizedDescription)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            KiaButton(
                "Retry Connection",
                icon: "arrow.clockwise",
                style: .primary,
                size: .large
            ) {
                onRetry()
            }
        }
        .padding(KiaDesign.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiaDesign.Colors.background)
    }
}

// MARK: - Preview

#Preview("Main Error View") {
    MainErrorView(
        error: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to connect to vehicle. Please check your internet connection and try again."]),
        onRetry: {
            print("Retry tapped")
        }
    )
}