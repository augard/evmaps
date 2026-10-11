//
//  KiaVehicleStatusMapper.swift
//  KiaMaps
//
//  Created by Codex on 09.03.2026.
//

import Foundation

enum KiaVehicleStatusMapper {
    static func map(response: VehicleStateResponse) -> VehicleStatusSnapshot {
        VehicleStatusSnapshot(
            lastUpdateTime: response.lastUpdateTime,
            status: map(state: response.state.vehicle)
        )
    }

    static func map(state: VehicleState) -> VehicleStatus {
        VehicleStatus(
            body: .init(
                hood: .init(
                    open: state.body.hood.open,
                    frunk: .init(fault: state.body.hood.frunk.fault)
                ),
                trunk: .init(open: state.body.trunk.open)
            ),
            cabin: .init(
                hvac: .init(
                    row1: .init(
                        driver: .init(
                            temperature: .init(
                                value: state.cabin.hvac.row1.driver.temperature.value,
                                unit: state.cabin.hvac.row1.driver.temperature.unit
                            ),
                            blower: .init(speedLevel: state.cabin.hvac.row1.driver.blower.speedLevel)
                        )
                    ),
                    ventilation: .init(
                        airCleaning: .init(indicator: state.cabin.hvac.ventilation.airCleaning.indicator)
                    )
                ),
                door: .init(
                    row1: .init(
                        passenger: .init(
                            lock: state.cabin.door.row1.passenger.lock,
                            open: state.cabin.door.row1.passenger.open
                        ),
                        driver: .init(
                            lock: state.cabin.door.row1.driver.lock,
                            open: state.cabin.door.row1.driver.open
                        )
                    ),
                    row2: .init(
                        left: .init(
                            lock: state.cabin.door.row2.left.lock,
                            open: state.cabin.door.row2.left.open
                        ),
                        right: .init(
                            lock: state.cabin.door.row2.right.lock,
                            open: state.cabin.door.row2.right.open
                        )
                    )
                ),
                seat: .init(
                    row1: .init(
                        passenger: .init(climate: .init(state: state.cabin.seat.row1.passenger.climate.state)),
                        driver: .init(climate: .init(state: state.cabin.seat.row1.driver.climate.state))
                    ),
                    row2: .init(
                        left: .init(climate: .init(state: state.cabin.seat.row2.left.climate.state)),
                        right: .init(climate: .init(state: state.cabin.seat.row2.right.climate.state))
                    )
                )
            ),
            chassis: .init(
                axle: .init(
                    row1: .init(
                        left: .init(tire: .init(
                            pressureLow: state.chassis.axle.row1.left.tire.pressureLow,
                            pressure: state.chassis.axle.row1.left.tire.pressure
                        )),
                        right: .init(tire: .init(
                            pressureLow: state.chassis.axle.row1.right.tire.pressureLow,
                            pressure: state.chassis.axle.row1.right.tire.pressure
                        ))
                    ),
                    row2: .init(
                        left: .init(tire: .init(
                            pressureLow: state.chassis.axle.row2.left.tire.pressureLow,
                            pressure: state.chassis.axle.row2.left.tire.pressure
                        )),
                        right: .init(tire: .init(
                            pressureLow: state.chassis.axle.row2.right.tire.pressureLow,
                            pressure: state.chassis.axle.row2.right.tire.pressure
                        ))
                    ),
                    tire: .init(
                        pressureLow: state.chassis.axle.tire.pressureLow,
                        pressureUnit: state.chassis.axle.tire.pressureUnit
                    )
                )
            ),
            drivetrain: .init(
                fuelSystem: .init(
                    dte: .init(
                        unit: state.drivetrain.fuelSystem.dte.unit,
                        total: state.drivetrain.fuelSystem.dte.total
                    ),
                    averageFuelEconomy: .init(
                        drive: state.drivetrain.fuelSystem.averageFuelEconomy.drive,
                        afterRefuel: state.drivetrain.fuelSystem.averageFuelEconomy.afterRefuel,
                        accumulated: state.drivetrain.fuelSystem.averageFuelEconomy.accumulated,
                        unit: state.drivetrain.fuelSystem.averageFuelEconomy.unit
                    )
                ),
                odometer: state.drivetrain.odometer,
                transmission: .init(parkingPosition: state.drivetrain.transmission.parkingPosition)
            ),
            green: .init(
                batteryManagement: .init(
                    soH: .init(ratio: state.green.batteryManagement.soH.ratio),
                    batteryRemain: .init(
                        value: state.green.batteryManagement.batteryRemain.value,
                        ratio: state.green.batteryManagement.batteryRemain.ratio
                    ),
                    batteryCapacity: state.green.batteryManagement.batteryCapacity.value
                ),
                electric: .init(
                    smartGrid: .init(
                        vehicleToLoad: .init(
                            dischargeLimitation: .init(
                                soc: state.green.electric.smartGrid.vehicleToLoad.dischargeLimitation.soc,
                                remainTime: state.green.electric.smartGrid.vehicleToLoad.dischargeLimitation.remainTime
                            )
                        ),
                        vehicleToGrid: .init(mode: state.green.electric.smartGrid.vehicleToGrid.mode),
                        realTimePower: state.green.electric.smartGrid.realTimePower
                    )
                ),
                chargingInformation: .init(
                    connectorFastening: .init(state: state.green.chargingInformation.connectorFastening.state),
                    electricCurrentLevel: .init(state: state.green.chargingInformation.electricCurrentLevel.state),
                    charging: .init(
                        remainTime: state.green.chargingInformation.charging.remainTime,
                        remainTimeUnit: state.green.chargingInformation.charging.remainTimeUnit
                    )
                ),
                chargingDoor: .init(state: state.green.chargingDoor.state),
                drivingHistory: .init(
                    average: state.green.drivingHistory.average,
                    unit: state.green.drivingHistory.unit
                )
            ),
            drivingReady: state.drivingReady,
            location: map(location: state.location)
        )
    }

    static func map(location: VehicleLocation?) -> VehicleStatus.Location? {
        guard let location else { return nil }
        return .init(
            date: location.date,
            geoCoordinate: .init(
                altitude: location.geoCoordinate.altitude,
                latitude: location.geoCoordinate.latitude,
                longitude: location.geoCoordinate.longitude
            ),
            heading: location.heading,
            speed: .init(
                unit: location.speed.unit,
                value: location.speed.value
            )
        )
    }
}
