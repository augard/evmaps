//
//  KiaButton.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired button components with haptic feedback and smooth animations
//

import SwiftUI

/// Modern button component with Tesla-inspired styling and haptic feedback
struct KiaButton: View {
    let title: String
    let icon: String?
    let style: Style
    let size: Size
    let isEnabled: Bool
    let isLoading: Bool
    let isFullWidth: Bool
    let hapticFeedback: HapticFeedback
    let action: () -> Void
    
    @State private var isPressed = false
    
    enum Style {
        case primary        // Kia brand color
        case secondary      // Gray outline
        case tertiary       // Text only
        case destructive    // Red for dangerous actions
        case success        // Green for positive actions
        case custom(background: Color, foreground: Color, border: Color?)
        
        var colors: (background: Color, foreground: Color, border: Color?) {
            switch self {
            case .primary:
                return (KiaDesign.Colors.primary, .white, nil)
            case .secondary:
                return (KiaDesign.Colors.cardBackground, KiaDesign.Colors.textPrimary, KiaDesign.Colors.textTertiary)
            case .tertiary:
                return (.clear, KiaDesign.Colors.accent, nil)
            case .destructive:
                return (KiaDesign.Colors.error, .white, nil)
            case .success:
                return (KiaDesign.Colors.success, .white, nil)
            case .custom(let bg, let fg, let border):
                return (bg, fg, border)
            }
        }
        
        var disabledColors: (background: Color, foreground: Color, border: Color?) {
            switch self {
            case .primary:
                return (KiaDesign.Colors.textTertiary, KiaDesign.Colors.textSecondary, nil)
            case .secondary:
                return (KiaDesign.Colors.cardBackground.opacity(0.5), KiaDesign.Colors.textTertiary, KiaDesign.Colors.textTertiary.opacity(0.3))
            case .tertiary:
                return (.clear, KiaDesign.Colors.textTertiary, nil)
            case .destructive:
                return (KiaDesign.Colors.error.opacity(0.3), KiaDesign.Colors.textTertiary, nil)
            case .success:
                return (KiaDesign.Colors.success.opacity(0.3), KiaDesign.Colors.textTertiary, nil)
            case .custom(let bg, _, let border):
                return (bg.opacity(0.3), KiaDesign.Colors.textTertiary, border?.opacity(0.3))
            }
        }
        
        var pressedColors: (background: Color, foreground: Color) {
            let colors = self.colors
            switch self {
            case .tertiary:
                return (KiaDesign.Colors.accent.opacity(0.1), colors.foreground)
            default:
                return (colors.background.opacity(0.8), colors.foreground)
            }
        }
    }
    
    enum Size {
        case small      // Compact size for secondary actions
        case medium     // Standard size for most buttons
        case large      // Prominent size for primary actions
        case extraLarge // Hero size for main actions
        
        var dimensions: (height: CGFloat, padding: EdgeInsets, font: Font) {
            switch self {
            case .small:
                return (36, EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16), KiaDesign.Typography.bodySmall)
            case .medium:
                return (44, EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20), KiaDesign.Typography.body)
            case .large:
                return (52, EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24), KiaDesign.Typography.bodyBold)
            case .extraLarge:
                return (60, EdgeInsets(top: 20, leading: 32, bottom: 20, trailing: 32), KiaDesign.Typography.title3)
            }
        }
    }
    
    enum HapticFeedback {
        case none
        case light
        case medium
        case heavy
        case selection
        case success
        case warning
        case error
        
        func trigger() {
            switch self {
            case .none:
                break
            case .light:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .heavy:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .selection:
                UISelectionFeedbackGenerator().selectionChanged()
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .error:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    // MARK: - Initializers
    
    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        size: Size = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        isFullWidth: Bool = false,
        hapticFeedback: HapticFeedback = .light,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.hapticFeedback = hapticFeedback
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: KiaDesign.Spacing.small) {
                if isLoading {
                    KiaInlineLoadingView(
                        size: .small,
                        color: currentColors.foreground
                    )
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                }
                
                if !title.isEmpty {
                    Text(title)
                        .font(size.dimensions.font)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(currentColors.foreground)
            .padding(size.dimensions.padding)
            .frame(minHeight: size.dimensions.height)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(currentColors.background)
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium))
            .overlay(borderOverlay)
            .scaleEffect(isPressed && isEnabled ? 0.96 : 1.0)
            .animation(KiaDesign.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle()) // Remove default button styling
        .disabled(!isEnabled || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            if isEnabled && !isLoading {
                isPressed = pressing
            }
        } perform: {
            // Long press completed - handled by button action
        }
    }
    
    // MARK: - Private Properties
    
    private var currentColors: (background: Color, foreground: Color, border: Color?) {
        if !isEnabled || isLoading {
            return style.disabledColors
        } else if isPressed && isEnabled && !isLoading {
            let pressed = style.pressedColors
            return (pressed.background, pressed.foreground, style.colors.border)
        } else {
            return style.colors
        }
    }
    
    private var borderOverlay: some View {
        Group {
            if let borderColor = currentColors.border {
                RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            } else {
                EmptyView()
            }
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small:
            return 14
        case .medium:
            return 16
        case .large:
            return 18
        case .extraLarge:
            return 20
        }
    }
    
    private func handleTap() {
        if isEnabled && !isLoading {
            hapticFeedback.trigger()
            action()
        }
    }
}

