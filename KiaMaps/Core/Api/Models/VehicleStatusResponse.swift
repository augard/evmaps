//
//  VehicleStatusResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 01.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - VehicleStatusResponse

/// Represents the complete vehicle status response from the API, containing detailed information
/// about the vehicle's current state including location, battery, climate, doors, and more.
///
/// This structure maps to the response from the vehicle status API endpoint that provides
/// real-time vehicle telemetry data for electric vehicles.
///
/// ## Example API Response Structure
/// ```json
/// {
///   "retCode": "S",
///   "resCode": "0000",
///   "resMsg": {
///     "resCode": "0000",
///     "ServiceNo": "RVS-K", 
///     "RetCode": "S",
///     "lastUpdateTime": "1753344063251",
///     "state": {
///       "Vehicle": {
///         "Location": { ... },
///         "Body": { ... },
///         "Cabin": { ... },
///         "Green": { ... }
///       }
///     }
///   },
///   "msgId": "c86a2dc0-6866-11f0-bc51-4c1fe9b3080a"
/// }
/// ```
///
/// ## Usage
/// ```swift
/// let response = try JSONDecoder().decode(VehicleStatusResponse.self, from: data)
/// let batteryLevel = response.state.vehicle.green.batteryManagement.batteryRemain.ratio
/// let isCharging = response.state.vehicle.isCharging
/// ```
struct VehicleStatusResponse: Codable {
    /// API result code indicating success/failure ("S" for success)
    let resultCode: String
    
    /// Service number identifier (e.g., "RVS-K")
    let serviceNumber: String
    
    /// Return code within the response
    let returnCode: String
    
    /// Timestamp of when the vehicle status was last updated
    @DateValue<TimeIntervalDateFormatter> private(set) var lastUpdateTime: Date
    
    /// The complete vehicle state information
    let state: State

    /// Wrapper for the main vehicle status data
    struct State: Codable {
        /// The detailed vehicle status information
        let vehicle: VehicleStatus

        enum CodingKeys: String, CodingKey {
            case vehicle = "Vehicle"
        }
    }

    enum CodingKeys: String, CodingKey {
        case resultCode = "resCode"
        case serviceNumber = "ServiceNo"
        case returnCode = "RetCode"
        case lastUpdateTime
        case state
    }
}

// MARK: - VehicleStatus

/// Represents the complete vehicle status containing all subsystem information.
/// This is the main data structure that holds real-time information about the vehicle's
/// current state across all systems including location, body, cabin, chassis, and electric systems.
struct VehicleStatus: Codable {
    /// Vehicle body status including doors, lights, hood, trunk, and windshield systems
    let body: VehicleBody
    
    /// Vehicle cabin status including HVAC, doors, seats, windows, and steering wheel
    let cabin: VehicleCabin
    
    /// Vehicle chassis information including tires, brakes, and driving mode
    let chassis: VehicleChassis
    
    /// Drivetrain status including fuel system, odometer, and transmission
    let drivetrain: VehicleDrivetrain
    
    /// Electronic systems status including battery, power supply, and FOB
    let electronics: VehicleElectronics
    
    /// Electric vehicle specific systems including charging, battery management, and energy information
    let green: VehicleGreen
    
    /// Connected car services status
    let service: Service
    
    /// Remote control capabilities and sleep mode status
    let remoteControl: RemoteControl
    
    /// Connected services including OTA updates
    let connectedService: ConnectedService
    
    /// Whether the vehicle is ready to drive (true if ready)
    @BoolValue private(set) var drivingReady: Bool
    
    /// Version string for this status data format
    let version: String
    
    /// Date and time when this status was generated
    @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
    
    /// Timezone offset for the timestamp
    let offset: String
    
    /// Vehicle GPS location and movement information
    let location: Location

    /// Computed property that determines if the vehicle is currently charging
    /// Returns true if both the charging connector is fastened and the charging door is open
    var isCharging: Bool {
        let chargingInfo = green.chargingInformation
        let isConnectorFastened = chargingInfo.connectorFastening.state > 0
        let chargingDoorOpen = green.chargingDoor.state == .open
        return isConnectorFastened && chargingDoorOpen
    }

    /// Remote control capabilities for the vehicle
    struct RemoteControl: Codable {
        /// Whether the vehicle's remote control system is in sleep mode
        @BoolValue private(set) var sleepMode: Bool

        enum CodingKeys: String, CodingKey {
            case sleepMode = "SleepMode"
        }
    }
    
    /// Connected services status including over-the-air updates
    struct ConnectedService: Codable {
        /// Over-the-air update system status
        let ota: Ota

        /// OTA (Over-The-Air) update system information
        struct Ota: Codable {
            /// Whether the OTA controller is active
            @BoolValue private(set) var controllerStatus: Bool

