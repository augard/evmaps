//
//  ThemeSystemView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Advanced theme system with Dark/Light mode optimization and Dynamic Type testing
//

import SwiftUI

// MARK: - Enhanced Theme System

/// Advanced theme manager with Dark/Light mode optimization
final class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    @Published var accentColor: Color = KiaDesign.Colors.primary
    @Published var enableHighContrast: Bool = false
    @Published var enableReducedMotion: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadThemePreferences()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveThemePreferences()
        
        // Apply theme system-wide
        applyTheme(theme)
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveThemePreferences()
    }
    
    private func loadThemePreferences() {
        if let themeRawValue = userDefaults.object(forKey: "selectedTheme") as? String,
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
        }
        
        enableHighContrast = userDefaults.bool(forKey: "enableHighContrast")
        enableReducedMotion = userDefaults.bool(forKey: "enableReducedMotion")
        
        // Load accent color if available
        if let colorData = userDefaults.data(forKey: "accentColor"),
           let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            accentColor = Color(uiColor)
        }
    }
    
    private func saveThemePreferences() {
        userDefaults.set(currentTheme.rawValue, forKey: "selectedTheme")
        userDefaults.set(enableHighContrast, forKey: "enableHighContrast")
        userDefaults.set(enableReducedMotion, forKey: "enableReducedMotion")
        
        // Save accent color
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(accentColor), requiringSecureCoding: false) {
            userDefaults.set(colorData, forKey: "accentColor")
        }
    }
    
    private func applyTheme(_ theme: AppTheme) {
        // Apply to all windows
        for windowScene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in windowScene.windows {
                switch theme {
                case .light:
                    window.overrideUserInterfaceStyle = .light
                case .dark:
                    window.overrideUserInterfaceStyle = .dark
                case .system:
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
    }
}

// MARK: - App Theme Model

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Enhanced Color System

/// Extended color system with theme-aware colors
extension KiaDesign.Colors {
    
    // MARK: - Theme-Aware Colors
    
    /// Primary colors that adapt to theme
    struct Adaptive {
        static func primaryBackground(_ colorScheme: ColorScheme, highContrast: Bool = false) -> Color {
            switch colorScheme {
            case .light:
                return highContrast ? .white : Color(red: 0.98, green: 0.98, blue: 0.99)
            case .dark:
                return highContrast ? Color(red: 0.05, green: 0.05, blue: 0.05) : Color(red: 0.11, green: 0.11, blue: 0.12)
            @unknown default:
                return Color(red: 0.98, green: 0.98, blue: 0.99)
            }
        }
        
        static func cardBackground(_ colorScheme: ColorScheme, highContrast: Bool = false) -> Color {
            switch colorScheme {
            case .light:
                return highContrast ? Color(red: 0.95, green: 0.95, blue: 0.96) : .white
            case .dark:
                return highContrast ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.15, green: 0.15, blue: 0.16)
            @unknown default:
                return .white
            }
        }
        
        static func textPrimary(_ colorScheme: ColorScheme, highContrast: Bool = false) -> Color {
            switch colorScheme {
            case .light:
                return highContrast ? .black : Color(red: 0.09, green: 0.09, blue: 0.09)
            case .dark:
                return highContrast ? .white : Color(red: 0.98, green: 0.98, blue: 0.99)
            @unknown default:
                return Color(red: 0.09, green: 0.09, blue: 0.09)
            }
        }
        
        static func textSecondary(_ colorScheme: ColorScheme, highContrast: Bool = false) -> Color {
            switch colorScheme {
            case .light:
                return highContrast ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.45, green: 0.45, blue: 0.45)
            case .dark:
                return highContrast ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.65, green: 0.65, blue: 0.65)
            @unknown default:
                return Color(red: 0.45, green: 0.45, blue: 0.45)
            }
        }
        
        static func separator(_ colorScheme: ColorScheme, highContrast: Bool = false) -> Color {
            switch colorScheme {
            case .light:
                return highContrast ? Color(red: 0.7, green: 0.7, blue: 0.7) : Color(red: 0.9, green: 0.9, blue: 0.9)
            case .dark:
                return highContrast ? Color(red: 0.4, green: 0.4, blue: 0.4) : Color(red: 0.25, green: 0.25, blue: 0.25)
            @unknown default:
                return Color(red: 0.9, green: 0.9, blue: 0.9)
            }
        }
    }
    
    // MARK: - Accessibility Colors
    
    struct Accessible {
        static let focusRing = Color(red: 0.0, green: 0.48, blue: 1.0)
        static let selectedBackground = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1)
        static let highContrastBorder = Color(red: 0.0, green: 0.0, blue: 0.0)
    }
}

