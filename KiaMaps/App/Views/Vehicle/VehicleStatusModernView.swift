import SwiftUI

/// Tesla-inspired modern vehicle status view integrating all new design components
struct VehicleStatusModernView: View {
    let vehicle: Vehicle
    let vehicleStatus: VehicleStatusResponse
    let lastUpdateTime: Date
    
    @State private var refreshing = false
    @State private var selectedSection: Section = .overview
    
    enum Section: String, CaseIterable {
        case overview = "Overview"
        case details = "Details" 
        case controls = "Controls"
        
        var icon: String {
            switch self {
            case .overview: return "gauge"
            case .details: return "list.bullet"
            case .controls: return "slider.horizontal.3"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: KiaDesign.Spacing.large) {
                // Vehicle Header
                vehicleHeaderSection
                
                // Battery Hero Section
                BatteryHeroView(from: vehicleStatus)
                
                // Quick Actions
                KiaCard(elevation: .medium) {
                    QuickActionsView(
                        vehicleStatus: vehicleStatus,
                        onLockAction: { handleLockAction() },
                        onClimateAction: { handleClimateAction() },
                        onHornAction: { handleHornAction() },
                        onLocateAction: { handleLocateAction() }
                    )
                }
                
                // Section Switcher
                sectionSwitcher
                
                // Dynamic Content Based on Selected Section
                Group {
                    switch selectedSection {
                    case .overview:
                        overviewSection
                    case .details:
                        detailsSection
                    case .controls:
                        controlsSection
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedSection)
            }
            .padding(.horizontal, KiaDesign.Spacing.medium)
            .padding(.bottom, KiaDesign.Spacing.xl)
        }
        .background(KiaDesign.Colors.background)
        .navigationBarHidden(true)
        .refreshable {
            await refreshVehicleStatus()
        }
    }
    
    // MARK: - Header Section
    
    private var vehicleHeaderSection: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.nickname)
                        .font(KiaDesign.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("EV9 GT-Line • 2024")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                // Status indicators
                HStack(spacing: KiaDesign.Spacing.small) {
                    KiaStatusIndicator(
                        status: vehicleStatus.state.vehicle.drivingReady ? .ready : .warning("Not Ready")
                    )
                    
                    if vehicleStatus.state.vehicle.green.batteryManagement.batteryRemain.ratio > 80 {
                        KiaStatusIndicator(
                            status: .charging
                        )
                    }
                }
            }
            
