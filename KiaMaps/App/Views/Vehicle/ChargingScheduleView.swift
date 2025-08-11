//
//  ChargingScheduleView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired smart charging scheduling with time-based pricing and optimization
//

import SwiftUI

/// Smart charging schedule management with time-based pricing optimization
struct ChargingScheduleView: View {
    @State private var isScheduleEnabled = false
    @State private var targetBatteryLevel: Double = 80
    @State private var departureTime = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    @State private var enableCostOptimization = true
    @State private var onlyRenewableEnergy = false
    
    @State private var scheduleItems: [ChargingScheduleItem] = []
    @State private var estimatedCost: Double = 15.50
    @State private var estimatedDuration: TimeInterval = 4 * 3600 // 4 hours
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: KiaDesign.Spacing.xl) {
                // Header
                scheduleHeader
                
                // Main Schedule Toggle
                scheduleToggleCard
                
                if isScheduleEnabled {
                    // Schedule Configuration
                    scheduleConfigurationSection
                    
                    // Optimization Options
                    optimizationOptionsSection
                    
                    // Schedule Timeline
                    scheduleTimelineSection
                    
                    // Cost Summary
                    costSummarySection
                }
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
        .navigationTitle("Charging Schedule")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            generateSchedule()
        }
        .onChange(of: isScheduleEnabled) {
            if isScheduleEnabled {
                generateSchedule()
            }
        }
        .onChange(of: targetBatteryLevel) {
            generateSchedule()
        }
        .onChange(of: departureTime) {
            generateSchedule()
        }
    }
    
    // MARK: - Header
    
    private var scheduleHeader: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            Text("Smart Charging")
                .font(KiaDesign.Typography.title1)
                .fontWeight(.bold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
            
            Text("Optimize charging based on electricity rates and renewable energy availability")
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Schedule Toggle
    
    private var scheduleToggleCard: some View {
        KiaCard(elevation: .medium) {
            VStack(spacing: KiaDesign.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Schedule")
                            .font(KiaDesign.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                        
                        Text(isScheduleEnabled ? "Active" : "Manual charging")
                            .font(KiaDesign.Typography.body)
                            .foregroundStyle(isScheduleEnabled ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isScheduleEnabled)
                        .toggleStyle(KiaToggleStyle())
                }
                
                if isScheduleEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Session")
                                .font(KiaDesign.Typography.caption)
                                .foregroundStyle(KiaDesign.Colors.textSecondary)
                            
                            Text(nextSessionTime)
                                .font(KiaDesign.Typography.body)
                                .fontWeight(.medium)
                                .foregroundStyle(KiaDesign.Colors.textPrimary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Estimated Cost")
                                .font(KiaDesign.Typography.caption)
                                .foregroundStyle(KiaDesign.Colors.textSecondary)
                            
                            Text("$\(estimatedCost, specifier: "%.2f")")
                                .font(KiaDesign.Typography.body)
                                .fontWeight(.medium)
                                .foregroundStyle(KiaDesign.Colors.success)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Schedule Configuration
    
    private var scheduleConfigurationSection: some View {
        VStack(spacing: KiaDesign.Spacing.large) {
            // Target Battery Level
            KiaCard {
                VStack(spacing: KiaDesign.Spacing.medium) {
                    HStack {
                        Text("Target Battery Level")
                            .font(KiaDesign.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(Int(targetBatteryLevel))%")
                            .font(KiaDesign.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(KiaDesign.Colors.charging)
                    }
                    
                    KiaSlider(
                        value: $targetBatteryLevel,
                        in: 50...100,
                        step: 5,
                        style: .custom(
                            gradient: LinearGradient(
                                colors: [
                                    KiaDesign.Colors.warning.opacity(0.7),
                                    KiaDesign.Colors.charging,
                                    KiaDesign.Colors.success
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            thumbColor: KiaDesign.Colors.charging
                        ),
                        hapticFeedback: true
                    )
                    
                    HStack {
                        Text("50%")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("100%")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
            }
            
            // Departure Time
            KiaCard {
                VStack(spacing: KiaDesign.Spacing.medium) {
                    HStack {
                        Text("Ready By")
                            .font(KiaDesign.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text(departureTime, format: .dateTime.hour().minute())
                            .font(KiaDesign.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(KiaDesign.Colors.accent)
                    }
                    
                    DatePicker("Departure Time", selection: $departureTime, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Optimization Options
    
    private var optimizationOptionsSection: some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Optimization Options")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    optimizationOption(
                        title: "Cost Optimization",
                        description: "Charge during lowest electricity rates",
                        icon: "dollarsign.circle.fill",
                        color: KiaDesign.Colors.success,
                        isEnabled: $enableCostOptimization
                    )
                    
                    optimizationOption(
                        title: "Renewable Energy",
                        description: "Prioritize solar and wind power",
                        icon: "leaf.fill",
                        color: KiaDesign.Colors.Climate.auto,
                        isEnabled: $onlyRenewableEnergy
                    )
                }
            }
        }
    }
    
    private func optimizationOption(
        title: String,
        description: String,
        icon: String,
        color: Color,
        isEnabled: Binding<Bool>
    ) -> some View {
        HStack(spacing: KiaDesign.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text(description)
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isEnabled)
                .toggleStyle(KiaToggleStyle())
        }
        .padding(.vertical, KiaDesign.Spacing.xs)
    }
    
    // MARK: - Schedule Timeline
    
    private var scheduleTimelineSection: some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.medium) {
                HStack {
                    Text("Charging Timeline")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(Int(estimatedDuration / 3600))h \(Int(estimatedDuration.truncatingRemainder(dividingBy: 3600) / 60))m")
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                // Timeline visualization
                timelineVisualization
                
                // Schedule items
                VStack(spacing: KiaDesign.Spacing.small) {
                    ForEach(scheduleItems) { item in
                        scheduleItemRow(item: item)
                    }
                }
            }
        }
    }
    
    private var timelineVisualization: some View {
        GeometryReader { geometry in
            ZStack {
                // Background timeline
                Rectangle()
                    .fill(KiaDesign.Colors.textTertiary.opacity(0.2))
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Charging periods
                ForEach(scheduleItems.indices, id: \.self) { index in
                    let item = scheduleItems[index]
                    let startProgress = timeProgress(for: item.startTime)
                    let endProgress = timeProgress(for: item.endTime)
                    let width = (endProgress - startProgress) * geometry.size.width
                    let xOffset = startProgress * geometry.size.width
                    
                    Rectangle()
                        .fill(item.energySource.color)
                        .frame(width: width, height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .offset(x: xOffset - geometry.size.width / 2 + width / 2)
                }
            }
        }
        .frame(height: 8)
    }
    
    private func scheduleItemRow(item: ChargingScheduleItem) -> some View {
        HStack {
            // Time range
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.startTime, format: .dateTime.hour().minute()) - \(item.endTime, format: .dateTime.hour().minute())")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text(item.energySource.description)
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(item.energySource.color)
            }
            
            Spacer()
            
            // Power and cost
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(item.power)) kW")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("$\(item.ratePerKwh, specifier: "%.3f")/kWh")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
        }
        .padding(.horizontal, KiaDesign.Spacing.small)
        .padding(.vertical, KiaDesign.Spacing.xs)
        .background(item.energySource.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.small))
    }
    
    // MARK: - Cost Summary
    
    private var costSummarySection: some View {
        KiaCard(elevation: .high) {
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Cost Summary")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.medium) {
                    costSummaryItem(
                        title: "Total Cost",
                        value: String(format: "$%.2f", estimatedCost),
                        color: KiaDesign.Colors.textPrimary
                    )
                    
                    costSummaryItem(
                        title: "Savings",
                        value: String(format: "$%.2f", savedAmount),
                        color: KiaDesign.Colors.success
                    )
                    
                    costSummaryItem(
                        title: "Energy",
                        value: "\(Int(estimatedEnergyUsed)) kWh",
                        color: KiaDesign.Colors.charging
                    )
                    
                    costSummaryItem(
                        title: "Renewable",
                        value: "\(Int(renewablePercentage))%",
                        color: KiaDesign.Colors.Climate.auto
                    )
                }
            }
        }
    }
    
    private func costSummaryItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(KiaDesign.Typography.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KiaDesign.Spacing.small)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.small))
    }
    
    // MARK: - Helper Properties
    
    private var nextSessionTime: String {
        guard let nextItem = scheduleItems.first else {
            return "No sessions scheduled"
        }
        return nextItem.startTime.formatted(date: .omitted, time: .shortened)
    }
    
    private var savedAmount: Double {
        let regularRate = 0.25 // Regular rate per kWh
        let regularCost = estimatedEnergyUsed * regularRate
        return regularCost - estimatedCost
    }
    
    private var estimatedEnergyUsed: Double {
        scheduleItems.reduce(0) { total, item in
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600 // hours
            return total + (item.power * duration)
        }
    }
    
    private var renewablePercentage: Double {
        let totalEnergy = estimatedEnergyUsed
        let renewableEnergy = scheduleItems.reduce(0) { total, item in
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600
            let energy = item.power * duration
            return total + (item.energySource.isRenewable ? energy : 0)
        }
        return totalEnergy > 0 ? (renewableEnergy / totalEnergy) * 100 : 0
    }
    
    private func timeProgress(for time: Date) -> Double {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let totalDuration = endOfDay.timeIntervalSince(startOfDay)
        let timeFromStart = time.timeIntervalSince(startOfDay)
        
        return timeFromStart / totalDuration
    }
    
    // MARK: - Helper Methods
    
    private func generateSchedule() {
        guard isScheduleEnabled else {
            scheduleItems = []
            return
        }
        
        // Mock schedule generation based on optimal pricing
        let now = Date()
        let morning = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: now)!
        let earlyMorning = Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: now)!
        
        scheduleItems = [
            ChargingScheduleItem(
                id: UUID(),
                startTime: morning,
                endTime: Calendar.current.date(byAdding: .hour, value: 2, to: morning)!,
                power: 11.0,
                ratePerKwh: 0.08,
                energySource: .grid(renewable: true)
            ),
            ChargingScheduleItem(
                id: UUID(),
                startTime: earlyMorning,
                endTime: Calendar.current.date(byAdding: .minute, value: 90, to: earlyMorning)!,
                power: 7.2,
                ratePerKwh: 0.12,
                energySource: .solar
            )
        ]
        
        // Calculate estimated cost and duration
        estimatedCost = scheduleItems.reduce(0) { total, item in
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600
            let energy = item.power * duration
            return total + (energy * item.ratePerKwh)
        }
        
        estimatedDuration = scheduleItems.reduce(0) { total, item in
            return total + item.endTime.timeIntervalSince(item.startTime)
        }
    }
}

