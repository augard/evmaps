//
//  ChargingAnimationView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired charging animations and management interface
//

import SwiftUI

/// Tesla-style charging animation with realistic timing and visual feedback
struct ChargingAnimationView: View {
    let chargingSession: ChargingSession
    let onStopCharging: (() -> Void)?
    
    @State private var animationProgress: Double = 0
    @State private var energyFlowAnimation: Bool = false
    @State private var pulseAnimation: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Charging Animation Visual
            chargingVisualization
            
            // Charging Stats
            chargingStatsGrid
            
            // Progress and Controls
            chargingProgressSection
            
            // Stop Charging Button
            if chargingSession.status == .active {
                stopChargingButton
            }
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: chargingSession.status) { _, newStatus in
            if newStatus == .completed || newStatus == .stopped {
                stopAnimations()
            }
        }
    }
    
    // MARK: - Charging Visualization
    
    private var chargingVisualization: some View {
        ZStack {
            // Charging port visualization
            chargingPortView
            
            // Energy flow animation
            energyFlowView
                .opacity(energyFlowAnimation ? 1.0 : 0.3)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: energyFlowAnimation
                )
        }
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.xl)
                .fill(chargingSession.status.color.opacity(0.1))
                .stroke(chargingSession.status.color.opacity(0.3), lineWidth: 2)
        )
        .scaleEffect(pulseAnimation ? 1.02 : 1.0)
        .animation(
            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
            value: pulseAnimation
        )
    }
    
    private var chargingPortView: some View {
        HStack(spacing: 40) {
            // Charging cable/connector
            VStack {
                Image(systemName: "cable.connector")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(chargingSession.status.color)
                
                Text("Charger")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
            
            // Energy flow indicator
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(chargingSession.status.color)
                        .frame(width: 8, height: 8)
                        .opacity(energyFlowOpacity(for: index))
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: energyFlowAnimation
                        )
                }
            }
            
            // Vehicle charging port
            VStack {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(chargingSession.status.color)
                
                Text("Vehicle")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
        }
    }
    
    private var energyFlowView: some View {
        // Animated energy waves
        HStack(spacing: 4) {
            ForEach(0..<8) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                chargingSession.status.color.opacity(0.2),
                                chargingSession.status.color,
                                chargingSession.status.color.opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 3, height: energyWaveHeight(for: index))
                    .animation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: energyFlowAnimation
                    )
            }
        }
    }
    
    // MARK: - Charging Stats Grid
    
    private var chargingStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: KiaDesign.Spacing.medium) {
            chargingStatCard(
                icon: "bolt.fill",
                title: "Charging Power",
                value: "\(Int(chargingSession.currentPower)) kW",
                color: chargingSession.status.color
            )
            
            chargingStatCard(
                icon: "battery.75",
                title: "Battery Level",
                value: "\(Int(chargingSession.currentBatteryLevel * 100))%",
                color: batteryLevelColor
            )
            
            chargingStatCard(
                icon: "clock.fill",
                title: "Time Remaining",
                value: formatTimeRemaining(chargingSession.estimatedTimeRemaining),
                color: KiaDesign.Colors.accent
            )
            
            chargingStatCard(
                icon: "dollarsign.circle.fill",
                title: "Session Cost",
                value: String(format: "$%.2f", chargingSession.currentCost),
                color: KiaDesign.Colors.textSecondary
            )
        }
    }
    
    private func chargingStatCard(icon: String, title: String, value: String, color: Color) -> some View {
        KiaCompactCard {
            VStack(spacing: KiaDesign.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                
                VStack(spacing: 2) {
                    Text(value)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                        .monospacedDigit()
                    
                    Text(title)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, KiaDesign.Spacing.small)
        }
    }
    
    // MARK: - Charging Progress Section
    
    private var chargingProgressSection: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            HStack {
                Text("Charging Progress")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Spacer()
                
                Text("\(Int(chargingSession.currentBatteryLevel * 100))% → \(Int(chargingSession.targetBatteryLevel * 100))%")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(chargingSession.status.color)
                    .monospacedDigit()
            }
            
            // Animated progress bar
            KiaProgressBar(
                value: chargingSession.currentBatteryLevel,
                style: .charging,
                showPercentage: false,
                animationDuration: 1.0
            )
            
            // Charging curve visualization
            chargingCurveView
        }
        .padding()
        .background(KiaDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
    }
    
    private var chargingCurveView: some View {
        VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
            Text("Power Curve")
                .font(KiaDesign.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            // Simplified charging curve visualization
            GeometryReader { geometry in
                Path { path in
                    let points = chargingCurvePoints(in: geometry.size)
                    guard let firstPoint = points.first else { return }
                    
                    path.move(to: firstPoint)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [chargingSession.status.color.opacity(0.8), chargingSession.status.color],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
                
                // Current position indicator
                Circle()
                    .fill(chargingSession.status.color)
                    .frame(width: 8, height: 8)
                    .position(currentPositionOnCurve(in: geometry.size))
            }
            .frame(height: 60)
        }
    }
    
    // MARK: - Stop Charging Button
    
    private var stopChargingButton: some View {
        KiaButton(
            "Stop Charging",
            icon: "stop.circle.fill",
            style: .secondary,
            size: .large,
            hapticFeedback: .warning
        ) {
            onStopCharging?()
        }
    }
    
    // MARK: - Helper Methods
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.5)) {
            animationProgress = chargingSession.currentBatteryLevel
        }
        
        if chargingSession.status == .active {
            energyFlowAnimation = true
            pulseAnimation = true
            
            // Start periodic updates
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // This would typically update from real data
                // For demo purposes, we're not modifying the charging session
            }
        }
    }
    
    private func stopAnimations() {
        energyFlowAnimation = false
        pulseAnimation = false
        timer?.invalidate()
        timer = nil
    }
    
    private func energyFlowOpacity(for index: Int) -> Double {
        if !energyFlowAnimation { return 0.3 }
        
        // Create a wave effect
        let phase = Double(index) * 0.5
        return 0.3 + 0.7 * sin((Date().timeIntervalSince1970 * 2) + phase)
    }
    
    private func energyWaveHeight(for index: Int) -> CGFloat {
        if !energyFlowAnimation { return 20 }
        
        let baseHeight: CGFloat = 20
        let amplitude: CGFloat = 15
        let phase = Double(index) * 0.3
        
        return baseHeight + amplitude * sin((Date().timeIntervalSince1970 * 3) + phase)
    }
    
    private var batteryLevelColor: Color {
        switch chargingSession.currentBatteryLevel {
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
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func chargingCurvePoints(in size: CGSize) -> [CGPoint] {
        // Simulate typical EV charging curve (fast at start, slower near full)
        let points = stride(from: 0.0, through: 1.0, by: 0.1).map { progress in
            let x = progress * size.width
            let power = chargingPowerAtProgress(progress)
            let y = size.height - (power * size.height)
            return CGPoint(x: x, y: y)
        }
        return points
    }
    
    private func chargingPowerAtProgress(_ progress: Double) -> Double {
        // Typical EV charging curve - high power up to ~80%, then tapers off
        if progress < 0.8 {
            return 1.0 - (progress * 0.2) // Slight decline
        } else {
            return 0.8 - ((progress - 0.8) / 0.2) * 0.6 // Steep decline after 80%
        }
    }
    
    private func currentPositionOnCurve(in size: CGSize) -> CGPoint {
        let x = chargingSession.currentBatteryLevel * size.width
        let power = chargingPowerAtProgress(chargingSession.currentBatteryLevel)
        let y = size.height - (power * size.height)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Charging Session Model

struct ChargingSession: Identifiable {
    let id = UUID()
    let startTime: Date
    let chargingStationName: String
    let maxPower: Double
    let pricePerKwh: Double
    
    var currentBatteryLevel: Double
    var targetBatteryLevel: Double
    var currentPower: Double
    var estimatedTimeRemaining: TimeInterval
    var currentCost: Double
    var status: ChargingStatus
    
    enum ChargingStatus {
        case preparing
        case active
        case paused
        case completed
        case stopped
        case error(String)
        
        var color: Color {
            switch self {
            case .preparing:
                return KiaDesign.Colors.warning
            case .active:
                return KiaDesign.Colors.charging
            case .paused:
                return KiaDesign.Colors.accent
            case .completed:
                return KiaDesign.Colors.success
            case .stopped:
                return KiaDesign.Colors.textSecondary
            case .error:
                return KiaDesign.Colors.error
            }
        }
        
        var displayName: String {
            switch self {
            case .preparing:
                return "Preparing"
            case .active:
                return "Charging"
            case .paused:
                return "Paused"
            case .completed:
                return "Completed"
            case .stopped:
                return "Stopped"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }
}

// MARK: - Charging Station Finder

/// Tesla-style charging station finder with route planning
struct ChargingStationFinderView: View {
    let currentLocation: CLLocationCoordinate2D
    let currentBatteryLevel: Double
    let onStationSelected: ((ChargingStation) -> Void)?
    
    @State private var searchRadius: Double = 25 // km
    @State private var filterByPower: ChargingStation.PowerLevel?
    @State private var showOnlyAvailable = true
    @State private var stations: [ChargingStation] = []
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.large) {
            // Header with filters
            VStack(spacing: KiaDesign.Spacing.medium) {
                HStack {
                    Text("Find Charging Stations")
                        .font(KiaDesign.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(stations.count) stations")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                // Filters
                filterControls
            }
            
            // Stations list
            LazyVStack(spacing: KiaDesign.Spacing.medium) {
                ForEach(filteredStations) { station in
                    ChargingStationCard(
                        station: station,
                        currentBatteryLevel: currentBatteryLevel
                    ) {
                        onStationSelected?(station)
                    }
                }
            }
        }
        .onAppear {
            loadNearbyStations()
        }
    }
    
    private var filterControls: some View {
        HStack(spacing: KiaDesign.Spacing.small) {
            // Radius slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Radius: \(Int(searchRadius)) km")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                KiaSlider(
                    value: $searchRadius,
                    in: 5...100,
                    step: 5,
                    style: .standard
                )
            }
            .frame(maxWidth: .infinity)
            
            // Power filter
            Menu {
                Button("All Power Levels") {
                    filterByPower = nil
                }
                
                ForEach([ChargingStation.PowerLevel.slow, .fast, .rapid, .superfast], id: \.self) { power in
                    Button(power.displayName) {
                        filterByPower = power
                    }
                }
            } label: {
                HStack {
                    Text(filterByPower?.displayName ?? "All")
                        .font(KiaDesign.Typography.caption)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .padding(.horizontal, KiaDesign.Spacing.small)
                .padding(.vertical, KiaDesign.Spacing.xs)
                .background(KiaDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.small))
            }
        }
    }
    
    private var filteredStations: [ChargingStation] {
        stations.filter { station in
            // Distance filter
            guard station.distanceKm <= searchRadius else { return false }
            
            // Power filter
            if let powerFilter = filterByPower {
                guard station.powerLevel == powerFilter else { return false }
            }
            
            // Availability filter
            if showOnlyAvailable {
                guard station.availablePorts > 0 else { return false }
            }
            
            return true
        }
        .sorted { $0.distanceKm < $1.distanceKm }
    }
    
    private func loadNearbyStations() {
        // Mock data - in real app, this would fetch from API
        stations = [
            ChargingStation(
                id: "station1",
                name: "Tesla Supercharger - Downtown",
                coordinate: CLLocationCoordinate2D(
                    latitude: currentLocation.latitude + 0.01,
                    longitude: currentLocation.longitude + 0.005
                ),
                powerLevel: .superfast,
                totalPorts: 12,
                availablePorts: 8,
                pricePerKwh: 0.42,
                distanceKm: 2.1
            ),
            ChargingStation(
                id: "station2",
                name: "EVgo Fast Charging",
                coordinate: CLLocationCoordinate2D(
                    latitude: currentLocation.latitude - 0.008,
                    longitude: currentLocation.longitude + 0.012
                ),
                powerLevel: .fast,
                totalPorts: 6,
                availablePorts: 2,
                pricePerKwh: 0.38,
                distanceKm: 3.7
            ),
            ChargingStation(
                id: "station3",
                name: "ChargePoint DC Hub",
                coordinate: CLLocationCoordinate2D(
                    latitude: currentLocation.latitude + 0.015,
                    longitude: currentLocation.longitude - 0.008
                ),
                powerLevel: .rapid,
                totalPorts: 8,
                availablePorts: 0,
                pricePerKwh: 0.45,
                distanceKm: 4.2
            )
        ]
    }
}

/// Individual charging station card
struct ChargingStationCard: View {
    let station: ChargingStation
    let currentBatteryLevel: Double
    let onSelect: () -> Void
    
    var body: some View {
        KiaCard(action: onSelect) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                // Station icon and power level
                VStack {
                    Image(systemName: "bolt.car.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(station.powerLevel.color)
                    
                    Text(station.powerLevel.displayName)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(station.powerLevel.color)
                        .fontWeight(.medium)
                }
                .frame(width: 60)
                
                // Station details
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    HStack {
                        Text("\(String(format: "%.1f", station.distanceKm)) km")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                        
                        Text("•")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textTertiary)
                        
                        Text("\(station.powerLevel.maxPower) kW max")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    
                    HStack {
                        KiaStatusIndicator(
                            status: station.availablePorts > 0 ? .ready : .warning("Full"),
                            size: .small
                        )
                        
                        Text("\(station.availablePorts)/\(station.totalPorts) available")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Price and charging time
                VStack(alignment: .trailing, spacing: 4) {
                    Text(station.pricePerKwh, format: .currency(code: "USD"))
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("per kWh")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    // Estimated charging time
                    let chargingTime = estimatedChargingTime()
                    Text("~\(chargingTime)")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.accent)
                }
            }
        }
    }
    
    private func estimatedChargingTime() -> String {
        // Simplified calculation based on power level and current battery
        let batteryToCharge = min(0.8 - currentBatteryLevel, 0.8) // Charge to 80%
        let energyNeeded = batteryToCharge * 77.4 // kWh (EV9 battery capacity)
        let chargingPower = Double(station.powerLevel.maxPower) * 0.9 // 90% efficiency
        let timeHours = energyNeeded / chargingPower
        
        let hours = Int(timeHours)
        let minutes = Int((timeHours - Double(hours)) * 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview("Charging Animation") {
    let mockSession = ChargingSession(
        startTime: Date().addingTimeInterval(-1800), // Started 30 minutes ago
        chargingStationName: "Tesla Supercharger",
        maxPower: 150.0,
        pricePerKwh: 0.42,
        currentBatteryLevel: 0.65,
        targetBatteryLevel: 0.80,
        currentPower: 120.0,
        estimatedTimeRemaining: 1800, // 30 minutes remaining
        currentCost: 12.50,
        status: .active
    )
    
    ScrollView {
        ChargingAnimationView(chargingSession: mockSession) {
            print("Stop charging")
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}

#Preview("Charging Station Finder") {
    ScrollView {
        ChargingStationFinderView(
            currentLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            currentBatteryLevel: 0.25
        ) { station in
            print("Selected station: \(station.name)")
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}