            enum CodingKeys: String, CodingKey {
                case controllerStatus = "ControllerStatus"
            }
        }

        enum CodingKeys: String, CodingKey {
            case ota = "OTA"
        }
    }

    enum CodingKeys: String, CodingKey {
        case body = "Body"
        case cabin = "Cabin"
        case chassis = "Chassis"
        case drivetrain = "Drivetrain"
        case electronics = "Electronics"
        case green = "Green"
        case service = "Service"
        case remoteControl = "RemoteControl"
        case connectedService = "ConnectedService"
        case drivingReady = "DrivingReady"
        case version = "Version"
        case date = "Date"
        case offset = "Offset"
        case location = "Location"
    }
}

// MARK: - VehicleBody

/// Represents the vehicle's body systems including external components and their status.
/// Contains information about doors, lights, hood, trunk, windshield, and sunroof systems.
struct VehicleBody: Codable {
    /// Windshield defog, heat, and washer fluid systems
    let windshield: Windshield
    
    /// Hood and frunk (front trunk) status
    let hood: Hood
    
    /// All vehicle lighting systems (headlights, taillights, turn signals, hazards)
    let lights: VehicleLights
    
    /// Sunroof status (optional, not all vehicles have sunroofs)
    let sunroof: Sunroof?
    
    /// Trunk open/closed status
    let trunk: Trunk

    /// Trunk/tailgate status
    struct Trunk: Codable {
        /// Whether the trunk is currently open
        @BoolValue private(set) var open: Bool

        enum CodingKeys: String, CodingKey {
            case open = "Open"
        }
    }

    /// Sunroof system status
    struct Sunroof: Codable {
        /// Glass panel status (uses same structure as trunk for open/closed state)
        let glass: Trunk

        enum CodingKeys: String, CodingKey {
            case glass = "Glass"
        }
    }

    /// Windshield systems including defog, heating, and washer fluid
    struct Windshield: Codable {
        /// Front windshield systems
        let front: WindshieldFront
        
        /// Rear windshield systems
        let rear: WindshieldRear
        
        /// Generic state mode structure for boolean states
        struct StateMode: Codable {
            /// Whether this system is currently active
            @BoolValue private(set) var state: Bool

            enum CodingKeys: String, CodingKey {
                case state = "State"
            }
        }

        /// Rear windshield defog system
        struct WindshieldRear: Codable {
            /// Rear windshield defog status
            let defog: StateMode

            enum CodingKeys: String, CodingKey {
                case defog = "Defog"
            }
        }

        /// Front windshield systems including heating, defog, and washer fluid
        struct WindshieldFront: Codable {
            /// Front windshield heating system status
            let heat: StateMode
            
            /// Front windshield defog system status
            let defog: StateMode
            
            /// Washer fluid level information
            let washerFluid: WasherFluid

            /// Windshield washer fluid system status
            struct WasherFluid: Codable {
                /// Whether the washer fluid level is low (true if low)
                @BoolValue private(set) var levelLow: Bool

                enum CodingKeys: String, CodingKey {
                    case levelLow = "LevelLow"
                }
            }

            enum CodingKeys: String, CodingKey {
                case heat = "Heat"
                case defog = "Defog"
                case washerFluid = "WasherFluid"
            }
        }

        enum CodingKeys: String, CodingKey {
            case rear = "Rear"
            case front = "Front"
        }
    }

    struct Hood: Codable {
        @BoolValue private(set) var open: Bool
        let frunk: Frunk

        enum CodingKeys: String, CodingKey {
            case open = "Open"
            case frunk = "Frunk"
        }
    }

    struct Frunk: Codable {
        @BoolValue private(set) var fault: Bool

        enum CodingKeys: String, CodingKey {
            case fault = "Fault"
        }
    }

    enum CodingKeys: String, CodingKey {
        case windshield = "Windshield"
        case hood = "Hood"
        case lights = "Lights"
        case sunroof = "Sunroof"
        case trunk = "Trunk"
    }
}

struct VehicleLights: Codable {
    let front: LightsFront
    let dischargeAlert: RESTMode
    let rear: LightsRear
    let tailLamp: Hazard
    let hazard: Hazard

    struct LightsFront: Codable {
        let headLamp: HeadLamp
        let frontLeft: FrontLight
        let frontRight: FrontLight

        struct HeadLamp: Codable {
            let systemWarning: Int

            enum CodingKeys: String, CodingKey {
                case systemWarning = "SystemWarning"
            }
        }

        struct FrontLight: Codable {
            let low: VehicleFluid
            let high: VehicleFluid
            let turnSignal: TurnSignal

            struct TurnSignal: Codable {
                @BoolValue private(set) var warning: Bool
                let lampState: Int

                enum CodingKeys: String, CodingKey {
                    case warning = "Warning"
                    case lampState = "LampState"
                }
            }

