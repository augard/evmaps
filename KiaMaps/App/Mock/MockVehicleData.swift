//
//  MockVehicleData.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Centralized mock data system for SwiftUI previews and testing
//

import Foundation

/// Centralized mock data provider for VehicleStatusResponse and related structures
struct MockVehicleData {
    
    // MARK: - Private JSON Factory
    
    private static func createVehicleStatusJSON(
        batteryLevel: Int,
        isCharging: Bool,
        drivingReady: Bool,
        scenario: String
    ) -> String {
        let chargingHeading = isCharging ? "180" : "0"
        let drivingReadyValue = drivingReady ? "1" : "0"
        let currentTime = String(Int(Date().timeIntervalSince1970))
        
        return """
        {
            "Body": {
                "Windshield": {
                    "Front": {
                        "Heat": {
                            "State": \(scenario == "preconditioning" ? 1 : 0)
                        },
                        "Defog": {
                            "State": \(scenario == "preconditioning" ? 1 : 0)
                        },
                        "WasherFluid": {
                            "LevelLow": \(scenario == "maintenance" ? 1 : 0)
                        }
                    },
                    "Rear": {
                        "Defog": {
                            "State": \(scenario == "preconditioning" ? 0 : 1)
                        }
                    }
                },
                "Hood": {
                    "Open": 0,
                    "Frunk": {
                        "Fault": 0
                    }
                },
                "Lights": {
                    "Front": {
                        "Left": {
                            "TurnSignal": "0",
                            "FogLamp": "0",
                            "DippedBeam": "0",
                            "MainBeam": "0",
                            "PositionLamp": "0",
                            "DRL": "1",
                            "Fault": "0"
                        },
                        "Right": {
                            "TurnSignal": "0",
                            "FogLamp": "0",
                            "DippedBeam": "0",
                            "MainBeam": "0",
                            "PositionLamp": "0",
                            "DRL": "1",
                            "Fault": "0"
                        }
                    },
                    "Rear": {
                        "Left": {
                            "TurnSignal": "0",
                            "BrakeLamp": "0",
                            "PositionLamp": "0",
                            "ReverseLamp": "0",
                            "Fault": "0"
                        },
                        "Right": {
                            "TurnSignal": "0",
                            "BrakeLamp": "0",
                            "PositionLamp": "0",
                            "ReverseLamp": "0",
                            "Fault": "0"
                        }
                    },
                    "Hazard": "0",
                    "InteriorLamp": "0"
                },
                "Sunroof": {
                    "Tilt": "0",
                    "Slide": "0",
                    "Fault": "0"
                },
                "Trunk": {
                    "Open": "0",
                    "Fault": "0"
                }
            },
            "Cabin": {
                "RESTMode": {
                    "Active": "0"
                },
                "HVAC": {
                    "AirConditioning": "\(scenario == "preconditioning" ? "1" : "0")",
                    "Heater": "\(scenario == "preconditioning" ? "1" : "0")",
                    "TemperatureDriver": \(scenario == "preconditioning" ? 22 : 20),
                    "TemperaturePassenger": \(scenario == "preconditioning" ? 22 : 20),
                    "FanSpeed": \(scenario == "preconditioning" ? 3 : 0),
                    "VentilationMode": \(scenario == "preconditioning" ? 2 : 0),
                    "Recirculation": "0",
                    "FineDustMode": "\(scenario == "preconditioning" ? "1" : "0")",
                    "AirCleaning": "\(scenario == "preconditioning" ? "1" : "0")",
                    "AutoMode": "\(scenario == "preconditioning" ? "1" : "0")",
                    "DualMode": "0"
                },
                "Door": {
                    "Row1": {
                        "Driver": {
                            "Open": "0",
                            "Lock": "1",
                            "Fault": "0"
                        },
                        "Passenger": {
                            "Open": "0",
                            "Lock": "1",
                            "Fault": "0"
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Open": "0",
                            "Lock": "1",
                            "Fault": "0"
                        },
                        "Right": {
                            "Open": "0",
                            "Lock": "1",
                            "Fault": "0"
                        }
                    }
                },
                "Seat": {
                    "Row1": {
                        "Driver": {
                            "Heating": \(scenario == "preconditioning" ? 2 : 0),
                            "Ventilation": 0
                        },
                        "Passenger": {
                            "Heating": \(scenario == "preconditioning" ? 1 : 0),
                            "Ventilation": 0
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Heating": 0,
                            "Ventilation": 0
                        },
                        "Right": {
                            "Heating": 0,
                            "Ventilation": 0
                        }
                    }
                },
                "Window": {
                    "Row1": {
                        "Driver": {
                            "Open": "0",
                            "Fault": "0"
                        },
                        "Passenger": {
                            "Open": "0",
                            "Fault": "0"
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Open": "0",
                            "Fault": "0"
                        },
                        "Right": {
                            "Open": "0",
                            "Fault": "0"
                        }
                    }
                },
                "SteeringWheel": {
                    "Heating": "\(scenario == "preconditioning" ? "1" : "0")"
                }
            },
            "Chassis": {
                "DrivingMode": {
                    "Current": "\(scenario == "fast_charging" ? "Sport" : "Eco")"
                },
                "Axle": {
                    "Front": {
                        "Left": {
                            "Pressure": 32.0,
                            "Temperature": 28.4,
                            "Fault": "0"
                        },
                        "Right": {
                            "Pressure": \(scenario == "maintenance" ? 28.5 : 32.5),
                            "Temperature": \(scenario == "maintenance" ? 31.2 : 28.9),
                            "Fault": "\(scenario == "maintenance" ? "1" : "0")"
                        }
                    },
                    "Rear": {
                        "Left": {
                            "Pressure": 31.8,
                            "Temperature": 27.8,
                            "Fault": "0"
                        },
                        "Right": {
                            "Pressure": 32.2,
                            "Temperature": 28.1,
                            "Fault": "0"
                        }
                    }
                },
                "Brake": {
                    "FluidLevel": \(scenario == "maintenance" ? 0.7 : 0.9),
                    "WearFront": 2.4,
                    "WearRear": 4.1
                }
            },
            "Drivetrain": {
                "Motor": {
                    "Temperature": \(isCharging ? 35.2 : 28.4),
                    "Power": \(isCharging ? -11.2 : 0.0),
                    "Torque": 0.0
                }
            },
            "Electronics": {
                "Battery": {
                    "Voltage": 12.8,
                    "Level": \(max(50, min(100, batteryLevel + Int.random(in: -15...25)))),
                    "Temperature": 22.1
                },
                "AutoCut": {
                    "Active": "\(batteryLevel < 15 ? "1" : "0")",
                    "Threshold": 10.0
                },
                "Fob": {
                    "BatteryLevel": \(Int.random(in: 65...95)),
                    "LastSeen": "\(currentTime)"
                },
                "PowerSupply": {
                    "Ignition": "\(batteryLevel > 5 ? "Ready" : "Off")",
                    "Accessory": "1"
                }
            },
            "Green": {
                "DrivingReady": "\(drivingReadyValue)",
                "PowerConsumption": {
                    "Current": \(isCharging ? -11.2 : 2.4),
                    "Average": 4.2,
                    "Instantaneous": \(isCharging ? -11.2 : 0.0)
                },
                "BatteryManagement": {
                    "BatteryRemain": {
                        "Ratio": \(batteryLevel),
                        "Capacity": \(Double(batteryLevel) * 0.77),
                        "Energy": \(Double(batteryLevel) * 2770.0)
                    },
                    "BatteryCapacity": {
                        "Total": 77.4,
                        "Usable": 74.2,
                        "Degradation": \(scenario == "maintenance" ? 2.8 : 1.2)
                    },
                    "StateOfHealth": {
                        "Percentage": \(scenario == "maintenance" ? 94.2 : 97.8),
                        "Cycles": \(scenario == "maintenance" ? 1247 : 823)
                    },
                    "CellTemperature": {
                        "Minimum": 21.5,
                        "Maximum": 23.2,
                        "Average": 22.4
                    }
                },
                "Electric": {
                    "SmartGridReady": "1",
                    "VehicleToLoad": "0",
                    "VehicleToGrid": "0"
                },
                "ChargingInformation": {
                    "ChargingTime": {
                        "ICCB": \(isCharging ? (100 - batteryLevel) * 8 : 0),
                        "Standard": \(isCharging ? (100 - batteryLevel) * 3 : 0),
                        "Quick": \(isCharging ? Int(Double(100 - batteryLevel) * 0.6) : 0)
                    },
                    "TargetSoC": {
                        "AC": 80,
                        "DC": 90
                    },
                    "CurrentPower": \(isCharging ? 11.0 : 0.0),
                    "Voltage": \(isCharging ? 238.4 : 0.0),
                    "Current": \(isCharging ? 46.2 : 0.0),
                    "Temperature": \(isCharging ? 24.8 : 20.2)
                },
                "Reservation": {
                    "Active": "\(scenario == "charging" || scenario == "preconditioning" ? "1" : "0")",
                    "DepartureTime": "\(currentTime)",
                    "TargetSoC": 80,
                    "ClimateControl": "\(scenario == "charging" || scenario == "preconditioning" ? "1" : "0")",
                    "TargetTemperature": 22.0
                },
                "EnergyInformation": {
                    "Consumption": {
                        "Total": \(Double(batteryLevel) * 0.8),
                        "Climate": \(scenario == "preconditioning" ? 2.4 : 0.8),
                        "Driving": \(Double(batteryLevel) * 0.6),
                        "Electronics": 0.2
                    },
                    "Regeneration": {
                        "Total": \(Double(batteryLevel) * 0.1),
                        "Braking": \(Double(batteryLevel) * 0.08),
                        "Coasting": \(Double(batteryLevel) * 0.02)
                    }
                },
                "ChargingDoor": {
                    "Status": \(isCharging ? 1 : 2),
                    "Fault": "0"
                },
                "PlugAndCharge": {
                    "Certificates": \(isCharging ? 3 : 2),
                    "LastUpdate": "\(Int(Date().timeIntervalSince1970) - 3600)"
                },
                "DrivingHistory": {
                    "TotalDistance": 12847.5,
                    "TotalTime": 186.3,
                    "AverageSpeed": 68.9,
                    "AverageConsumption": 4.2
                }
            },
            "Service": {
                "Connectivity": {
                    "Status": "Connected",
                    "Strength": 4,
                    "Carrier": "Kia Connect"
                },
                "Subscription": {
                    "Active": "1",
                    "ExpiryDate": "\(Int(Date().addingTimeInterval(63072000).timeIntervalSince1970))",
                    "Plan": "Premium"
                }
            },
            "RemoteControl": {
                "Engine": {
                    "Available": "1",
                    "Active": "0",
                    "Duration": 10
                },
                "Climate": {
                    "Available": "1",
                    "Active": "0",
                    "TargetTemperature": 22.0
                },
                "Lock": {
                    "Available": "1",
                    "Locked": "1"
                },
                "Lights": {
                    "Available": "1",
                    "Active": "0"
                },
                "Horn": {
                    "Available": "1",
                    "Active": "0"
                }
            },
            "ConnectedService": {
                "MapUpdates": {
                    "Available": "1",
                    "LastUpdate": "\(Int(Date().addingTimeInterval(-604800).timeIntervalSince1970))",
                    "Version": "2024.1"
                },
                "VoiceRecognition": {
                    "Available": "1",
                    "Language": "en-US"
                },
                "OverTheAirUpdates": {
                    "Available": "1",
                    "PendingUpdates": 0,
                    "LastCheck": "\(Int(Date().addingTimeInterval(-21600).timeIntervalSince1970))"
                }
            },
            "DrivingReady": "\(drivingReadyValue)",
            "Version": "24.1.0",
            "Date": "\(currentTime)",
            "Offset": "+00:00",
            "Location": {
                "Date": "\(currentTime)",
                "Offset": 0,
                "ServiceState": 1,
                "TimeStamp": {
                    "Seconds": \(Int(Date().timeIntervalSince1970)),
                    "Milliseconds": \(Int(Date().timeIntervalSince1970 * 1000) % 1000)
                },
                "Version": "1.0",
                "GeoCoordinate": {
                    "Latitude": \(getLatitude(for: scenario)),
                    "Longitude": \(getLongitude(for: scenario)),
                    "Altitude": \(getAltitude(for: scenario)),
                    "Accuracy": 3.2
                },
                "Heading": \(chargingHeading),
                "Speed": {
                    "Value": \(isCharging ? 0 : Int.random(in: 0...50)),
                    "Unit": 1
                }
            }
        }
        """
    }
    
