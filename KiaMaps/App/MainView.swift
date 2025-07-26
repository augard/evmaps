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
    
    @Environment(\.dismiss) private var dismiss

    enum ViewState {
        case loading
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
        state = .loading
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                MainLoadingView()
                    .task {
                        await loadData()
                    }
            case .authorized:
                contentView
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
                MainErrorView(error: error) {
                    Task {
                        state = .loading
                        await loadData()
                    }
                }
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


    // MARK: - Modern Tesla-Inspired Content View
    
    @ViewBuilder
    var contentView: some View {
        if let selectedVehicle = selectedVehicle, let selectedVehicleStatus = selectedVehicleStatus {
            OverviewPageView(vehicle: selectedVehicle, status: selectedVehicleStatus, isActive: true) {
                await refreshData()
            }
        } else {
            // Vehicle Selection (Pre-Authorization)
            VehicleSelectionView(vehicles: vehicles) {
                await refreshData()
            }
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
    
    
    

    
    // MARK: - Helper Views
    
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
    

    private func loadData() async {
        do {
            if let authorization = Authorization.authorization {
                api.authorization = authorization
            } else {
                // Try to restore login with stored credentials first
                if let storedCredentials = LoginCredentialManager.retrieveCredentials() {
                    let authorization = try await api.login(username: storedCredentials.username, password: storedCredentials.password)
                    Authorization.store(data: authorization)
                } else {
                    // Fallback to configuration credentials (for development/testing)
                    let authorization = try await api.login(username: configuration.username, password: configuration.password)
                    Authorization.store(data: authorization)
                }
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
            state = .error(error)
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
            state = .error(error)
        }
    }

    private func logout() async {
        try? await api.logout()
        Authorization.remove()
        
        // Clear stored login credentials
        LoginCredentialManager.clearCredentials()
        
        // Dismiss to return to root (login screen)
        dismiss()
    }
}
