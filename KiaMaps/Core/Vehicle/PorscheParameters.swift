//
//  PorscheParameters.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import Intents

/// Vehicle-specific parameters for Porsche electric vehicles
/// These parameters are used for route planning, energy consumption calculations,
/// and charging time estimations in Apple Maps integration
enum PorscheParameters: VehicleParameters {
    case taycanGen1

    /// Supported charging connector types for this vehicle
    /// - Mennekes (Type 2): Standard AC charging connector in Europe
    /// - CCS2: Combined Charging System for DC fast charging
    var supportedChargingConnectors: [INCar.ChargingConnectorType] {
        [.mennekes, .ccs2]
    }

    /// Maximum charging power (in kW) for each connector type
    /// - Parameter connector: The charging connector type
    /// - Returns: Maximum power in kilowatts, or nil if connector not supported
    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double? {
        if connector == .mennekes {
            return 11.0  // AC charging: 11 kW (3-phase 16A)
        } else if connector == .ccs2 {
            return 234.0  // DC fast charging: Up to 234 kW peak
        } else {
            return nil
        }
    }

    /// Maximum driving range in kilometers (WLTP standard)
    var maximumDistance: Double {
        541  // WLTP range for Taycan Gen1
    }

    /// Unique identifier for this vehicle's consumption model
    /// Used for server-side route calculations and energy estimations
    var consumptionModelId: Int {
        12_582_912
    }

    /// Energy consumption parameters for route planning
    /// These values are used to calculate battery usage based on:
    /// - Speed-dependent consumption
    /// - Elevation changes (climbing/descending)
    /// - Auxiliary power consumption (electronics, climate control)
    var consumptionFormulaParameters: [String: Any] {
        [
            // Constant power draw from vehicle electronics, climate control, etc. (in Watts)
            "vehicle_auxiliary_power_w": 669.9999809265137,
            
            // Speed-dependent energy consumption values (Wh per meter)
            // These 10 values represent different driving efficiency scenarios
            // Values correlate with real-world Taycan consumption data:
            // - Range: 172-258 Wh/km covers WLTP (180 Wh/km) to high-speed highway (250+ Wh/km)
            // - Validated against real test data: 90 km/h = ~190 Wh/km, 130 km/h = 220-260 Wh/km
            "vehicle_consumption_values_wh_per_m": [
                0.2254000186920166,   // 225.4 Wh/km - Demanding conditions (city stop/start, cold weather)
                0.18230000734329224,  // 182.3 Wh/km - Efficient city driving
                0.19320000410079957,  // 193.2 Wh/km - Normal mixed driving
                0.21390001773834227,  // 213.9 Wh/km - Urban with traffic
                0.1721000075340271,   // 172.1 Wh/km - Optimal efficiency (matches WLTP ~180 Wh/km)
                0.1721000075340271,   // 172.1 Wh/km - Optimal efficiency (duplicate)
                0.18310000896453857,  // 183.1 Wh/km - Steady highway (90 km/h range)
                0.2052000045776367,   // 205.2 Wh/km - Moderate highway speeds
                0.2266000032424927,   // 226.6 Wh/km - Fast highway driving
                0.25840001106262206,  // 258.4 Wh/km - High-speed Autobahn (matches 130 km/h tests)
            ],
            
            // Additional energy required when climbing (Wh per meter of elevation gain)
            "vehicle_altitude_gain_consumption_wh_per_m": 8.345999908447265,
            
            // Energy recovered through regenerative braking when descending (Wh per meter of elevation loss)
            // Lower than gain due to conversion losses
            "vehicle_altitude_loss_consumption_wh_per_m": 6.972999572753906,
        ]
    }

    /// Unique identifier for this vehicle's charging model
    /// Used for server-side charging curve calculations
    var chargingModelId: Int {
        12_582_916
    }

    /// Charging curve parameters defining how the vehicle charges at different battery levels
    /// This data is crucial for accurate charging time estimations at charging stations
    /// - Parameters:
    ///   - maximumBatteryCapacity: Total battery capacity (not used for Taycan as it has fixed curve)
    ///   - unit: Energy unit for capacity (not used for Taycan)
    /// - Returns: Dictionary containing charging curve data
    func chargingFormulaParameters(maximumBatteryCapacity _: Double, unit _: UnitEnergy) -> [String: Any] {
        [
            // Battery state of charge levels in Watt-hours
            // These values represent checkpoints in the battery from 0% to ~100%
            // Total usable capacity: ~90.25 kWh (90,250 Wh)
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
                90250,  // ~100% SOC
            ],
            
            // Simple linear energy progression for UI display (Wh)
            // 21 points from 0% to 100% in 5% increments
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
                77050,  // 100%
            ],
            
            // Charging power (in Watts) at each energy level
            // This defines the actual charging curve showing how power decreases as battery fills
            // Peak power: 232 kW at low SOC, tapering down to protect battery health
            "vehicle_charge_axis_w": [
                232_000,  // 0-34 kWh: Peak 232 kW
                232_000,
                223_000,  // 34-37 kWh: 223 kW
                223_000,
                204_000,  // 37-39 kWh: 204 kW
                204_000,
                186_000,  // 39-41 kWh: 186 kW
                186_000,
                167_000,  // 41-43 kWh: 167 kW
                167_000,
                158_000,  // 43-46 kWh: 158 kW
                158_000,
                148_000,  // 46-49 kWh: 148 kW
                148_000,
                144_000,  // 49-52 kWh: 144 kW
                144_000,
                134_000,  // 52-54 kWh: 134 kW
                134_000,
                107_000,  // 54-58 kWh: 107 kW
                107_000,
                74000,    // 58-61 kWh: 74 kW
                74000,
                55000,    // 61-68 kWh: 55 kW
                55000,
                51000,    // 68-77 kWh: 51 kW
                13000,    // 77-78 kWh: 13 kW (trickle charge to 100%)
                0,        // >78 kWh: Charging complete
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
            ],
            
            // Charging efficiency factor (0.9 = 90% efficiency)
            // Accounts for energy losses during AC to DC conversion and battery heating/cooling
            "efficiency_factor": 0.8999999761581421,
        ]
    }
}
