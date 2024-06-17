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
            case .vehicleNotFound(let vin):
                return "Vehicle with VIN \"\(vin)\" not found."
            }
        }
    }
    
    @State var state: ViewState
    @State var vehicles: [Vehicle] = []
    @State var selectedVehicle: Vehicle? = nil
    @State var selectedVehicleStatus: VehicleStatusResponse? = nil
    
    private let percentNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    init(configuration: AppConfiguration.Type) {
        self.configuration = configuration
        self.api = Api(configuration: configuration.apiConfiguration)
        self.state = Authorization.isAuthorized ? .loading : .unauthorized
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
                contentView
                    .toolbar(content: {
                        ToolbarItem(id: "logout", placement: .topBarTrailing) {
                            Button("Logout", action: {
                                Task {
                                    await logout()
                                }
                            })
                        }
                    })
            case .error(let error):
                errorView(error: error)
            }
        }
        .navigationTitle(api.configuration.name)
    }
    
    var loadingView: some View {
        VStack {
            Text("Loading...")
                .font(.body)
                .multilineTextAlignment(.center)
        }
    }
    
    var loginView: some View {
        HStack(alignment: .center) {
            Button("Login", role: .none, action: { login() })
        }
    }
    
    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, content: {
                Text("Vehicles:")
                    .font(.headline)
                
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(vehicles) { vehicle in
                        vehicleRow(vehicle)
                    }
                }
                .padding(20)
                
                if let selectedVehicle = selectedVehicle, let selectedVehicleStatus = selectedVehicleStatus {
                    Text("Selected Vehicle:")
                        .font(.headline)
                    
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        vehicleRow(selectedVehicle)
                        
                        GridRow {
                            Image(systemName: "ev.charger")
                            HStack {
                                let value = selectedVehicleStatus.state.vehicle.green.batteryManagement.batteryRemain.ratio / 100
                                VStack(alignment: .leading) {
                                    ProgressView(value: value) {
                                        Text("Charge: ") + Text(percentNumberFormatter.string(from: value as NSNumber) ?? "")
                                    }
                                }
                                Spacer()
                            }
                        }
                        GridRow {
                            Image(systemName: "minus.plus.and.fluid.batteryblock")
                            HStack {
                                let value = selectedVehicleStatus.state.vehicle.green.batteryManagement.soH.ratio / 100
                                VStack(alignment: .leading) {
                                    ProgressView(value: value) {
                                        Text("SOH: ") + Text(percentNumberFormatter.string(from: value as NSNumber) ?? "")
                                    }
                                }
                                Spacer()
                            }
                        }
                        
                        GridRow {
                            Image(systemName: "clock")
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Last update: ") + Text(selectedVehicleStatus.lastUpdateTime, style: .relative)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                }
            })
        }
        .padding()
        .refreshable {
            await loadData()
        }
    }
    
    func vehicleRow(_ vehicle: Vehicle) -> some View {
        GridRow {
            Image(systemName: "car")
            HStack {
                VStack(alignment: .leading) {
                    Text(api.configuration.name + " - " + vehicle.nickname + " (" + vehicle.year + ")")
                    
                    Text("VIN: " + vehicle.vin)
                }
                Spacer()
            }
        }
    }
    
    func errorView(error: Error) -> some View {
        HStack {
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
        }
    }
    
    func loadData() async {
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
            
            if let cachedVehicle = cachedCarStatus(cardId: vehicle.vehicleId) {
                self.selectedVehicleStatus = cachedVehicle
            } else {
                let vehicleStatus = try await api.vehicleCachedStatus(vehicle.vehicleId)
                storeCachedCarStatus(carId: vehicle.vehicleId, status: vehicleStatus)
                self.selectedVehicleStatus = vehicleStatus
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
    
    func login() {
        state = .loading
    }
    
    func logout() async {
        try? await api.logout()
        Authorization.remove()
        state = .unauthorized
    }
    
    func cachedCarStatus(cardId: UUID) -> VehicleStatusResponse? {
        guard UserDefaults.standard.string(forKey: "cached-vehicle-id") == cardId.uuidString,
              let cachedDate = UserDefaults.standard.object(forKey: "cached-vehicle-date") as? Date, cachedDate + 2 * 60 > Date.now,
              let cachedData = UserDefaults.standard.data(forKey: "cached-vehicle") else {
            return nil
        }
        return try! JSONDecoders.default.decode(VehicleStatusResponse.self, from: cachedData)
    }
    
    func storeCachedCarStatus(carId: UUID, status: VehicleStatusResponse) {
        guard let statusData = try? JSONEncoders.default.encode(status) else { return }
        UserDefaults.standard.setValue(statusData, forKey: "cached-vehicle")
        UserDefaults.standard.setValue(carId.uuidString, forKey: "cached-vehicle-id")
        UserDefaults.standard.setValue(Date.now, forKey: "cached-vehicle-date")
        UserDefaults.standard.synchronize()
    }
}
