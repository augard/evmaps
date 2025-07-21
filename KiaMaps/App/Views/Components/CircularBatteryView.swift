import SwiftUI

struct CircularBatteryView: View {
    let level: Double // 0.0 to 1.0
    let isCharging: Bool
    let size: CGFloat
    
    @State private var animationProgress: Double = 0
    @State private var chargingAnimation: Bool = false
    
    private var batteryPercentage: Int {
        Int(level * 100)
    }
    
    private var strokeColor: Color {
        switch level {
        case 0.8...1.0:
            return KiaDesign.Colors.success
        case 0.2...0.8:
            return KiaDesign.Colors.charging
        default:
            return KiaDesign.Colors.error
        }
    }
    
    private var batteryColor: LinearGradient {
        switch level {
        case 0.8...1.0:
            return LinearGradient(
                colors: [KiaDesign.Colors.success, KiaDesign.Colors.success.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 0.2...0.8:
            return LinearGradient(
                colors: [KiaDesign.Colors.charging, KiaDesign.Colors.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [KiaDesign.Colors.error, KiaDesign.Colors.error.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    init(level: Double, isCharging: Bool = false, size: CGFloat = 200) {
        self.level = max(0, min(1, level)) // Clamp between 0 and 1
        self.isCharging = isCharging
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(KiaDesign.Colors.textTertiary.opacity(0.2), lineWidth: 8)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: animationProgress * level)
                .stroke(
                    batteryColor,
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: strokeColor.opacity(0.3),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            
            // Charging animation overlay
            if isCharging {
                Circle()
                    .trim(from: 0, to: 0.1)
                    .stroke(
                        KiaDesign.Colors.charging.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: 10,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(chargingAnimation ? 360 : -90))
                    .shadow(
                        color: KiaDesign.Colors.charging,
                        radius: 8,
                        x: 0,
                        y: 0
                    )
            }
            
            // Center content
            VStack(spacing: 4) {
                // Battery percentage
                Text("\(batteryPercentage)")
                    .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("%")
                    .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                // Charging indicator
                if isCharging {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: size * 0.06))
                            .foregroundStyle(KiaDesign.Colors.charging)
                        
                        Text("Charging")
                            .font(.system(size: size * 0.05, weight: .medium))
                            .foregroundStyle(KiaDesign.Colors.textSecondary)
                    }
                    .scaleEffect(chargingAnimation ? 1.05 : 1.0)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            // Animate progress on appearance
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
            
            // Start charging animation if charging
            if isCharging {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    chargingAnimation = true
                }
                
                // Pulsing effect
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    chargingAnimation = true
                }
            }
        }
        .onChange(of: level) { _, newLevel in
            // Animate to new level
            withAnimation(.easeInOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: isCharging) { _, charging in
            // Handle charging state change
            if charging {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    chargingAnimation = true
                }
            } else {
                chargingAnimation = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery level")
        .accessibilityValue("\(batteryPercentage) percent\(isCharging ? ", charging" : "")")
    }
}

// MARK: - Preview
#Preview("Battery Levels") {
    VStack(spacing: 30) {
        HStack(spacing: 30) {
            CircularBatteryView(level: 0.85, isCharging: false, size: 120)
            CircularBatteryView(level: 0.45, isCharging: true, size: 120)
        }
        
        HStack(spacing: 30) {
            CircularBatteryView(level: 0.15, isCharging: false, size: 120)
            CircularBatteryView(level: 0.92, isCharging: true, size: 120)
        }
    }
    .padding()
    .background(KiaDesign.Colors.background)
}

#Preview("Charging Battery") {
    let chargingStatus = MockVehicleData.charging
    
    CircularBatteryView(
        level: MockVehicleData.batteryLevel(from: chargingStatus),
        isCharging: MockVehicleData.isCharging(chargingStatus), 
        size: 200
    )
    .padding()
    .background(KiaDesign.Colors.background)
}

#Preview("Low Battery") {
    let lowBatteryStatus = MockVehicleData.lowBattery
    
    CircularBatteryView(
        level: MockVehicleData.batteryLevel(from: lowBatteryStatus),
        isCharging: MockVehicleData.isCharging(lowBatteryStatus),
        size: 200
    )
    .padding()
    .background(KiaDesign.Colors.background)
}

#Preview("Full Battery") {
    let fullBatteryStatus = MockVehicleData.fullBattery
    
    CircularBatteryView(
        level: MockVehicleData.batteryLevel(from: fullBatteryStatus),
        isCharging: MockVehicleData.isCharging(fullBatteryStatus),
        size: 200
    )
    .padding()
    .background(KiaDesign.Colors.background)
}