    private static func getLatitude(for scenario: String) -> Double {
        switch scenario {
        case "charging": return 37.7749
        case "maintenance": return 37.7849
        case "preconditioning": return 37.7649
        default: return 37.7749
        }
    }
    
    private static func getLongitude(for scenario: String) -> Double {
        switch scenario {
        case "charging": return -122.4194
        case "maintenance": return -122.4094
        case "preconditioning": return -122.4294
        default: return -122.4194
        }
    }
    
    private static func getAltitude(for scenario: String) -> Double {
        switch scenario {
        case "charging": return 52.3
        case "maintenance": return 48.7
        case "preconditioning": return 67.2
        default: return 52.3
        }
    }
    
    // MARK: - Vehicle Status Factory
    
    private static func createVehicleStatus(
        batteryLevel: Int,
        isCharging: Bool,
        drivingReady: Bool,
        scenario: String
    ) -> VehicleStatus {
        let jsonString = createVehicleStatusJSON(
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            drivingReady: drivingReady,
            scenario: scenario
        )
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("Failed to create JSON data for mock vehicle status")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(VehicleStatus.self, from: jsonData)
        } catch {
            fatalError("Failed to decode mock vehicle status: \(error)")
        }
    }
    
    // MARK: - Public Mock Data
    
    /// Standard driving scenario - 75% battery, ready to drive
    static let standard = createVehicleStatus(
        batteryLevel: 75,
        isCharging: false,
        drivingReady: true,
        scenario: "standard"
    )
    
    /// Charging scenario - 45% battery, actively charging
    static let charging = createVehicleStatus(
        batteryLevel: 45,
        isCharging: true,
        drivingReady: false,
        scenario: "charging"
    )
    
    /// Low battery scenario - 12% battery, needs charging
    static let lowBattery = createVehicleStatus(
        batteryLevel: 12,
        isCharging: false,
        drivingReady: true,
        scenario: "low_battery"
    )
    
    /// Full battery scenario - 100% battery, just finished charging
    static let fullBattery = createVehicleStatus(
        batteryLevel: 100,
        isCharging: false,
        drivingReady: true,
        scenario: "full_battery"
    )
    
    /// Fast charging scenario - 67% battery, DC fast charging
    static let fastCharging = createVehicleStatus(
        batteryLevel: 67,
        isCharging: true,
        drivingReady: false,
        scenario: "fast_charging"
    )
    
    /// Climate preconditioning - 82% battery, climate active
    static let preconditioning = createVehicleStatus(
        batteryLevel: 82,
        isCharging: false,
        drivingReady: true,
        scenario: "preconditioning"
    )
    
    /// Maintenance mode - 58% battery, some systems offline
    static let maintenance = createVehicleStatus(
        batteryLevel: 58,
        isCharging: false,
        drivingReady: false,
        scenario: "maintenance"
    )
}