// MARK: - Theme-Aware Components

/// Theme-aware card component
struct ThemedKiaCard<Content: View>: View {
    let content: Content
    let action: (() -> Void)?
    let elevation: KiaCard<Content>.Elevation
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    
    init(
        elevation: KiaCard<Content>.Elevation = .medium,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large)
                .fill(cardBackgroundColor)
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    y: shadowOffset
                )
        )
    }
    
    private var cardContent: some View {
        content
            .padding(KiaDesign.Spacing.medium)
    }
    
    private var cardBackgroundColor: Color {
        KiaDesign.Colors.Adaptive.cardBackground(colorScheme, highContrast: themeManager.enableHighContrast)
    }
    
    private var shadowColor: Color {
        switch colorScheme {
        case .light:
            return .black.opacity(themeManager.enableHighContrast ? 0.15 : 0.08)
        case .dark:
            return .black.opacity(0.3)
        @unknown default:
            return .black.opacity(0.08)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch elevation {
        case .flat: return 0
        case .low: return themeManager.enableHighContrast ? 1 : 4
        case .medium: return themeManager.enableHighContrast ? 2 : 8
        case .high: return themeManager.enableHighContrast ? 4 : 16
        case .floating: return themeManager.enableHighContrast ? 6 : 24
        }
    }
    
    private var shadowOffset: CGFloat {
        switch elevation {
        case .flat: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 4
        case .floating: return 8
        }
    }
}

// MARK: - Dynamic Type Testing View

