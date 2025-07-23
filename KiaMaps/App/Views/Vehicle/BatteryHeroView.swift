import SwiftUI

struct BatteryHeroView: View {
    let batteryLevel: Double
    let range: String
    let isCharging: Bool
    let estimatedTimeToFull: String?
    let chargingPower: String?
    let batteryHealth: Double // State of Health as a percentage (0-100)
    let efficiency: String? // Real efficiency value from API
    
    @State private var showDetails = false
    
    private var statusText: String {
        if isCharging {
            if let timeToFull = estimatedTimeToFull {
                return "Charging • \(timeToFull) remaining"
            } else {
                return "Charging"
            }
        } else {
            return "Ready to drive"
        }
    }
    
    private var secondaryInfo: String? {
        if isCharging, let power = chargingPower {
            return "Charging at \(power)"
        }
        return nil
    }
    
    var body: some View {
        KiaHeroCard {
            VStack(spacing: 24) {
                // Header with range
                VStack(spacing: 2) {
                    Text(range)
                        .font(KiaDesign.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("Estimated Range")
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                // Circular battery indicator
                CircularBatteryView(
                    level: batteryLevel,
                    isCharging: isCharging,
                    size: 150
                )

                // Status information
                VStack(spacing: 6) {
                    Text(statusText)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.medium)
                        .foregroundStyle(isCharging ? KiaDesign.Colors.charging : KiaDesign.Colors.textPrimary)
                    
                    if let secondaryInfo = secondaryInfo {
                        Text(secondaryInfo)
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                }
                
                // Expandable details
                if showDetails {
                    BatteryDetailsView(
                        batteryLevel: batteryLevel,
                        isCharging: isCharging,
                        chargingPower: chargingPower,
                        batteryHealth: batteryHealth,
                        efficiency: efficiency
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
                
                // Toggle details button
                KiaButton(
                    showDetails ? "Show Less" : "View Details",
                    style: .secondary,
                    size: .small,
                    hapticFeedback: .light
                ) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDetails.toggle()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery status")
        .accessibilityValue("\(Int(batteryLevel * 100)) percent, \(range) range, \(statusText)")
    }
    
    // MARK: - Helper Functions
    private func formatEfficiency(value: Double, unit: EconomyUnit) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 1
        
        let formattedValue = numberFormatter.string(from: value as NSNumber) ?? "\(value)"
        return "\(formattedValue) \(unit.unitTitle)"
    }
}

// MARK: - Battery Details View
private struct BatteryDetailsView: View {
    let batteryLevel: Double
    let isCharging: Bool
    let chargingPower: String?
    let batteryHealth: Double // State of Health as a percentage (0-100)
    let efficiency: String?
    
    private var batteryHealthString: String {
        return "\(Int(batteryHealth))%"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .background(KiaDesign.Colors.textTertiary.opacity(0.3))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                DetailItem(
                    icon: "battery.100percent",
                    label: "Battery Health",
                    value: batteryHealthString,
                    color: batteryHealth > 90 ? KiaDesign.Colors.success : 
                           batteryHealth > 80 ? KiaDesign.Colors.warning : KiaDesign.Colors.error
                )
                
                if let power = chargingPower, isCharging {
                    DetailItem(
                        icon: "bolt.fill",
                        label: "Charging Power",
                        value: power,
                        color: KiaDesign.Colors.charging
                    )
                }
                
                DetailItem(
                    icon: "thermometer",
                    label: "Battery Temp",
                    value: "22°C", // Should be from BatteryPreCondition
                    color: KiaDesign.Colors.textSecondary
                )
                
                DetailItem(
                    icon: "speedometer",
                    label: "Efficiency",
                    value: efficiency ?? "Not available",
                    color: KiaDesign.Colors.accent
                )
            }
        }
    }
}

// MARK: - Detail Item Component
private struct DetailItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text(label)
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Convenience Initializers
extension BatteryHeroView {
    /// Create BatteryHeroView from VehicleStatus
    init(from status: VehicleStatus) {
        let batteryPercent = status.green.batteryManagement.batteryRemain.ratio
        let dte = status.drivetrain.fuelSystem.dte
        let rangeValue = dte.total
        let rangeUnit = dte.unit == .kilometers ? "km" : "mi"
        
        let chargingInfo = status.green.chargingInformation
        let isCharging = status.isCharging

        self.batteryLevel = Double(batteryPercent) / 100.0
        self.range = "\(rangeValue) \(rangeUnit)"
        self.isCharging = isCharging

        // Calculate estimated time to full if charging
        if isCharging && chargingInfo.charging.remainTime > 0 {
            let remainingMinutes = Int(chargingInfo.charging.remainTime)
            let hours = remainingMinutes / 60
            let minutes = remainingMinutes % 60
            if hours > 0 {
                estimatedTimeToFull = "\(hours)h \(minutes)m"
            } else {
                estimatedTimeToFull = "\(minutes)m"
            }
        } else {
            self.estimatedTimeToFull = nil
        }
        
        // Get real charging power
        if isCharging {
            let realPower = status.green.electric.smartGrid.realTimePower
            self.chargingPower = realPower > 0 ? String(format: "%.1f kW", realPower) : nil
        } else {
            self.chargingPower = nil
        }
        
        // Get battery health
        self.batteryHealth = status.green.batteryManagement.soH.ratio
        
        // Get real efficiency data from API (formatted inline to avoid calling self methods)
        let economy = status.drivetrain.fuelSystem.averageFuelEconomy
        
        if economy.drive > 0 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.maximumFractionDigits = 1
            let formattedValue = numberFormatter.string(from: economy.drive as NSNumber) ?? "\(economy.drive)"
            self.efficiency = "\(formattedValue) \(economy.unit.unitTitle)"
        } else if economy.accumulated > 0 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.maximumFractionDigits = 1
            let formattedValue = numberFormatter.string(from: economy.accumulated as NSNumber) ?? "\(economy.accumulated)"
            self.efficiency = "\(formattedValue) \(economy.unit.unitTitle)"
        } else {
            // Final fallback to driving history average
            let drivingHistory = status.green.drivingHistory
            if drivingHistory.average > 0 {
                self.efficiency = String(format: "%.1f km/kWh", drivingHistory.average)
            } else {
                self.efficiency = nil
            }
        }
    }
    
    /// Create BatteryHeroView from VehicleStatusResponse
    init(from response: VehicleStatusResponse) {
        self.init(from: response.state.vehicle)
    }
}

// MARK: - Preview
#Preview("Battery Hero - Charging") {
    BatteryHeroView(from: MockVehicleData.charging)
        .padding()
        .background(KiaDesign.Colors.background)
}

#Preview("Battery Hero - Standard") {
    BatteryHeroView(from: MockVehicleData.standard)
        .padding()
        .background(KiaDesign.Colors.background)
}

#Preview("Battery Hero - Low Battery") {
    BatteryHeroView(from: MockVehicleData.lowBattery)
        .padding()
        .background(KiaDesign.Colors.background)
}

#Preview("Battery Hero - Full Battery") {
    BatteryHeroView(from: MockVehicleData.fullBattery)
        .padding()
        .background(KiaDesign.Colors.background)
}

#Preview("Battery Hero - Fast Charging") {
    BatteryHeroView(from: MockVehicleData.fastCharging)
        .padding()
        .background(KiaDesign.Colors.background)
}