// MARK: - Data Models

struct ChargingScheduleItem: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let power: Double // kW
    let ratePerKwh: Double
    let energySource: EnergySource
}

enum EnergySource {
    case grid(renewable: Bool)
    case solar
    case wind
    case battery
    
    var description: String {
        switch self {
        case .grid(let renewable):
            return renewable ? "Clean Grid" : "Standard Grid"
        case .solar:
            return "Solar Power"
        case .wind:
            return "Wind Power"
        case .battery:
            return "Battery Storage"
        }
    }
    
    var color: Color {
        switch self {
        case .grid(let renewable):
            return renewable ? KiaDesign.Colors.Climate.auto : KiaDesign.Colors.textSecondary
        case .solar:
            return KiaDesign.Colors.Climate.warm
        case .wind:
            return KiaDesign.Colors.accent
        case .battery:
            return KiaDesign.Colors.charging
        }
    }
    
    var isRenewable: Bool {
        switch self {
        case .grid(let renewable):
            return renewable
        case .solar, .wind:
            return true
        case .battery:
            return false
        }
    }
}

// MARK: - Custom Toggle Style

struct KiaToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? KiaDesign.Colors.primary : KiaDesign.Colors.textTertiary.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                    
                    // Haptic feedback
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        }
    }
}

// MARK: - Preview

#Preview("Charging Schedule") {
    NavigationView {
        ChargingScheduleView()
    }
}