//
//  VehicleSilhouetteView.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired vehicle silhouette visualization with interactive elements
//

import SwiftUI

/// Interactive vehicle silhouette showing doors, windows, and status indicators
struct VehicleSilhouetteView: View {
    let vehicleStatus: VehicleStatus
    let onDoorTap: ((DoorPosition) -> Void)?
    let onTireTap: ((TirePosition) -> Void)?
    
    @State private var selectedElement: InteractiveElement?
    @State private var pulsingElements: Set<InteractiveElement> = []
    
    enum DoorPosition: String, CaseIterable {
        case frontLeft = "Front Left"
        case frontRight = "Front Right"
        case rearLeft = "Rear Left"
        case rearRight = "Rear Right"
        case trunk = "Trunk"
        
        var systemIcon: String {
            switch self {
            case .frontLeft, .rearLeft: return "door.left.hand.closed"
            case .frontRight, .rearRight: return "door.right.hand.closed"
            case .trunk: return "car.rear"
            }
        }
    }
    
    enum TirePosition: String, CaseIterable {
        case frontLeft = "Front Left"
        case frontRight = "Front Right"
        case rearLeft = "Rear Left"
        case rearRight = "Rear Right"
        
        var systemIcon: String {
            return "circle.fill"
        }
    }
    
    enum InteractiveElement: Hashable {
        case door(DoorPosition)
        case tire(TirePosition)
        case chargingPort
        case vehicle
        case warning(WarningType)
    }
    
    enum WarningType: String, CaseIterable {
        case lowBattery = "Low Battery"
        case engineWarning = "Engine Warning"
        case maintenanceRequired = "Maintenance Required"
        case tirePressure = "Tire Pressure"
        case batteryHealth = "Battery Health"
        case chargingIssue = "Charging Issue"
        
        var icon: String {
            switch self {
            case .lowBattery: return "battery.25"
            case .engineWarning: return "exclamationmark.triangle.fill"
            case .maintenanceRequired: return "wrench.fill"
            case .tirePressure: return "exclamationmark.circle.fill"
            case .batteryHealth: return "battery.0"
            case .chargingIssue: return "bolt.slash.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .lowBattery: return KiaDesign.Colors.warning
            case .engineWarning: return KiaDesign.Colors.error
            case .maintenanceRequired: return KiaDesign.Colors.accent
            case .tirePressure: return KiaDesign.Colors.warning
            case .batteryHealth: return KiaDesign.Colors.error
            case .chargingIssue: return KiaDesign.Colors.error
            }
        }
    }
    
    init(
        vehicleStatus: VehicleStatus,
        onDoorTap: ((DoorPosition) -> Void)? = nil,
        onTireTap: ((TirePosition) -> Void)? = nil
    ) {
        self.vehicleStatus = vehicleStatus
        self.onDoorTap = onDoorTap
        self.onTireTap = onTireTap
    }
    
    var body: some View {
        ZStack {
            // Main vehicle silhouette
            vehicleSilhouette
            
            // Interactive elements overlay
            interactiveElementsOverlay
            
            // Charging indicator (if charging)
            if isCharging {
                chargingPortIndicator
            }
            
            // Warning indicators overlay
            warningIndicatorsOverlay
        }
        .frame(width: 280, height: 140)
        .background(
            RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large)
                .fill(KiaDesign.Colors.cardBackground)
                .stroke(KiaDesign.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            startStatusAnimations()
        }
    }
    
    // MARK: - Vehicle Silhouette
    
