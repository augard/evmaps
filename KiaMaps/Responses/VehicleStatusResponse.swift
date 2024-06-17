//
//  VehicleStatusResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 01.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

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
    let body: Body
    let cabin: Cabin
    let chassis: Chassis
    let drivetrain: Drivetrain
    let electronics: Electronics
    let green: Green
    let service: Service
    let remoteControl: VehicleRemoteControl
    let connectedService: ConnectedService
    let drivingReady: Int
    let version: String
    @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
    let offset: String
    let location: Location

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
struct Body: Codable {
    let windshield: Windshield
    let hood: Hood
    let lights: Lights
    let sunroof: Sunroof
    let trunk: Trunk
    
    struct Trunk: Codable {
        @BoolValue private(set) var trunkOpen: Bool

        enum CodingKeys: String, CodingKey {
            case trunkOpen = "Open"
        }
    }
    
    struct Sunroof: Codable {
        let glass: Trunk

        enum CodingKeys: String, CodingKey {
            case glass = "Glass"
        }
    }

    struct Windshield: Codable {
        let rear: WindshieldRear
        let front: WindshieldFront
        
        struct WindshieldRear: Codable {
            let defog: RESTMode

            enum CodingKeys: String, CodingKey {
                case defog = "Defog"
            }
        }
        
        
        struct WindshieldFront: Codable {
            let heat: RESTMode
            let defog: RESTMode
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
        @BoolValue private(set) var hoodOpen: Bool
        let frunk: Frunk

        enum CodingKeys: String, CodingKey {
            case hoodOpen = "Open"
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

struct Lights: Codable {
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
            let low: Fluid
            let high: Fluid
            let turnSignal: TurnSignal
            
            struct TurnSignal: Codable {
                let warning: Int
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
        let stopLamp: Fluid
        let turnSignal: Fluid

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

struct Fluid: Codable {
    @BoolValue private(set) var warning: Bool

    enum CodingKeys: String, CodingKey {
        case warning = "Warning"
    }
}

struct Cabin: Codable {
    let restMode: RESTMode
    let hvac: Hvac
    let door: Door
    let seat: Seat
    let window: Window
    let steeringWheel: SteeringWheel

    enum CodingKeys: String, CodingKey {
        case restMode = "RestMode"
        case hvac = "HVAC"
        case door = "Door"
        case seat = "Seat"
        case window = "Window"
        case steeringWheel = "SteeringWheel"
    }
}

struct Door: Codable {
    let row1: DoorRow1
    let row2: DoorRow2

    struct PlaceLock: Codable {
        @BoolValue private(set) var lock: Bool
        @BoolValue private(set) var driverOpen: Bool

        enum CodingKeys: String, CodingKey {
            case lock = "Lock"
            case driverOpen = "Open"
        }
    }
    
    struct DoorRow1: Codable {
        let passenger: PlaceLock
        let driver: PlaceLock

        enum CodingKeys: String, CodingKey {
            case passenger = "Passenger"
            case driver = "Driver"
        }
    }
    
    struct DoorRow2: Codable {
        let row2Left: PlaceLock
        let row2Right: PlaceLock

        enum CodingKeys: String, CodingKey {
            case row2Left = "Left"
            case row2Right = "Right"
        }
    }

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case row2 = "Row2"
    }
}

// MARK: - Hvac
struct Hvac: Codable {
    let vent: Vent
    let row1: HVACRow1
    let temperature: HVACTemperature
    
    struct Blower: Codable {
        let speedLevel: Int

        enum CodingKeys: String, CodingKey {
            case speedLevel = "SpeedLevel"
        }
    }

    struct HVACRow1: Codable {
        let driver: Driver
        
        struct Driver: Codable {
            let temperature: DriverTemperature
            let blower: Blower
            
            struct DriverTemperature: Codable {
                let value: String
                let unit: Int

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
    
    enum CodingKeys: String, CodingKey {
        case vent = "Vent"
        case row1 = "Row1"
        case temperature = "Temperature"
    }
}

// MARK: - HVACTemperature
struct HVACTemperature: Codable {
    let rangeType: Int

    enum CodingKeys: String, CodingKey {
        case rangeType = "RangeType"
    }
}

// MARK: - Vent
struct Vent: Codable {
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

// MARK: - Seat
struct Seat: Codable {
    let row2: SeatRow2
    let row1: SeatRow1
    