// MARK: - Quick Action Button

/// Compact button for quick actions like lock, climate, etc.
struct KiaQuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isActive: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: KiaDesign.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(KiaDesign.Typography.captionSmall)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
            }
            .padding(KiaDesign.Spacing.medium)
            .frame(minWidth: 80, minHeight: 80)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large)
                    .stroke(
                        isActive ? KiaDesign.Colors.primary : .clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(KiaDesign.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            isPressed = pressing
        } perform: {
            // Handled by button action
        }
    }
    
    private var iconColor: Color {
        isActive ? KiaDesign.Colors.primary : KiaDesign.Colors.textSecondary
    }
    
    private var backgroundColor: Color {
        if isActive {
            return KiaDesign.Colors.primary.opacity(0.1)
        } else if isPressed {
            return KiaDesign.Colors.cardBackground.opacity(0.8)
        } else {
            return KiaDesign.Colors.cardBackground
        }
    }
    
    private func handleTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        action()
    }
}

// MARK: - Floating Action Button

/// Tesla-style floating action button for primary actions
struct KiaFloatingActionButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(icon: String, size: CGFloat = 56, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(KiaDesign.Colors.primary)
                        .shadow(
                            color: KiaDesign.Colors.primary.opacity(0.3),
                            radius: 8,
                            y: 4
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(KiaDesign.Animation.bouncy, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            isPressed = pressing
        } perform: {
            // Handled by button action
        }
    }
    
    private func handleTap() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        action()
    }
}

// MARK: - Preview

#Preview("Button Variants") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Standard buttons
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Standard Buttons")
                    .font(KiaDesign.Typography.title2)
                
                KiaButton("Primary Action", icon: "bolt.car.fill", style: .primary) {
                    print("Primary tapped")
                }
                
                KiaButton("Secondary Action", icon: "gear", style: .secondary) {
                    print("Secondary tapped")
                }
                
                KiaButton("Tertiary Action", style: .tertiary) {
                    print("Tertiary tapped")
                }
                
                KiaButton("Destructive Action", icon: "trash", style: .destructive) {
                    print("Delete tapped")
                }
            }
            
            Divider()
            
            // Different sizes
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Button Sizes")
                    .font(KiaDesign.Typography.title2)
                
                KiaButton("Small", size: .small) { }
                KiaButton("Medium", size: .medium) { }
                KiaButton("Large", size: .large) { }
                KiaButton("Extra Large", size: .extraLarge) { }
            }
            
            Divider()
            
            // Quick action buttons
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Quick Actions")
                    .font(KiaDesign.Typography.title2)
                
                HStack(spacing: KiaDesign.Spacing.medium) {
                    KiaQuickActionButton(
                        icon: "lock.fill",
                        title: "Lock",
                        subtitle: "Locked",
                        isActive: true
                    ) { }
                    
                    KiaQuickActionButton(
                        icon: "snow",
                        title: "Climate",
                        subtitle: "22°C"
                    ) { }
                    
                    KiaQuickActionButton(
                        icon: "horn",
                        title: "Horn",
                        subtitle: "Available"
                    ) { }
                }
            }
            
            Divider()
            
            // Floating action button
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Floating Action")
                    .font(KiaDesign.Typography.title2)
                
                KiaFloatingActionButton(icon: "plus") { }
            }
            
            // States
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Button States")
                    .font(KiaDesign.Typography.title2)
                
                KiaButton("Loading", isLoading: true) { }
                
                // Disabled states for all styles
                VStack(spacing: KiaDesign.Spacing.small) {
                    Text("Disabled States")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    KiaButton("Disabled Primary", style: .primary, isEnabled: false) { }
                    KiaButton("Disabled Secondary", style: .secondary, isEnabled: false) { }
                    KiaButton("Disabled Tertiary", style: .tertiary, isEnabled: false) { }
                    KiaButton("Disabled Destructive", style: .destructive, isEnabled: false) { }
                }
            }
            
            Divider()
            
            // Full width buttons
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Full Width Buttons")
                    .font(KiaDesign.Typography.title2)
                
                KiaButton("Full Width Primary", style: .primary, isFullWidth: true) { }
                KiaButton("Full Width Secondary", style: .secondary, isFullWidth: true) { }
                KiaButton("Sign In", icon: "arrow.right", style: .primary, size: .large, isFullWidth: true) { }
            }
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}