    private var vehicleSilhouette: some View {
        ZStack {
            // Main body - simplified SUV/crossover shape
            RoundedRectangle(cornerRadius: 16)
                .fill(vehicleBodyColor)
                .frame(width: 200, height: 80)
                .overlay(
                    // Windows
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KiaDesign.Colors.textTertiary.opacity(0.3))
                        .frame(width: 160, height: 40)
                        .offset(y: -5)
                )
            
            // Hood detail
            RoundedRectangle(cornerRadius: 6)
                .fill(vehicleBodyColor.opacity(0.8))
                .frame(width: 40, height: 20)
                .offset(x: -80, y: 0)
            
            // Rear detail
            RoundedRectangle(cornerRadius: 6)
                .fill(vehicleBodyColor.opacity(0.8))
                .frame(width: 30, height: 16)
                .offset(x: 85, y: 0)
        }
    }
    
    // MARK: - Interactive Elements
    
    private var interactiveElementsOverlay: some View {
        ZStack {
            // Doors
            ForEach(DoorPosition.allCases, id: \.self) { door in
                doorIndicator(for: door)
            }
            
            // Tires
            ForEach(TirePosition.allCases, id: \.self) { tire in
                tireIndicator(for: tire)
            }
        }
    }
    
    private func doorIndicator(for door: DoorPosition) -> some View {
        let isOpen = isDoorOpen(door)
        let position = doorPosition(for: door)
        
        return Circle()
            .fill(isOpen ? KiaDesign.Colors.warning : KiaDesign.Colors.success)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(KiaDesign.Colors.cardBackground, lineWidth: 2)
            )
            .scaleEffect(
                (pulsingElements as Set<InteractiveElement>).contains(.door(door)) ? 1.3 : 1.0
            )
            .animation(
                (pulsingElements as Set<InteractiveElement>).contains(.door(door)) ? 
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : 
                    .default,
                value: (pulsingElements as Set<InteractiveElement>).contains(.door(door))
            )
            .offset(x: position.x, y: position.y)
            .onTapGesture {
                selectedElement = .door(door)
                onDoorTap?(door)
                
                // Haptic feedback
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                // Pulse animation
                withAnimation(.default) {
                    pulsingElements.insert(.door(door))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.default) {
                        _ = pulsingElements.remove(.door(door))
                    }
                }
            }
    }
    
    private func tireIndicator(for tire: TirePosition) -> some View {
        let pressure = tirePressure(for: tire)
        let isHealthy = pressure > 30.0
        let position = tirePosition(for: tire)
        
        return Circle()
            .fill(isHealthy ? KiaDesign.Colors.textPrimary : KiaDesign.Colors.warning)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(KiaDesign.Colors.cardBackground, lineWidth: 2)
            )
            .scaleEffect(
                (pulsingElements as Set<InteractiveElement>).contains(.tire(tire)) ? 1.2 : 1.0
            )
            .animation(
                (pulsingElements as Set<InteractiveElement>).contains(.tire(tire)) ? 
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                    .default,
                value: (pulsingElements as Set<InteractiveElement>).contains(.tire(tire))
            )
            .offset(x: position.x, y: position.y)
            .onTapGesture {
                selectedElement = .tire(tire)
                onTireTap?(tire)
                
                // Haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                
                // Pulse animation
                withAnimation(.default) {
                    pulsingElements.insert(.tire(tire))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.default) {
                        _ = pulsingElements.remove(.tire(tire))
                    }
                }
            }
    }
    
    private var chargingPortIndicator: some View {
        ZStack {
            // Charging port glow
            Circle()
                .fill(KiaDesign.Colors.charging.opacity(0.3))
                .frame(width: 20, height: 20)
                .blur(radius: 2)
            
            // Port indicator
            Circle()
                .fill(KiaDesign.Colors.charging)
                .frame(width: 10, height: 10)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .offset(x: -60, y: 10) // Left side of vehicle
        .scaleEffect((pulsingElements as Set<InteractiveElement>).contains(.chargingPort) ? 1.4 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: (pulsingElements as Set<InteractiveElement>).contains(.chargingPort)
        )
    }
    
    // MARK: - Warning Indicators
    
    private var warningIndicatorsOverlay: some View {
        ZStack {
            // Display active warnings as floating indicators
            ForEach(Array(activeWarnings.enumerated()), id: \.element) { index, warning in
                warningIndicator(for: warning, index: index)
            }
        }
    }
    
    private func warningIndicator(for warning: WarningType, index: Int) -> some View {
        let position = warningPosition(for: index)
        
        return ZStack {
            // Warning glow effect
            Circle()
                .fill(warning.color.opacity(0.3))
                .frame(width: 24, height: 24)
                .blur(radius: 2)
            
            // Warning icon background
            Circle()
                .fill(warning.color)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
            
            // Warning icon
            Image(systemName: warning.icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(
            (pulsingElements as Set<InteractiveElement>).contains(.warning(warning)) ? 1.3 : 1.0
        )
        .animation(
            (pulsingElements as Set<InteractiveElement>).contains(.warning(warning)) ? 
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                .default,
            value: (pulsingElements as Set<InteractiveElement>).contains(.warning(warning))
        )
        .offset(x: position.x, y: position.y)
        .onTapGesture {
            // Handle warning tap
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            
            // Pulse animation
            withAnimation(.default) {
                pulsingElements.insert(.warning(warning))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.default) {
                    _ = pulsingElements.remove(.warning(warning))
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var vehicleBodyColor: Color {
        // Use battery level to subtly influence vehicle color
        let batteryLevel = Double(vehicleStatus.green.batteryManagement.batteryRemain.ratio) / 100.0
        
        if batteryLevel < 0.2 {
            return KiaDesign.Colors.textTertiary.opacity(0.7)
        } else if isCharging {
            return KiaDesign.Colors.primary.opacity(0.8)
        } else {
            return KiaDesign.Colors.textSecondary.opacity(0.8)
        }
    }
    
    private var isCharging: Bool {
        // Using heading as charging indicator placeholder
        vehicleStatus.location.heading > 0
    }
    
    private var activeWarnings: [WarningType] {
        var warnings: [WarningType] = []
        
        // Check battery level
        let batteryLevel = Double(vehicleStatus.green.batteryManagement.batteryRemain.ratio) / 100.0
        if batteryLevel < 0.2 {
            warnings.append(.lowBattery)
        }
        
        // Check battery health
        let batteryHealth = Double(vehicleStatus.green.batteryManagement.soH.ratio) / 100.0
        if batteryHealth < 0.8 {
            warnings.append(.batteryHealth)
        }
        
        // Check tire pressures
        let lowTirePressure = TirePosition.allCases.contains { tire in
            tirePressure(for: tire) <= 30.0
        }
        if lowTirePressure {
            warnings.append(.tirePressure)
        }
        
        // Check for maintenance needs (using mock logic - park position and full battery)
        if vehicleStatus.drivetrain.transmission.parkingPosition && batteryLevel > 0.9 {
            warnings.append(.maintenanceRequired)
        }
        
        // Check charging issues (when should be charging but not)
        if batteryLevel < 0.3 && !isCharging {
            warnings.append(.chargingIssue)
        }
        
        return warnings
    }
    
    // MARK: - Position Calculations
    
    private func doorPosition(for door: DoorPosition) -> CGPoint {
        switch door {
        case .frontLeft:
            return CGPoint(x: -60, y: -25)
        case .frontRight:
            return CGPoint(x: -60, y: 25)
        case .rearLeft:
            return CGPoint(x: 60, y: -25)
        case .rearRight:
            return CGPoint(x: 60, y: 25)
        case .trunk:
            return CGPoint(x: 95, y: 0)
        }
    }
    
    private func tirePosition(for tire: TirePosition) -> CGPoint {
        switch tire {
        case .frontLeft:
            return CGPoint(x: -75, y: -35)
        case .frontRight:
            return CGPoint(x: -75, y: 35)
        case .rearLeft:
            return CGPoint(x: 75, y: -35)
        case .rearRight:
            return CGPoint(x: 75, y: 35)
        }
    }
    
    private func warningPosition(for index: Int) -> CGPoint {
        // Position warnings in a semi-circle above the vehicle
        let baseY: CGFloat = -60
        let radius: CGFloat = 40
        let startAngle: CGFloat = .pi * 0.2 // Start from left side
        let endAngle: CGFloat = .pi * 0.8   // End at right side
        
        let angle = startAngle + (endAngle - startAngle) * CGFloat(index) / max(1, CGFloat(activeWarnings.count - 1))
        
        return CGPoint(
            x: radius * cos(angle),
            y: baseY + radius * sin(angle) * 0.5
        )
    }
    
    // MARK: - Status Methods
    
    private func isDoorOpen(_ door: DoorPosition) -> Bool {
        // Placeholder logic - doors are closed in current API
        false
    }
    
    private func tirePressure(for tire: TirePosition) -> Double {
        // Simulate tire pressure values
        switch tire {
        case .frontLeft: return 32.0
        case .frontRight: return 32.5
        case .rearLeft: return 31.8
        case .rearRight: return 32.2
        }
    }
    
    private func startStatusAnimations() {
        if isCharging {
            pulsingElements.insert(.chargingPort)
        }
        
        // Pulse any low tire pressure indicators
        for tire in TirePosition.allCases {
            if tirePressure(for: tire) <= 30.0 {
                pulsingElements.insert(.tire(tire))
            }
        }
        
        // Start warning animations
        for warning in activeWarnings {
            pulsingElements.insert(.warning(warning))
        }
    }
}

// MARK: - Status Detail View

/// Expandable detail view showing comprehensive vehicle status
struct VehicleStatusDetailView: View {
    let vehicleStatus: VehicleStatus
    let selectedElement: VehicleSilhouetteView.InteractiveElement?
    
    var body: some View {
        if let element = selectedElement {
            KiaCard(elevation: .medium) {
                VStack(spacing: KiaDesign.Spacing.medium) {
                    elementDetailContent(for: element)
                }
                .padding(.vertical, KiaDesign.Spacing.small)
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
        }
    }
    
    @ViewBuilder
    private func elementDetailContent(for element: VehicleSilhouetteView.InteractiveElement) -> some View {
        switch element {
        case .door(let position):
            doorDetailView(for: position)
        case .tire(let position):
            tireDetailView(for: position)
        case .chargingPort:
            chargingDetailView()
        case .vehicle:
            vehicleOverviewView()
        case .warning(let warningType):
            warningDetailView(for: warningType)
        }
    }
    
    private func doorDetailView(for door: VehicleSilhouetteView.DoorPosition) -> some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: door.systemIcon)
                    .foregroundStyle(KiaDesign.Colors.primary)
                
                Text(door.rawValue + " Door")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: .ready)
            }
            
            HStack {
                Text("Status:")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                Spacer()
                
                Text("Closed & Locked")
                    .font(KiaDesign.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.success)
            }
        }
    }
    
    private func tireDetailView(for tire: VehicleSilhouetteView.TirePosition) -> some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(KiaDesign.Colors.primary)
                
                Text(tire.rawValue + " Tire")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: .ready)
            }
            
            HStack {
                Text("Pressure:")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                Spacer()
                
                Text("32.0 PSI")
                    .font(KiaDesign.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.success)
            }
        }
    }
    
    private func chargingDetailView() -> some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(KiaDesign.Colors.charging)
                
                Text("Charging Port")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: .charging)
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text("Power:")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("11 kW")
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.charging)
                }
                
                HStack {
                    Text("Time Remaining:")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("2h 15m")
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                }
            }
        }
    }
    
    private func vehicleOverviewView() -> some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundStyle(KiaDesign.Colors.primary)
                
                Text("Vehicle Overview")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: .ready)
            }
            
            Text("All systems normal. Vehicle ready to drive.")
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func warningDetailView(for warning: VehicleSilhouetteView.WarningType) -> some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: warning.icon)
                    .foregroundStyle(warning.color)
                
                Text(warning.rawValue)
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: .warning(warning.rawValue))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(warningDescription(for: warning))
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let action = warningAction(for: warning) {
                    Text("Action: \(action)")
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(warning.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func warningDescription(for warning: VehicleSilhouetteView.WarningType) -> String {
        switch warning {
        case .lowBattery:
            return "Battery level is below 20%. Consider charging soon."
        case .engineWarning:
            return "Engine system requires attention. Check diagnostics."
        case .maintenanceRequired:
            return "Scheduled maintenance is due. Book service appointment."
        case .tirePressure:
            return "One or more tires have low pressure. Check and inflate."
        case .batteryHealth:
            return "Battery health has degraded. Consider replacement."
        case .chargingIssue:
            return "Charging is recommended but not active. Check charging cable."
        }
    }
    
    private func warningAction(for warning: VehicleSilhouetteView.WarningType) -> String? {
        switch warning {
        case .lowBattery:
            return "Find charging station"
        case .engineWarning:
            return "Contact service center"
        case .maintenanceRequired:
            return "Schedule service"
        case .tirePressure:
            return "Check tire pressure"
        case .batteryHealth:
            return "Battery diagnostic"
        case .chargingIssue:
            return "Check charging setup"
        }
    }
}

// MARK: - Interactive Silhouette Container

/// Container view combining silhouette with expandable details
struct InteractiveVehicleSilhouetteView: View {
    let vehicleStatus: VehicleStatus
    
    @State private var selectedElement: VehicleSilhouetteView.InteractiveElement?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // Silhouette
            VehicleSilhouetteView(
                vehicleStatus: vehicleStatus,
                onDoorTap: { door in
                    selectedElement = .door(door)
                    showingDetails = true
                },
                onTireTap: { tire in
                    selectedElement = .tire(tire)
                    showingDetails = true
                }
            )
            
            // Details (if selected)
            if showingDetails {
                VehicleStatusDetailView(
                    vehicleStatus: vehicleStatus,
                    selectedElement: selectedElement
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingDetails = false
                        selectedElement = nil
                    }
                }
            }
        }
        .onTapGesture {
            if showingDetails {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingDetails = false
                    selectedElement = nil
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Vehicle Silhouette") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Static silhouette
            Text("Static Silhouette")
                .font(KiaDesign.Typography.title2)
            
            // Mock vehicle status for preview
            VehicleSilhouetteView(vehicleStatus: MockVehicleData.standard)
            
            Divider()
            
            // Interactive silhouette
            Text("Interactive Silhouette")
                .font(KiaDesign.Typography.title2)
            
            InteractiveVehicleSilhouetteView(vehicleStatus: MockVehicleData.charging)
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}
