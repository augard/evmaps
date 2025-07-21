//
//  TeslaInspiredShowcaseView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Comprehensive showcase of all Tesla-inspired UI components and interactions
//

import SwiftUI
import MapKit
import CoreLocation

/// Complete showcase of Tesla-inspired UI modernization
struct TeslaInspiredShowcaseView: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var selectedPageIndex = 0
    @State private var isRefreshing = false
    @State private var loadingState: LoadingState = .visible
    
    // Sample data states
    @State private var batteryLevel: Double = 0.78
    @State private var targetTemperature: Double = 22
    @State private var isCharging: Bool = false
    @State private var isClimateOn: Bool = true
    
    private let showcasePages = [
        NavigationPage(
            id: "overview",
            title: "Overview",
            icon: "car.fill",
            accessibilityLabel: "Vehicle overview"
        ),
        NavigationPage(
            id: "battery",
            title: "Battery",
            icon: "battery.75",
            accessibilityLabel: "Battery status and charging"
        ),
        NavigationPage(
            id: "climate",
            title: "Climate",
            icon: "thermometer",
            accessibilityLabel: "Climate control"
        ),
        NavigationPage(
            id: "map",
            title: "Map",
            icon: "map.fill",
            accessibilityLabel: "Vehicle location and navigation"
        ),
        NavigationPage(
            id: "settings",
            title: "Theme",
            icon: "paintbrush.fill",
            accessibilityLabel: "Theme and accessibility settings"
        )
    ]
    
    var body: some View {
        NavigationView {
            SwipeNavigationView(pages: showcasePages) { page, isActive in
                pageContent(for: page, isActive: isActive)
            }
            .navigationTitle("Tesla-Inspired Kia")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleLoadingDemo) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(themeManager.accentColor)
                    }
                    .accessibilityLabel("Refresh demo")
                    .accessibilityHint("Demonstrates loading states and animations")
                }
            }
        }
        .environmentObject(themeManager)
        .onAppear {
            startBatteryAnimation()
        }
    }
    
    // MARK: - Page Content
    
    @ViewBuilder
    private func pageContent(for page: NavigationPage, isActive: Bool) -> some View {
        StateTransitionView(state: isActive ? .visible : .hidden) {
            switch page.id {
            case "overview":
                overviewPage
            case "battery":
                batteryPage
            case "climate":
                climatePage
            case "map":
                mapPage
            case "settings":
                settingsPage
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Overview Page
    
    private var overviewPage: some View {
        PullToRefreshView(
            content: {
                ScrollView {
                    LazyVStack(spacing: KiaDesign.Spacing.xl) {
                        // Hero Battery Section
                        heroSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Vehicle Status Cards
                        statusCardsSection
                        
                        // Performance Metrics
                        performanceSection
                    }
                    .padding()
                }
            },
            onRefresh: refreshVehicleData
        )
    }
    
    private var heroSection: some View {
        ThemedKiaCard(elevation: .elevated) {
            VStack(spacing: KiaDesign.Spacing.xl) {
                // Large circular battery indicator
                ZStack {
                    CircularBatteryView(
                        level: batteryLevel,
                        isCharging: isCharging,
                        size: 180
                    )
                    
                    VStack(spacing: 4) {
                        Text("\(Int(batteryLevel * 100))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                        
                        Text("\(Int(batteryLevel * 350)) km")
                            .font(KiaDesign.Typography.body)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
                
                // Status text
                VStack(spacing: 8) {
                    Text(isCharging ? "Charging" : "Ready to Drive")
                        .font(KiaDesign.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(isCharging ? KiaDesign.Colors.charging : KiaDesign.Colors.success)
                    
                    if isCharging {
                        Text("Full charge in 2h 30m")
                            .font(KiaDesign.Typography.body)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    } else {
                        Text("Last updated 5 minutes ago")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
            }
            .padding(.vertical, KiaDesign.Spacing.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery status: \(Int(batteryLevel * 100))% charged, \(Int(batteryLevel * 350)) kilometers range")
    }
    
    private var quickActionsSection: some View {
        ThemedKiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Quick Actions")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: KiaDesign.Spacing.medium) {
                    QuickActionButton(
                        icon: "lock.fill",
                        title: "Lock Vehicle",
                        subtitle: "Doors locked",
                        color: KiaDesign.Colors.primary,
                        action: { toggleAction("lock") }
                    )
                    
                    QuickActionButton(
                        icon: "thermometer",
                        title: "Climate",
                        subtitle: isClimateOn ? "Active" : "Off",
                        color: isClimateOn ? KiaDesign.Colors.Climate.auto : KiaDesign.Colors.textSecondary,
                        action: { toggleClimate() }
                    )
                    
                    QuickActionButton(
                        icon: "horn",
                        title: "Horn & Lights",
                        subtitle: "Find vehicle",
                        color: KiaDesign.Colors.accent,
                        action: { toggleAction("horn") }
                    )
                    
                    QuickActionButton(
                        icon: "location.fill",
                        title: "Locate",
                        subtitle: "Open Maps",
                        color: KiaDesign.Colors.primary,
                        action: { toggleAction("locate") }
                    )
                }
            }
        }
    }
    
    private var statusCardsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.medium) {
            StatusCard(
                icon: "thermometer",
                title: "Interior",
                value: "\(Int(targetTemperature))°C",
                color: KiaDesign.Colors.Climate.auto
            )
            
            StatusCard(
                icon: "speedometer",
                title: "Efficiency",
                value: "4.2 km/kWh",
                color: KiaDesign.Colors.success
            )
            
            StatusCard(
                icon: "location.circle",
                title: "Location",
                value: "Home",
                color: KiaDesign.Colors.primary
            )
            
            StatusCard(
                icon: "timer",
                title: "Last Trip",
                value: "45 min",
                color: KiaDesign.Colors.textSecondary
            )
        }
    }
    
    private var performanceSection: some View {
        ThemedKiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Performance")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                VStack(spacing: KiaDesign.Spacing.medium) {
                    PerformanceMetric(
                        title: "Energy Usage",
                        value: 0.65,
                        label: "18.4 kWh/100km",
                        color: KiaDesign.Colors.success
                    )
                    
                    PerformanceMetric(
                        title: "Regeneration",
                        value: 0.78,
                        label: "Strong regen active",
                        color: KiaDesign.Colors.accent
                    )
                    
                    PerformanceMetric(
                        title: "Battery Health",
                        value: 0.94,
                        label: "Excellent condition",
                        color: KiaDesign.Colors.success
                    )
                }
            }
        }
    }
    
    // MARK: - Battery Page
    
    private var batteryPage: some View {
        ScrollView {
            LazyVStack(spacing: KiaDesign.Spacing.xl) {
                // Large battery visualization
                BatteryHeroView(
                    batteryLevel: batteryLevel,
                    range: "\(Int(batteryLevel * 350)) km",
                    isCharging: isCharging
                )
                
                // Charging session (if charging)
                if isCharging {
                    chargingSessionView
                } else {
                    nearbyChargingStationsView
                }
                
                // Battery health and statistics
                batteryHealthSection
            }
            .padding()
        }
    }
    
    private var chargingSessionView: some View {
        let mockSession = ChargingSession(
            startTime: Date().addingTimeInterval(-1800),
            chargingStationName: "Tesla Supercharger",
            maxPower: 150.0,
            pricePerKwh: 0.42,
            currentBatteryLevel: batteryLevel,
            targetBatteryLevel: 0.80,
            currentPower: 120.0,
            estimatedTimeRemaining: 2700,
            currentCost: 8.50,
            status: .active
        )
        
        return ChargingAnimationView(chargingSession: mockSession) {
            withAnimation(.spring()) {
                isCharging = false
            }
        }
    }
    
    private var nearbyChargingStationsView: some View {
        ThemedKiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                HStack {
                    Text("Nearby Charging")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Spacer()
                    
                    AccessibleKiaButton(
                        "Find More",
                        style: .secondary,
                        size: .small,
                        accessibilityLabel: "Find more charging stations"
                    ) {
                        // Would navigate to map page
                        selectedPageIndex = 3
                    }
                }
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    ChargingStationRow(
                        name: "Tesla Supercharger",
                        distance: "1.2 km",
                        power: "150 kW",
                        available: "8/12",
                        price: "$0.42"
                    )
                    
                    ChargingStationRow(
                        name: "ChargePoint DC",
                        distance: "2.1 km",
                        power: "50 kW",
                        available: "2/4",
                        price: "$0.38"
                    )
                }
            }
        }
    }
    
    private var batteryHealthSection: some View {
        ThemedKiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Battery Health")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                VStack(spacing: KiaDesign.Spacing.medium) {
                    BatteryHealthMetric(
                        title: "State of Health",
                        percentage: 0.94,
                        description: "Excellent"
                    )
                    
                    BatteryHealthMetric(
                        title: "Degradation",
                        percentage: 0.06,
                        description: "6% over 2 years"
                    )
                }
            }
        }
    }
    
    // MARK: - Climate Page
    
    private var climatePage: some View {
        ScrollView {
            VStack(spacing: KiaDesign.Spacing.xl) {
                ClimateControlView(unit: .celsius)
                    .environmentObject(themeManager)
                
                // Additional climate features
                climatePresetsSection
            }
            .padding()
        }
    }
    
    private var climatePresetsSection: some View {
        ThemedKiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Climate Presets")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: KiaDesign.Spacing.medium) {
                    ClimatePresetButton(
                        icon: "snowflake",
                        title: "Cool",
                        temperature: "18°C",
                        color: KiaDesign.Colors.Climate.cool
                    ) {
                        targetTemperature = 18
                    }
                    
                    ClimatePresetButton(
                        icon: "leaf.fill",
                        title: "Eco",
                        temperature: "22°C",
                        color: KiaDesign.Colors.Climate.auto
                    ) {
                        targetTemperature = 22
                    }
                    
                    ClimatePresetButton(
                        icon: "sun.max.fill",
                        title: "Warm",
                        temperature: "25°C",
                        color: KiaDesign.Colors.Climate.warm
                    ) {
                        targetTemperature = 25
                    }
                    
                    ClimatePresetButton(
                        icon: "person.fill",
                        title: "Comfort",
                        temperature: "21°C",
                        color: KiaDesign.Colors.primary
                    ) {
                        targetTemperature = 21
                    }
                }
            }
        }
    }
    
    // MARK: - Map Page
    
    private var mapPage: some View {
        VStack(spacing: 0) {
            // Map would go here - using placeholder
            ThemedKiaCard {
                VStack(spacing: KiaDesign.Spacing.large) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(KiaDesign.Colors.primary)
                    
                    VStack(spacing: KiaDesign.Spacing.small) {
                        Text("Vehicle Map")
                            .font(KiaDesign.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                        
                        Text("Tesla-style map integration with vehicle location and charging stations would be displayed here.")
                            .font(KiaDesign.Typography.body)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    AccessibleKiaButton(
                        "Open in Maps",
                        icon: "map",
                        style: .primary,
                        accessibilityLabel: "Open vehicle location in Maps app"
                    ) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                .padding(.vertical, KiaDesign.Spacing.xl)
            }
            .padding()
        }
    }
    
    // MARK: - Settings Page
    
    private var settingsPage: some View {
        DynamicTypeTestView()
            .environmentObject(themeManager)
    }
    
    // MARK: - Helper Actions
    
    private func toggleAction(_ action: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Would perform actual vehicle action
    }
    
    private func toggleClimate() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isClimateOn.toggle()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    private func toggleLoadingDemo() {
        withAnimation(.easeInOut(duration: 0.3)) {
            loadingState = .loading
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                loadingState = .visible
                // Simulate battery update
                batteryLevel = Double.random(in: 0.6...0.9)
            }
        }
    }
    
    private func startBatteryAnimation() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                batteryLevel += Double.random(in: -0.05...0.05)
                batteryLevel = max(0.1, min(0.9, batteryLevel))
            }
        }
    }
    
    private func refreshVehicleData() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        await MainActor.run {
            withAnimation(.spring()) {
                batteryLevel = Double.random(in: 0.6...0.9)
                isCharging = Bool.random()
                targetTemperature = Double.random(in: 18...26)
            }
        }
    }
}

