//
//  VehicleManager.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

final class SharedVehicleManager: ObservableObject {
    static let shared = SharedVehicleManager()
    
    // Global selected vehicle VIN for sharing with extensions
    @Published var selectedVehicleVIN: String? {
        didSet {
            UserDefaults.standard.set(selectedVehicleVIN, forKey: "selectedVehicleVIN")
        }
    }
    
    private init() {
        // Load selected VIN from UserDefaults
        selectedVehicleVIN = UserDefaults.standard.string(forKey: "selectedVehicleVIN")
    }
    
    /// Gets vehicle manager for a specific vehicle
    func manager(for vehicleID: UUID) -> VehicleManager {
        VehicleManager(id: vehicleID)
    }
}

struct VehicleManager {
    let id: UUID

    private enum CacheKey: String {
        case vehicleType
        case vehicleStatus
        case vehicleLastUpdateDate
    }

    var vehicleParamter: VehicleParameters {
        guard let type = stringValue(for: .vehicleType) else {
            return PorscheParameters.taycanGen1
        }
        switch type {
        case "Kia-EV9":
            return KiaParameters.ev9
        default:
            return PorscheParameters.taycanGen1
        }
    }

    var vehicleStatus: VehicleStatusResponse? {
        get throws {
            guard let lastUpdate = dateValue(for: .vehicleLastUpdateDate), lastUpdate + 2 * 60 > Date.now,
                  let cachedStatus: VehicleStatusResponse = try value(for: .vehicleStatus)
            else {
                return nil
            }
            return cachedStatus
        }
    }

    func store(type: String) {
        setValue(with: .vehicleType, value: type)
        UserDefaults.standard.synchronize()
    }

    func store(status: VehicleStatusResponse) throws {
        try setValue(with: .vehicleStatus, encodable: status)
        setValue(with: .vehicleLastUpdateDate, value: Date.now)
        UserDefaults.standard.synchronize()
    }

    func removeLastUpdateDate() {
        setValue(with: .vehicleLastUpdateDate, value: Date.distantPast)
    }

    func restoreOutdatedData() {
        setValue(with: .vehicleLastUpdateDate, value: Date.now)
    }

    private func setValue(with key: CacheKey, value: Any) {
        UserDefaults.standard.setValue(value, forKey: vehicleKey(key))
    }

    private func setValue(with key: CacheKey, encodable: Encodable) throws {
        try UserDefaults.standard.setValue(JSONEncoders.default.encode(encodable), forKey: vehicleKey(key))
    }

    private func dateValue(for key: CacheKey) -> Date? {
        UserDefaults.standard.object(forKey: vehicleKey(key)) as? Date
    }

    private func stringValue(for key: CacheKey) -> String? {
        UserDefaults.standard.string(forKey: vehicleKey(key))
    }

    private func value<Object: Decodable>(for key: CacheKey) throws -> Object? {
        guard let data = dataValue(for: key) else { return nil }
        return try JSONDecoders.default.decode(Object.self, from: data)
    }

    private func dataValue(for key: CacheKey) -> Data? {
        UserDefaults.standard.data(forKey: vehicleKey(key))
    }

    private func vehicleKey(_ key: CacheKey) -> String {
        key.rawValue + "-" + id.uuidString
    }
}
