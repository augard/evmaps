//
//  KiaCard.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired card component with modern styling and animations
//

import SwiftUI

/// Modern card container component inspired by Tesla's design language
/// Provides consistent styling, elevation, and interactive feedback
struct KiaCard<Content: View>: View {
    let content: Content
    let elevation: Elevation
    let padding: CGFloat
    let cornerRadius: CGFloat
    let showBorder: Bool
    let isInteractive: Bool
    let action: (() -> Void)?
    
    @State private var isPressed = false
    
    enum Elevation {
        case flat       // No shadow
        case low        // Subtle shadow
        case medium     // Standard card shadow
        case high       // Elevated shadow
        case floating   // Prominent shadow
        
        var shadow: KiaDesign.Shadow.custom {
            switch self {
            case .flat:
                return KiaDesign.Shadow.custom(color: .clear, radius: 0, x: 0, y: 0)
            case .low:
                return KiaDesign.Shadow.custom(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
            case .medium:
                return KiaDesign.Shadow.card
            case .high:
                return KiaDesign.Shadow.elevated
            case .floating:
                return KiaDesign.Shadow.floating
            }
        }
    }
    
    // MARK: - Initializers
    
    /// Standard card with default styling
    init(
        elevation: Elevation = .medium,
        padding: CGFloat = KiaDesign.Spacing.cardPadding,
        cornerRadius: CGFloat = KiaDesign.CornerRadius.large,
        showBorder: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.elevation = elevation
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
        self.isInteractive = false
        self.action = nil
    }
    
    /// Interactive card with tap action
    init(
        elevation: Elevation = .medium,
        padding: CGFloat = KiaDesign.Spacing.cardPadding,
        cornerRadius: CGFloat = KiaDesign.CornerRadius.large,
        showBorder: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.elevation = elevation
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
        self.isInteractive = true
        self.action = action
    }
    
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(borderOverlay)
            .shadow(
                color: currentShadow.color,
                radius: currentShadow.radius,
                x: currentShadow.x,
                y: currentShadow.y
            )
            .scaleEffect(isPressed && isInteractive ? 0.98 : 1.0)
            .animation(KiaDesign.Animation.quick, value: isPressed)
            .if(isInteractive) { view in
                view
                    .onTapGesture {
                        action?()
                    }
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
                        isPressed = pressing
                    } perform: {
                        // Long press completed
                    }
            }
    }
    
    // MARK: - Private Views
    
    private var cardBackground: some View {
        Group {
            if isInteractive && isPressed {
                KiaDesign.Colors.cardBackground
                    .brightness(-0.05)
            } else {
                KiaDesign.Colors.cardBackground
            }
        }
    }
    
    private var borderOverlay: some View {
        Group {
            if showBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        KiaDesign.Colors.textTertiary.opacity(0.2),
                        lineWidth: 1
                    )
            } else {
                EmptyView()
            }
        }
    }
    
    private var currentShadow: KiaDesign.Shadow.custom {
        if isInteractive && isPressed {
            // Reduce shadow when pressed
            let shadow = elevation.shadow
            return KiaDesign.Shadow.custom(
                color: shadow.color,
                radius: shadow.radius * 0.5,
                x: shadow.x,
                y: shadow.y * 0.5
            )
        }
        return elevation.shadow
    }
}

// MARK: - Specialized Card Variants

/// Hero section card for prominent content like battery status
struct KiaHeroCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient?
    
    init(
        gradient: LinearGradient? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.gradient = gradient
    }
    
    var body: some View {
        KiaCard(elevation: .high, padding: KiaDesign.Spacing.xl) {
            content
        }
        .background(
            Group {
                if let gradient = gradient {
                    gradient
                        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
                        .opacity(0.1)
                } else {
                    EmptyView()
                }
            }
        )
    }
}

/// Compact card for quick actions and status items
struct KiaCompactCard<Content: View>: View {
    let content: Content
    let action: (() -> Void)?
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.action = action
    }
    
    var body: some View {
        Group {
            if let action = action {
                KiaCard(
                    elevation: .medium,
                    padding: KiaDesign.Spacing.medium,
                    cornerRadius: KiaDesign.CornerRadius.medium,
                    action: action
                ) {
                    content
                }
            } else {
                KiaCard(
                    elevation: .medium,
                    padding: KiaDesign.Spacing.medium,
                    cornerRadius: KiaDesign.CornerRadius.medium
                ) {
                    content
                }
            }
        }
    }
}

/// Warning or alert card with colored border
struct KiaAlertCard<Content: View>: View {
    let content: Content
    let alertType: AlertType
    
    enum AlertType {
        case info
        case success
        case warning
        case error
        
        var color: Color {
            switch self {
            case .info:
                return KiaDesign.Colors.accent
            case .success:
                return KiaDesign.Colors.success
            case .warning:
                return KiaDesign.Colors.warning
            case .error:
                return KiaDesign.Colors.error
            }
        }
    }
    
    init(type: AlertType, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.alertType = type
    }
    
    var body: some View {
        KiaCard(elevation: .medium, showBorder: true) {
            HStack(spacing: KiaDesign.Spacing.small) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(alertType.color)
                    .frame(width: 4)
                
                content
            }
        }
    }
}

// MARK: - View Extension Helpers

extension View {
    /// Conditionally apply modifier
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview("Card Variants") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.large) {
            // Standard card
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Standard Card")
                        .font(KiaDesign.Typography.title3)
                    Text("This is a standard card with medium elevation and default styling.")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
            }
            
            // Interactive card
            KiaCard(action: {
                print("Card tapped!")
            }) {
                HStack {
                    Image(systemName: "bolt.car.fill")
                        .font(.title2)
                        .foregroundStyle(KiaDesign.Colors.primary)
                    
                    VStack(alignment: .leading) {
                        Text("Interactive Card")
                            .font(KiaDesign.Typography.bodyBold)
                        Text("Tap me!")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(KiaDesign.Colors.textTertiary)
                }
            }
            
            // Hero card
            KiaHeroCard(gradient: KiaDesign.Colors.chargingGradient) {
                VStack(spacing: KiaDesign.Spacing.medium) {
                    Text("Hero Card")
                        .font(KiaDesign.Typography.displayMedium)
                    Text("Prominent content with gradient background")
                        .font(KiaDesign.Typography.body)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Alert cards
            KiaAlertCard(type: .success) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KiaDesign.Colors.success)
                    Text("Vehicle is ready to drive")
                        .font(KiaDesign.Typography.body)
                }
            }
            
            KiaAlertCard(type: .warning) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(KiaDesign.Colors.warning)
                    Text("Low tire pressure detected")
                        .font(KiaDesign.Typography.body)
                }
            }
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}