            enum CodingKeys: String, CodingKey {
                case low = "Low"
                case high = "High"
                case turnSignal = "TurnSignal"
            }
        }

        enum CodingKeys: String, CodingKey {
            case headLamp = "HeadLamp"
            case frontLeft = "Left"
            case frontRight = "Right"
        }
    }

    struct LightsRear: Codable {
        let rearLeft: RearLight
        let rearRight: RearLight

        enum CodingKeys: String, CodingKey {
            case rearLeft = "Left"
            case rearRight = "Right"
        }
    }

    struct RearLight: Codable {
        let stopLamp: VehicleFluid
        let turnSignal: VehicleFluid

        enum CodingKeys: String, CodingKey {
            case stopLamp = "StopLamp"
            case turnSignal = "TurnSignal"
        }
    }

    struct Hazard: Codable {
        @BoolValue private(set) var alert: Bool

        enum CodingKeys: String, CodingKey {
            case alert = "Alert"
        }
    }

    enum CodingKeys: String, CodingKey {
        case front = "Front"
        case dischargeAlert = "DischargeAlert"
        case rear = "Rear"
        case tailLamp = "TailLamp"
        case hazard = "Hazard"
    }
}

struct RESTMode: Codable {
    let state: Int

    enum CodingKeys: String, CodingKey {
        case state = "State"
    }
}

struct VehicleFluid: Codable {
    @BoolValue private(set) var warning: Bool

    enum CodingKeys: String, CodingKey {
        case warning = "Warning"
    }
}

struct VehicleCabin: Codable {
    let restMode: RESTMode
    let hvac: VehicleHVAC
    let door: VehicleDoor
    let seat: VehicleSeat
    let window: VehicleWindow
    let steeringWheel: SteeringWheel
    
    struct SteeringWheel: Codable {
        let heat: Heat?
        
        struct Heat: Codable {
            let remoteControl: RemoteControl
            @BoolValue private(set) var state: Bool

            struct RemoteControl: Codable {
                let step: Int

                enum CodingKeys: String, CodingKey {
                    case step = "Step"
                }
            }

            enum CodingKeys: String, CodingKey {
                case remoteControl = "RemoteControl"
                case state = "State"
            }
        }

        enum CodingKeys: String, CodingKey {
            case heat = "Heat"
        }
    }

    enum CodingKeys: String, CodingKey {
        case restMode = "RestMode"
        case hvac = "HVAC"
        case door = "Door"
        case seat = "Seat"
        case window = "Window"
        case steeringWheel = "SteeringWheel"
    }
}

struct VehicleDoor: Codable {
    let row1: Row1
    let row2: Row2

    struct Status: Codable {
        @BoolValue private(set) var lock: Bool
        @BoolValue private(set) var open: Bool

        enum CodingKeys: String, CodingKey {
            case lock = "Lock"
            case open = "Open"
        }
    }

    struct Row1: Codable {
        let passenger: Status
        let driver: Status

        enum CodingKeys: String, CodingKey {
            case passenger = "Passenger"
            case driver = "Driver"
        }
    }

    struct Row2: Codable {
        let left: Status
        let right: Status

        enum CodingKeys: String, CodingKey {
            case left = "Left"
            case right = "Right"
        }
    }

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case row2 = "Row2"
    }
}

// MARK: - Hvac

struct VehicleHVAC: Codable {
    let row1: Row1
    let ventilation: Ventilation
    let temperature: Temperature

    struct Ventilation: Codable {
        let fineDust: FineDust
        let airCleaning: AirCleaning

        struct FineDust: Codable {
            let level: Int

            enum CodingKeys: String, CodingKey {
                case level = "Level"
            }
        }

        struct AirCleaning: Codable {
            let indicator: Int
            let symbolColor: Int

            enum CodingKeys: String, CodingKey {
                case indicator = "Indicator"
                case symbolColor = "SymbolColor"
            }
        }

        enum CodingKeys: String, CodingKey {
            case fineDust = "FineDust"
            case airCleaning = "AirCleaning"
        }
    }

    struct Temperature: Codable {
        let rangeType: Int

        enum CodingKeys: String, CodingKey {
            case rangeType = "RangeType"
        }
    }

    struct Row1: Codable {
        let driver: Driver

        struct Driver: Codable {
            let temperature: DriverTemperature
            let blower: Blower

            struct DriverTemperature: Codable {
                let value: String
                let unit: TemperatureUnit

                enum CodingKeys: String, CodingKey {
                    case value = "Value"
                    case unit = "Unit"
                }
            }

            enum CodingKeys: String, CodingKey {
                case temperature = "Temperature"
                case blower = "Blower"
            }
        }

        enum CodingKeys: String, CodingKey {
            case driver = "Driver"
        }
    }
    
