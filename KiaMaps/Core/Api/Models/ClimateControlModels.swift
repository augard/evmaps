//
//  ClimateControlModels.swift
//  KiaMaps
//
//  Created by Claude Code on 24.07.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation

// MARK: - Climate Control Request Models

/// Request model for starting climate control
struct ClimateControlRequest: Codable {
    let setting: ClimateSettings
    let pin: String
}

/// Climate control settings
struct ClimateSettings: Codable {
    let airCtrl: Int            // 0=off, 1=on
    let defrost: Bool           // Defrost on/off
    let heating1: Bool          // Heating on/off
    let igniOnDuration: Int     // Ignition duration in minutes
    let ims: Int                // Internal mode setting
    let airTemp: AirTemperature // Temperature settings
    let seatHeaterVentCMD: SeatCommands // Seat heating/cooling commands
}

/// Air temperature configuration
struct AirTemperature: Codable {
    let value: String           // Temperature in hex format (e.g., "16H")
    let unit: Int               // 0=Celsius, 1=Fahrenheit
    let hvacTempType: Int       // HVAC temperature type
}

/// Seat heating and ventilation commands
struct SeatCommands: Codable {
    let drvSeatOptCmd: Int      // Driver seat command (0-3)
    let astSeatOptCmd: Int      // Assistant seat command (0-3)
    let rlSeatOptCmd: Int       // Rear left seat command (0-3)
    let rrSeatOptCmd: Int       // Rear right seat command (0-3)
}

// MARK: - Climate Control Options

/// Options for configuring climate control
struct ClimateControlOptions {
    let temperature: Int        // Temperature in Celsius (16-32°C typically)
    let defrost: Bool           // Enable defrost
    let duration: Int           // Duration in minutes (1-30)
    let driverSeatLevel: Int    // Driver seat heating/cooling (0-3)
    let passengerSeatLevel: Int // Passenger seat heating/cooling (0-3)
    let rearLeftSeatLevel: Int  // Rear left seat heating/cooling (0-3)
    let rearRightSeatLevel: Int // Rear right seat heating/cooling (0-3)
    
    init(
        temperature: Int = 22,
        defrost: Bool = false,
        duration: Int = 10,
        driverSeatLevel: Int = 0,
        passengerSeatLevel: Int = 0,
        rearLeftSeatLevel: Int = 0,
        rearRightSeatLevel: Int = 0
    ) {
        self.temperature = temperature
        self.defrost = defrost
        self.duration = duration
        self.driverSeatLevel = driverSeatLevel
        self.passengerSeatLevel = passengerSeatLevel
        self.rearLeftSeatLevel = rearLeftSeatLevel
        self.rearRightSeatLevel = rearRightSeatLevel
    }
}

// MARK: - Temperature Conversion Utilities

extension ClimateControlOptions {
    /// Convert temperature to hex format expected by the API
    var temperatureHex: String {
        return String(format: "%02XH", temperature)
    }
    
    /// Validate temperature is within acceptable range
    var isTemperatureValid: Bool {
        return temperature >= 16 && temperature <= 32
    }
    
    /// Validate seat levels are within acceptable range (0-3)
    var areSeatLevelsValid: Bool {
        return [driverSeatLevel, passengerSeatLevel, rearLeftSeatLevel, rearRightSeatLevel]
            .allSatisfy { $0 >= 0 && $0 <= 3 }
    }
    
    /// Validate duration is within acceptable range (1-30 minutes)
    var isDurationValid: Bool {
        return duration >= 1 && duration <= 30
    }
    
    /// Check if all options are valid
    var isValid: Bool {
        return isTemperatureValid && areSeatLevelsValid && isDurationValid
    }
}

// MARK: - Conversion to API Models

extension ClimateControlOptions {
    /// Convert to ClimateControlRequest for API
    func toClimateControlRequest(pin: String) -> ClimateControlRequest {
        return ClimateControlRequest(
            setting: ClimateSettings(
                airCtrl: 1, // Always 1 for start climate
                defrost: defrost,
                heating1: false, // Default heating off
                igniOnDuration: duration,
                ims: 0, // Default internal mode
                airTemp: AirTemperature(
                    value: temperatureHex,
                    unit: 0, // Always Celsius for EU
                    hvacTempType: 0
                ),
                seatHeaterVentCMD: SeatCommands(
                    drvSeatOptCmd: driverSeatLevel,
                    astSeatOptCmd: passengerSeatLevel,
                    rlSeatOptCmd: rearLeftSeatLevel,
                    rrSeatOptCmd: rearRightSeatLevel
                )
            ),
            pin: pin
        )
    }
}

// MARK: - Climate Control Errors

enum ClimateControlError: LocalizedError {
    case invalidTemperature(Int)
    case invalidSeatLevel(Int)
    case invalidDuration(Int)
    case missingPin
    case vehicleNotReady
    
    var errorDescription: String? {
        switch self {
        case .invalidTemperature(let temp):
            return "Invalid temperature: \(temp)°C. Must be between 16-32°C."
        case .invalidSeatLevel(let level):
            return "Invalid seat level: \(level). Must be between 0-3."
        case .invalidDuration(let duration):
            return "Invalid duration: \(duration) minutes. Must be between 1-30 minutes."
        case .missingPin:
            return "Vehicle PIN is required for climate control."
        case .vehicleNotReady:
            return "Vehicle is not ready for climate control. Ensure it's parked and engine is off."
        }
    }
}
