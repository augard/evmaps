//
//  KiaStatusIndicator.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired status indicator chips and badges
//

import SwiftUI

/// Status indicator chip for displaying vehicle states with visual feedback
struct KiaStatusIndicator: View {
    let status: Status
    let size: Size
    let style: Style
    let showAnimation: Bool
    
    @State private var isAnimating = false
    
    enum Status: Equatable {
        case ready
        case normal
        case charging
        case locked
        case unlocked
        case warning(String)
        case error(String)
        case inactive
        case custom(title: String, icon: String, color: Color)
        
        var title: String {
            switch self {
            case .ready:
                return "Ready"
            case .normal:
                return "Normal"
            case .charging:
                return "Charging"
            case .locked:
                return "Locked"
            case .unlocked:
                return "Unlocked"
            case .warning(let message):
                return message
            case .error(let message):
                return message
            case .inactive:
                return "Inactive"
            case .custom(let title, _, _):
                return title
            }
        }
        
        var icon: String {
            switch self {
            case .ready:
                return "checkmark.circle.fill"
            case .normal:
                return "checkmark.circle.fill"
            case .charging:
                return "bolt.circle.fill"
            case .locked:
                return "lock.circle.fill"
            case .unlocked:
                return "lock.open.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            case .inactive:
                return "circle.fill"
            case .custom(_, let icon, _):
                return icon
            }
        }
        
        var color: Color {
            switch self {
            case .ready:
                return KiaDesign.Colors.Status.ready
            case .normal:
                return KiaDesign.Colors.Status.ready
            case .charging:
                return KiaDesign.Colors.Status.locked
            case .locked:
                return KiaDesign.Colors.Status.locked
            case .unlocked:
                return KiaDesign.Colors.Status.unlocked
            case .warning:
                return KiaDesign.Colors.Status.warning
            case .error:
                return KiaDesign.Colors.Status.error
            case .inactive:
                return KiaDesign.Colors.Status.inactive
            case .custom(_, _, let color):
                return color
            }
        }
        
        var shouldPulse: Bool {
            switch self {
            case .charging:
                return true
            default:
                return false
            }
        }
    }
    
    enum Size {
        case small
        case medium
        case large
        
