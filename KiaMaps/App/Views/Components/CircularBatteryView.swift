import SwiftUI

struct CircularBatteryView: View {
    let level: Double // 0.0 to 1.0
    let isCharging: Bool
    let size: CGFloat
    
    @State private var animationProgress: Double = 0
    @State private var chargingRotation: Double = 0
    @State private var chargingPulse: Double = 1.0
    
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
                    .rotationEffect(.degrees(chargingRotation))
                    .shadow(
                        color: KiaDesign.Colors.charging,
                        radius: 8,
                        x: 0,
                        y: 0
                    )
            }
            
            // Center content
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    // Charging indicator
                    if isCharging {
                        Group() {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: size * 0.1))
                                .foregroundStyle(KiaDesign.Colors.charging)
                        }
                        .scaleEffect(chargingPulse)
                        .padding(.top, 1)
                        .padding(.trailing, 4)
                    }

                    // Battery percentage
                    Text("\(batteryPercentage)")
                        .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                        .foregroundStyle(KiaDesign.Colors.textPrimary)

                    Text("%")
                        .font(.system(size: size * 0.08, weight: .medium, design: .rounded))
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
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
                startChargingAnimations()
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
                startChargingAnimations()
            } else {
                stopChargingAnimations()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery level")
        .accessibilityValue("\(batteryPercentage) percent\(isCharging ? ", charging" : "")")
    }
    
    // MARK: - Helper Methods
    
    private func startChargingAnimations() {
        // Start rotation animation
        withAnimation(
            .linear(duration: 3.0)
            .repeatForever(autoreverses: false)
        ) {
            chargingRotation = 360
        }
        
        // Start pulse animation
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            chargingPulse = 1.1
        }
    }
    
    private func stopChargingAnimations() {
        // Stop animations smoothly
        withAnimation(.easeOut(duration: 0.5)) {
            // Keep the current rotation value to prevent jumping
            let currentRotation = chargingRotation.truncatingRemainder(dividingBy: 360)
            chargingRotation = currentRotation
            chargingPulse = 1.0
        }
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