    struct PlaceClimate: Codable {
        let climate: RESTMode

        enum CodingKeys: String, CodingKey {
            case climate = "Climate"
        }
    }

    struct SeatRow1: Codable {
        let passenger: PlaceClimate
        let driver: PlaceClimate

        enum CodingKeys: String, CodingKey {
            case passenger = "Passenger"
            case driver = "Driver"
        }
    }
    
    struct SeatRow2: Codable {
        let row2Left: PlaceClimate
        let row2Right: PlaceClimate

        enum CodingKeys: String, CodingKey {
            case row2Left = "Left"
            case row2Right = "Right"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case row2 = "Row2"
        case row1 = "Row1"
    }
}

// MARK: - SteeringWheel
struct SteeringWheel: Codable {
    let heat: Heat

    enum CodingKeys: String, CodingKey {
        case heat = "Heat"
    }
}

// MARK: - Heat
struct Heat: Codable {
    let remoteControl: HeatRemoteControl
    @BoolValue private(set) var state: Bool
    
    struct HeatRemoteControl: Codable {
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

// MARK: - Window
struct Window: Codable {
    let row1: WindowRow1
    let row2: WindowRow2

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case row2 = "Row2"
    }
}

// MARK: - WindowRow1
struct WindowRow1: Codable {
    let driver: TentacledDriver
    let passenger: TentacledDriver

    enum CodingKeys: String, CodingKey {
        case driver = "Driver"
        case passenger = "Passenger"
    }
}

// MARK: - TentacledDriver
struct TentacledDriver: Codable {
    let driverOpen: Int
    let openLevel: Int

    enum CodingKeys: String, CodingKey {
        case driverOpen = "Open"
        case openLevel = "OpenLevel"
    }
}

// MARK: - WindowRow2
struct WindowRow2: Codable {
    let row2Left, row2Right: TentacledDriver

    enum CodingKeys: String, CodingKey {
        case row2Left = "Left"
        case row2Right = "Right"
    }
}

// MARK: - Chassis
struct Chassis: Codable {
    let drivingMode: DrivingMode
    let axle: Axle
    let brake: Brake

    enum CodingKeys: String, CodingKey {
        case drivingMode = "DrivingMode"
        case axle = "Axle"
        case brake = "Brake"
    }
}

// MARK: - Axle
struct Axle: Codable {
    let row1: Row
    let row2: Row
    let tire: AxleTire

    enum CodingKeys: String, CodingKey {
        case row1 = "Row1"
        case row2 = "Row2"
        case tire = "Tire"
    }
}

// MARK: - Row
struct Row: Codable {
    let rowLeft: Row1Left
    let rowRight: Row1Left

    enum CodingKeys: String, CodingKey {
        case rowLeft = "Left"
        case rowRight = "Right"
    }
}

// MARK: - Row1Left
struct Row1Left: Codable {
    let tire: LeftTire

    enum CodingKeys: String, CodingKey {
        case tire = "Tire"
    }
}

// MARK: - LeftTire
struct LeftTire: Codable {
    @BoolValue private(set) var pressureLow: Bool
    let pressure: Int

    enum CodingKeys: String, CodingKey {
        case pressureLow = "PressureLow"
        case pressure = "Pressure"
    }
}

// MARK: - AxleTire
struct AxleTire: Codable {
    @BoolValue private(set) var pressureLow: Bool
    let pressureUnit: Int

    enum CodingKeys: String, CodingKey {
        case pressureLow = "PressureLow"
        case pressureUnit = "PressureUnit"
    }
}

// MARK: - Brake
struct Brake: Codable {
    let fluid: Fluid

    enum CodingKeys: String, CodingKey {
        case fluid = "Fluid"
    }
}

// MARK: - DrivingMode
struct DrivingMode: Codable {
    let state: String

    enum CodingKeys: String, CodingKey {
        case state = "State"
    }
}

// MARK: - ConnectedService
struct ConnectedService: Codable {
    let ota: Ota

    struct Ota: Codable {
        let controllerStatus: Int

        enum CodingKeys: String, CodingKey {
            case controllerStatus = "ControllerStatus"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case ota = "OTA"
    }
}

// MARK: - Drivetrain
struct Drivetrain: Codable {
    let fuelSystem: FuelSystem
    let odometer: Double
    let transmission: Transmission
    
