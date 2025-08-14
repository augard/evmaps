//
//  VehicleManager.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

/// Singleton manager for coordinating vehicle selection across the app and extensions
/// Provides shared access to the currently selected vehicle VIN
final class SharedVehicleManager: ObservableObject {
    /// Shared instance for app-wide access
    static let shared = SharedVehicleManager()
    
    /// Currently selected vehicle VIN, synchronized with UserDefaults for extension access
    @Published var selectedVehicleVIN: String? {
        didSet {
            UserDefaults.standard.set(selectedVehicleVIN, forKey: "selectedVehicleVIN")
        }
    }
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Load selected VIN from UserDefaults
        selectedVehicleVIN = UserDefaults.standard.string(forKey: "selectedVehicleVIN")
    }
    
    /// Creates a VehicleManager instance for a specific vehicle
    /// - Parameter vehicleID: Unique identifier for the vehicle
    /// - Returns: VehicleManager configured for the specified vehicle
    func manager(for vehicleID: UUID) -> VehicleManager {
        VehicleManager(id: vehicleID)
    }
}

/// Manages vehicle-specific data caching and retrieval using UserDefaults
/// Handles vehicle status caching with automatic expiration and type-specific parameters
struct VehicleManager {
    /// Unique identifier for this vehicle
    let id: UUID

    /// Keys used for caching vehicle data in UserDefaults
    private enum CacheKey: String {
        /// Vehicle type identifier (e.g., "Kia-EV9")
        case vehicleType
        /// Cached vehicle status response
        case vehicleStatus
        /// Timestamp of last status update
        case vehicleLastUpdateDate
    }

    /// Returns vehicle-specific parameters based on stored vehicle type
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

    /// Retrieves cached vehicle status if it's still valid (within 2 minutes)
    /// - Returns: Cached VehicleStatusResponse if valid, nil if expired or not found
    /// - Throws: Decoding errors if cached data is corrupted
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

    /// Stores the vehicle type identifier for parameter lookup
    /// - Parameter type: Vehicle type string (e.g., "Kia-EV9")
    func store(type: String) {
        setValue(with: .vehicleType, value: type)
        UserDefaults.standard.synchronize()
    }

    /// Stores vehicle status response with current timestamp
    /// - Parameter status: VehicleStatusResponse to cache
    /// - Throws: Encoding errors if status cannot be serialized
    func store(status: VehicleStatusResponse) throws {
        try setValue(with: .vehicleStatus, encodable: status)
        setValue(with: .vehicleLastUpdateDate, value: Date.now)
        UserDefaults.standard.synchronize()
    }

    /// Marks cached data as expired by setting update date to distant past
    func removeLastUpdateDate() {
        setValue(with: .vehicleLastUpdateDate, value: Date.distantPast)
    }

    /// Marks cached data as fresh by updating the timestamp to now
    func restoreOutdatedData() {
        setValue(with: .vehicleLastUpdateDate, value: Date.now)
    }

    /// Stores a value in UserDefaults using vehicle-specific key
    /// - Parameters:
    ///   - key: The cache key to store under
    ///   - value: The value to store
    private func setValue(with key: CacheKey, value: Any) {
        UserDefaults.standard.setValue(value, forKey: vehicleKey(key))
    }

    /// Encodes and stores a Codable object in UserDefaults
    /// - Parameters:
    ///   - key: The cache key to store under
    ///   - encodable: The Codable object to encode and store
    /// - Throws: Encoding errors if object cannot be serialized
    private func setValue(with key: CacheKey, encodable: Encodable) throws {
        try UserDefaults.standard.setValue(JSONEncoders.default.encode(encodable), forKey: vehicleKey(key))
    }

    /// Retrieves a Date value from UserDefaults
    /// - Parameter key: The cache key to retrieve
    /// - Returns: Date value or nil if not found or wrong type
    private func dateValue(for key: CacheKey) -> Date? {
        UserDefaults.standard.object(forKey: vehicleKey(key)) as? Date
    }

    /// Retrieves a String value from UserDefaults
    /// - Parameter key: The cache key to retrieve
    /// - Returns: String value or nil if not found
    private func stringValue(for key: CacheKey) -> String? {
        UserDefaults.standard.string(forKey: vehicleKey(key))
    }

    /// Decodes a Codable object from UserDefaults data
    /// - Parameter key: The cache key to retrieve and decode
    /// - Returns: Decoded object of type Object or nil if not found
    /// - Throws: Decoding errors if data cannot be deserialized
    private func value<Object: Decodable>(for key: CacheKey) throws -> Object? {
        guard let data = dataValue(for: key) else { return nil }
        return try JSONDecoders.default.decode(Object.self, from: data)
    }

    /// Retrieves raw Data from UserDefaults
    /// - Parameter key: The cache key to retrieve
    /// - Returns: Data value or nil if not found
    private func dataValue(for key: CacheKey) -> Data? {
        UserDefaults.standard.data(forKey: vehicleKey(key))
    }

    /// Generates a vehicle-specific key by combining the cache key with vehicle ID
    /// - Parameter key: The base cache key
    /// - Returns: Unique key string for this vehicle and cache key combination
    private func vehicleKey(_ key: CacheKey) -> String {
        key.rawValue + "-" + id.uuidString
    }
}
