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
    let onChargingPortTap: (() -> Void)?
    
    @State private var selectedElement: InteractiveElement?
    @State private var pulsingElements: Set<InteractiveElement> = []
    
    enum DoorPosition: String, CaseIterable {
        case frontLeft = "Front Left"
        case frontRight = "Front Right"
        case rearLeft = "Rear Left"
        case rearRight = "Rear Right"
        case trunk = "Trunk"
        case frunk = "Frunk"
        
        var systemIcon: String {
            switch self {
            case .frontLeft: return "car.top.door.front.left.open"
            case .rearLeft: return "car.top.door.rear.left.open"
            case .frontRight: return "car.top.door.front.right.open"
            case .rearRight: return "car.top.door.rear.right.open"
            case .trunk: return "car.side.rear.open"
            case .frunk: return "car.side.front.open"
            }
        }
    }
    
    enum TirePosition: String, CaseIterable {
        case frontLeft = "Front Left"
        case frontRight = "Front Right"
        case rearLeft = "Rear Left"
        case rearRight = "Rear Right"
        
        var systemIcon: String {
            return "tire"
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
        onTireTap: ((TirePosition) -> Void)? = nil,
        onChargingPortTap: (() -> Void)? = nil
    ) {
        self.vehicleStatus = vehicleStatus
        self.onDoorTap = onDoorTap
        self.onTireTap = onTireTap
        self.onChargingPortTap = onChargingPortTap
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * 0.5 // Maintain 2:1 aspect ratio
            
            ZStack {
                // Main vehicle silhouette
                vehicleSilhouette
                    .scaleEffect(width / 280) // Scale based on original 280 width

                // Interactive elements overlay
                interactiveElementsOverlay
                    .scaleEffect(width / 280)
                
                // Charging indicator (if charging)
                if isCharging {
                    chargingPortIndicator
                        .scaleEffect(width / 280)
                }
                
                // Warning indicators overlay
                warningIndicatorsOverlay
                    .scaleEffect(width / 280)
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large)
                    .fill(KiaDesign.Colors.cardBackground)
                    .stroke(KiaDesign.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
            .onAppear {
                startStatusAnimations()
            }
        }
        .aspectRatio(2, contentMode: .fit)
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
                        .frame(width: 160, height: 50)
                        .offset(y: 0)
                )
            
            // Hood detail
            RoundedRectangle(cornerRadius: 12)
                .fill(vehicleBodyColor.opacity(0.8))
                .frame(width: 30, height: 70)
                .offset(x: -80, y: 0)

            // Rear detail
            RoundedRectangle(cornerRadius: 12)
                .fill(vehicleBodyColor.opacity(0.8))
                .frame(width: 40, height: 70)
                .offset(x: 75, y: 0)
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
        let isLocked = isDoorLocked(door)
        let hasFault = door == .frunk && vehicleStatus.hasFrunkFault(door)
        let position = doorPosition(for: door)
        
        // Determine door color based on state
        let doorColor: Color = {
            if hasFault {
                return KiaDesign.Colors.error // Red for frunk fault
            } else if isOpen {
                return KiaDesign.Colors.warning // Orange for open
            } else if !isLocked {
                return KiaDesign.Colors.error // Red for unlocked
            } else {
                return KiaDesign.Colors.success // Green for locked and closed
            }
        }()
        
        return Circle()
            .fill(doorColor)
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
        let isLowPressure = isTirePressureLow(for: tire)
        let position = tirePosition(for: tire)
        
        return Circle()
            .fill(isLowPressure ? KiaDesign.Colors.warning : KiaDesign.Colors.textPrimary)
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
                .overlay(
                    Circle()
                        .stroke(KiaDesign.Colors.cardBackground, lineWidth: 2)
                )

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
        .scaleEffect((pulsingElements as Set<InteractiveElement>).contains(.chargingPort) ? 1.4 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: (pulsingElements as Set<InteractiveElement>).contains(.chargingPort)
        )
        .onTapGesture {
            selectedElement = .chargingPort
            onChargingPortTap?()
            
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Pulse animation
            withAnimation(.default) {
                pulsingElements.insert(.chargingPort)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.default) {
                    _ = pulsingElements.remove(.chargingPort)
                }
            }
        }
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
        // Use real charging status from API
        vehicleStatus.isCharging
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
            isTirePressureLow(for: tire)
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
            return CGPoint(x: -50, y: -40)
        case .frontRight:
            return CGPoint(x: -50, y: 40)
        case .rearLeft:
            return CGPoint(x: 40, y: -40)
        case .rearRight:
            return CGPoint(x: 40, y: 40)
        case .trunk:
            return CGPoint(x: 100, y: 0)
        case .frunk:
            return CGPoint(x: -100, y: 0)
        }
    }
    
    private func tirePosition(for tire: TirePosition) -> CGPoint {
        let outsidePossition = 40.0
        switch tire {
        case .frontLeft:
            return CGPoint(x: -80, y: -outsidePossition)
        case .frontRight:
            return CGPoint(x: -80, y: outsidePossition)
        case .rearLeft:
            return CGPoint(x: 75, y: -outsidePossition)
        case .rearRight:
            return CGPoint(x: 75, y: outsidePossition)
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
        return vehicleStatus.isDoorOpen(door)
    }
    
    private func isDoorLocked(_ door: DoorPosition) -> Bool {
        return vehicleStatus.isDoorLocked(door)
    }
    
    private func tirePressure(for tire: TirePosition) -> Double {
        // Get real tire pressure values from API
        let chassis = vehicleStatus.chassis
        switch tire {
        case .frontLeft: 
            return Double(chassis.axle.row1.left.tire.pressure)
        case .frontRight: 
            return Double(chassis.axle.row1.right.tire.pressure)
        case .rearLeft: 
            return Double(chassis.axle.row2.left.tire.pressure)
        case .rearRight: 
            return Double(chassis.axle.row2.right.tire.pressure)
        }
    }
    
    private func isTirePressureLow(for tire: TirePosition) -> Bool {
        // Check if tire pressure is low from API
        let chassis = vehicleStatus.chassis
        switch tire {
        case .frontLeft:
            return chassis.axle.row1.left.tire.pressureLow
        case .frontRight:
            return chassis.axle.row1.right.tire.pressureLow
        case .rearLeft:
            return chassis.axle.row2.left.tire.pressureLow
        case .rearRight:
            return chassis.axle.row2.right.tire.pressureLow
        }
    }
    
    private func startStatusAnimations() {
        if isCharging {
            pulsingElements.insert(.chargingPort)
        }
        
        // Pulse any low tire pressure indicators
        for tire in TirePosition.allCases {
            if isTirePressureLow(for: tire) {
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
        let isOpen = vehicleStatus.isDoorOpen(door)
        let isLocked = vehicleStatus.isDoorLocked(door)
        let hasFault = door == .frunk && vehicleStatus.hasFrunkFault(door)
        
        // Determine status text and color based on door type
        let (statusText, statusColor, statusIndicator): (String, Color, KiaStatusIndicator.Status) = {
            if door == .frunk {
                if hasFault {
                    return ("Fault Detected", KiaDesign.Colors.error, .error("Fault"))
                } else if isOpen {
                    return ("Open", KiaDesign.Colors.warning, .warning("Open"))
                } else {
                    return ("Closed", KiaDesign.Colors.success, .ready)
                }
            } else {
                if isOpen {
                    return ("Open", KiaDesign.Colors.warning, .warning("Open"))
                } else if !isLocked {
                    return ("Closed & Unlocked", KiaDesign.Colors.error, .warning("Unlocked"))
                } else {
                    return ("Closed & Locked", KiaDesign.Colors.success, .ready)
                }
            }
        }()
        
        let doorTitle = door == .frunk ? "Frunk" : door.rawValue + " Door"
        
        return VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: door.systemIcon)
                    .foregroundStyle(KiaDesign.Colors.primary)
                
                Text(doorTitle)
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: statusIndicator)
            }
            
            HStack {
                Text("Status:")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                Spacer()
                
                Text(statusText)
                    .font(KiaDesign.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
            }
            
            // Show frunk-specific information
            if door == .frunk && hasFault {
                HStack {
                    Text("Note:")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("Service Required")
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.error)
                }
            }
        }
    }
    
    private func tireDetailView(for tire: VehicleSilhouetteView.TirePosition) -> some View {
        let pressure = getTirePressure(for: tire)
        let pressureStatus = getTirePressureStatus(for: tire)
        
        return VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                Image(systemName: tire.systemIcon)
                    .foregroundStyle(KiaDesign.Colors.primary)
                
                Text(tire.rawValue + " Tire")
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.semibold)
                
                Spacer()
                
                KiaStatusIndicator(status: pressureStatus)
            }
            
            HStack {
                Text("Pressure:")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(pressure)) \(getPressureUnit())")
                    .font(KiaDesign.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.success)
            }
        }
    }
    
    private func chargingDetailView() -> some View {
        let chargingPower = getChargingPower()
        let remainingTime = getChargingRemainingTime()
        let chargingCurrentLevel = getChargingCurrentLevel()
        
        return VStack(spacing: KiaDesign.Spacing.small) {
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
                // Charging Power
                HStack {
                    Text("Power:")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(chargingPower)
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.charging)
                }
                
                // Remaining Time
                HStack {
                    Text("Time Remaining:")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(remainingTime)
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                }
                
                // Charging Level (AC/DC indicator)
                HStack {
                    Text("Mode:")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(chargingCurrentLevel)
                        .font(KiaDesign.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
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
    
    // MARK: - Tire Pressure Helpers
    
    private func getTirePressure(for tire: VehicleSilhouetteView.TirePosition) -> Double {
        let chassis = vehicleStatus.chassis
        switch tire {
        case .frontLeft:
            return Double(chassis.axle.row1.left.tire.pressure)
        case .frontRight:
            return Double(chassis.axle.row1.right.tire.pressure)
        case .rearLeft:
            return Double(chassis.axle.row2.left.tire.pressure)
        case .rearRight:
            return Double(chassis.axle.row2.right.tire.pressure)
        }
    }
    
    private func getTirePressureStatus(for tire: VehicleSilhouetteView.TirePosition) -> KiaStatusIndicator.Status {
        let chassis = vehicleStatus.chassis
        let isLow: Bool
        
        switch tire {
        case .frontLeft:
            isLow = chassis.axle.row1.left.tire.pressureLow
        case .frontRight:
            isLow = chassis.axle.row1.right.tire.pressureLow
        case .rearLeft:
            isLow = chassis.axle.row2.left.tire.pressureLow
        case .rearRight:
            isLow = chassis.axle.row2.right.tire.pressureLow
        }
        
        return isLow ? .warning("Low") : .normal
    }
    
    private func getPressureUnit() -> String {
        // Get pressure unit from API (0 = PSI, 1 = kPa, 2 = bar)
        let unit = vehicleStatus.chassis.axle.tire.pressureUnit
        switch unit {
        case 0: return "PSI"
        case 1: return "kPa"
        case 2: return "bar"
        default: return "PSI"
        }
    }
    
    // MARK: - Charging Helpers
    
    private func getChargingPower() -> String {
        // Get real-time charging power from API
        let power = vehicleStatus.green.electric.smartGrid.realTimePower
        
        if power > 0 {
            if power >= 1.0 {
                return String(format: "%.1f kW", power)
            } else {
                return String(format: "%.0f W", power * 1000)
            }
        } else {
            return "Not charging"
        }
    }
    
    private func getChargingRemainingTime() -> String {
        // Get remaining charging time from API
        let remainTime = vehicleStatus.green.chargingInformation.charging.remainTime
        let unit = vehicleStatus.green.chargingInformation.charging.remainTimeUnit
        
        if remainTime > 0 {
            let hours = Int(remainTime / 60)
            let minutes = Int(remainTime.truncatingRemainder(dividingBy: 60))
            
            switch unit {
            case .minute:
                if hours > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(minutes)m"
                }
            case .hour:
                // Time is already in hours
                let totalHours = Int(remainTime)
                let remainingMinutes = Int((remainTime - Double(totalHours)) * 60)
                if totalHours > 0 {
                    return "\(totalHours)h \(remainingMinutes)m"
                } else {
                    return "\(remainingMinutes)m"
                }
            case .second:
                // Convert seconds to hours and minutes
                let totalMinutes = Int(remainTime / 60)
                let hours = totalMinutes / 60
                let minutes = totalMinutes % 60
                if hours > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(minutes)m"
                }
            case .microseconds:
                // Convert microseconds to minutes (very unlikely for charging times)
                let totalMinutes = Int(remainTime / 60_000_000)
                if totalMinutes > 0 {
                    return "\(totalMinutes)m"
                } else {
                    return "< 1m"
                }
            }
        } else {
            return "Complete"
        }
    }
    
    private func getChargingCurrentLevel() -> String {
        // Get charging current level from API (AC/DC indicator)
        let currentLevel = vehicleStatus.green.chargingInformation.electricCurrentLevel.state
        
        switch currentLevel {
        case 0:
            return "Not connected"
        case 1:
            return "AC Charging"
        case 2:
            return "DC Fast Charging"
        default:
            return "Unknown"
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if selectedElement == .door(door) && showingDetails {
                            // Toggle off if tapping the same door
                            showingDetails = false
                            selectedElement = nil
                        } else {
                            // Show details for this door
                            selectedElement = .door(door)
                            showingDetails = true
                        }
                    }
                },
                onTireTap: { tire in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if selectedElement == .tire(tire) && showingDetails {
                            // Toggle off if tapping the same tire
                            showingDetails = false
                            selectedElement = nil
                        } else {
                            // Show details for this tire
                            selectedElement = .tire(tire)
                            showingDetails = true
                        }
                    }
                },
                onChargingPortTap: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if selectedElement == .chargingPort && showingDetails {
                            // Toggle off if tapping the charging port again
                            showingDetails = false
                            selectedElement = nil
                        } else {
                            // Show charging details
                            selectedElement = .chargingPort
                            showingDetails = true
                        }
                    }
                }
            )
            .frame(maxWidth: .infinity)
            
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
        .frame(maxWidth: .infinity)
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
            // Static silhouette - standard scenario
            Text("Standard Scenario")
                .font(KiaDesign.Typography.title2)
            
            VehicleSilhouetteView(vehicleStatus: MockVehicleData.standard)
            
            Divider()
            
            // Interactive silhouette - charging scenario
            Text("Charging Scenario (AC)")
                .font(KiaDesign.Typography.title2)
            
            InteractiveVehicleSilhouetteView(vehicleStatus: MockVehicleData.charging)
            
            Divider()
            
            // Fast charging scenario
            Text("Fast Charging Scenario (DC)")
                .font(KiaDesign.Typography.title2)
            
            InteractiveVehicleSilhouetteView(vehicleStatus: MockVehicleData.fastCharging)
            
            Divider()
            
            // Low tire pressure demo
            Text("Low Tire Pressure Demo")
                .font(KiaDesign.Typography.title2)
            
            InteractiveVehicleSilhouetteView(vehicleStatus: MockVehicleData.lowTirePressure)
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}