    struct Blower: Codable {
        let speedLevel: Int

        enum CodingKeys: String, CodingKey {
            case speedLevel = "SpeedLevel"
        }
    }

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case ventilation = "Vent"
        case temperature = "Temperature"
    }
}

// MARK: - Seat

struct VehicleSeat: Codable {
    let row1: Row1
    let row2: Row2

    struct Seat: Codable {
        let climate: RESTMode

        enum CodingKeys: String, CodingKey {
            case climate = "Climate"
        }
    }

    struct Row1: Codable {
        let passenger: Seat
        let driver: Seat

        enum CodingKeys: String, CodingKey {
            case passenger = "Passenger"
            case driver = "Driver"
        }
    }

    struct Row2: Codable {
        let left: Seat
        let right: Seat

        enum CodingKeys: String, CodingKey {
            case left = "Left"
            case right = "Right"
        }
    }

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case row2 = "Row2"
    }
}

// MARK: - Window

struct VehicleWindow: Codable {
    let row1: Row1
    let row2: Row2

    struct Window: Codable {
        @BoolValue private(set) var open: Bool
        let openLevel: Int

        enum CodingKeys: String, CodingKey {
            case open = "Open"
            case openLevel = "OpenLevel"
        }
    }

    struct Row1: Codable {
        let driver: Window
        let passenger: Window

        enum CodingKeys: String, CodingKey {
            case driver = "Driver"
            case passenger = "Passenger"
        }
    }

    struct Row2: Codable {
        let left: Window
        let right: Window

        enum CodingKeys: String, CodingKey {
            case left = "Left"
            case right = "Right"
        }
    }

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case row2 = "Row2"
    }
}

// MARK: - Chassis

struct VehicleChassis: Codable {
    let drivingMode: DrivingMode
    let axle: Axle
    let brake: Brake

    struct DrivingMode: Codable {
        let state: String

        enum CodingKeys: String, CodingKey {
            case state = "State"
        }
    }
    
    struct Axle: Codable {
        let row1: TireRow
        let row2: TireRow
        let tire: Tire
        
        enum CodingKeys: String, CodingKey {
            case row1 = "Row1"
            case row2 = "Row2"
            case tire = "Tire"
        }
    }

    struct Tire: Codable {
        @BoolValue private(set) var pressureLow: Bool
        let pressureUnit: Int

        enum CodingKeys: String, CodingKey {
            case pressureLow = "PressureLow"
            case pressureUnit = "PressureUnit"
        }
    }

    struct TireRow: Codable {
        let left: Tire
        let right: Tire
        
        struct Tire: Codable {
            let tire: Pressure

            struct Pressure: Codable {
                @BoolValue private(set) var pressureLow: Bool
                let pressure: Int

                enum CodingKeys: String, CodingKey {
                    case pressureLow = "PressureLow"
                    case pressure = "Pressure"
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case tire = "Tire"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case left = "Left"
            case right = "Right"
        }
    }
    
    struct Brake: Codable {
        let fluid: VehicleFluid

        enum CodingKeys: String, CodingKey {
            case fluid = "Fluid"
        }
    }

    enum CodingKeys: String, CodingKey {
        case drivingMode = "DrivingMode"
        case axle = "Axle"
        case brake = "Brake"
    }
}

// MARK: - Drivetrain

struct VehicleDrivetrain: Codable {
    let fuelSystem: FuelSystem
    let odometer: Double
    let transmission: Transmission

    struct FuelSystem: Codable {
        let dte: Dte
        @BoolValue private(set) var lowFuelWarning: Bool
        let fuelLevel: Int
        let averageFuelEconomy: AverageFuelEconomy

        struct Dte: Codable {
            let unit: DistanceUnit
            let total: Int

            enum CodingKeys: String, CodingKey {
                case unit = "Unit"
                case total = "Total"
            }
        }

        struct AverageFuelEconomy: Codable {
            let drive: Double
            let afterRefuel: Double
            let accumulated: Double
            let unit: EconomyUnit

            enum CodingKeys: String, CodingKey {
                case drive = "Drive"
                case afterRefuel = "AfterRefuel"
                case accumulated = "Accumulated"
                case unit = "Unit"
            }
        }

        enum CodingKeys: String, CodingKey {
            case dte = "DTE"
            case lowFuelWarning = "LowFuelWarning"
            case fuelLevel = "FuelLevel"
            case averageFuelEconomy = "AverageFuelEconomy"
        }
    }

    struct Transmission: Codable {
        @BoolValue private(set) var parkingPosition: Bool
        let gearPosition: Int

        enum CodingKeys: String, CodingKey {
            case parkingPosition = "ParkingPosition"
            case gearPosition = "GearPosition"
        }
    }

