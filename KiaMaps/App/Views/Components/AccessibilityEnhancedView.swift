//
//  AccessibilityEnhancedView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Comprehensive accessibility system with VoiceOver, Dynamic Type, and inclusive design
//

import SwiftUI

// MARK: - Accessibility Enhanced Button

/// Tesla-inspired button with full accessibility support
struct AccessibleKiaButton: View {
    let title: String
    let icon: String?
    let style: KiaButton.Style
    let size: KiaButton.Size
    let isEnabled: Bool
    let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle
    let action: () -> Void
    
    // Accessibility properties
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let accessibilityTraits: AccessibilityTraits
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: KiaButton.Style = .primary,
        size: KiaButton.Size = .medium,
        isEnabled: Bool = true,
        hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityTraits: AccessibilityTraits = [.button],
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.hapticFeedback = hapticFeedback
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityTraits = accessibilityTraits
        self.action = action
    }
    
    var body: some View {
        Button(action: handleAction) {
            HStack(spacing: scaledSpacing) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: scaledIconSize, weight: .medium))
                        .accessibilityHidden(true)
                }
                
                Text(title)
                    .font(scaledFont)
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(foregroundColor)
            .frame(minHeight: minTouchTarget)
            .padding(.horizontal, scaledHorizontalPadding)
            .padding(.vertical, scaledVerticalPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.1),
                value: isPressed
            )
        }
        .disabled(!isEnabled)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint)
        .accessibilityTraits(isEnabled ? accessibilityTraits : [accessibilityTraits, .notEnabled])
        .accessibilityAddTraits(isPressed ? [.isSelected] : [])
    }
    
    // MARK: - Dynamic Scaling
    
    private var minTouchTarget: CGFloat {
        max(44, scaledVerticalPadding * 2 + scaledFont.lineHeight)
    }
    
    private var scaledSpacing: CGFloat {
        let baseSpacing: CGFloat = 8
        return baseSpacing * dynamicTypeMultiplier
    }
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = {
            switch size {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }()
        return baseSize * dynamicTypeMultiplier
    }
    
    private var scaledFont: Font {
        let baseSize: CGFloat = {
            switch size {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }()
        return .system(size: baseSize * dynamicTypeMultiplier, weight: .semibold)
    }
    
    private var scaledHorizontalPadding: CGFloat {
        let basePadding: CGFloat = {
            switch size {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }()
        return basePadding * dynamicTypeMultiplier
    }
    
    private var scaledVerticalPadding: CGFloat {
        let basePadding: CGFloat = {
            switch size {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }()
        return basePadding * dynamicTypeMultiplier
    }
    
    private var dynamicTypeMultiplier: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.0
        case .xLarge: return 1.1
        case .xxLarge: return 1.2
        case .xxxLarge: return 1.3
        case .accessibility1: return 1.4
        case .accessibility2: return 1.5
        case .accessibility3: return 1.6
        case .accessibility4: return 1.7
        case .accessibility5: return 1.8
        @unknown default: return 1.0
        }
    }
    
    // MARK: - Colors
    
    private var backgroundColor: Color {
        let baseColor: Color = {
            switch style {
            case .primary:
                return KiaDesign.Colors.primary
            case .secondary:
                return KiaDesign.Colors.cardBackground
            case .destructive:
                return KiaDesign.Colors.error
            case .success:
                return KiaDesign.Colors.success
            }
        }()
        
        // Adjust for pressed state with accessibility considerations
        if isPressed {
            return colorScheme == .dark ? baseColor.lighter(by: 0.1) : baseColor.darker(by: 0.1)
        }
        
        return baseColor
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive, .success:
            return .white
        case .secondary:
            return KiaDesign.Colors.textPrimary
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        }
    }
    
    private func handleAction() {
        if isEnabled {
            UIImpactFeedbackGenerator(style: hapticFeedback).impactOccurred()
            action()
        }
    }
}

// MARK: - Accessibility Enhanced Progress Bar

/// Battery/charging progress bar with full accessibility support
struct AccessibleProgressBar: View {
    let value: Double
    let style: KiaProgressBar.Style
    let showPercentage: Bool
    let animationDuration: Double
    let accessibilityLabel: String?
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var animatedValue: Double = 0
    
