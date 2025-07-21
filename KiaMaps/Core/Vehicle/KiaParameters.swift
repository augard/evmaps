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
    case ev9 = "Kia - EV9 GT-Line AWD"

    /// Maximum charging power (in kW) for each connector type
    /// - Parameter connector: The charging connector type
    /// - Returns: Maximum power in kilowatts, or nil if connector not supported
    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double? {
        if connector == .mennekes {
            return 11.0  // AC charging: 11 kW (3-phase 16A)
        } else if connector == .ccs2 {
            return 233.0  // DC fast charging: Up to 233 kW peak (E-GMP platform)
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
        505  // WLTP range for EV9 GT-Line AWD (top trim)
    }

    /// Unique identifier for this vehicle's consumption model
    /// Used for server-side route calculations and energy estimations
    var consumptionModelId: Int {
        12_582_913  // EV9-specific model ID (updated from Taycan placeholder)
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
            // Based on real EV9 GT-Line AWD consumption data from EVKX
            // Values validated against test data: WLTP 19.4 kWh/100km, 90 km/h = 21 kWh/100km, 120 km/h = 26 kWh/100km
            "vehicle_consumption_values_wh_per_m": [
                0.2320,   // 232 Wh/km - City stop/start with heating (23.2 kWh/100km)
                0.1914,   // 191.4 Wh/km - WLTP optimal conditions (19.14 kWh/100km basic trim)  
                0.1941,   // 194.1 Wh/km - WLTP top trim conditions (19.41 kWh/100km)
                0.2100,   // 210 Wh/km - Mixed city/suburban driving
                0.2100,   // 210 Wh/km - 90 km/h perfect conditions (21 kWh/100km)
                0.2300,   // 230 Wh/km - 112 km/h / 70 mph (23 kWh/100km)
                0.2340,   // 234 Wh/km - EPA conditions (23.4 kWh/100km) 
                0.2600,   // 260 Wh/km - 120 km/h perfect conditions (26 kWh/100km)
                0.2770,   // 277 Wh/km - 120 km/h with heating (27.7 kWh/100km)
                0.3000,   // 300 Wh/km - High-speed highway (~130 km/h estimated)
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
        12_582_917  // EV9-specific charging model ID (updated from Taycan placeholder)
    }

    /// Charging curve parameters defining how the vehicle charges at different battery levels  
    /// Based on real EV9 GT-Line AWD data: 98 kWh usable, peak 204 kW at 26-30% SOC
    /// - Parameters:
    ///   - maximumBatteryCapacity: Total battery capacity (98 kWh for EV9)
    ///   - unit: Energy unit for capacity
    /// - Returns: Dictionary containing EV9-specific charging curve data
    func chargingFormulaParameters(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any] {
        // Generate a linear energy progression for UI display
        // Divides battery capacity into 20 equal segments (5% each)
        let value = Int((Measurement<UnitEnergy>(value: maximumBatteryCapacity, unit: unit).converted(to: .kilowattHours) / 20).value * 1000)
        var energyWattPerHour: [Int] = []
        for index in 0 ... 20 {
            energyWattPerHour.append(value * index)
        }

        // Battery state of charge levels in Watt-hours
        // Based on EV9 GT-Line AWD battery: 98 kWh usable capacity
        // SOC progression from 0% to 100% in increments
        let energyAxisWH = [
            0,      // 0% SOC
            1960,   // 2% SOC (start of optimal charging range)
            4900,   // 5% SOC
            9800,   // 10% SOC
            14700,  // 15% SOC
            19600,  // 20% SOC
            24500,  // 25% SOC
            29400,  // 30% SOC (peak power area)
            34300,  // 35% SOC
            39200,  // 40% SOC
            44100,  // 45% SOC
            49000,  // 50% SOC
            53900,  // 55% SOC
            58800,  // 60% SOC
            63700,  // 65% SOC
            68600,  // 70% SOC
            69580,  // 71% SOC (end of optimal range)
            73500,  // 75% SOC
            78400,  // 80% SOC
            83300,  // 85% SOC
            88200,  // 90% SOC
            93100,  // 95% SOC
            98000,  // 100% SOC
        ]

        // Charging power (in Watts) at each energy level
        // Based on real EV9 GT-Line AWD charging curve from EVKX
        // Peak: 204 kW around 26-30% SOC, optimal range 2-71% SOC
        let energyAxisW = [
            50000,     // 0% SOC - Initial ramp-up
            150000,    // 2% SOC - Start of optimal range
            180000,    // 5% SOC - Rising power
            195000,    // 10% SOC - Approaching peak
            200000,    // 15% SOC - Near peak
            204000,    // 20% SOC - Peak area
            204000,    // 25% SOC - Peak maintained
            204000,    // 30% SOC - Peak power ~204 kW
            200000,    // 35% SOC - Slight decrease
            195000,    // 40% SOC - Gradual taper
            190000,    // 45% SOC - Continued taper
            180000,    // 50% SOC - Mid-range power
            170000,    // 55% SOC - Decreasing
            160000,    // 60% SOC - Further reduction  
            150000,    // 65% SOC - Approaching end optimal
            140000,    // 70% SOC - Near end of optimal range
            134000,    // 71% SOC - End of optimal charging (134 kW from EVKX)
            120000,    // 75% SOC - Significant reduction
            90000,     // 80% SOC - Major taper
            70000,     // 85% SOC - Slow charging
            40000,     // 90% SOC - Very slow
            25000,     // 95% SOC - Trickle charge
            15000,     // 100% SOC - Final trickle
        ]

        return [
            // Battery SOC checkpoints for charging curve
            "vehicle_energy_axis_wh": energyAxisWH,
            
            // Charging power at each SOC checkpoint
            "vehicle_charge_axis_w": energyAxisW,
            
            // Linear energy progression for UI (0-100% in 5% steps)
            "energy_w_per_h": energyWattPerHour,
            
            // Charging efficiency factor for EV9 (typical E-GMP platform efficiency)
            // Updated to realistic value based on EV charging standards
            "efficiency_factor": 0.9,
        ]
    }
}