    enum CodingKeys: String, CodingKey {
        case fuelSystem = "FuelSystem"
        case odometer = "Odometer"
        case transmission = "Transmission"
    }
}

// MARK: - Electronics

struct VehicleElectronics: Codable {
    let battery: Battery
    let autoCut: AutoCut
    let fob: Fob
    let powerSupply: PowerSupply

    struct Battery: Codable {
        let auxiliary: Auxiliary
        let level: Int
        let charging: BatteryCharging
        let powerStateAlert: PowerStateAlert
        let sensorReliability: Int

        struct Auxiliary: Codable {
            @BoolValue private(set) var failWarning: Bool

            enum CodingKeys: String, CodingKey {
                case failWarning = "FailWarning"
            }
        }

        struct BatteryCharging: Codable {
            let warningLevel: Int

            enum CodingKeys: String, CodingKey {
                case warningLevel = "WarningLevel"
            }
        }

        struct PowerStateAlert: Codable {
            let classC: Int

            enum CodingKeys: String, CodingKey {
                case classC = "ClassC"
            }
        }

        enum CodingKeys: String, CodingKey {
            case auxiliary = "Auxiliary"
            case level = "Level"
            case charging = "Charging"
            case powerStateAlert = "PowerStateAlert"
            case sensorReliability = "SensorReliability"
        }
    }

    struct AutoCut: Codable {
        let powerMode: Int
        @BoolValue private(set) var batteryPreWarning: Bool
        let deliveryMode: Int

        enum CodingKeys: String, CodingKey {
            case powerMode = "PowerMode"
            case batteryPreWarning = "BatteryPreWarning"
            case deliveryMode = "DeliveryMode"
        }
    }

    struct Fob: Codable {
        @BoolValue private(set) var lowBattery: Bool

        enum CodingKeys: String, CodingKey {
            case lowBattery = "LowBattery"
        }
    }

    struct PowerSupply: Codable {
        let accessory: Int
        let ignition1: Int?
        let ignition2: Int?
        let ignition3: Int?

        enum CodingKeys: String, CodingKey {
            case accessory = "Accessory"
            case ignition1 = "Ignition1"
            case ignition2 = "Ignition2"
            case ignition3 = "Ignition3"
        }
    }

    enum CodingKeys: String, CodingKey {
        case battery = "Battery"
        case autoCut = "AutoCut"
        case fob = "FOB"
        case powerSupply = "PowerSupply"
    }
}

// MARK: - VehicleGreen (Electric Vehicle Systems)

/// Contains all electric vehicle specific systems including battery management, charging, and energy information.
/// This is the core structure for EV-specific data that differentiates electric vehicles from traditional vehicles.
struct VehicleGreen: Codable {
    /// Whether the electric drivetrain is ready for driving
    @BoolValue private(set) var drivingReady: Bool
    
    /// Power consumption predictions and climate impact
    let powerConsumption: VehiclePowerConsumption
    
    /// Battery management system including state of health, capacity, and remaining charge
    let batteryManagement: VehicleBatteryManagement
    
    /// Smart grid and vehicle-to-load/grid capabilities
    let electric: Electric
    
    /// Charging status, times, and connector information
    let chargingInformation: VehicleChargingInformation
    
    /// Charging and climate scheduling reservations
    let reservation: Reservation
    
    /// Energy consumption and distance-to-empty information
    let energyInformation: EnergyInformation
    
    /// Charging port door status and error information
    let chargingDoor: ChargingDoor
    
    /// Plug & Charge authentication and contract information
    let plugAndCharge: PlugAndCharge
    
    /// Historical driving efficiency data
    let drivingHistory: DrivingHistory
    
    /// Charging port door status and diagnostics
    struct ChargingDoor: Codable {
        /// Current state of the charging door (open/closed)
        let state: ChargeDoorStatus
        
        /// Error state code (0 = no error)
        let errorState: Int

        enum CodingKeys: String, CodingKey {
            case state = "State"
            case errorState = "ErrorState"
        }
    }

    enum CodingKeys: String, CodingKey {
        case drivingReady = "DrivingReady"
        case powerConsumption = "PowerConsumption"
        case batteryManagement = "BatteryManagement"
        case electric = "Electric"
        case chargingInformation = "ChargingInformation"
        case reservation = "Reservation"
        case energyInformation = "EnergyInformation"
        case chargingDoor = "ChargingDoor"
        case plugAndCharge = "PlugAndCharge"
        case drivingHistory = "DrivingHistory"
    }
}

// MARK: - VehicleBatteryManagement

/// Battery management system containing all battery-related status and health information.
/// This system monitors battery condition, remaining capacity, and thermal management.
struct VehicleBatteryManagement: Codable {
    /// State of Health - overall battery condition and degradation level
    let soH: SoH
    
    /// Current battery charge remaining in both absolute and percentage values
    let batteryRemain: BatteryRemain
    