    init(
        value: Double,
        style: KiaProgressBar.Style = .standard,
        showPercentage: Bool = true,
        animationDuration: Double = 0.5,
        accessibilityLabel: String? = nil
    ) {
        self.value = value
        self.style = style
        self.showPercentage = showPercentage
        self.animationDuration = animationDuration
        self.accessibilityLabel = accessibilityLabel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: scaledSpacing) {
            if showPercentage {
                HStack {
                    if let label = accessibilityLabel {
                        Text(label)
                            .font(scaledCaptionFont)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(value * 100))%")
                        .font(scaledCaptionFont)
                        .fontWeight(.medium)
                        .foregroundStyle(progressColor)
                        .monospacedDigit()
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(trackBackgroundColor)
                        .frame(height: trackHeight)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(progressGradient)
                        .frame(width: max(0, geometry.size.width * animatedValue), height: trackHeight)
                        .animation(
                            reduceMotion ? .none : .easeInOut(duration: animationDuration),
                            value: animatedValue
                        )
                    
                    // Animated highlight (for charging)
                    if style == .charging && animatedValue > 0 {
                        chargingHighlight(width: geometry.size.width)
                    }
                }
            }
            .frame(height: trackHeight)
            .onAppear {
                animatedValue = value
            }
            .onChange(of: value) { _, newValue in
                animatedValue = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityTraits(.updatesFrequently)
    }
    
    // MARK: - Dynamic Scaling
    
    private var scaledSpacing: CGFloat {
        4 * dynamicTypeMultiplier
    }
    
    private var scaledCaptionFont: Font {
        .caption.weight(.medium)
    }
    
    private var trackHeight: CGFloat {
        let baseHeight: CGFloat = 8
        return baseHeight * max(1.0, dynamicTypeMultiplier * 0.8)
    }
    
    private var dynamicTypeMultiplier: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.0
        case .xLarge: return 1.1
        case .xxLarge: return 1.2
        case .xxxLarge: return 1.3
        default: return min(1.5, max(1.0, dynamicTypeSize.rawValue))
        }
    }
    
    // MARK: - Visual Properties
    
    private var trackBackgroundColor: Color {
        KiaDesign.Colors.textTertiary.opacity(0.2)
    }
    
    private var progressColor: Color {
        switch style {
        case .standard:
            return KiaDesign.Colors.primary
        case .charging:
            return KiaDesign.Colors.charging
        case .battery:
            return batteryColor
        case .temperature:
            return KiaDesign.Colors.Climate.auto
        }
    }
    
    private var batteryColor: Color {
        switch value {
        case 0.8...1.0:
            return KiaDesign.Colors.success
        case 0.5...0.8:
            return KiaDesign.Colors.primary
        case 0.2...0.5:
            return KiaDesign.Colors.warning
        default:
            return KiaDesign.Colors.error
        }
    }
    
    private var progressGradient: LinearGradient {
        switch style {
        case .charging:
            return LinearGradient(
                colors: [KiaDesign.Colors.charging.opacity(0.8), KiaDesign.Colors.charging],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .battery:
            return LinearGradient(
                colors: [batteryColor.opacity(0.8), batteryColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [progressColor.opacity(0.8), progressColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    @ViewBuilder
    private func chargingHighlight(width: CGFloat) -> some View {
        if !reduceMotion {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.6),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 30, height: trackHeight)
                .offset(x: -15)
                .animation(
                    .linear(duration: 2.0).repeatForever(autoreverses: false),
                    value: UUID()
                )
        }
    }
    
    private var accessibilityDescription: String {
        let percentage = Int(value * 100)
        let baseDescription = accessibilityLabel ?? "Progress"
        
        switch style {
        case .battery:
            return "\(baseDescription): \(percentage)% battery remaining"
        case .charging:
            return "\(baseDescription): \(percentage)% charged"
        default:
            return "\(baseDescription): \(percentage)%"
        }
    }
}

// MARK: - State Transition Animation System

/// Manages smooth state transitions with accessibility considerations
struct StateTransitionView<Content: View>: View {
    let content: Content
    let state: TransitionState
    let onStateChange: ((TransitionState) -> Void)?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentState: TransitionState
    
    init(
        state: TransitionState,
        onStateChange: ((TransitionState) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.state = state
        self.onStateChange = onStateChange
        self._currentState = State(initialValue: state)
    }
    
    var body: some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .blur(radius: blurRadius)
            .animation(
                reduceMotion ? .none : transitionAnimation,
                value: currentState
            )
            .onChange(of: state) { _, newState in
                currentState = newState
                onStateChange?(newState)
                
                // Provide accessibility announcement for state changes
                if currentState != newState {
                    announceStateChange(newState)
                }
            }
    }
    
    private var opacity: Double {
        switch currentState {
        case .hidden: return 0
        case .loading: return 0.7
        case .visible: return 1.0
        case .highlighted: return 1.0
        case .disabled: return 0.5
        }
    }
    
    private var scale: CGFloat {
        switch currentState {
        case .hidden: return 0.8
        case .loading: return 0.95
        case .visible: return 1.0
        case .highlighted: return 1.05
        case .disabled: return 0.98
        }
    }
    
    private var yOffset: CGFloat {
        switch currentState {
        case .hidden: return 20
        case .loading: return 5
        case .visible: return 0
        case .highlighted: return -2
        case .disabled: return 0
        }
    }
    
    private var blurRadius: CGFloat {
        switch currentState {
        case .hidden: return 2
        case .loading: return 1
        case .visible: return 0
        case .highlighted: return 0
        case .disabled: return 0.5
        }
    }
    
    private var transitionAnimation: Animation {
        switch currentState {
        case .hidden:
            return .easeOut(duration: 0.3)
        case .loading:
            return .easeInOut(duration: 0.2)
        case .visible:
            return .spring(response: 0.5, dampingFraction: 0.8)
        case .highlighted:
            return .spring(response: 0.3, dampingFraction: 0.6)
        case .disabled:
            return .easeInOut(duration: 0.2)
        }
    }
    
    private func announceStateChange(_ newState: TransitionState) {
        let announcement: String = {
            switch newState {
            case .hidden:
                return "Content hidden"
            case .loading:
                return "Loading content"
            case .visible:
                return "Content loaded"
            case .highlighted:
                return "Content highlighted"
            case .disabled:
                return "Content disabled"
            }
        }()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
}

// MARK: - Transition State Model

enum TransitionState: Equatable {
    case hidden
    case loading
    case visible
    case highlighted
    case disabled
    
    var isInteractive: Bool {
        switch self {
        case .visible, .highlighted:
            return true
        case .hidden, .loading, .disabled:
            return false
        }
    }
}

// MARK: - Press Events ViewModifier

private struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Color Extensions for Accessibility

private extension Color {
    func lighter(by percentage: CGFloat) -> Color {
        return self.opacity(1.0 - percentage * 0.3)
    }
    
    func darker(by percentage: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(max(brightness * (1.0 - percentage), 0.0)),
            opacity: Double(alpha)
        )
    }
}

// MARK: - Dynamic Type Size Extension

private extension DynamicTypeSize {
    var rawValue: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.0
        case .xLarge: return 1.1
        case .xxLarge: return 1.2
        case .xxxLarge: return 1.3
        case .accessibility1: return 1.4
        case .accessibility2: return 1.5
        case .accessibility3: return 1.6
        case .accessibility4: return 1.7
        case .accessibility5: return 1.8
        @unknown default: return 1.0
        }
    }
}

// MARK: - Preview

#Preview("Accessible Components") {
    NavigationView {
        ScrollView {
            VStack(spacing: 24) {
                // Accessible buttons
                VStack(spacing: 16) {
                    Text("Accessible Buttons")
                        .font(.headline)
                    
                    AccessibleKiaButton(
                        "Lock Vehicle",
                        icon: "lock.fill",
                        style: .primary,
                        accessibilityLabel: "Lock vehicle",
                        accessibilityHint: "Locks all doors and activates security system"
                    ) {
                        print("Vehicle locked")
                    }
                    
                    AccessibleKiaButton(
                        "Climate Control",
                        icon: "thermometer",
                        style: .secondary,
                        accessibilityLabel: "Open climate control",
                        accessibilityHint: "Adjust temperature and fan settings"
                    ) {
                        print("Climate control opened")
                    }
                }
                
                // Progress bars
                VStack(spacing: 16) {
                    Text("Accessible Progress Bars")
                        .font(.headline)
                    
                    AccessibleProgressBar(
                        value: 0.75,
                        style: .battery,
                        accessibilityLabel: "Battery level"
                    )
                    
                    AccessibleProgressBar(
                        value: 0.45,
                        style: .charging,
                        accessibilityLabel: "Charging progress"
                    )
                }
                
                // State transitions
                VStack(spacing: 16) {
                    Text("State Transitions")
                        .font(.headline)
                    
                    StateTransitionView(state: .visible) {
                        KiaCard {
                            Text("This card has smooth state transitions")
                                .padding()
                        }
                    }
                }
            }
            .padding()
        }
        .background(KiaDesign.Colors.background)
        .navigationTitle("Accessibility")
    }
}