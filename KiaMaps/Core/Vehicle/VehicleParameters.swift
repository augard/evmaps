//
//  VehicleParameters.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import Intents

/// Protocol defining essential parameters for electric vehicle route planning and charging calculations
/// These parameters are used by Apple Maps to provide accurate EV-specific navigation including:
/// - Energy consumption estimation based on speed, elevation, and auxiliary power usage
/// - Charging time calculations at different charging stations
/// - Route planning with charging stops
protocol VehicleParameters {
    /// List of charging connector types supported by this vehicle
    /// Common types include Mennekes (Type 2 AC) and CCS2 (DC fast charging)
    var supportedChargingConnectors: [INCar.ChargingConnectorType] { get }

    /// Returns the maximum charging power in kilowatts for a specific connector type
    /// - Parameter connector: The charging connector type
    /// - Returns: Maximum power in kW, or nil if connector is not supported
    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double?

    /// Maximum driving range in kilometers according to WLTP standard
    /// Used for initial route planning estimations
    var maximumDistance: Double { get }

    /// Unique identifier for the vehicle's energy consumption model
    /// This ID is sent to the server for route calculations
    var consumptionModelId: Int { get }

    /// Energy consumption parameters used to calculate battery usage during driving
    /// Required keys:
    /// - vehicle_auxiliary_power_w: Constant power draw from electronics (Watts)
    /// - vehicle_consumption_values_wh_per_m: Array of 10 consumption values representing different driving efficiency scenarios (Wh/meter)
    ///   Research shows these values correlate with real-world data (e.g., Taycan: 172-258 Wh/km range covers WLTP to Autobahn speeds)
    /// - vehicle_altitude_gain_consumption_wh_per_m: Extra energy for climbing (Wh/meter elevation)
    /// - vehicle_altitude_loss_consumption_wh_per_m: Energy recovered when descending (Wh/meter elevation)
    var consumptionFormulaParameters: [String: Any] { get }

    /// Unique identifier for the vehicle's charging curve model
    /// This ID is sent to the server for charging time calculations
    var chargingModelId: Int { get }

    /// Charging curve parameters that define how the vehicle charges at different battery levels
    /// Required keys:
    /// - vehicle_energy_axis_wh: Array of battery energy levels (Wh)
    /// - vehicle_charge_axis_w: Array of charging power at each energy level (Watts)
    /// - energy_w_per_h: Linear progression for UI display (Wh)
    /// - efficiency_factor: Charging efficiency (0.0-1.0, where 0.9 = 90% efficiency)
    /// - Parameters:
    ///   - maximumBatteryCapacity: Total battery capacity
    ///   - unit: Energy unit for the capacity
    /// - Returns: Dictionary with charging curve data
    func chargingFormulaParameters(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any]

}

extension VehicleParameters {
    /// Creates consumption formula arguments for server API requests
    /// - Returns: Dictionary containing vehicle parameters and model ID for consumption calculations
    func consumptionFormulaArguments() -> [String: Any] {
        [
            "vehicle_parameters": consumptionFormulaParameters,
            "model_id": consumptionModelId,
        ]
    }

    /// Creates charging formula arguments for server API requests
    /// - Parameters:
    ///   - maximumBatteryCapacity: Total battery capacity
    ///   - unit: Energy unit for the capacity
    /// - Returns: Dictionary containing vehicle parameters and model ID for charging calculations
    func chargingFormulaArguments(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any] {
        [
            "vehicle_parameters": chargingFormulaParameters(maximumBatteryCapacity: maximumBatteryCapacity, unit: unit),
            "model_id": chargingModelId,
        ]
    }
}

// MARK: - Sample Data Documentation

/*
 Example consumption model parameters:
     {
         "vehicle_parameters": {
             "vehicle_auxiliary_power_w": 669.9999809265137,
             "vehicle_consumption_values_wh_per_m": [
                 0.2254000186920166,
                 0.18230000734329224,
                 0.19320000410079957,
                 0.21390001773834227,
                 0.1721000075340271,
                 0.1721000075340271,
                 0.18310000896453857,
                 0.2052000045776367,
                 0.2266000032424927,
                 0.25840001106262206
             ],
             "vehicle_altitude_gain_consumption_wh_per_m": 8.345999908447265,
             "vehicle_altitude_loss_consumption_wh_per_m": 6.972999572753906
         },
         "model_id": 12582912
     }

     {
         "vehicle_parameters": {
             "vehicle_energy_axis_wh": [
                 0,
                 34050,
                 34250,
                 37100,
                 37350,
                 39300,
                 39550,
                 41500,
                 41750,
                 43700,
                 43900,
                 46750,
                 46950,
                 49900,
                 50100,
                 52800,
                 53000,
                 54250,
                 54450,
                 58750,
                 58950,
                 61900,
                 62150,
                 68450,
                 68700,
                 77050,
                 77250,
                 78150,
                 79100,
                 80050,
                 80950,
                 81900,
                 82800,
                 83750,
                 84700,
                 85600,
                 86550,
                 87450,
                 88400,
                 89350,
                 90250
             ],
             "energy_w_per_h": [
                 0,
                 3650,
                 7350,
                 11300,
                 15100,
                 18700,
                 22600,
                 26350,
                 30150,
                 34050,
                 37850,
                 41600,
                 45400,
                 49400,
                 53050,
                 57150,
                 60950,
                 64950,
                 68750,
                 72750,
                 77050
             ],
             "vehicle_charge_axis_w": [
                 232000,
                 232000,
                 223000,
                 223000,
                 204000,
                 204000,
                 186000,
                 186000,
                 167000,
                 167000,
                 158000,
                 158000,
                 148000,
                 148000,
                 144000,
                 144000,
                 134000,
                 134000,
                 107000,
                 107000,
                 74000,
                 74000,
                 55000,
                 55000,
                 51000,
                 13000,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0,
                 0
             ],
             "efficiency_factor": 0.8999999761581421
         },
         "model_id": 12582916
     }
     */
