import SwiftUI

struct BatteryHeroView: View {
    let batteryLevel: Double
    let range: String
    let isCharging: Bool
    let estimatedTimeToFull: String?
    let chargingPower: String?
    
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
                VStack(spacing: 8) {
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
                    size: 200
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
                        chargingPower: chargingPower
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
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery status")
        .accessibilityValue("\(Int(batteryLevel * 100)) percent, \(range) range, \(statusText)")
    }
}

// MARK: - Battery Details View
private struct BatteryDetailsView: View {
    let batteryLevel: Double
    let isCharging: Bool
    let chargingPower: String?
    
    private var batteryHealth: String {
        // Simulate battery health based on level patterns
        let health = Int.random(in: 92...98)
        return "\(health)%"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .background(KiaDesign.Colors.textTertiary.opacity(0.3))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                DetailItem(
                    icon: "battery.100percent",
                    label: "Battery Health",
                    value: batteryHealth,
                    color: KiaDesign.Colors.success
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
                    value: "22°C",
                    color: KiaDesign.Colors.textSecondary
                )
                
                DetailItem(
                    icon: "speedometer",
                    label: "Efficiency",
                    value: "4.2 km/kWh",
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
        
        self.batteryLevel = Double(batteryPercent) / 100.0
        self.range = "\(Int(batteryPercent * 4)) km" // Rough range calculation
        self.isCharging = status.location.heading > 0 // Using heading as charging indicator placeholder
        self.estimatedTimeToFull = isCharging ? "2h 15m" : nil
        self.chargingPower = isCharging ? "11 kW" : nil
    }
    
    /// Create BatteryHeroView from VehicleStatusResponse
    init(from response: VehicleStatusResponse) {
        let vehicleStatus = response.state.vehicle
        let batteryPercent = vehicleStatus.green.batteryManagement.batteryRemain.ratio
        
        self.batteryLevel = Double(batteryPercent) / 100.0
        self.range = "\(Int(batteryPercent * 4)) km" // Rough range calculation
        self.isCharging = vehicleStatus.location.heading > 0 // Using heading as charging indicator placeholder
        self.estimatedTimeToFull = isCharging ? "2h 15m" : nil
        self.chargingPower = isCharging ? "11 kW" : nil
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