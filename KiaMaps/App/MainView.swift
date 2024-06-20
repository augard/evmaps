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

    private let percentNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()

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
            case let .error(error):
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
        List {
            Section {
                vehiclesView
            }

            Section {
                selectedVehicleView
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshData()
        }
    }

    var vehiclesView: some View {
        DisclosureGroup("Vehicles") {
            ForEach(vehicles) { vehicle in
                vehicleRow(vehicle)
            }
        }
    }

    @ViewBuilder
    var selectedVehicleView: some View {
        if let selectedVehicle = selectedVehicle, let selectedVehicleStatus = selectedVehicleStatus {
            DisclosureGroup("Selected vehicle", isExpanded: $isSelectedVahicleExpanded) {
                vehicleRow(selectedVehicle)

                VStack(alignment: .leading) {
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

                VStack(alignment: .leading) {
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

                VStack(alignment: .leading) {
                    Image(systemName: "clock")
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Last update: ") + Text(selectedVehicleStatus.lastUpdateTime, style: .relative)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    func vehicleRow(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading) {
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

    func refreshData() async {
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

    func login() {
        state = .loading
    }

    func logout() async {
        try? await api.logout()
        Authorization.remove()
        state = .unauthorized
    }
}