        var dimensions: (height: CGFloat, iconSize: CGFloat, padding: EdgeInsets, font: Font) {
            switch self {
            case .small:
                return (24, 12, EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8), KiaDesign.Typography.captionSmall)
            case .medium:
                return (32, 16, EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12), KiaDesign.Typography.caption)
            case .large:
                return (40, 20, EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16), KiaDesign.Typography.bodySmall)
            }
        }
    }
    
    enum Style {
        case filled     // Solid background with white text
        case outlined   // Border with colored text
        case ghost      // No background, colored text
        
        func colors(for status: Status) -> (background: Color, foreground: Color, border: Color?) {
            let statusColor = status.color
            
            switch self {
            case .filled:
                return (statusColor, .white, nil)
            case .outlined:
                return (.clear, statusColor, statusColor)
            case .ghost:
                return (.clear, statusColor, nil)
            }
        }
    }
    
    // MARK: - Initializers
    
    init(
        status: Status,
        size: Size = .medium,
        style: Style = .filled,
        showAnimation: Bool = true
    ) {
        self.status = status
        self.size = size
        self.style = style
        self.showAnimation = showAnimation
    }
    
    var body: some View {
        HStack(spacing: KiaDesign.Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: size.dimensions.iconSize, weight: .medium))
                .foregroundStyle(colors.foreground)
                .opacity(isAnimating && status.shouldPulse ? 0.6 : 1.0)
            
            Text(status.title)
                .font(size.dimensions.font)
                .fontWeight(.medium)
                .foregroundStyle(colors.foreground)
        }
        .padding(size.dimensions.padding)
        .frame(minHeight: size.dimensions.height)
        .background(colors.background)
        .clipShape(Capsule())
        .overlay(borderOverlay)
        .scaleEffect(isAnimating && status.shouldPulse ? 1.05 : 1.0)
        .animation(
            status.shouldPulse && showAnimation 
                ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                : .none,
            value: isAnimating
        )
        .onAppear {
            if status.shouldPulse && showAnimation {
                isAnimating = true
            }
        }
        .onChange(of: status) { oldStatus, newStatus in
            isAnimating = newStatus.shouldPulse && showAnimation
        }
    }
    
    // MARK: - Private Properties
    
    private var colors: (background: Color, foreground: Color) {
        let colors = style.colors(for: status)
        return (colors.background, colors.foreground)
    }
    
    private var borderOverlay: some View {
        Group {
            if let borderColor = style.colors(for: status).border {
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Battery Status Indicator

/// Specialized indicator for battery level with visual representation
struct KiaBatteryStatusIndicator: View {
    let batteryLevel: Double // 0.0 to 1.0
    let isCharging: Bool
    let showPercentage: Bool
    
    init(batteryLevel: Double, isCharging: Bool = false, showPercentage: Bool = true) {
        self.batteryLevel = max(0, min(1, batteryLevel))
        self.isCharging = isCharging
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        HStack(spacing: KiaDesign.Spacing.small) {
            batteryIcon
            
            if showPercentage {
                Text("\(Int(batteryLevel * 100))%")
                    .font(KiaDesign.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(batteryColor)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, KiaDesign.Spacing.small)
        .padding(.vertical, KiaDesign.Spacing.xs)
        .background(batteryColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var batteryIcon: some View {
        ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 2)
                .stroke(batteryColor, lineWidth: 1.5)
                .frame(width: 20, height: 12)
            
            // Battery terminal
            RoundedRectangle(cornerRadius: 1)
                .fill(batteryColor)
                .frame(width: 2, height: 6)
                .offset(x: 12)
            
            // Battery fill
            RoundedRectangle(cornerRadius: 1)
                .fill(batteryColor)
                .frame(width: max(2, 16 * batteryLevel), height: 8)
                .offset(x: -8 + (8 * batteryLevel))
            
            // Charging indicator
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(batteryColor)
                            .frame(width: 12, height: 12)
                    )
            }
        }
    }
    
    private var batteryColor: Color {
        if isCharging {
            return KiaDesign.Colors.Battery.charging
        } else if batteryLevel > 0.8 {
            return KiaDesign.Colors.Battery.full
        } else if batteryLevel > 0.5 {
            return KiaDesign.Colors.Battery.good
        } else if batteryLevel > 0.2 {
            return KiaDesign.Colors.Battery.medium
        } else if batteryLevel > 0.1 {
            return KiaDesign.Colors.Battery.low
        } else {
            return KiaDesign.Colors.Battery.critical
        }
    }
}

// MARK: - Temperature Status Indicator

/// Climate temperature indicator with visual feedback
struct KiaTemperatureStatusIndicator: View {
    let temperature: Double // in Celsius
    let targetTemperature: Double?
    let unit: TemperatureUnit
    
    init(temperature: Double, targetTemperature: Double? = nil, unit: TemperatureUnit = .celsius) {
        self.temperature = temperature
        self.targetTemperature = targetTemperature
        self.unit = unit
    }
    
    var body: some View {
        HStack(spacing: KiaDesign.Spacing.xs) {
            temperatureIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTemperature)
                    .font(KiaDesign.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                if let targetTemperature = targetTemperature {
                    Text("Target: \(Int(targetTemperature))°")
                        .font(KiaDesign.Typography.captionSmall)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, KiaDesign.Spacing.small)
        .padding(.vertical, KiaDesign.Spacing.xs)
        .background(temperatureColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var temperatureIcon: some View {
        Image(systemName: temperatureSymbol)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(temperatureColor)
    }
    
    private var temperatureSymbol: String {
        if temperature < 10 {
            return "thermometer.snowflake"
        } else if temperature < 20 {
            return "thermometer.low"
        } else if temperature < 30 {
            return "thermometer.medium"
        } else {
            return "thermometer.high"
        }
    }
    
    private var temperatureColor: Color {
        if temperature < 10 {
            return KiaDesign.Colors.Climate.cold
        } else if temperature < 20 {
            return KiaDesign.Colors.Climate.cool
        } else if temperature < 25 {
            return KiaDesign.Colors.Climate.auto
        } else if temperature < 30 {
            return KiaDesign.Colors.Climate.warm
        } else {
            return KiaDesign.Colors.Climate.hot
        }
    }
    
    private var formattedTemperature: String {
        let temp = unit == .celsius ? temperature : temperature * 9/5 + 32
        return "\(Int(temp))°\(unit == .celsius ? "C" : "F")"
    }
}

// MARK: - Preview

#Preview("Status Indicators") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Basic status indicators
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Basic Status Indicators")
                    .font(KiaDesign.Typography.title2)
                
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    KiaStatusIndicator(status: .ready)
                    KiaStatusIndicator(status: .normal)
                    KiaStatusIndicator(status: .charging, style: .outlined)
                    KiaStatusIndicator(status: .locked, style: .ghost)
                    KiaStatusIndicator(status: .warning("Low Tire Pressure"))
                    KiaStatusIndicator(status: .error("System Fault"))
                    KiaStatusIndicator(status: .inactive)
                }
            }
            
            Divider()
            
            // Different sizes
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Different Sizes")
                    .font(KiaDesign.Typography.title2)
                
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    KiaStatusIndicator(status: .ready, size: .small)
                    KiaStatusIndicator(status: .charging, size: .medium)
                    KiaStatusIndicator(status: .locked, size: .large)
                }
            }
            
            Divider()
            
            // Battery indicators
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Battery Status")
                    .font(KiaDesign.Typography.title2)
                
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    KiaBatteryStatusIndicator(batteryLevel: 0.85, isCharging: false)
                    KiaBatteryStatusIndicator(batteryLevel: 0.45, isCharging: true)
                    KiaBatteryStatusIndicator(batteryLevel: 0.15, isCharging: false)
                }
            }
            
            Divider()
            
            // Temperature indicators
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Temperature Status")
                    .font(KiaDesign.Typography.title2)
                
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    KiaTemperatureStatusIndicator(temperature: 22, targetTemperature: 24)
                    KiaTemperatureStatusIndicator(temperature: 5)
                    KiaTemperatureStatusIndicator(temperature: 35, unit: .celsius)
                }
            }
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}
