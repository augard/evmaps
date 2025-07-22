import SwiftUI

/// Tesla-style quick action buttons for common vehicle operations
struct QuickActionsView: View {
    let vehicleStatus: VehicleStatusResponse
    let onLockAction: () -> Void
    let onClimateAction: () -> Void
    let onHornAction: () -> Void
    let onLocateAction: () -> Void
    
    @State private var isPerformingAction: String? = nil
    
    private var isLocked: Bool {
        // Use actual lock status from cabin door data
        let cabin = vehicleStatus.state.vehicle.cabin.door
        return !cabin.row1.driver.lock && !cabin.row1.passenger.lock && !cabin.row2.left.lock && !cabin.row2.right.lock
    }
    
    private var isClimateOn: Bool {
        // Use actual climate status when available - placeholder for now
        false // Placeholder logic - would need actual climate system data
    }
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            Text("Quick Actions")
                .font(KiaDesign.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: KiaDesign.Spacing.medium), count: 2),
                spacing: KiaDesign.Spacing.medium
            ) {
                ActionButton(
                    icon: isLocked ? "lock.fill" : "lock.open.fill",
                    title: isLocked ? "Unlock" : "Lock",
                    subtitle: isLocked ? "Vehicle Secured" : "Tap to Lock",
                    color: isLocked ? KiaDesign.Colors.success : KiaDesign.Colors.warning,
                    isLoading: isPerformingAction == "lock",
                    action: {
                        performAction("lock", onLockAction)
                    }
                )
                
                ActionButton(
                    icon: "snow",
                    title: "Climate",
                    subtitle: isClimateOn ? "On • 22°C" : "Start Comfort",
                    color: isClimateOn ? KiaDesign.Colors.accent : KiaDesign.Colors.textSecondary,
                    isLoading: isPerformingAction == "climate",
                    action: {
                        performAction("climate", onClimateAction)
                    }
                )
                
                ActionButton(
                    icon: "speaker.wave.2.fill",
                    title: "Horn & Lights",
                    subtitle: "Find Vehicle",
                    color: KiaDesign.Colors.primary,
                    isLoading: isPerformingAction == "horn",
                    action: {
                        performAction("horn", onHornAction)
                    }
                )
                
                ActionButton(
                    icon: "location.fill",
                    title: "Locate",
                    subtitle: "Show on Map",
                    color: KiaDesign.Colors.accent,
                    isLoading: isPerformingAction == "locate",
                    action: {
                        performAction("locate", onLocateAction)
                    }
                )
            }
        }
    }
    
    private func performAction(_ actionType: String, _ action: @escaping () -> Void) {
        isPerformingAction = actionType
        
        // Add haptic feedback
        ActionButton.HapticFeedback.medium.trigger()
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            action()
            isPerformingAction = nil
            
            // Success haptic
            ActionButton.HapticFeedback.success.trigger()
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        KiaCompactCard(action: action) {
            VStack(spacing: KiaDesign.Spacing.small) {
                // Icon section
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Group {
                        if isLoading {
                            KiaInlineLoadingView(
                                size: .medium,
                                color: color
                            )
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(color)
                        }
                    }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                
                // Text section
                VStack(spacing: 2) {
                    Text(title)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, KiaDesign.Spacing.small)
            .frame(maxWidth: .infinity)
            .opacity(isLoading ? 0.7 : 1.0)
            .disabled(isLoading)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isPressed = pressing && !isLoading
            }
        } perform: {
            // Long press completed - could add additional functionality here
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to \(title.lowercased())")
    }
}

// MARK: - Haptic Feedback Extension
extension ActionButton {
    enum HapticFeedback {
        case light, medium, heavy, success, warning, error
        
        func trigger() {
            switch self {
            case .light:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .heavy:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .error:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}


// MARK: - Preview
#Preview("Quick Actions - Standard") {
    QuickActionsView(
        vehicleStatus: MockVehicleData.standardResponse,
        onLockAction: { print("🔒 Lock vehicle") },
        onClimateAction: { print("❄️ Climate control") },
        onHornAction: { print("🔊 Horn and lights") },
        onLocateAction: { print("📍 Locate vehicle") }
    )
    .padding()
    .background(KiaDesign.Colors.background)
}

#Preview("Quick Actions - Charging") {
    QuickActionsView(
        vehicleStatus: MockVehicleData.chargingResponse,
        onLockAction: { print("🔒 Lock vehicle") },
        onClimateAction: { print("❄️ Climate control") },
        onHornAction: { print("🔊 Horn and lights") },
        onLocateAction: { print("📍 Locate vehicle") }
    )
    .padding()
    .background(KiaDesign.Colors.background)
}

#Preview("Quick Actions - Low Battery") {
    QuickActionsView(
        vehicleStatus: MockVehicleData.lowBatteryResponse,
        onLockAction: { print("🔒 Lock vehicle") },
        onClimateAction: { print("❄️ Climate control") },
        onHornAction: { print("🔊 Horn and lights") },
        onLocateAction: { print("📍 Locate vehicle") }
    )
    .padding()
    .background(KiaDesign.Colors.background)
}