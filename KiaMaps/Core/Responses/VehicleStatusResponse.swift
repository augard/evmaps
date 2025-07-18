//
//  VehicleStatusResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 01.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - ResMsg

struct VehicleStatusResponse: Codable {
    let resultCode: String
    let serviceNumber: String
    let returnCode: String
    @DateValue<TimeIntervalDateFormatter> private(set) var lastUpdateTime: Date
    let state: State

    struct State: Codable {
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

// MARK: - Vehicle

struct VehicleStatus: Codable {
    let body: VehicleBody
    let cabin: VehicleCabin
    let chassis: VehicleChassis
    let drivetrain: VehicleDrivetrain
    let electronics: VehicleElectronics
    let green: VehicleGreen
    let service: Service
    let remoteControl: RemoteControl
    let connectedService: ConnectedService
    @BoolValue private(set) var drivingReady: Bool
    let version: String
    @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
    let offset: String
    let location: Location
    
    struct RemoteControl: Codable {
        @BoolValue private(set) var sleepMode: Bool

        enum CodingKeys: String, CodingKey {
            case sleepMode = "SleepMode"
        }
    }
    
    struct ConnectedService: Codable {
        let ota: Ota

        struct Ota: Codable {
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

// MARK: - Body

struct VehicleBody: Codable {
    let windshield: Windshield
    let hood: Hood
    let lights: VehicleLights
    let sunroof: Sunroof?
    let trunk: Trunk

    struct Trunk: Codable {
        @BoolValue private(set) var open: Bool

        enum CodingKeys: String, CodingKey {
            case open = "Open"
        }
    }

    struct Sunroof: Codable {
        let glass: Trunk

        enum CodingKeys: String, CodingKey {
            case glass = "Glass"
        }
    }

    struct Windshield: Codable {
        let front: WindshieldFront
        let rear: WindshieldRear
        
        struct StateMode: Codable {
            @BoolValue private(set) var state: Bool

            enum CodingKeys: String, CodingKey {
                case state = "State"
            }
        }

        struct WindshieldRear: Codable {
            let defog: StateMode

            enum CodingKeys: String, CodingKey {
                case defog = "Defog"
            }
        }

        struct WindshieldFront: Codable {
            let heat: StateMode
            let defog: StateMode
            let washerFluid: WasherFluid

            struct WasherFluid: Codable {
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

// MARK: - Green

struct VehicleGreen: Codable {
    @BoolValue private(set) var drivingReady: Bool
    let powerConsumption: VehiclePowerConsumption
    let batteryManagement: VehicleBatteryManagement
    let electric: Electric
    let chargingInformation: VehicleChargingInformation
    let reservation: Reservation
    let energyInformation: EnergyInformation
    let chargingDoor: ChargingDoor
    let plugAndCharge: PlugAndCharge
    let drivingHistory: DrivingHistory
    
    struct ChargingDoor: Codable {
        let state: ChargeDoorStatus
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

// MARK: - BatteryManagement

struct VehicleBatteryManagement: Codable {
    let soH: SoH
    let batteryRemain: BatteryRemain
    @BoolValue private(set) var batteryConditioning: Bool
    let batteryPreCondition: BatteryPreCondition
    let batteryCapacity: BatteryCapacity

    struct SoH: Codable {
        let ratio: Double

        enum CodingKeys: String, CodingKey {
            case ratio = "Ratio"
        }
    }

    struct BatteryRemain: Codable {
        /// This value looks like it's lower than ratio, but ratio is value that is display in app
        let value: Double // 127324.8, kiloJoules
        let ratio: Double // 39, %

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

struct Location: Codable {
    @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
    let offset: Int
    let servicestate: Int
    let timeStamp: TimeStamp
    let version: String
    let geoCoordinate: GeoCoordinate
    let heading: Double
    let speed: Speed

    struct TimeStamp: Codable {
        let day: Int
        let month: Int
        let year: Int
        let hour: Int
        let minute: Int
        let seconds: Int

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

    struct GeoCoordinate: Codable {
        let altitude: Double
        let latitude: Double
        let longitude: Double
        let type: Int

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

    struct Speed: Codable {
        let unit: SpeedUnit
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
