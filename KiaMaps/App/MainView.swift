//
//  MainView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 29.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import SwiftUI

struct MainView: View {
    let configuration: AppConfiguration.Type
    var api: Api

    enum ViewState {
        case loading
        case unauthorized
        case authorized
        case error(Error)
    }

    enum ViewError: Error {
        case noVehicles
        case vehicleNotFound(String)

        var description: String {
            switch self {
            case .noVehicles:
                return "No vehicles in account."
            case let .vehicleNotFound(vin):
                return "Vehicle with VIN \"\(vin)\" not found."
            }
        }
    }

    @State var state: ViewState
    @State var vehicles: [Vehicle] = []
    @State var selectedVehicle: Vehicle? = nil
    @State var selectedVehicleStatus: VehicleStatusResponse? = nil
    @State var isSelectedVahicleExpanded = true
    @State var lastUpdateDate: Date?
    @State var showingProfile = false

    init(configuration: AppConfiguration.Type) {
        self.configuration = configuration
        api = Api(configuration: configuration.apiConfiguration)
        state = Authorization.isAuthorized ? .loading : .unauthorized
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                loadingView
                    .task {
                        await loadData()
                    }
            case .unauthorized:
                loginView
            case .authorized:
                modernContentView
                    .toolbar(content: {
                        ToolbarItem(id: "profile", placement: .topBarLeading) {
                            Button(action: {
                                showingProfile = true
                            }) {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                                    .foregroundStyle(KiaDesign.Colors.primary)
                            }
                        }
                        
                        // Enhanced vehicle status in toolbar when vehicle is selected
                        if selectedVehicle != nil, let selectedVehicleStatus = selectedVehicleStatus {
                            ToolbarItem(placement: .topBarTrailing) {
                                vehicleStatusIcons(status: selectedVehicleStatus)
                            }
                        }
                    })
            case let .error(error):
                errorView(error: error)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(KiaDesign.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingProfile) {
            UserProfileView(api: api)
        }
    }

    // MARK: - Tesla-Inspired Loading View
    
    var loadingView: some View {
        KiaLoadingView(
            message: "Loading",
            submessage: "Connecting to your vehicle"
        )
    }

