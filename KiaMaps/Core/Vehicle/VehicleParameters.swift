//
//  VehicleParameters.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import Intents

protocol VehicleParameters {
    var supportedChargingConnectors: [INCar.ChargingConnectorType] { get }

    func maximumPower(for connector: INCar.ChargingConnectorType) -> Double?

    var maximumDistance: Double { get }

    var consumptionModelId: Int { get }

    // A dictionary mapping NSStrings to serializable objects (NSString, NSNumber, NSArray, NSDictionary, or NSNull) that contains the OEM provided parameters for the consumption model used to calculate the vehicle’s energy consumption as the user drives. The keys of this dictionary describe the parameters that fit into the consumpteion model of the electric vehicle. The values of this dictionary represent the parameter values. model_id is a mandatory key in this dictionary. */
    var consumptionFormulaParameters: [String: Any] { get }

    var chargingModelId: Int { get }

    // A dictionary mapping NSStrings to serializable objects (NSString, NSNumber, NSArray, NSDictionary, or NSNull) that contains OEM provided parameters for the charging model that is used to calculate the duration of charging at a station. The keys of this dictionary describe the parameters that fit into the Charging model of the electric vehicle. The values of this dictionary represent the parameter values. model_id is a mandatory key in this dictionary.
    func chargingFormulaParameters(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any]

    // Sample data
    /*
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
}