    struct FuelSystem: Codable {
        let dte: FuelSystemDte
        let lowFuelWarning: Int
        let fuelLevel: Int
        let averageFuelEconomy: AverageFuelEconomy
        
        struct FuelSystemDte: Codable {
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
            let unit: Int

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
        let parkingPosition: Int
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
struct Electronics: Codable {
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
        let batteryPreWarning: Int
        let deliveryMode: Int

        enum CodingKeys: String, CodingKey {
            case powerMode = "PowerMode"
            case batteryPreWarning = "BatteryPreWarning"
            case deliveryMode = "DeliveryMode"
        }
    }
    
    struct Fob: Codable {
        @BoolValue private(set) var  lowBattery: Bool
        
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
struct Green: Codable {
    @BoolValue private(set) var drivingReady: Bool
    let powerConsumption: PowerConsumption
    let batteryManagement: BatteryManagement
    let electric: Electric
    let chargingInformation: ChargingInformation
    let reservation: Reservation
    let energyInformation: EnergyInformation
    let chargingDoor: ChargingDoor
    let plugAndCharge: PlugAndCharge
    let drivingHistory: DrivingHistory

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
struct BatteryManagement: Codable {
    let soH: SoH
    let batteryRemain: BatteryRemain
    @BoolValue private(set) var  batteryConditioning: Bool
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

// MARK: - ChargingDoor
struct ChargingDoor: Codable {
    let state: Int
    let errorState: Int

    enum CodingKeys: String, CodingKey {
        case state = "State"
        case errorState = "ErrorState"
    }
}

// MARK: - ChargingInformation
struct ChargingInformation: Codable {
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
        let targetSoC: TargetSoC
        
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
    let unit: Int

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
            let mode: Int

            enum CodingKeys: String, CodingKey {
                case mode = "Mode"
            }
        }

        struct VehicleToLoad: Codable {
            let dischargeLimitation: [String: Int]

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
    let contractCertificate1: ContractCertificate1Class
    let contractCertificate2: ContractCertificate1Class
    let contractCertificate3: ContractCertificate1Class
    let contractCertificate4: ContractCertificate1Class
    let contractCertificate5: ContractCertificate1Class
    let contractCertificate: ContractCertificate

    struct ContractCertificate: Codable {
        let selectedCert: Int
        let changeable: Int
        let mode: Int

        enum CodingKeys: String, CodingKey {
            case selectedCert = "SelectedCert"
            case changeable = "Changeable"
            case mode = "Mode"
        }
    }

    struct ContractCertificate1Class: Codable {
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
        case contractCertificate = "ContractCertificate"
    }
}

// MARK: - PowerConsumption
struct PowerConsumption: Codable {
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
    let offPeakTime: OffPeakTime
    let offPeakTime2: OffPeakTime

    struct Departure: Codable {
        let schedule1: Schedule
        let schedule2: Schedule
        let climate: Climate
        let climate2: Climate

        enum CodingKeys: String, CodingKey {
            case schedule1 = "Schedule1"
            case schedule2 = "Schedule2"
            case climate = "Climate"
            case climate2 = "Climate2"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case departure = "Departure"
        case offPeakTime = "OffPeakTime"
        case offPeakTime2 = "OffPeakTime2"
    }
}


// MARK: - Climate
struct Climate: Codable {
    let activation: Int
    let temperatureHex: String
    let defrost: Int
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

// MARK: - Schedule
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
    let climate: Schedule1Climate?
    @BoolValue private(set) var enable: Bool
    let activation: Int?

    struct Schedule1Climate: Codable {
        let defrost: Int
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

// MARK: - OffPeakTime
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

// MARK: - Location
struct Location: Codable {
    @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
    let offset: Int
    let servicestate: Int
    let timeStamp: TimeStamp
    let version: String
    let geoCoord: GeoCoordinate
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

        enum CodingKeys: String, CodingKey {
            case altitude = "Altitude"
            case latitude = "Latitude"
            case longitude = "Longitude"
            case type = "Type"
        }
    }
    
    struct Speed: Codable {
        let unit: SpeedUnit
        let value: Int

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
        case geoCoord = "GeoCoord"
        case heading = "Heading"
        case speed = "Speed"
    }
}

// MARK: - VehicleRemoteControl
struct VehicleRemoteControl: Codable {
    @BoolValue private(set) var sleepMode: Bool

    enum CodingKeys: String, CodingKey {
        case sleepMode = "SleepMode"
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
