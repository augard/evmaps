//
//  PorscheParameters.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import Intents

enum PorscheParameters: VehicleParameters {
    case taycanGen1

    var supportedChargingConnectors: [INCar.ChargingConnectorType] {
        [.mennekes, .ccs2]
    }

    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double? {
        if connector == .mennekes {
            return 11.0
        } else if connector == .ccs2 {
            return 234.0
        } else {
            return nil
        }
    }

    var maximumDistance: Double {
        541
    }

    var consumptionModelId: Int {
        12_582_912
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
                0.25840001106262206,
            ],
            "vehicle_altitude_gain_consumption_wh_per_m": 8.345999908447265, // rekupera?
            "vehicle_altitude_loss_consumption_wh_per_m": 6.972999572753906, // o kolik je narocnejsi jet nahoru?
        ]
    }

    var chargingModelId: Int {
        12_582_916
    }

    func chargingFormulaParameters(maximumBatteryCapacity _: Double, unit _: UnitEnergy) -> [String: Any] {
        [
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
                90250,
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
                77050,
            ],
            "vehicle_charge_axis_w": [
                232_000,
                232_000,
                223_000,
                223_000,
                204_000,
                204_000,
                186_000,
                186_000,
                167_000,
                167_000,
                158_000,
                158_000,
                148_000,
                148_000,
                144_000,
                144_000,
                134_000,
                134_000,
                107_000,
                107_000,
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
                0,
            ],
            "efficiency_factor": 0.8999999761581421,
        ]
    }
}