// MARK: - Helper Components

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                
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
            }
            .padding(KiaDesign.Spacing.medium)
            .background(KiaDesign.Colors.cardBackground.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

private struct StatusCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        ThemedKiaCard {
            VStack(spacing: KiaDesign.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                
                VStack(spacing: 2) {
                    Text(value)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text(title)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KiaDesign.Spacing.small)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct PerformanceMetric: View {
    let title: String
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Text(title)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Spacer()
                
                Text(label)
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
            
            AccessibleProgressBar(
                value: value,
                style: .standard,
                showPercentage: false,
                accessibilityLabel: title
            )
        }
    }
}

private struct ChargingStationRow: View {
    let name: String
    let distance: String
    let power: String
    let available: String
    let price: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("\(distance) • \(power) • \(available) available")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(price)
                .font(KiaDesign.Typography.body)
                .fontWeight(.semibold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
        }
        .padding(.vertical, KiaDesign.Spacing.xs)
    }
}

private struct BatteryHealthMetric: View {
    let title: String
    let percentage: Double
    let description: String
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Text(title)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Spacer()
                
                Text(description)
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(healthColor)
            }
            
            AccessibleProgressBar(
                value: percentage,
                style: .standard,
                showPercentage: false,
                accessibilityLabel: title
            )
        }
    }
    
    private var healthColor: Color {
        switch percentage {
        case 0.9...1.0: return KiaDesign.Colors.success
        case 0.7...0.9: return KiaDesign.Colors.primary
        case 0.5...0.7: return KiaDesign.Colors.warning
        default: return KiaDesign.Colors.error
        }
    }
}

private struct ClimatePresetButton: View {
    let icon: String
    let title: String
    let temperature: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: KiaDesign.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text(temperature)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) preset, \(temperature)")
    }
}

// MARK: - Preview

#Preview("Tesla-Inspired Showcase") {
    TeslaInspiredShowcaseView()
}