//
//  VehicleStatus.swift
//  KiaMaps
//
//  Created by Codex on 09.03.2026.
//

import Foundation
import CoreLocation

struct VehicleStatusSnapshot: Codable {
    @DateValue<TimeIntervalDateFormatter> private(set) var lastUpdateTime: Date
    let status: VehicleStatus
}

struct VehicleStatus: Codable {
    let body: Body
    let cabin: Cabin
    let chassis: Chassis
    let drivetrain: Drivetrain
    let green: Green
    let drivingReady: Bool
    let location: Location?

    var isCharging: Bool {
        let isConnectorFastened = green.chargingInformation.connectorFastening.state > 0
        let chargingDoorOpen = green.chargingDoor.state == ChargeDoorStatus.open
        return isConnectorFastened && chargingDoorOpen
    }

    /// Energy is flowing into the battery (plugged in alone may be scheduled, paused, or finished).
    var isActivelyCharging: Bool {
        green.chargingInformation.electricCurrentLevel.state == 1
    }

    struct Body: Codable {
        let hood: Hood
        let trunk: Trunk

        struct Hood: Codable {
            let open: Bool
            let frunk: Frunk
        }

        struct Frunk: Codable {
            let fault: Bool
        }

        struct Trunk: Codable {
            let open: Bool
        }
    }

    struct Cabin: Codable {
        let hvac: HVAC
        let door: Door
        let seat: Seat

        struct HVAC: Codable {
            let row1: Row1
            let ventilation: Ventilation

            struct Row1: Codable {
                let driver: Driver

                struct Driver: Codable {
                    let temperature: Temperature
                    let blower: Blower
                }
            }

            struct Temperature: Codable {
                let value: String
                let unit: TemperatureUnit
            }

            struct Blower: Codable {
                let speedLevel: Int
            }

            struct Ventilation: Codable {
                let airCleaning: AirCleaning

                struct AirCleaning: Codable {
                    let indicator: Int
                }
            }
        }

        struct Door: Codable {
            let row1: Row1
            let row2: Row2

            struct Status: Codable {
                let lock: Bool
                let open: Bool
            }

            struct Row1: Codable {
                let passenger: Status
                let driver: Status
            }

            struct Row2: Codable {
                let left: Status
                let right: Status
            }
        }

        struct Seat: Codable {
            let row1: Row1
            let row2: Row2

            struct Climate: Codable {
                let state: Int
            }

            struct Status: Codable {
                let climate: Climate
            }

            struct Row1: Codable {
                let passenger: Status
                let driver: Status
            }

            struct Row2: Codable {
                let left: Status
                let right: Status
            }
        }
    }

    struct Chassis: Codable {
        let axle: Axle

        struct Axle: Codable {
            let row1: TireRow
            let row2: TireRow
            let tire: Tire

            struct TireRow: Codable {
                let left: Wheel
                let right: Wheel

                struct Wheel: Codable {
                    let tire: Pressure
                }
            }

            struct Pressure: Codable {
                let pressureLow: Bool
                let pressure: Int
            }

            struct Tire: Codable {
                let pressureLow: Bool
                let pressureUnit: Int
            }
        }
    }

    struct Drivetrain: Codable {
        let fuelSystem: FuelSystem
        let odometer: Double
        let transmission: Transmission

        struct FuelSystem: Codable {
            let dte: DTE
            let averageFuelEconomy: AverageFuelEconomy

            struct DTE: Codable {
                let unit: DistanceUnit
                let total: Int
            }

            struct AverageFuelEconomy: Codable {
                let drive: Double
                let afterRefuel: Double
                let accumulated: Double
                let unit: EconomyUnit
            }
        }

        struct Transmission: Codable {
            let parkingPosition: Bool
        }
    }

    struct Green: Codable {
        let batteryManagement: BatteryManagement
        let electric: Electric
        let chargingInformation: ChargingInformation
        let chargingDoor: ChargingDoor
        let drivingHistory: DrivingHistory

        struct BatteryManagement: Codable {
            let soH: SoH
            let batteryRemain: BatteryRemain
            /// Reported usable capacity in kilojoules. Nil for snapshots cached before it was mapped.
            var batteryCapacity: Double? = nil

            struct SoH: Codable {
                let ratio: Double
            }

            struct BatteryRemain: Codable {
                let value: Double
                let ratio: Double
            }
        }

        struct Electric: Codable {
            let smartGrid: SmartGrid

            struct SmartGrid: Codable {
                let vehicleToLoad: VehicleToLoad
                let vehicleToGrid: VehicleToGrid
                let realTimePower: Double

                struct VehicleToLoad: Codable {
                    let dischargeLimitation: DischargeLimitation

                    struct DischargeLimitation: Codable {
                        let soc: Int
                        let remainTime: Int
                    }
                }

                struct VehicleToGrid: Codable {
                    let mode: Bool
                }
            }
        }

        struct ChargingInformation: Codable {
            let connectorFastening: State
            let electricCurrentLevel: State
            let charging: Charging

            struct State: Codable {
                let state: Int
            }

            struct Charging: Codable {
                let remainTime: Double
                let remainTimeUnit: TimeUnit
            }
        }

        struct ChargingDoor: Codable {
            let state: ChargeDoorStatus
        }

        struct DrivingHistory: Codable {
            let average: Double
            let unit: DistanceUnit
        }
    }

    struct Location: Codable {
        @DateValue<TimeIntervalDateFormatter> private(set) var date: Date
        let geoCoordinate: GeoCoordinate
        let heading: Double
        let speed: Speed

        struct GeoCoordinate: Codable {
            let altitude: Double
            let latitude: Double
            let longitude: Double

            var location: CLLocation {
                .init(
                    coordinate: .init(latitude: latitude, longitude: longitude),
                    altitude: altitude,
                    horizontalAccuracy: 100,
                    verticalAccuracy: 100,
                    timestamp: .now
                )
            }
        }

        struct Speed: Codable {
            let unit: SpeedUnit
            let value: Double
        }
    }
}
