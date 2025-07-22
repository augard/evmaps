//
//  VehicleStatusView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 27.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI
import MapKit

struct VehicleStatusView: View {
    let brand: String
    let vehicle: Vehicle
    let vehicleStatus: VehicleStatus
    let lastUpdateTime: Date

    private let percentNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        List {
            Group {
                mainSection(vehicle: vehicle, status: vehicleStatus, lastUpdateTime: lastUpdateTime)

                DisclosureGroup("Body") {
                    bodySection(body: vehicleStatus.body)
                }

                DisclosureGroup("Cabin") {
                    cabinSection(cabin: vehicleStatus.cabin)
                }

                DisclosureGroup("Chassis") {
                    chasisSection(chassis: vehicleStatus.chassis)
                }

                DisclosureGroup("Drivetrain") {
                    drivetrainSection(drivetrain: vehicleStatus.drivetrain)
                }

                DisclosureGroup("Electronics") {
                    electronicsSection(electronics: vehicleStatus.electronics)
                }

                DisclosureGroup("Green") {
                    greenSection(green: vehicleStatus.green)
                }

                DisclosureGroup("Service") {
                    serviceSection(service: vehicleStatus.service, remoteControl: vehicleStatus.remoteControl)
                }

                DisclosureGroup("Location") {
                    locationSection(location: vehicleStatus.location)
                }
            }
        }
    }
    
    private func mainSection(vehicle: Vehicle, status: VehicleStatus, lastUpdateTime: Date) -> some View {
        Group {
            DataRowView(icon: .car, label: brand + " - " + vehicle.nickname + " (" + vehicle.year + ")") {
                Text("VIN: " + vehicle.vin)
            }

            let value = status.green.batteryManagement.batteryRemain.ratio / 100
            DataProgressRowView(icon: .charger, label: "Charge: " + (percentNumberFormatter.string(from: value as NSNumber) ?? ""), value: value)
            
            let sohValue = status.green.batteryManagement.soH.ratio / 100
            DataProgressRowView(icon: .battery, label: "SOH: " + (percentNumberFormatter.string(from: sohValue as NSNumber) ?? ""), value: sohValue)

            DataStateRowView(icon: .ready, label: "Driving Ready", value: status.drivingReady, kind: .fault)
            
            DataRowView(icon: .info, label: "Version") {
                Text(status.version)
            }
            
            DataStateRowView(icon: .update, label: "Update Available", value: status.connectedService.ota.controllerStatus, kind: .fault)
            
            DataRowView(icon: .clock, label: "Last Update") {
                Text(lastUpdateTime, style: .relative)
            }
        }
    }
    
    // MARK: - Body
    
    private func bodySection(body: VehicleBody) -> some View {
        Group {
            Section("Windshield - Front") {
                DataStateRowView(icon: .windshieldDefog, label: "Defog", value: body.windshield.front.defog.state)
                
                DataStateRowView(icon: .windshieldHeat, label: "Heat", value: body.windshield.front.heat.state)
                
                DataStateRowView(icon: .warning, label: "Washer Fluid Low", value: body.windshield.front.washerFluid.levelLow, kind: .fault)
            }
            
            Section("Windshield - Rear") {
                DataStateRowView(icon: .windshieldDefog, label: "Defog", value: body.windshield.rear.defog.state)
            }
            
            Section("Hood") {
                DataStateRowView(icon: .frunkOpen, label: "State", value: body.hood.open, kind: .door)
                DataStateRowView(icon: .warning, label: "Fault", value: body.hood.frunk.fault, kind: .fault)
            }
            
            if let sunroof = body.sunroof {
                Section("Sunroof") {
                    DataStateRowView(icon: .sunRoofOpen, label: "State", value: sunroof.glass.open, kind: .door)
                }
            }
            
            Section("Trunk") {
                DataStateRowView(icon: .trunkOpen, label: "State", value: body.trunk.open, kind: .door)
            }
            
            bodyLightSection(body: body)
        }
    }
    
    private func bodyLightSection(body: VehicleBody) -> some View {
        Group {
            Section("Lights") {
                DataStateRowView(icon: .hazardLight, label: "Hazard", value: body.lights.hazard.alert)
                DataStateRowView(icon: .light, label: "Tail Lamp", value: body.lights.tailLamp.alert)
                DataStateRowView(icon: .warning, label: "Discharge Alert", value: body.lights.dischargeAlert.state == 1, kind: .fault)
            }
            
            Section("Lights - Front") {
                DataStateRowView(icon: .hazardLight, label: "Hazard", value: body.lights.hazard.alert)
            }
            
            Section("Lights - Rear") {
                DataStateRowView(icon: .lightWarning, label: "Head Lamp Alert", value: body.lights.front.headLamp.systemWarning == 1, kind: .fault)
                Group {
                    DataStateRowView(icon: .lightWarning, label: "Left Low Fluid Alert", value: body.lights.front.frontLeft.low.warning, kind: .fault)
                    DataStateRowView(icon: .lightWarning, label: "Left High Fluid Alert", value: body.lights.front.frontLeft.high.warning, kind: .fault)
                    DataStateRowView(icon: .lightWarning, label: "Left Turn Signal Alert", value: body.lights.front.frontLeft.high.warning, kind: .fault)
                    DataRowView(icon: .light, label: "Left Turn Signal Lamp State") {
                        Text("\(body.lights.front.frontLeft.turnSignal.lampState)")
                    }
                }
                Group {
                    DataStateRowView(icon: .lightWarning, label: "Right Low Fluid Alert", value: body.lights.front.frontRight.low.warning, kind: .fault)
                    DataStateRowView(icon: .lightWarning, label: "Right High Fluid Alert", value: body.lights.front.frontRight.high.warning, kind: .fault)
                    DataStateRowView(icon: .lightWarning, label: "Right Turn Signal Alert", value: body.lights.front.frontRight.turnSignal.warning, kind: .fault)
                    DataRowView(icon: .light, label: "Right Turn Signal Lamp State") {
                        Text("\(body.lights.front.frontRight.turnSignal.lampState)")
                    }
                }
            }
        }
    }
    
    // MARK: - Cabin
    
    @ViewBuilder
    private func cabinSection(cabin: VehicleCabin) -> some View {
        Group {
            DataRowView(icon: .info, label: "Rest Mode") {
                Text("\(cabin.restMode.state)")
            }
            
            Section("HVAC") {
                DataTemperatureRowView(
                    icon: .temperature,
                    label: "Driver",
                    value: cabin.hvac.row1.driver.temperature.value,
                    unit: cabin.hvac.row1.driver.temperature.unit
                )
                
                DataRowView(icon: .fan, label: "Driver") {
                    Text(cabin.hvac.row1.driver.blower.speedLevel == 0 ? "Off" : "\(cabin.hvac.row1.driver.blower.speedLevel)")
                }
                
                DataRowView(icon: .smoke, label: "Ventilation - Fine Dust") {
                    Text("\(cabin.hvac.ventilation.fineDust.level)")
                }
                
                DataRowView(icon: .info, label: "Ventilation - Air Cleaning") {
                    Text("\(cabin.hvac.ventilation.airCleaning.indicator)")
                }
                
                DataRowView(icon: .info, label: "Ventilation - Air Cleaning - Symbol Color") {
                    Text("\(cabin.hvac.ventilation.airCleaning.symbolColor)")
                }
                
                DataRowView(icon: .info, label: "Temperature - Range Type") {
                    Text("\(cabin.hvac.temperature.rangeType)")
                }
            }
            
            Section("Door") {
                let row1 = cabin.door.row1
                let row2 = cabin.door.row2
                
                DataStateRowView(icon: !row1.driver.lock ? .doorLocked : .doorUnlocked, label: "Row 1 - Driver", value: !row1.driver.lock, kind: .lock)
                DataStateRowView(icon: !row1.passenger.lock ? .doorLocked : .doorUnlocked, label: "Row 1 - Passanger", value: !row1.passenger.lock, kind: .door)
                DataStateRowView(icon: !row2.left.lock ? .doorLocked : .doorUnlocked, label: "Row 2 - Left", value: !row2.left.lock, kind: .lock)
                DataStateRowView(icon: !row2.right.lock ? .doorLocked : .doorUnlocked, label: "Row 2 - Right", value: !row2.right.lock, kind: .lock)

                DataStateRowView(icon: .doorFrontLeft, label: "Row 1 - Driver", value: !row1.driver.open, kind: .door)
                DataStateRowView(icon: .doorFrontRight, label: "Row 1 - Passanger", value: !row1.passenger.open, kind: .door)
                DataStateRowView(icon: .doorRearLeft, label: "Row 2 - Left", value: !row2.left.open, kind: .door)
                DataStateRowView(icon: .doorRearRight, label: "Row 2 - Right", value: !row2.right.open, kind: .door)
            }

            Section("Seat") {
                let row1 = cabin.seat.row1 // State 2
                let row2 = cabin.seat.row2
                
                DataRowView(icon: .seatCooling, label: "Row 1 - Driver") {
                    Text("\(row1.driver.climate.state)")
                }
                DataRowView(icon: .seatCooling, label: "Row 1 - Passanger") {
                    Text("\(row1.passenger.climate.state)")
                }
                DataRowView(icon: .seatCooling, label: "Row 2 - Left") {
                    Text("\(row2.left.climate.state)")
                }
                DataRowView(icon: .seatCooling, label: "Row 2 - Right") {
                    Text("\(row2.right.climate.state)")
                }
            }
            
            Section("Window") {
                let row1 = cabin.window.row1
                let row2 = cabin.window.row2
                
                DataStateRowView(icon: .window, label: "Row 1 - Driver", value: row1.driver.open, kind: .door)
                DataStateRowView(icon: .window, label: "Row 1 - Passanger", value: row1.passenger.open, kind: .door)
                DataStateRowView(icon: .window, label: "Row 2 - Left", value: row2.left.open, kind: .door)
                DataStateRowView(icon: .window, label: "Row 2 - Right", value: row2.right.open, kind: .door)
                
                DataRowView(icon: .windowLevel, label: "Row 1 - Driver - Level") {
                    Text("\(row1.driver.openLevel)")
                }
                DataRowView(icon: .windowLevel, label: "Row 1 - Passanger - Level") {
                    Text("\(row1.passenger.openLevel)")
                }
                DataRowView(icon: .windowLevel, label: "Row 2 - Left - Level") {
                    Text("\(row2.left.openLevel)")
                }
                DataRowView(icon: .windowLevel, label: "Row 2 - Right - Level") {
                    Text("\(row2.right.openLevel)")
                }
            }
            
            Section("Steering Wheel") {
                if let heat = cabin.steeringWheel.heat {
                    DataStateRowView(icon: .steeringHeating, label: "Heat", value: heat.state)
                    DataRowView(icon: .info, label: "Remote Control") {
                        Text("\(heat.remoteControl.step)")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func chasisSection(chassis: VehicleChassis) -> some View {
        Group {
            DataRowView(icon: .info, label: "Driving Mode") {
                Text(chassis.drivingMode.state)
            }
            
            Section("Tires") {
                let row1 = chassis.axle.row1
                let row2 = chassis.axle.row2
                
                DataRowView(icon: .tirePressure, label: "Row 1 - Driver - Pressure") {
                    Text("\(row1.left.tire.pressure)")
                }
                DataRowView(icon: .windowLevel, label: "Row 1 - Passanger - Pressure") {
                    Text("\(row1.right.tire.pressure)")
                }
                DataRowView(icon: .windowLevel, label: "Row 2 - Left - Pressure") {
                    Text("\(row2.left.tire.pressure)")
                }
                DataRowView(icon: .windowLevel, label: "Row 2 - Right - Pressure") {
                    Text("\(row2.right.tire.pressure)")
                }
                
                DataStateRowView(icon: .tirePressure, label: "Row 1 - Driver - Pressure Low", value: row1.left.tire.pressureLow, kind: .fault)
                DataStateRowView(icon: .tirePressure, label: "Row 1 - Passanger - Pressure Low", value: row1.right.tire.pressureLow, kind: .fault)
                DataStateRowView(icon: .tirePressure, label: "Row 2 - Left - Pressure Low", value: row2.left.tire.pressureLow, kind: .fault)
                DataStateRowView(icon: .tirePressure, label: "Row 2 - Right - Pressure Low", value: row2.right.tire.pressureLow, kind: .fault)
            }
            
            Section("Brake") {
                DataStateRowView(icon: .breakFluid, label: "Fluid - Warning", value: chassis.brake.fluid.warning)
            }
        }
    }
    
    func drivetrainSection(drivetrain: VehicleDrivetrain) -> some View {
        Group {
            DataDistanceRowView(label: "Odometer", value: drivetrain.odometer, unit: .kilometers)
            
            Section("Fuel System") {
                DataDistanceRowView(label: "Range", value: drivetrain.fuelSystem.dte.total, unit: drivetrain.fuelSystem.dte.unit)
                DataStateRowView(icon: .info, label: "Low Range Warning", value: drivetrain.fuelSystem.lowFuelWarning, kind: .fault)
                DataRowView(icon: .info, label: "Fuel Level") {
                    Text("\(drivetrain.fuelSystem.fuelLevel)")
                }
                
                DataEconomyRowView(label: "Fuel Economy - Drive", value: drivetrain.fuelSystem.averageFuelEconomy.drive, unit: drivetrain.fuelSystem.averageFuelEconomy.unit)
                DataEconomyRowView(label: "Fuel Economy - After Refuel", value: drivetrain.fuelSystem.averageFuelEconomy.afterRefuel, unit: drivetrain.fuelSystem.averageFuelEconomy.unit)
                DataEconomyRowView(label: "Fuel Economy - Accumulated", value: drivetrain.fuelSystem.averageFuelEconomy.accumulated, unit: drivetrain.fuelSystem.averageFuelEconomy.unit)
            }
            
            Section("Transmission") {
                DataStateRowView(icon: .parking, label: "Parking Position", value: drivetrain.transmission.parkingPosition, kind: .fault)
                DataRowView(icon: .gearShift, label: "Gear Position") {
                    Text("\(drivetrain.transmission.gearPosition)")
                }
            }
        }
    }
    
    @ViewBuilder
    func electronicsSection(electronics: VehicleElectronics) -> some View {
        Group {
            Section("Battery - V12") {
                let value = Double(electronics.battery.level) / 100
                DataProgressRowView(icon: .battery, label: "Charge: " + (percentNumberFormatter.string(from: value as NSNumber) ?? ""), value: value)
                
                DataStateRowView(icon: .batteryWarning, label: "Warning", value: electronics.battery.auxiliary.failWarning, kind: .fault)
                
                DataRowView(icon: .batteryWarning, label: "Warning Level At") {
                    Text("\(electronics.battery.charging.warningLevel) %")
                }
                DataRowView(icon: .info, label: "Power State Alert - Class C") {
                    Text("\(electronics.battery.powerStateAlert.classC)")
                }
                DataRowView(icon: .info, label: "Sensor Reliability") {
                    Text("\(electronics.battery.sensorReliability)")
                }
            }
            
            Section("Auto Cut") {
                DataRowView(icon: .info, label: "Power Mode") {
                    Text("\(electronics.autoCut.powerMode)")
                }
                DataRowView(icon: .info, label: "Delivery Mode") {
                    Text("\(electronics.autoCut.deliveryMode)")
                }
                DataStateRowView(icon: .warning, label: "Battery Pre Warning", value: electronics.autoCut.batteryPreWarning, kind: .fault)
            }
            
            DataStateRowView(icon: .key, label: "Key - Low Battery", value: electronics.fob.lowBattery, kind: .fault)
            
            Section("Power Supply") {
                DataRowView(icon: .info, label: "Accessory") {
                    Text("\(electronics.powerSupply.accessory)")
                }
                if let ignition1 = electronics.powerSupply.ignition1 {
                    DataRowView(icon: .info, label: "Ignition 1") {
                        Text("\(ignition1)")
                    }
                }
                if let ignition2 = electronics.powerSupply.ignition2 {
                    DataRowView(icon: .info, label: "Ignition 2") {
                        Text("\(ignition2)")
                    }
                }
                if let ignition3 = electronics.powerSupply.ignition3 {
                    DataRowView(icon: .info, label: "Ignition 3") {
                        Text("\(ignition3)")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func greenSection(green: VehicleGreen) -> some View {
        Group {
            DataStateRowView(icon: .steering, label: "Driving Ready", value: green.drivingReady, kind: .fault)
            
            Section("Power Consumption") {
                DataRowView(icon: .info, label: "Predication Climate") {
                    Text("\(green.powerConsumption.prediction.climate)")
                }
            }
            
            Section("Battery Management") {
                let value = green.batteryManagement.batteryRemain.ratio / 100
                DataProgressRowView(icon: .charger, label: "Charge: " + (percentNumberFormatter.string(from: value as NSNumber) ?? ""), value: value)
                DataEnergyRowView(label: "Charge", value: green.batteryManagement.batteryRemain.value)
                
                let sohValue = green.batteryManagement.soH.ratio / 100
                DataProgressRowView(icon: .battery, label: "State of Health: " + (percentNumberFormatter.string(from: sohValue as NSNumber) ?? ""), value: sohValue)
                
                DataEnergyRowView(label: "Total", value: green.batteryManagement.batteryCapacity.value)
                
                DataStateRowView(icon: .info, label: "Battery Conditioning", value: green.batteryManagement.batteryConditioning, kind: .fault)
                
                DataRowView(icon: .info, label: "Battery Pre Condition - Status") {
                    Text("\(green.batteryManagement.batteryPreCondition.status)")
                }
                DataRowView(icon: .temperature, label: "Battery Pre Condition - Temperature Level") {
                    Text("\(green.batteryManagement.batteryPreCondition.temperatureLevel)")
                }
            }
            
            Section("Charging Information") {
                let unit = green.chargingInformation.estimatedTime.unit
                Group {
                    DataTimeRowView(label: "ICCB", value: green.chargingInformation.estimatedTime.iccb, unit: unit)
                    DataTimeRowView(label: "Standard", value: green.chargingInformation.estimatedTime.standard, unit: unit)
                    DataTimeRowView(label: "Quick", value: green.chargingInformation.estimatedTime.standard, unit: unit)
                    DataTimeRowView(label: "Charging Time", value: green.chargingInformation.charging.remainTime, unit: green.chargingInformation.charging.remainTimeUnit)
                }
                
                let expectedTime = green.chargingInformation.expectedTime
                DataRowView(icon: .info, label: "Expected Time - Start") {
                    Text("Day: \(expectedTime.startHour), time: \(expectedTime.startHour):\(expectedTime.startMin)")
                }
                DataRowView(icon: .info, label: "Expected Time - End") {
                    Text("Day: \(expectedTime.endDay), time: \(expectedTime.endHour):\(expectedTime.endMin)")
                }
                
                Group {
                    DataRowView(icon: .info, label: "DTE - Target SOC - Standard") {
                        Text("\(green.chargingInformation.dte.targetSoC.standard)")
                    }
                    DataRowView(icon: .info, label: "DTE - Target SOC - Quick") {
                        Text("\(green.chargingInformation.dte.targetSoC.quick)")
                    }
                    DataRowView(icon: .info, label: "Target SOC - Standard") {
                        Text("\(green.chargingInformation.targetSoC.standard) %")
                    }
                    DataRowView(icon: .info, label: "Target SOC - Quick") {
                        Text("\(green.chargingInformation.targetSoC.quick) %")
                    }
                }
                
                DataStateRowView(icon: .connector, label: "Connector Fasteining", value: green.chargingInformation.connectorFastening.state == 1)
                
                DataStateRowView(icon: .plug, label: "Electric Current Level", value: green.chargingInformation.electricCurrentLevel.state == 1)
                
                DataRowView(icon: .info, label: "Sequence Details") {
                    Text("\(green.chargingInformation.sequenceDetails)")
                }
                DataRowView(icon: .info, label: "Sequence Subcode") {
                    Text("\(green.chargingInformation.sequenceSubcode)")
                }
            }

            Section("Charging Door") {
                DataRowView(icon: .info, label: "Status") {
                    Text(green.chargingDoor.state == .open ? "Open" : "Closed")
                }
                DataRowView(icon: .warning, label: "Error State") {
                    Text(String(green.chargingDoor.errorState))
                }
            }


            Section("Driving History") {
                DataRowView(icon: .info, label: "Avarge") {
                    Text(numberFormatter.string(from: green.drivingHistory.average as NSNumber) ?? "")
                }
            }
            
            Section("Electric - Smart Grid") {
                DataRowView(icon: .grid, label: "Vehicle to Load - SOC") {
                    Text("\(green.electric.smartGrid.vehicleToLoad.dischargeLimitation.soc) %")
                }

                DataRowView(icon: .clock, label: "Vehicle to Load - Remaining Time") {
                    Text("\(green.electric.smartGrid.vehicleToLoad.dischargeLimitation.remainTime)")
                }

                DataRowView(icon: .grid, label: "Vehicle to Grid - Mode") {
                    Text(String(green.electric.smartGrid.vehicleToGrid.mode))
                }

                DataRowView(icon: .power, label: "Real Time Power") {
                    Text(numberFormatter.string(from: green.electric.smartGrid.realTimePower as NSNumber) ?? "")
                }
            }

            Section("Energy Information") {
                DataRowView(icon: .info, label: "DTE - Invalid") {
                    Text("\(green.energyInformation.dte.invalid)")
                }
            }

            Section("Reservation") {
                reservationDepartureSection(departure: green.reservation.departure)
                reservationOffPeakSection(offPeak1: green.reservation.offPeakTime1, offPeak2: green.reservation.offPeakTime2)
            }

            Section("Plug & Charge") {
                DataRowView(icon: .info, label: "Selected Certificate") {
                    Text("\(green.plugAndCharge.selection.selectedCert + 1)")
                }
                DataStateRowView(icon: .info, label: "Selected Certificate - Changeable", value: green.plugAndCharge.selection.changeable == 1)
                DataRowView(icon: .info, label: "Selected Certificate - Mode") {
                    Text("\(green.plugAndCharge.selection.mode)")
                }

                DataRowView(icon: .info, label: "Certificate 1 - Company") {
                    Text("\(green.plugAndCharge.contractCertificate1.company)")
                }
                DataRowView(icon: .info, label: "Certificate 1 - State") {
                    Text("\(green.plugAndCharge.contractCertificate1.state)")
                }

                DataRowView(icon: .info, label: "Certificate 2 - Company") {
                    Text("\(green.plugAndCharge.contractCertificate2.company)")
                }
                DataRowView(icon: .info, label: "Certificate 2 - State") {
                    Text("\(green.plugAndCharge.contractCertificate2.state)")
                }

                DataRowView(icon: .info, label: "Certificate 3 - Company") {
                    Text("\(green.plugAndCharge.contractCertificate3.company)")
                }
                DataRowView(icon: .info, label: "Certificate 3 - State") {
                    Text("\(green.plugAndCharge.contractCertificate3.state)")
                }

                DataRowView(icon: .info, label: "Certificate 4 - Company") {
                    Text("\(green.plugAndCharge.contractCertificate4.company)")
                }
                DataRowView(icon: .info, label: "Certificate 4 - State") {
                    Text("\(green.plugAndCharge.contractCertificate4.state)")
                }

                DataRowView(icon: .info, label: "Certificate 5 - Company") {
                    Text("\(green.plugAndCharge.contractCertificate5.company)")
                }
                DataRowView(icon: .info, label: "Certificate 5 - State") {
                    Text("\(green.plugAndCharge.contractCertificate5.state)")
                }
            }
        }
    }

    @ViewBuilder
    func serviceSection(service: Service, remoteControl: VehicleStatus.RemoteControl) -> some View {
        Group {
            Section("Connected Car") {
                DataStateRowView(icon: .update, label: "Remote Control - Available", value: service.connectedCar.remoteControl.available, kind: .fault)
                DataRowView(icon: .clock, label: "Remote Control - Waiting Time") {
                    Text(numberFormatter.string(from: service.connectedCar.remoteControl.waitingTime as NSNumber) ?? "")
                }
                DataStateRowView(icon: .update, label: "Remote Control - Sleep Mode", value: remoteControl.sleepMode, kind: .fault)
                DataStateRowView(icon: .info, label: "Active Alert - Available", value: service.connectedCar.activeAlert.available, kind: .fault)
            }
        }
    }

    @ViewBuilder
    func locationSection(location: Location) -> some View {
        Group {
            Section("Vehicle Position") {
                DataRowView(icon: .info, label: "Latitude") {
                    Text(String(format: "%.6f", location.geoCoordinate.latitude))
                }
                DataRowView(icon: .info, label: "Longitude") {
                    Text(String(format: "%.6f", location.geoCoordinate.longitude))
                }
                DataRowView(icon: .compass, label: "Heading") {
                    Text("\(location.heading)°")
                }
                DataRowView(icon: .speedometer, label: "Speed") {
                    Text("\(location.speed.value) \(location.speed.unit == .km ? "km/h" : "mph")")
                }
                if let timestamp = location.timeStamp.toDate {
                    DataRowView(icon: .clock, label: "Timestamp") {
                        Text(timestamp, style: .time)
                    }
                }
            }

            Map(initialPosition: .camera(.init(centerCoordinate: location.geoCoordinate.location.coordinate, distance: 500))) {
                Marker(vehicle.nickname, systemImage: "bolt.car", coordinate: location.geoCoordinate.location.coordinate)
                    .tint(.blue)
            }
            .mapStyle(.standard)
            .mapControlVisibility(.hidden)
            .frame(height: 400)
        }
    }
    
    // MARK: - Reservation Helper Methods
    
    @ViewBuilder
    private func reservationDepartureSection(departure: Reservation.Departure) -> some View {
        Group {
            Section("Departure Schedule 1") {
                DataRowView(icon: .clock, label: "Time") {
                    Text(String(format: "%02d:%02d", departure.schedule1.hour, departure.schedule1.minute))
                }
                DataRowView(icon: .info, label: "Days") {
                    Text(formatWeekdays(schedule: departure.schedule1))
                }
                DataRowView(icon: .temperature, label: "Climate Temperature") {
                    Text("\(departure.climate1.temperature)")
                }
                DataStateRowView(icon: .windshieldDefog, label: "Climate Defrost", value: departure.climate1.defrost)
            }
            
            Section("Departure Schedule 2") {
                DataRowView(icon: .clock, label: "Time") {
                    Text(String(format: "%02d:%02d", departure.schedule2.hour, departure.schedule2.minute))
                }
                DataRowView(icon: .info, label: "Days") {
                    Text(formatWeekdays(schedule: departure.schedule2))
                }
                DataRowView(icon: .temperature, label: "Climate Temperature") {
                    Text("\(departure.climate2.temperature)")
                }
                DataStateRowView(icon: .windshieldDefog, label: "Climate Defrost", value: departure.climate2.defrost)
            }
        }
    }
    
    @ViewBuilder
    private func reservationOffPeakSection(offPeak1: Reservation.OffPeakTime, offPeak2: Reservation.OffPeakTime) -> some View {
        Group {
            Section("Off-Peak Charging 1") {
                DataRowView(icon: .clock, label: "Start Time") {
                    Text(String(format: "%02d:%02d", offPeak1.startHour, offPeak1.startMin))
                }
                DataRowView(icon: .clock, label: "End Time") {
                    Text(String(format: "%02d:%02d", offPeak1.endHour, offPeak1.endMin))
                }
                DataRowView(icon: .info, label: "Days") {
                    Text(formatWeekdays(offPeak: offPeak1))
                }
            }
            
            Section("Off-Peak Charging 2") {
                DataRowView(icon: .clock, label: "Start Time") {
                    Text(String(format: "%02d:%02d", offPeak2.startHour, offPeak2.startMin))
                }
                DataRowView(icon: .clock, label: "End Time") {
                    Text(String(format: "%02d:%02d", offPeak2.endHour, offPeak2.endMin))
                }
                DataRowView(icon: .info, label: "Days") {
                    Text(formatWeekdays(offPeak: offPeak2))
                }
            }
        }
    }
    
    private func formatWeekdays(schedule: Reservation.Departure.Schedule) -> String {
        var days: [String] = []
        if schedule.monday == 1 { days.append("Mon") }
        if schedule.tuesday == 1 { days.append("Tue") }
        if schedule.wensday == 1 { days.append("Wed") }
        if schedule.thursday == 1 { days.append("Thu") }
        if schedule.friday == 1 { days.append("Fri") }
        if schedule.saturday == 1 { days.append("Sat") }
        if schedule.sunday == 1 { days.append("Sun") }
        return days.isEmpty ? "None" : days.joined(separator: ", ")
    }
    
    private func formatWeekdays(offPeak: Reservation.OffPeakTime) -> String {
        return "See vehicle app for schedule details"
    }
}
