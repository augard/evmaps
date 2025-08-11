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
    
    public static func createVehicleStatusJSON(
        batteryLevel: Int,
        isCharging: Bool,
        drivingReady: Bool,
        scenario: String
    ) -> String {
        let chargingHeading = isCharging ? "180" : "0"
        let drivingReadyValue = drivingReady ? 1 : 0
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
                        "HeadLamp": {
                            "SystemWarning": 0
                        },
                        "Left": {
                            "Low": {
                                "Warning": 0
                            },
                            "High": {
                                "Warning": 0
                            },
                            "TurnSignal": {
                                "Warning": 0,
                                "LampState": 0
                            }
                        },
                        "Right": {
                            "Low": {
                                "Warning": 0
                            },
                            "High": {
                                "Warning": 0
                            },
                            "TurnSignal": {
                                "Warning": 0,
                                "LampState": 0
                            }
                        }
                    },
                    "DischargeAlert": {
                        "State": 0
                    },
                    "Rear": {
                        "Left": {
                            "StopLamp": {
                                "Warning": 0
                            },
                            "TurnSignal": {
                                "Warning": 0
                            }
                        },
                        "Right": {
                            "StopLamp": {
                                "Warning": 0
                            },
                            "TurnSignal": {
                                "Warning": 0
                            }
                        }
                    },
                    "TailLamp": {
                        "Alert": 0
                    },
                    "Hazard": {
                        "Alert": 0
                    }
                },
                "Sunroof": {
                    "Glass": {
                        "Open": 0
                    }
                },
                "Trunk": {
                    "Open": 0
                }
            },
            "Cabin": {
                "RestMode": {
                    "State": 0
                },
                "HVAC": {
                    "Row1": {
                        "Driver": {
                            "Temperature": {
                                "Value": "\(scenario == "preconditioning" ? "22" : "20")",
                                "Unit": 0
                            },
                            "Blower": {
                                "SpeedLevel": \(scenario == "preconditioning" ? 3 : 0)
                            }
                        }
                    },
                    "Vent": {
                        "FineDust": {
                            "Level": 1
                        },
                        "AirCleaning": {
                            "Indicator": 0,
                            "SymbolColor": 0
                        }
                    },
                    "Temperature": {
                        "RangeType": 0
                    }
                },
                "Door": {
                    "Row1": {
                        "Driver": {
                            "Open": 0,
                            "Lock": 1,
                            "Fault": 0
                        },
                        "Passenger": {
                            "Open": 0,
                            "Lock": 1,
                            "Fault": 0
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Open": 0,
                            "Lock": 1,
                            "Fault": 0
                        },
                        "Right": {
                            "Open": 0,
                            "Lock": 1,
                            "Fault": 0
                        }
                    }
                },
                "Seat": {
                    "Row1": {
                        "Driver": {
                            "Climate": {
                                "State": \(scenario == "preconditioning" ? 2 : 0)
                            }
                        },
                        "Passenger": {
                            "Climate": {
                                "State": \(scenario == "preconditioning" ? 1 : 0)
                            }
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Climate": {
                                "State": 0
                            }
                        },
                        "Right": {
                            "Climate": {
                                "State": 0
                            }
                        }
                    }
                },
                "Window": {
                    "Row1": {
                        "Driver": {
                            "Open": 0,
                            "OpenLevel": 0
                        },
                        "Passenger": {
                            "Open": 0,
                            "OpenLevel": 0
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Open": 0,
                            "OpenLevel": 0
                        },
                        "Right": {
                            "Open": 0,
                            "OpenLevel": 0
                        }
                    }
                },
                "SteeringWheel": {
                    "Heat": {
                        "RemoteControl": {
                            "Step": 0
                        },
                        "State": \(scenario == "preconditioning" ? 1 : 0)
                    }
                }
            },
            "Chassis": {
                "DrivingMode": {
                    "State": "\(scenario == "fast_charging" ? "Sport" : "Eco")"
                },
                "Axle": {
                    "Row1": {
                        "Left": {
                            "Tire": {
                                "PressureLow": \(scenario == "low_tire_pressure" ? 1 : 0),
                                "Pressure": \(scenario == "low_tire_pressure" ? 26 : 32)
                            }
                        },
                        "Right": {
                            "Tire": {
                                "PressureLow": \(scenario == "maintenance" || scenario == "low_tire_pressure" ? 1 : 0),
                                "Pressure": \(scenario == "maintenance" ? 28 : (scenario == "low_tire_pressure" ? 24 : 32))
                            }
                        }
                    },
                    "Row2": {
                        "Left": {
                            "Tire": {
                                "PressureLow": 0,
                                "Pressure": 31
                            }
                        },
                        "Right": {
                            "Tire": {
                                "PressureLow": \(scenario == "low_tire_pressure" ? 1 : 0),
                                "Pressure": \(scenario == "low_tire_pressure" ? 27 : 32)
                            }
                        }
                    },
                    "Tire": {
                        "PressureLow": \(scenario == "maintenance" || scenario == "low_tire_pressure" ? 1 : 0),
                        "PressureUnit": 0
                    }
                },
                "Brake": {
                    "Fluid": {
                        "Warning": \(scenario == "maintenance" ? 1 : 0)
                    }
                }
            },
            "Drivetrain": {
                "FuelSystem": {
                    "DTE": {
                        "Unit": 1,
                        "Total": \(batteryLevel * 4)
                    },
                    "LowFuelWarning": \(batteryLevel < 15 ? 1 : 0),
                    "FuelLevel": \(batteryLevel),
                    "AverageFuelEconomy": {
                        "Drive": 4.2,
                        "AfterRefuel": 4.0,
                        "Accumulated": 4.1,
                        "Unit": 4
                    }
                },
                "Odometer": 12847.5,
                "Transmission": {
                    "ParkingPosition": 1,
                    "GearPosition": 0
                }
            },
            "Electronics": {
                "Battery": {
                    "Auxiliary": {
                        "FailWarning": 0
                    },
                    "Level": \(batteryLevel),
                    "Charging": {
                        "WarningLevel": 0
                    },
                    "PowerStateAlert": {
                        "ClassC": 0
                    },
                    "SensorReliability": 1
                },
                "AutoCut": {
                    "PowerMode": 1,
                    "BatteryPreWarning": \(batteryLevel < 15 ? 1 : 0),
                    "DeliveryMode": 0
                },
                "FOB": {
                    "LowBattery": 0
                },
                "PowerSupply": {
                    "Accessory": 1,
                    "Ignition1": 0,
                    "Ignition2": 0,
                    "Ignition3": 0
                }
            },
            "Green": {
                "DrivingReady": \(drivingReadyValue),
                "PowerConsumption": {
                    "Prediction": {
                        "Climate": 2
                    }
                },
                "BatteryManagement": {
                    "SoH": {
                        "Ratio": \(scenario == "maintenance" ? 94.2 : 97.8)
                    },
                    "BatteryRemain": {
                        "Value": \(Double(batteryLevel) * 2770.0),
                        "Ratio": \(Double(batteryLevel))
                    },
                    "BatteryConditioning": 0,
                    "BatteryPreCondition": {
                        "Status": 0,
                        "TemperatureLevel": 1
                    },
                    "BatteryCapacity": {
                        "Value": 277000.0
                    }
                },
                "Electric": {
                    "SmartGrid": {
                        "VehicleToLoad": {
                            "DischargeLimitation": {
                                "SoC": 20,
                                "RemainTime": 0
                            }
                        },
                        "VehicleToGrid": {
                            "Mode": 0
                        },
                        "RealTimePower": \(getChargingPower(for: scenario, isCharging: isCharging))
                    }
                },
                "ChargingInformation": {
                    "EstimatedTime": {
                        "ICCB": \(isCharging ? (100 - batteryLevel) * 8 : 0),
                        "Standard": \(isCharging ? (100 - batteryLevel) * 3 : 0),
                        "Quick": \(isCharging ? Int(Double(100 - batteryLevel) * 0.6) : 0),
                        "Unit": 1
                    },
                    "ExpectedTime": {
                        "StartDay": 0,
                        "StartHour": 22,
                        "StartMin": 0,
                        "EndDay": 0,
                        "EndHour": 6,
                        "EndMin": 0
                    },
                    "DTE": {
                        "TargetSoC": {
                            "Standard": 80,
                            "Quick": 90
                        }
                    },
                    "ConnectorFastening": {
                        "State": \(isCharging ? 1 : 0)
                    },
                    "SequenceDetails": 0,
                    "SequenceSubcode": 0,
                    "ElectricCurrentLevel": {
                        "State": \(getChargingCurrentLevel(for: scenario, isCharging: isCharging))
                    },
                    "Charging": {
                        "RemainTime": \(isCharging ? Double((100 - batteryLevel) * 3) : 0.0),
                        "RemainTimeUnit": 1
                    },
                    "TargetSoC": {
                        "Standard": 80,
                        "Quick": 90
                    }
                },
                "Reservation": {
                    "Departure": {
                        "Schedule1": {
                            "Hour": 6,
                            "Min": 30,
                            "Mon": 1,
                            "Tue": 1,
                            "Wed": 1,
                            "Thu": 1,
                            "Fri": 1,
                            "Sat": 0,
                            "Sun": 0,
                            "Climate": {
                                "Defrost": 0,
                                "TemperatureHex": "16",
                                "Temperature": "22"
                            },
                            "Enable": \(scenario == "charging" || scenario == "preconditioning" ? 1 : 0),
                            "Activation": 0
                        },
                        "Schedule2": {
                            "Hour": 0,
                            "Min": 0,
                            "Mon": 0,
                            "Tue": 0,
                            "Wed": 0,
                            "Thu": 0,
                            "Fri": 0,
                            "Sat": 0,
                            "Sun": 0,
                            "Enable": 0
                        },
                        "Climate": {
                            "Activation": \(scenario == "preconditioning" ? 1 : 0),
                            "TemperatureHex": "16",
                            "Defrost": 0,
                            "TemperatureUnit": 0,
                            "Temperature": "22"
                        },
                        "Climate2": {
                            "Activation": 0,
                            "TemperatureHex": "16",
                            "Defrost": 0,
                            "TemperatureUnit": 0,
                            "Temperature": "22"
                        }
                    },
                    "OffPeakTime": {
                        "StartHour": 23,
                        "StartMin": 0,
                        "EndHour": 6,
                        "EndMin": 0,
                        "Mode": 1
                    },
                    "OffPeakTime2": {
                        "StartHour": 0,
                        "StartMin": 0,
                        "EndHour": 0,
                        "EndMin": 0
                    }
                },
                "EnergyInformation": {
                    "DTE": {
                        "Invalid": 0
                    }
                },
                "ChargingDoor": {
                    "State": \(isCharging ? 1 : 2),
                    "ErrorState": 0
                },
                "PlugAndCharge": {
                    "ContractCertificate1": {
                        "Company": "Company1",
                        "CompanyMask": 0,
                        "State": 1,
                        "Year": 2024,
                        "Mon": 12
                    },
                    "ContractCertificate2": {
                        "Company": "Company2",
                        "CompanyMask": 0,
                        "State": 0,
                        "Year": 0,
                        "Mon": 0
                    },
                    "ContractCertificate3": {
                        "Company": "Company3",
                        "CompanyMask": 0,
                        "State": 0,
                        "Year": 0,
                        "Mon": 0
                    },
                    "ContractCertificate4": {
                        "Company": "Company4",
                        "CompanyMask": 0,
                        "State": 0,
                        "Year": 0,
                        "Mon": 0
                    },
                    "ContractCertificate5": {
                        "Company": "Company5",
                        "CompanyMask": 0,
                        "State": 0,
                        "Year": 0,
                        "Mon": 0
                    },
                    "ContractCertificate": {
                        "SelectedCert": 1,
                        "Changeable": 1,
                        "Mode": 1
                    }
                },
                "DrivingHistory": {
                    "Average": 4.2,
                    "Unit": 1
                }
            },
            "Service": {
                "ConnectedCar": {
                    "RemoteControl": {
                        "Available": 1,
                        "WaitingTime": 30
                    },
                    "ActiveAlert": {
                        "Available": 1
                    }
                }
            },
            "RemoteControl": {
                "SleepMode": 0
            },
            "ConnectedService": {
                "OTA": {
                    "ControllerStatus": 1
                }
            },
            "DrivingReady": \(drivingReadyValue),
            "Version": "24.1.0",
            "Date": "\(currentTime)",
            "Offset": "+00:00",
            "Location": {
                "Date": "\(currentTime)",
                "Offset": 0,
                "Servicestate": 1,
                "TimeStamp": {
                    "Day": 21,
                    "Hour": 15,
                    "Mon": 7,
                    "Year": 2025,
                    "Min": 30,
                    "Sec": 0
                },
                "Version": "1.0",
                "GeoCoord": {
                    "Altitude": \(getAltitude(for: scenario)),
                    "Latitude": \(getLatitude(for: scenario)),
                    "Longitude": \(getLongitude(for: scenario)),
                    "Type": 1
                },
                "Heading": \(chargingHeading),
                "Speed": {
                    "Unit": 1,
                    "Value": \(isCharging ? 0 : Double.random(in: 0...50))
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
    
    private static func getChargingPower(for scenario: String, isCharging: Bool) -> Double {
        if !isCharging { return 0.0 }
        
        switch scenario {
        case "charging": return 11.2  // AC charging
        case "fast_charging": return 150.0  // DC fast charging
        default: return 0.0
        }
    }
    
    private static func getChargingCurrentLevel(for scenario: String, isCharging: Bool) -> Int {
        if !isCharging { return 0 }
        
        switch scenario {
        case "charging": return 1  // AC charging
        case "fast_charging": return 2  // DC fast charging
        default: return 0
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
    
    /// Low tire pressure demo - 73% battery, multiple tires with low pressure
    static let lowTirePressure = createVehicleStatus(
        batteryLevel: 73,
        isCharging: false,
        drivingReady: true,
        scenario: "low_tire_pressure"
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
    
    /// Complete VehicleStatusResponse with low tire pressure scenario
    static let lowTirePressureResponse = createVehicleStatusResponse(vehicleStatus: lowTirePressure)
}

// MARK: - Vehicle Mock Data

extension MockVehicleData {
    
    /// Mock Vehicle object for components that need basic vehicle info
    static let mockVehicle: Vehicle = {
        let jsonString = """
        {
            "vin": "KNDC14CXPPH000123",
            "type": "EV",
            "vehicleId": "12345678-1234-1234-1234-123456789012",
            "vehicleName": "Kia - EV9 GT",
            "nickname": "My EV9",
            "tmuNum": "1234",
            "year": "2024",
            "regDate": 123,
            "master": true,
            "carShare": 0,
            "personalFlag": "",
            "detailInfo": {
                "bodyType": "SUV",
                "inColor": "",
                "outColor": "",
                "saleCarmdlCd": "John Doe",
                "saleCarmdlEnNm": "EV9"
            },
            "protocolType": 1,
            "ccuCCS2ProtocolSupport": 1
            
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
    static let lowTirePressurePreview = MockVehicleData.lowTirePressure
}

extension VehicleStatusResponse {
    /// Convenience properties for previews
    static let preview = MockVehicleData.standardResponse
    static let chargingPreview = MockVehicleData.chargingResponse
    static let lowBatteryPreview = MockVehicleData.lowBatteryResponse
    static let lowTirePressurePreview = MockVehicleData.lowTirePressureResponse
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