// MARK: - VehicleStatus Extensions

extension VehicleStatus {
    func isDoorOpen(_ door: VehicleSilhouetteView.DoorPosition) -> Bool {
        let doors = cabin.door
        switch door {
        case .frontLeft:
            return doors.row1.driver.open
        case .frontRight:
            return doors.row1.passenger.open
        case .rearLeft:
            return doors.row2.left.open
        case .rearRight:
            return doors.row2.right.open
        case .trunk:
            // Trunk status not currently available in API
            return false
        case .frunk:
            return body.hood.open
        }
    }
    
    func isDoorLocked(_ door: VehicleSilhouetteView.DoorPosition) -> Bool {
        let doors = cabin.door
        switch door {
        case .frontLeft:
            return !doors.row1.driver.lock // API uses inverted logic (false = locked)
        case .frontRight:
            return !doors.row1.passenger.lock
        case .rearLeft:
            return !doors.row2.left.lock
        case .rearRight:
            return !doors.row2.right.lock
        case .trunk:
            // Trunk lock status not currently available in API
            return true
        case .frunk:
            // Frunk is typically not lockable, consider it "locked" when closed
            return !body.hood.open
        }
    }
    
    func hasFrunkFault(_ door: VehicleSilhouetteView.DoorPosition) -> Bool {
        guard door == .frunk else { return false }
        return body.hood.frunk.fault
    }
}
