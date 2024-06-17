//
//  KiaParameters.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import Intents

enum KiaParameters: String, VehicleParameters {
    case ev9 = "Kia - EV9"

    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double? {
        if connector == .mennekes {
            return 11.0
        } else if connector == .ccs2 {
            return 234.0
        } else {
            return nil
        }
    }
    
    var supportedChargingConnectors: [INCar.ChargingConnectorType] {
        [.mennekes, .ccs2]
    }

    var maximumDistance: Double {
        541
    }
    
    var consumptionModelId: Int {
        12582912
    }
    
    var consumptionFormulaParameters: [String: Any] {
        [
            "vehicle_auxiliary_power_w": 669.9999809265137, // how much it lose from other things (electronics)?
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
            "vehicle_altitude_gain_consumption_wh_per_m": 8.345999908447265, // rekupera?
            "vehicle_altitude_loss_consumption_wh_per_m": 6.972999572753906 // o kolik je narocnejsi jet nahoru?
        ]
    }
    
    var chargingModelId: Int {
        12582916
    }
    
    func chargingFormulaParameters(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any] {
        // in porsche data it don't look linear, but it's currently best what i can do
        let value = Int((Measurement<UnitEnergy>(value: maximumBatteryCapacity, unit: unit).converted(to: .kilowattHours) / 20).value * 1000)
        var energyWattPerHour: [Int] = []
        for index in 0...20 {
            energyWattPerHour.append(value * index)
        }
        
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
            98000,
        ]
        
        let energyAxisW = [
            50000,
            205000,
            217000,
            221000,
            221000,
            221000,
            223000,
            223000,
            224000,
            224000,
            225000,
            225000,
            226000,
            226000,
            227000,
            227000,
            233000,
            233000,
            233000,
            233000,
            196000,
            186000,
            189000,
            189000,
            185000,
            185000,
            190000,
            190000,
            184000,
            184000,
            169000,
            169000,
            158000,
            158000,
            122000,
            122000,
            63000,
            63000,
            40000,
            40000,
            12000,
        ]
        
        return [
            "vehicle_energy_axis_wh": energyAxisWH,
            "vehicle_charge_axis_w": energyAxisW,
            "energy_w_per_h": energyWattPerHour,
            "efficiency_factor": 2.2
        ]
    }
}