    var loginView: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Brand icon/logo area
            Image(systemName: "car.circle.fill")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(KiaDesign.Colors.primary)
            
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Welcome to KiaMaps")
                    .font(KiaDesign.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("Connect to your vehicle to get started")
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            KiaButton(
                "Connect Vehicle",
                icon: "car.circle",
                style: .primary,
                size: .large
            ) {
                login()
            }
            .accessibilityLabel("Connect your vehicle")
            .accessibilityHint("Tap to log in with your vehicle account credentials")
        }
        .padding(KiaDesign.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiaDesign.Colors.background)
    }

    // MARK: - Modern Tesla-Inspired Content View
    
    var modernContentView: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: KiaDesign.Spacing.xl) {
                if let selectedVehicle = selectedVehicle, let selectedVehicleStatus = selectedVehicleStatus {
                    // Hero Battery Section
                    batteryHeroSection(vehicle: selectedVehicle, status: selectedVehicleStatus)
                    
                    // Quick Actions
                    quickActionsSection(status: selectedVehicleStatus)
                    
                    // Vehicle Status Grid
                    vehicleStatusGrid(status: selectedVehicleStatus)
                    
                    // Vehicle Details Card
                    vehicleDetailsCard(vehicle: selectedVehicle)
                } else {
                    // Vehicle Selection
                    vehicleSelectionSection
                }
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Vehicle Status Icons (for toolbar)
    
    private func vehicleStatusIcons(status: VehicleStatusResponse) -> some View {
        HStack(spacing: KiaDesign.Spacing.small) {
            // Last update indicator
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
                
                Text(timeAgoString(from: status.lastUpdateTime))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
            }
            
            // Battery status
            let batteryLevel = status.state.vehicle.green.batteryManagement.batteryRemain.ratio
            VStack(spacing: 2) {
                if batteryLevel > 80 {
                    Image(systemName: "battery.100percent")
                        .font(.caption)
                        .foregroundStyle(KiaDesign.Colors.success)
                } else if batteryLevel < 20 {
                    Image(systemName: "battery.25")
                        .font(.caption)
                        .foregroundStyle(KiaDesign.Colors.warning)
                } else {
                    Image(systemName: "battery.75")
                        .font(.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Text("\(Int(batteryLevel))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
            
            // Charging status (if applicable)
            if status.state.vehicle.isCharging {
                VStack(spacing: 2) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.caption)
                        .foregroundStyle(KiaDesign.Colors.charging)
                    
                    Text("Charging")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(KiaDesign.Colors.charging)
                }
            }
        }
        .padding(.horizontal, KiaDesign.Spacing.small)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(KiaDesign.Colors.cardBackground)
                .opacity(0.7)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vehicle status: \(Int(status.state.vehicle.green.batteryManagement.batteryRemain.ratio))% battery, \(status.state.vehicle.drivingReady ? "ready" : "not ready"), updated \(timeAgoString(from: status.lastUpdateTime))")
    }
    
    // MARK: - Battery Hero Section
    
    private func batteryHeroSection(vehicle: Vehicle, status: VehicleStatusResponse) -> some View {
        BatteryHeroView(from: status)
    }
    
    // MARK: - Quick Actions Section
    
    private func quickActionsSection(status: VehicleStatusResponse) -> some View {
        KiaCard {
            QuickActionsView(
                vehicleStatus: status,
                onLockAction: {
                    // Lock vehicle action
                },
                onClimateAction: {
                    // Climate control action
                },
                onHornAction: {
                    // Horn and lights action
                },
                onLocateAction: {
                    // Locate vehicle action
                }
            )
        }
    }
    
    // MARK: - Vehicle Status Grid
    
    private func vehicleStatusGrid(status: VehicleStatusResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.medium) {
            // Doors Status - using the available lock data from cabin
            let row1 = status.state.vehicle.cabin.door.row1
            let row2 = status.state.vehicle.cabin.door.row2
            let doorsLocked = !row1.driver.lock && !row1.passenger.lock && !row2.left.lock && !row2.right.lock
            
            statusCard(
                icon: "car.side.lock.fill",
                title: "Doors",
                value: doorsLocked ? "Locked" : "Unlocked",
                color: doorsLocked ? KiaDesign.Colors.success : KiaDesign.Colors.warning
            )
            
            // Driving Ready Status
            statusCard(
                icon: "power",
                title: "Ready",
                value: status.state.vehicle.drivingReady ? "Ready" : "Off",
                color: status.state.vehicle.drivingReady ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary
            )
            
            // Battery Health
            let batteryHealth = status.state.vehicle.green.batteryManagement.soH.ratio / 100.0
            statusCard(
                icon: "battery.100",
                title: "Health",
                value: "\(Int(batteryHealth * 100))%",
                color: batteryHealth > 0.9 ? KiaDesign.Colors.success : 
                       batteryHealth > 0.8 ? KiaDesign.Colors.warning : KiaDesign.Colors.error
            )
            
            // Last Update
            statusCard(
                icon: "clock.fill",
                title: "Updated",
                value: timeAgoString(from: status.lastUpdateTime),
                color: KiaDesign.Colors.textSecondary
            )
        }
    }
    
    // MARK: - Vehicle Selection Section
    
    private var vehicleSelectionSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.large) {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Your Vehicles")
                        .font(KiaDesign.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("Select a vehicle to view its status and controls")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                LazyVStack(spacing: KiaDesign.Spacing.medium) {
                    ForEach(vehicles) { vehicle in
                        modernVehicleRow(vehicle)
                    }
                }
            }
        }
    }
    
    // MARK: - Vehicle Details Card
    
    private func vehicleDetailsCard(vehicle: Vehicle) -> some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Vehicle Information")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    vehicleDetailRow(
                        icon: "car.fill",
                        title: "Model",
                        value: "\(vehicle.nickname) (\(vehicle.year))"
                    )
                    
                    vehicleDetailRow(
                        icon: "barcode",
                        title: "VIN",
                        value: vehicle.vin
                    )
                    
                    vehicleDetailRow(
                        icon: "tag.fill",
                        title: "Brand",
                        value: api.configuration.name
                    )
                }
            }
        }
    }

    // MARK: - Helper Views
    
    private func statusCard(icon: String, title: String, value: String, color: Color) -> some View {
        KiaCard {
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, KiaDesign.Spacing.small)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
    
    private func modernVehicleRow(_ vehicle: Vehicle) -> some View {
        Button(action: {
            // Vehicle selection would go here - keeping existing logic
            UISelectionFeedbackGenerator().selectionChanged()
        }) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                // Vehicle icon
                ZStack {
                    Circle()
                        .fill(KiaDesign.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(KiaDesign.Colors.primary)
                }
                
                // Vehicle details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vehicle.nickname) (\(vehicle.year))")
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("VIN: \(vehicle.vin)")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
            }
            .padding(KiaDesign.Spacing.medium)
            .background(KiaDesign.Colors.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
    
    private func vehicleDetailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: KiaDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(KiaDesign.Typography.body)
                .fontWeight(.medium)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var navigationTitle: String {
        switch state {
        case .authorized:
            if let vehicle = selectedVehicle {
                return vehicle.nickname
            }
            return api.configuration.name
        default:
            return api.configuration.name
        }
    }
    
    func errorView(error: Error) -> some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Error icon
            ZStack {
                Circle()
                    .fill(KiaDesign.Colors.error.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.error)
            }
            
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Connection Error")
                    .font(KiaDesign.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text(error.localizedDescription)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            KiaButton(
                "Retry Connection",
                icon: "arrow.clockwise",
                style: .primary,
                size: .large
            ) {
                Task {
                    state = .loading
                    await loadData()
                }
            }
        }
        .padding(KiaDesign.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiaDesign.Colors.background)
    }

    private func loadData() async {
        do {
            if let authorization = Authorization.authorization {
                api.authorization = authorization
            } else {
                let authorization = try await api.login(username: configuration.username, password: configuration.password)
                Authorization.store(data: authorization)
            }

            // let profile = try await api.profile()
            vehicles = try await api.vehicles().vehicles
            let selectedVehicle = vehicles.vehicle(with: configuration.vehicleVin) ?? vehicles.first

            guard !vehicles.isEmpty else {
                state = .error(ViewError.noVehicles)
                return
            }
            guard let vehicle = selectedVehicle else {
                state = .error(ViewError.vehicleNotFound(configuration.vehicleVin ?? "none"))
                return
            }
            self.selectedVehicle = vehicle
            let manager = VehicleManager(id: vehicle.vehicleId)
            manager.store(type: configuration.apiConfiguration.name + "-" + vehicle.detailInfo.saleCarmdlEnName)

            if let cachedVehicle = try? manager.vehicleStatus {
                selectedVehicleStatus = cachedVehicle
            } else {
                let vehicleStatus = try await api.vehicleCachedStatus(vehicle.vehicleId)
                try manager.store(status: vehicleStatus)
                selectedVehicleStatus = vehicleStatus
            }

            state = .authorized
        } catch {
            if let error = error as? ApiError, case .unauthorized = error {
                await logout()
            } else {
                state = .error(error)
            }
        }
    }

    private func refreshData() async {
        do {
            guard let selectedVehicle = selectedVehicle, let selectedVehicleStatus = selectedVehicleStatus else { return }

            if let lastUpdateDate = lastUpdateDate {
                await loadData()
                if lastUpdateDate < selectedVehicleStatus.lastUpdateTime {
                    self.lastUpdateDate = nil
                    print("Updated")
                }
            } else {
                _ = try await api.refreshVehicle(selectedVehicle.vehicleId)
                lastUpdateDate = selectedVehicleStatus.lastUpdateTime
            }
            let manager = VehicleManager(id: selectedVehicle.vehicleId)
            manager.deleteStatus()
        } catch {
            if let error = error as? ApiError, case .unauthorized = error {
                await logout()
            } else {
                state = .error(error)
            }
        }
    }

    private func login() {
        state = .loading
    }

    private func logout() async {
        try? await api.logout()
        Authorization.remove()
        state = .unauthorized
    }
}
