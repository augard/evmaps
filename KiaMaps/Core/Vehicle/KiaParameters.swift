//
//  KiaParameters.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import Intents

/// Vehicle-specific parameters for Kia electric vehicles
/// These parameters are used for route planning, energy consumption calculations,
/// and charging time estimations in Apple Maps integration
enum KiaParameters: String, VehicleParameters {
    case ev9 = "Kia - EV9"

    /// Maximum charging power (in kW) for each connector type
    /// - Parameter connector: The charging connector type
    /// - Returns: Maximum power in kilowatts, or nil if connector not supported
    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double? {
        if connector == .mennekes {
            return 11.0  // AC charging: 11 kW (3-phase 16A)
        } else if connector == .ccs2 {
            return 234.0  // DC fast charging: Up to 234 kW peak (E-GMP platform)
        } else {
            return nil
        }
    }

    /// Supported charging connector types for this vehicle
    /// - Mennekes (Type 2): Standard AC charging connector in Europe
    /// - CCS2: Combined Charging System for DC fast charging
    var supportedChargingConnectors: [INCar.ChargingConnectorType] {
        [.mennekes, .ccs2]
    }

    /// Maximum driving range in kilometers (WLTP standard)
    var maximumDistance: Double {
        541  // WLTP range for EV9 AWD Long Range
    }

    /// Unique identifier for this vehicle's consumption model
    /// Used for server-side route calculations and energy estimations
    var consumptionModelId: Int {
        12_582_912  // Currently using same model as Taycan (to be updated)
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
            // Array represents consumption at different speed ranges (10 speed bands)
            // Lower values = more efficient, typically optimized for middle speeds
            // Note: Currently using Taycan values - should be updated for EV9
            "vehicle_consumption_values_wh_per_m": [
                0.2254000186920166,   // Very low speed (city traffic)
                0.18230000734329224,  // Low speed
                0.19320000410079957,  // City driving
                0.21390001773834227,  // Urban/suburban
                0.1721000075340271,   // Optimal efficiency speed
                0.1721000075340271,   // Optimal efficiency speed
                0.18310000896453857,  // Highway cruising
                0.2052000045776367,   // Fast highway
                0.2266000032424927,   // High speed
                0.25840001106262206,  // Very high speed
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
        12_582_916  // Currently using same model as Taycan (to be updated)
    }

    /// Charging curve parameters defining how the vehicle charges at different battery levels
    /// Unlike Porsche's fixed curve, this generates a simplified linear progression
    /// - Parameters:
    ///   - maximumBatteryCapacity: Total battery capacity (used to scale the curve)
    ///   - unit: Energy unit for capacity
    /// - Returns: Dictionary containing charging curve data
    func chargingFormulaParameters(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any] {
        // Generate a linear energy progression for UI display
        // Divides battery capacity into 20 equal segments (5% each)
        let value = Int((Measurement<UnitEnergy>(value: maximumBatteryCapacity, unit: unit).converted(to: .kilowattHours) / 20).value * 1000)
        var energyWattPerHour: [Int] = []
        for index in 0 ... 20 {
            energyWattPerHour.append(value * index)
        }

        // Battery state of charge levels in Watt-hours
        // Fixed progression points for EV9's battery capacity
        // Total range: 0 to 98,000 Wh (~98 kWh usable capacity)
        let energyAxisWH = [
            0,
            1450,
            4900,
            7350,
            9800,
            12250,
            14700,
            17150,
            19600,
            22050,
            24500,
            26950,
            29400,
            31850,
            34300,
            36750,
            39200,
            41650,
            44100,
            46550,
            49000,
            51450,
            53900,
            56350,
            58800,
            61250,
            63700,
            66150,
            68600,
            71050,
            73500,
            75950,
            78400,
            80850,
            83300,
            85750,
            88200,
            90650,
            93100,
            95550,
            98000,  // ~100% SOC
        ]

        // Charging power (in Watts) at each energy level
        // This is a simplified E-GMP platform charging curve
        // Peak power: 233 kW, maintained through mid-range, then tapering
        let energyAxisW = [
            50000,     // Initial ramp-up
            205_000,   // Quick rise to high power
            217_000,   // Approaching peak
            221_000,   // Near peak power
            221_000,
            221_000,
            223_000,   // ~10-15% SOC
            223_000,
            224_000,
            224_000,
            225_000,
            225_000,
            226_000,
            226_000,
            227_000,
            227_000,
            233_000,   // Peak power: 233 kW (maintained ~20-45% SOC)
            233_000,
            233_000,
            233_000,
            196_000,   // Start tapering ~50% SOC
            186_000,
            189_000,
            189_000,
            185_000,   // ~60% SOC
            185_000,
            190_000,
            190_000,
            184_000,   // ~70% SOC
            184_000,
            169_000,   // Significant taper
            169_000,
            158_000,   // ~80% SOC
            158_000,
            122_000,   // ~85% SOC
            122_000,
            63000,     // ~90% SOC
            63000,
            40000,     // ~95% SOC
            40000,
            12000,     // Trickle charge to 100%
        ]

        return [
            // Battery SOC checkpoints for charging curve
            "vehicle_energy_axis_wh": energyAxisWH,
            
            // Charging power at each SOC checkpoint
            "vehicle_charge_axis_w": energyAxisW,
            
            // Linear energy progression for UI (0-100% in 5% steps)
            "energy_w_per_h": energyWattPerHour,
            
            // Charging efficiency factor
            // Note: 2.2 seems unusually high - typical values are 0.85-0.95
            // This may be a placeholder value that needs updating
            "efficiency_factor": 2.2,
        ]
    }
}