/// Comprehensive Dynamic Type testing interface
struct DynamicTypeTestView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var batteryLevel: Double = 0.75
    @State private var isCharging: Bool = false
    @State private var temperature: Double = 22
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: KiaDesign.Spacing.xl) {
                    // Typography Testing
                    typographySection
                    
                    // Component Testing
                    componentSection
                    
                    // Interactive Testing
                    interactiveSection
                    
                    // Theme Controls
                    themeControlSection
                }
                .padding()
            }
            .background(adaptiveBackgroundColor)
            .navigationTitle("Dynamic Type Test")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Typography Section
    
    private var typographySection: some View {
        ThemedKiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Typography Scale")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(adaptiveTextPrimary)
                
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Large Title - \(dynamicTypeSizeName)")
                        .font(.largeTitle)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Text("Title 1 - Perfect for headings")
                        .font(.title)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Text("Title 2 - Section headers work well")
                        .font(.title2)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Text("Headline - Important information")
                        .font(.headline)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Text("Body - This is the standard body text that should be readable at all sizes")
                        .font(.body)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Text("Callout - Secondary information")
                        .font(.callout)
                        .foregroundStyle(adaptiveTextSecondary)
                    
                    Text("Caption - Small details and labels")
                        .font(.caption)
                        .foregroundStyle(adaptiveTextSecondary)
                }
            }
        }
    }
    
    // MARK: - Component Section
    
    private var componentSection: some View {
        ThemedKiaCard {
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Component Testing")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(adaptiveTextPrimary)
                
                // Progress bars
                VStack(spacing: KiaDesign.Spacing.medium) {
                    AccessibleProgressBar(
                        value: batteryLevel,
                        style: .battery,
                        accessibilityLabel: "Battery level"
                    )
                    
                    AccessibleProgressBar(
                        value: isCharging ? 0.45 : 0.0,
                        style: .charging,
                        accessibilityLabel: "Charging progress"
                    )
                }
                
                // Button grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.medium) {
                    AccessibleKiaButton(
                        "Lock",
                        icon: "lock.fill",
                        style: .primary,
                        size: .medium,
                        accessibilityLabel: "Lock vehicle"
                    ) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    
                    AccessibleKiaButton(
                        "Climate",
                        icon: "thermometer",
                        style: .secondary,
                        size: .medium,
                        accessibilityLabel: "Climate control"
                    ) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    
                    AccessibleKiaButton(
                        "Horn",
                        icon: "horn",
                        style: .secondary,
                        size: .medium,
                        accessibilityLabel: "Sound horn"
                    ) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    
                    AccessibleKiaButton(
                        "Locate",
                        icon: "location",
                        style: .primary,
                        size: .medium,
                        accessibilityLabel: "Find vehicle"
                    ) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
        }
    }
    
    // MARK: - Interactive Section
    
    private var interactiveSection: some View {
        ThemedKiaCard {
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Interactive Controls")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(adaptiveTextPrimary)
                
                // Battery level slider
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Battery Level: \(Int(batteryLevel * 100))%")
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Slider(value: $batteryLevel, in: 0...1)
                        .accentColor(themeManager.accentColor)
                }
                
                // Charging toggle
                Toggle("Charging Status", isOn: $isCharging)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(adaptiveTextPrimary)
                
                // Temperature control
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Temperature: \(Int(temperature))°C")
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Slider(value: $temperature, in: 16...30, step: 0.5)
                        .accentColor(themeManager.accentColor)
                }
            }
        }
    }
    
    // MARK: - Theme Control Section
    
    private var themeControlSection: some View {
        ThemedKiaCard {
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Theme Settings")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(adaptiveTextPrimary)
                
                // Theme selector
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Appearance")
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            HStack {
                                Image(systemName: theme.icon)
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: themeManager.currentTheme) { _, newTheme in
                        themeManager.setTheme(newTheme)
                    }
                }
                
                // Accessibility toggles
                VStack(spacing: KiaDesign.Spacing.medium) {
                    Toggle("High Contrast", isOn: $themeManager.enableHighContrast)
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(adaptiveTextPrimary)
                    
                    Toggle("Reduce Motion", isOn: $themeManager.enableReducedMotion)
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(adaptiveTextPrimary)
                }
            }
        }
    }
    
    // MARK: - Dynamic Properties
    
    private var dynamicTypeSizeName: String {
        switch dynamicTypeSize {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .xLarge: return "XL"
        case .xxLarge: return "XXL"
        case .xxxLarge: return "XXXL"
        case .accessibility1: return "A1"
        case .accessibility2: return "A2"
        case .accessibility3: return "A3"
        case .accessibility4: return "A4"
        case .accessibility5: return "A5"
        @unknown default: return "Unknown"
        }
    }
    
    private var adaptiveBackgroundColor: Color {
        KiaDesign.Colors.Adaptive.primaryBackground(
            themeManager.currentTheme == .system ? .light : (themeManager.currentTheme == .light ? .light : .dark),
            highContrast: themeManager.enableHighContrast
        )
    }
    
    private var adaptiveTextPrimary: Color {
        KiaDesign.Colors.Adaptive.textPrimary(
            themeManager.currentTheme == .system ? .light : (themeManager.currentTheme == .light ? .light : .dark),
            highContrast: themeManager.enableHighContrast
        )
    }
    
    private var adaptiveTextSecondary: Color {
        KiaDesign.Colors.Adaptive.textSecondary(
            themeManager.currentTheme == .system ? .light : (themeManager.currentTheme == .light ? .light : .dark),
            highContrast: themeManager.enableHighContrast
        )
    }
}

// MARK: - Theme Environment Setup

/// Environment setup for theme system
struct ThemeEnvironmentModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(themeManager)
            .environment(\.colorScheme, effectiveColorScheme ?? .light)
    }
    
    private var effectiveColorScheme: ColorScheme? {
        switch themeManager.currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Use system default
        }
    }
}

extension View {
    func withThemeEnvironment() -> some View {
        modifier(ThemeEnvironmentModifier())
    }
}

// MARK: - Preview

#Preview("Dynamic Type Test") {
    DynamicTypeTestView()
        .withThemeEnvironment()
}