            // Last update info
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
                
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: lastUpdateTime, relativeTo: Date()))")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
                
                Spacer()
                
                if refreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding(.top, KiaDesign.Spacing.medium)
    }
    
    // MARK: - Section Switcher
    
    private var sectionSwitcher: some View {
        KiaCard(elevation: .low) {
            HStack(spacing: 0) {
                ForEach(Section.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: KiaDesign.Spacing.small) {
                            Image(systemName: section.icon)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(section.rawValue)
                                .font(KiaDesign.Typography.body)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(
                            selectedSection == section ? 
                            KiaDesign.Colors.primary : KiaDesign.Colors.textSecondary
                        )
                        .padding(.vertical, KiaDesign.Spacing.small)
                        .padding(.horizontal, KiaDesign.Spacing.medium)
                        .background(
                            selectedSection == section ? 
                            KiaDesign.Colors.primary.opacity(0.1) : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium))
                    }
                    
                    if section != Section.allCases.last {
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // Vehicle Status Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: KiaDesign.Spacing.medium) {
                statusCard(
                    icon: "speedometer",
                    title: "Range",
                    value: "\(Int(vehicleStatus.state.vehicle.green.batteryManagement.batteryRemain.ratio * 3)) km",
                    color: KiaDesign.Colors.primary
                )
                
                statusCard(
                    icon: "gauge.high",
                    title: "Efficiency",
                    value: "4.2 km/kWh",
                    color: KiaDesign.Colors.success
                )
                
                statusCard(
                    icon: "thermometer",
                    title: "Temperature",
                    value: "22°C",
                    color: KiaDesign.Colors.accent
                )
                
                statusCard(
                    icon: "location",
                    title: "Location",
                    value: "Updated now",
                    color: KiaDesign.Colors.textSecondary
                )
            }
            
            // Battery Progress Bar
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Battery Status")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    KiaProgressBar(
                        value: Double(vehicleStatus.state.vehicle.green.batteryManagement.batteryRemain.ratio) / 100.0,
                        style: .battery,
                        showPercentage: true
                    )
                }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // Doors & Windows
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Doors & Windows")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: KiaDesign.Spacing.small) {
                        doorStatusItem("Driver Door", false)
                        doorStatusItem("Passenger Door", false)
                        doorStatusItem("Rear Left Door", false)
                        doorStatusItem("Rear Right Door", false)
                    }
                }
            }
            
            // Tire Pressure
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Tire Pressure")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: KiaDesign.Spacing.small) {
                        tireStatusItem("Front Left", 32.0)
                        tireStatusItem("Front Right", 32.5)
                        tireStatusItem("Rear Left", 31.8)
                        tireStatusItem("Rear Right", 32.2)
                    }
                }
            }
        }
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // Climate Controls
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Climate Control")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    KiaSlider(
                        value: .constant(22.0),
                        in: 16...30,
                        step: 0.5,
                        style: .temperature
                    )
                }
            }
            
            // Remote Controls
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Remote Functions")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    VStack(spacing: KiaDesign.Spacing.small) {
                        remoteControlButton("Start Remote Climate", icon: "snow", action: {})
                        remoteControlButton("Flash Lights", icon: "lightbulb", action: {})
                        remoteControlButton("Lock All Doors", icon: "lock.fill", action: {})
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statusCard(icon: String, title: String, value: String, color: Color) -> some View {
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
                    
                    Text(title)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
            }
            .padding(.vertical, KiaDesign.Spacing.small)
        }
    }
    
    private func doorStatusItem(_ label: String, _ isOpen: Bool) -> some View {
        HStack {
            Image(systemName: isOpen ? "door.left.hand.open" : "door.left.hand.closed")
                .foregroundStyle(isOpen ? KiaDesign.Colors.warning : KiaDesign.Colors.success)
            
            Text(label)
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(isOpen ? "Open" : "Closed")
                .font(KiaDesign.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(isOpen ? KiaDesign.Colors.warning : KiaDesign.Colors.textPrimary)
        }
    }
    
    private func tireStatusItem(_ label: String, _ pressure: Double) -> some View {
        HStack {
            Image(systemName: pressure > 30 ? "circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(pressure > 30 ? KiaDesign.Colors.success : KiaDesign.Colors.warning)
            
            Text(label)
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text("\(Int(pressure)) PSI")
                .font(KiaDesign.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
        }
    }
    
    private func remoteControlButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        KiaButton(title, icon: icon, style: .secondary, action: action)
    }
    
    // MARK: - Actions
    
    private func handleLockAction() {
        print("Lock vehicle action")
    }
    
    private func handleClimateAction() {
        print("Climate control action")
    }
    
    private func handleHornAction() {
        print("Horn and lights action")
    }
    
    private func handleLocateAction() {
        print("Locate vehicle action")
    }
    
    private func refreshVehicleStatus() async {
        refreshing = true
        
        // Simulate network request
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        refreshing = false
    }
}

// MARK: - Preview
#Preview("Modern Vehicle Status - Standard") {
    VehicleStatusModernView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleStatus: MockVehicleData.standardResponse,
        lastUpdateTime: Date().addingTimeInterval(-300) // 5 minutes ago
    )
}

#Preview("Modern Vehicle Status - Charging") {
    VehicleStatusModernView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleStatus: MockVehicleData.chargingResponse,
        lastUpdateTime: Date().addingTimeInterval(-60) // 1 minute ago
    )
}

#Preview("Modern Vehicle Status - Low Battery") {
    VehicleStatusModernView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleStatus: MockVehicleData.lowBatteryResponse,
        lastUpdateTime: Date().addingTimeInterval(-1200) // 20 minutes ago
    )
}