    /// Whether battery thermal conditioning is currently active
    @BoolValue private(set) var batteryConditioning: Bool
    
    /// Battery pre-conditioning status for optimal charging/performance
    let batteryPreCondition: BatteryPreCondition
    
    /// Total battery capacity information
    let batteryCapacity: BatteryCapacity

    /// State of Health information indicating battery degradation
    struct SoH: Codable {
        /// Battery health percentage (100% = new battery, lower values indicate degradation)
        let ratio: Double

        enum CodingKeys: String, CodingKey {
            case ratio = "Ratio"
        }
    }

    /// Current battery charge information
    struct BatteryRemain: Codable {
        /// Remaining battery energy in kiloJoules (absolute value)
        let value: Double // e.g., 127324.8 kJ
        
        /// Remaining battery charge as percentage (0-100%)
        let ratio: Double // e.g., 39%

        enum CodingKeys: String, CodingKey {
            case value = "Value"
            case ratio = "Ratio"
        }
    }

    struct BatteryPreCondition: Codable {
        let status: Int
        let temperatureLevel: Int

        enum CodingKeys: String, CodingKey {
            case status = "Status"
            case temperatureLevel = "TemperatureLevel"
        }
    }

    struct BatteryCapacity: Codable {
        let value: Double // kiloJoules

        enum CodingKeys: String, CodingKey {
            case value = "Value"
        }
    }

    enum CodingKeys: String, CodingKey {
        case soH = "SoH"
        case batteryRemain = "BatteryRemain"
        case batteryConditioning = "BatteryConditioning"
        case batteryPreCondition = "BatteryPreCondition"
        case batteryCapacity = "BatteryCapacity"
    }
}

// MARK: - ChargingInformation

struct VehicleChargingInformation: Codable {
    let estimatedTime: EstimatedTime
    let expectedTime: ExpectedTime
    let dte: Dte
    let connectorFastening: RESTMode
    let sequenceDetails: Int
    let sequenceSubcode: Int
    let electricCurrentLevel: RESTMode
    let charging: Charging
    let targetSoC: TargetSoC

    struct EstimatedTime: Codable {
        let iccb: Int // 1110, minutes, el-plug
        let standard: Int // 240, minuts, ac
        let quick: Int // 44, minutes, dc
        let unit: TimeUnit

        enum CodingKeys: String, CodingKey {
            case iccb = "ICCB"
            case standard = "Standard"
            case quick = "Quick"
            case unit = "Unit"
        }
    }

    struct ExpectedTime: Codable {
        let startDay: Int
        let startHour: Int
        let startMin: Int
        let endDay: Int
        let endHour: Int
        let endMin: Int

        enum CodingKeys: String, CodingKey {
            case startDay = "StartDay"
            case startHour = "StartHour"
            case startMin = "StartMin"
            case endDay = "EndDay"
            case endHour = "EndHour"
            case endMin = "EndMin"
        }
    }

    struct Dte: Codable {
        let targetSoC: TargetSoC // Not %

        enum CodingKeys: String, CodingKey {
            case targetSoC = "TargetSoC"
        }
    }

    struct TargetSoC: Codable {
        let standard: Int // 80, %, ac
        let quick: Int // 100 %, dc

        enum CodingKeys: String, CodingKey {
            case standard = "Standard"
            case quick = "Quick"
        }
    }

    struct Charging: Codable {
        let remainTime: Double
        let remainTimeUnit: TimeUnit

        enum CodingKeys: String, CodingKey {
            case remainTime = "RemainTime"
            case remainTimeUnit = "RemainTimeUnit"
        }
    }

    enum CodingKeys: String, CodingKey {
        case estimatedTime = "EstimatedTime"
        case expectedTime = "ExpectedTime"
        case dte = "DTE"
        case connectorFastening = "ConnectorFastening"
        case sequenceDetails = "SequenceDetails"
        case sequenceSubcode = "SequenceSubcode"
        case electricCurrentLevel = "ElectricCurrentLevel"
        case charging = "Charging"
        case targetSoC = "TargetSoC"
    }
}

// MARK: - DrivingHistory

struct DrivingHistory: Codable {
    let average: Double
    let unit: DistanceUnit

    enum CodingKeys: String, CodingKey {
        case average = "Average"
        case unit = "Unit"
    }
}

// MARK: - Electric

struct Electric: Codable {
    let smartGrid: SmartGrid

    struct SmartGrid: Codable {
        let vehicleToLoad: VehicleToLoad
        let vehicleToGrid: VehicleToGrid
        let realTimePower: Double

        struct VehicleToGrid: Codable {
            @BoolValue private(set) var mode: Bool

            enum CodingKeys: String, CodingKey {
                case mode = "Mode"
            }
        }

