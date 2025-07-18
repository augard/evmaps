//
//  VehicleTypes.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 05.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

enum TemperatureUnit: Int, Codable {
    case celsius = 0
    case fahrenheit = 1

    var name: String {
        switch self {
        case .celsius:
            "°C"
        case .fahrenheit:
            "°F"
        }
    }
    
    var measuremntUnit: UnitTemperature {
        switch self {
        case .celsius:
            .celsius
        case .fahrenheit:
            .fahrenheit
        }
    }
}

enum EconomyUnit: Int, Codable {
    case unknown0 = 0
    case unknown1 = 1
    case unknown2 = 2
    case unknown3 = 3
    case km1Kwh = 4
    case km100Kwh = 5
    
    var unitTitle: String {
        switch self {
        case .unknown0:
            return "unknown0"
        case .unknown1:
            return "unknown1"
        case .unknown2:
            return "unknown2"
        case .unknown3:
            return "unknown3"
        case .km1Kwh:
            return "km/kWh"
        case .km100Kwh:
            return "100 km/kWh"
        }
    }
}

enum SpeedUnit: Int, Codable {
    case feet = 0
    case km = 1
    case meter = 2
    case miles = 3
}

enum DistanceUnit: Int, Codable {
    case feet = 0
    case kilometers = 1
    case meters = 2
    case miles = 3

    var measuremntUnit: UnitLength {
        switch self {
        case .feet:
            return .feet
        case .kilometers:
            return .kilometers
        case .meters:
            return .meters
        case .miles:
            return .miles
        }
    }
}

enum TimeUnit: Int, Codable {
    case hour = 0
    case minute = 1
    case microseconds = 2
    case second = 3

    var unitDuration: UnitDuration {
        switch self {
        case .hour:
            .hours
        case .minute:
            .minutes
        case .microseconds:
            .microseconds
        case .second:
            .seconds
        }
    }
}

enum ChargerPlugedType: Int, Codable {
    case notConnected = 0
    case fastChargerConntected = 1
    case normalChargerConnected = 2
}

enum ChargerPlugType: Int, Codable {
    case dcCharger = 0
    case acCharger240V = 1
    case acCharger120V = 2
}

enum ChargeDoorStatus: Int, Codable {
    case open = 1
    case closed = 2
}

enum VehicleType: String, Codable {
    case internalCombustionEngine = "GN"
    case hybrid = "HEV"
    case plugInHybrid = "PGEV"
    case electric = "EV"
    case hydrogenElectric = "FCEV"
}