// MARK: - VehicleStatusResponse Mock Data

extension MockVehicleData {
    
    /// Create complete VehicleStatusResponse from JSON
    private static func createVehicleStatusResponse(
        vehicleStatus: VehicleStatus,
        resultCode: String = "0000"
    ) -> VehicleStatusResponse {
        // Create response with mock vehicle directly
        let response = VehicleStatusResponse(
            resultCode: resultCode,
            serviceNumber: "VehicleStatus", 
            returnCode: "S",
            lastUpdateTime: Date(),
            state: VehicleStatusResponse.State(vehicle: vehicleStatus)
        )
        return response
    }
    
    /// Complete VehicleStatusResponse with standard scenario
    static let standardResponse = createVehicleStatusResponse(vehicleStatus: standard)
    
    /// Complete VehicleStatusResponse with charging scenario  
    static let chargingResponse = createVehicleStatusResponse(vehicleStatus: charging)
    
    /// Complete VehicleStatusResponse with low battery scenario
    static let lowBatteryResponse = createVehicleStatusResponse(vehicleStatus: lowBattery)
}

// MARK: - Vehicle Mock Data

extension MockVehicleData {
    
    /// Mock Vehicle object for components that need basic vehicle info
    static let mockVehicle: Vehicle = {
        let jsonString = """
        {
            "VIN": "KNDC14CXPPH000123",
            "VehicleId": "MOCK001",
            "VehicleType": "EV",
            "VehicleName": "My EV9",
            "VehicleImage": null,
            "Year": "2024",
            "Make": "Kia",
            "Model": "EV9",
            "Trim": "GT-Line"
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("Failed to create JSON data for mock vehicle")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Vehicle.self, from: jsonData)
        } catch {
            fatalError("Failed to decode mock vehicle: \(error)")
        }
    }()
}

// MARK: - SwiftUI Preview Extensions

extension VehicleStatus {
    /// Convenience properties for previews
    static let preview = MockVehicleData.standard
    static let chargingPreview = MockVehicleData.charging  
    static let lowBatteryPreview = MockVehicleData.lowBattery
    static let fullBatteryPreview = MockVehicleData.fullBattery
    static let fastChargingPreview = MockVehicleData.fastCharging
    static let preconditioningPreview = MockVehicleData.preconditioning
    static let maintenancePreview = MockVehicleData.maintenance
}

extension VehicleStatusResponse {
    /// Convenience properties for previews
    static let preview = MockVehicleData.standardResponse
    static let chargingPreview = MockVehicleData.chargingResponse
    static let lowBatteryPreview = MockVehicleData.lowBatteryResponse
}

extension Vehicle {
    /// Convenience property for previews
    static let preview = MockVehicleData.mockVehicle
}

// MARK: - Battery Level Helpers

extension MockVehicleData {
    
    /// Extract battery percentage as Double (0.0 to 1.0) from VehicleStatus
    static func batteryLevel(from vehicleStatus: VehicleStatus) -> Double {
        return Double(vehicleStatus.green.batteryManagement.batteryRemain.ratio) / 100.0
    }
    
    /// Check if vehicle is charging based on mock data logic
    static func isCharging(_ vehicleStatus: VehicleStatus) -> Bool {
        return vehicleStatus.location.heading > 0
    }
    
    /// Get estimated range in kilometers
    static func estimatedRange(from vehicleStatus: VehicleStatus) -> Int {
        return Int(vehicleStatus.green.batteryManagement.batteryRemain.ratio * 4) // Rough calculation
    }
}