        struct VehicleToLoad: Codable {
            let dischargeLimitation: DischargeLimitation

            struct DischargeLimitation: Codable {
                var soc: Int
                var remainTime: Int

                enum CodingKeys: String, CodingKey {
                    case soc = "SoC"
                    case remainTime = "RemainTime"
                }
            }

            enum CodingKeys: String, CodingKey {
                case dischargeLimitation = "DischargeLimitation"
            }
        }

        enum CodingKeys: String, CodingKey {
            case vehicleToLoad = "VehicleToLoad"
            case vehicleToGrid = "VehicleToGrid"
            case realTimePower = "RealTimePower"
        }
    }

    enum CodingKeys: String, CodingKey {
        case smartGrid = "SmartGrid"
    }
}

// MARK: - EnergyInformation

struct EnergyInformation: Codable {
    let dte: EnergyInformationDte

    struct EnergyInformationDte: Codable {
        let invalid: Int

        enum CodingKeys: String, CodingKey {
            case invalid = "Invalid"
        }
    }

    enum CodingKeys: String, CodingKey {
        case dte = "DTE"
    }
}

// MARK: - PlugAndCharge

struct PlugAndCharge: Codable {
    let contractCertificate1: ContractCertificate
    let contractCertificate2: ContractCertificate
    let contractCertificate3: ContractCertificate
    let contractCertificate4: ContractCertificate
    let contractCertificate5: ContractCertificate
    let selection: Selection

    struct Selection: Codable {
        let selectedCert: Int
        private(set) var changeable: Int
        let mode: Int

        enum CodingKeys: String, CodingKey {
            case selectedCert = "SelectedCert"
            case changeable = "Changeable"
            case mode = "Mode"
        }
    }

    struct ContractCertificate: Codable {
        let company: String
        let companyMask: Int
        let state: Int
        let year: Int
        let month: Int

        enum CodingKeys: String, CodingKey {
            case company = "Company"
            case companyMask = "CompanyMask"
            case state = "State"
            case year = "Year"
            case month = "Mon"
        }
    }

    enum CodingKeys: String, CodingKey {
        case contractCertificate1 = "ContractCertificate1"
        case contractCertificate2 = "ContractCertificate2"
        case contractCertificate3 = "ContractCertificate3"
        case contractCertificate4 = "ContractCertificate4"
        case contractCertificate5 = "ContractCertificate5"
        case selection = "ContractCertificate"
    }
}

// MARK: - VehiclePowerConsumption

struct VehiclePowerConsumption: Codable {
    let prediction: Prediction

    struct Prediction: Codable {
        let climate: Int

        enum CodingKeys: String, CodingKey {
            case climate = "Climate"
        }
    }

    enum CodingKeys: String, CodingKey {
        case prediction = "Prediction"
    }
}

// MARK: - Reservation

struct Reservation: Codable {
    let departure: Departure
    let offPeakTime1: OffPeakTime
    let offPeakTime2: OffPeakTime

    struct Departure: Codable {
        let schedule1: Schedule
        let schedule2: Schedule
        let climate1: Climate
        let climate2: Climate

        struct Schedule: Codable {
            let hour: Int
            let minute: Int
            let monday: Int
            let tuesday: Int
            let wensday: Int
            let thursday: Int
            let friday: Int
            let saturday: Int
            let sunday: Int
            let climate: Climate?
            @BoolValue private(set) var enable: Bool
            let activation: Int?

            struct Climate: Codable {
                @BoolValue private(set) var defrost: Bool
                let temperatureHex: String
                let temperature: String

                enum CodingKeys: String, CodingKey {
                    case defrost = "Defrost"
                    case temperatureHex = "TemperatureHex"
                    case temperature = "Temperature"
                }
            }

            enum CodingKeys: String, CodingKey {
                case hour = "Hour"
                case minute = "Min"

                case monday = "Mon"
                case tuesday = "Tue"
                case wensday = "Wed"
                case thursday = "Thu"
                case friday = "Fri"
                case saturday = "Sat"
                case sunday = "Sun"
                case climate = "Climate"

                case enable = "Enable"
                case activation = "Activation"
            }
        }

        struct Climate: Codable {
            @BoolValue private(set) var activation: Bool
            let temperatureHex: String
            @BoolValue private(set) var defrost: Bool
            let temperatureUnit: TemperatureUnit
            let temperature: String

            enum CodingKeys: String, CodingKey {
                case activation = "Activation"
                case temperatureHex = "TemperatureHex"
                case defrost = "Defrost"
                case temperatureUnit = "TemperatureUnit"
                case temperature = "Temperature"
            }
        }

        enum CodingKeys: String, CodingKey {
            case schedule1 = "Schedule1"
            case schedule2 = "Schedule2"
            case climate1 = "Climate"
            case climate2 = "Climate2"
        }
    }

    struct OffPeakTime: Codable {
        let startHour: Int
        let startMin: Int
        let endHour: Int
        let endMin: Int
        let mode: Int?

        enum CodingKeys: String, CodingKey {
            case startHour = "StartHour"
            case startMin = "StartMin"
            case endHour = "EndHour"
            case endMin = "EndMin"
            case mode = "Mode"
        }
    }

    enum CodingKeys: String, CodingKey {
        case departure = "Departure"
        case offPeakTime1 = "OffPeakTime"
        case offPeakTime2 = "OffPeakTime2"
    }
}

// MARK: - Location

/// Vehicle GPS location and movement information.
/// Contains precise positioning data, movement direction, speed, and timestamp information.
struct Location: Codable {
    /// Date and time when this location was recorded
    @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
    
    /// Timezone offset for the timestamp
    let offset: Int
    
    /// GPS service state (0 = normal operation)
    let servicestate: Int
    
    /// Detailed timestamp breakdown
    let timeStamp: TimeStamp
    
    /// Version string for location data format
    let version: String
    
    /// GPS coordinates including latitude, longitude, and altitude
    let geoCoordinate: GeoCoordinate
    
    /// Vehicle heading/direction in degrees (0-360°, 0 = North)
    let heading: Double
    
    /// Current vehicle speed
    let speed: Speed

    /// Detailed timestamp information broken down into components
    struct TimeStamp: Codable {
        /// Day of the month (1-31)
        let day: Int
        
        /// Month of the year (1-12)
        let month: Int
        
        /// Year (e.g., 2025)
        let year: Int
        
        /// Hour in 24-hour format (0-23)
        let hour: Int
        
        /// Minute (0-59)
        let minute: Int
        
        /// Seconds (0-59)
        let seconds: Int

        /// Converts the timestamp components to a Date object
        /// - Returns: Date object constructed from the timestamp components, or nil if invalid
        var toDate: Date? {
            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = year
            components.hour = hour
            components.minute = minute
            components.second = seconds
            return Calendar.current.date(from: components)
        }

        enum CodingKeys: String, CodingKey {
            case day = "Day"
            case hour = "Hour"
            case month = "Mon"
            case year = "Year"
            case minute = "Min"
            case seconds = "Sec"
        }
    }

    /// GPS coordinate information with altitude
    struct GeoCoordinate: Codable {
        /// Altitude above sea level in meters
        let altitude: Double
        
        /// Latitude coordinate in degrees (-90 to +90)
        let latitude: Double
        
        /// Longitude coordinate in degrees (-180 to +180)
        let longitude: Double
        
        /// Coordinate type identifier (0 = standard GPS coordinates)
        let type: Int

        /// Converts GPS coordinates to CoreLocation CLLocation object
        /// - Returns: CLLocation object with GPS coordinates and altitude
        var location: CLLocation {
            .init(
                coordinate: .init(latitude: latitude, longitude: longitude),
                altitude: altitude,
                horizontalAccuracy: 100,
                verticalAccuracy: 100,
                timestamp: .now
            )
        }

        enum CodingKeys: String, CodingKey {
            case altitude = "Altitude"
            case latitude = "Latitude"
            case longitude = "Longitude"
            case type = "Type"
        }
    }

    /// Vehicle speed information
    struct Speed: Codable {
        /// Speed unit (0 = km/h, 1 = mph)
        let unit: SpeedUnit
        
        /// Current speed value in the specified unit
        let value: Double

        enum CodingKeys: String, CodingKey {
            case unit = "Unit"
            case value = "Value"
        }
    }

    enum CodingKeys: String, CodingKey {
        case date = "Date"
        case offset = "Offset"
        case servicestate = "Servicestate"
        case timeStamp = "TimeStamp"
        case version = "Version"
        case geoCoordinate = "GeoCoord"
        case heading = "Heading"
        case speed = "Speed"
    }
}

// MARK: - Service

struct Service: Codable {
    let connectedCar: ConnectedCar

    struct ConnectedCar: Codable {
        let remoteControl: ConnectedCarRemoteControl
        let activeAlert: ActiveAlert

        struct ConnectedCarRemoteControl: Codable {
            @BoolValue private(set) var available: Bool
            let waitingTime: TimeInterval

            enum CodingKeys: String, CodingKey {
                case available = "Available"
                case waitingTime = "WaitingTime"
            }
        }

        struct ActiveAlert: Codable {
            @BoolValue private(set) var available: Bool

            enum CodingKeys: String, CodingKey {
                case available = "Available"
            }
        }

        enum CodingKeys: String, CodingKey {
            case remoteControl = "RemoteControl"
            case activeAlert = "ActiveAlert"
        }
    }

    enum CodingKeys: String, CodingKey {
        case connectedCar = "ConnectedCar"
    }
}
