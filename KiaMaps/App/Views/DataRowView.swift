//
//  DataRowView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 20.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI

enum IconName: String {
    case car
    case info = "info.circle"
    case warning = "exclamationmark.circle"
    case ready = "figure.run"
    case power = "bolt.fill"
    case grid = "grid"

    case charger = "ev.charger"
    case battery = "minus.plus.and.fluid.batteryblock"
    case batteryWarning = "minus.plus.batteryblock.exclamationmark"
    case batteryCharing = "bolt.batteryblock"
    case connector = "ev.plug.dc.ccs2"
    case plug = "powerplug"
    
    case clock
    
    case windshield = "windshield.front.and.wiper"
    case windshieldDefog = "windshield.front.and.heat.waves"
    case windshieldHeat = "heat.element.windshield"
    
    case frunkOpen = "car.side.front.open"
    case trunkOpen = "suv.side.rear.open"
    case sunRoofOpen = "window.shade.open"
    case doorFrontLeft = "car.top.door.front.left.open"
    case doorFrontRight = "car.top.door.front.right.open"
    case doorRearLeft = "car.top.door.rear.left.open"
    case doorRearRight = "car.top.door.rear.right.open"
    case doorLocked = "suv.side.lock"
    case doorUnlocked = "suv.side.lock.open"
    
    case temperature = "thermometer.medium"
    case air = "suv.side.air.circulate"
    case fan = "fan"
    case smoke = "smoke"
    
    case seat = "carseat.left"
    case seatCooling = "carseat.left.fan"
    case seatHealing = "carseat.left.and.heat.waves"
    
    case window = "car.window.right"
    case windowLevel = "arrowtriangle.up.arrowtriangle.down.window.right"
    
    case steering = "steeringwheel"
    case steeringHeating = "steeringwheel.and.heat.waves"
    
    case tirePressure = "tirepressure"
    case breakFluid = "fluid.brakesignal"
    
    case light = "lightbulb"
    case lightWarning = "exclamationmark.warninglight"
    case headlight = "headlight.low.beam"
    case hazardLight = "parkinglight"
    case parking = "parkingsign.circle"
    case gearShift = "gearshift.layout.sixspeed"
    case key = "key"
    
    case update = "cloud"
}

struct DataRowView<Content: View>: View {
    var icon: IconName
    var label: String
    var content: Content
    
    init(icon: IconName, label: String, content: () -> Content) {
        self.icon = icon
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon.rawValue)
                .frame(width: 30)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)

                    content
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .frame(minHeight: 44)
    }
}

struct DataProgressRowView: View {
    var icon: IconName
    var label: String
    var value: Double
    
    init(icon: IconName, label: String, value: Double) {
        self.icon = icon
        self.label = label
        self.value = value
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            ProgressView(value: value)
                .frame(height: 10)
        }
    }
}

struct DataStateRowView: View {
    enum Kind {
        case state
        case door
        case fault
        case lock
    }
    
    var icon: IconName
    var label: String
    var value: Bool
    var kind: Kind
    
    init(icon: IconName, label: String, value: Bool, kind: Kind = .state) {
        self.icon = icon
        self.label = label
        self.value = value
        self.kind = kind
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            switch kind {
            case .state:
                Text(value ? "Enabled": "Disabled")
            case .door:
                Text(value ? "Open": "Closed")
            case .fault:
                Text(value ? "Yes": "No")
            case .lock:
                Text(value ? "Locked" : "Unlocked")
            }
        }
    }
}

struct DataTemperatureRowView: View {
    var icon: IconName
    var label: String
    var value: String
    
    init(
        icon: IconName = .temperature,
        label: String = "Temperature",
        value: String,
        unit: TemperatureUnit
    ) {
        self.icon = icon
        self.label = label
        
        if value == "OFF" {
            self.value = "Off"
        } else if let value = Double(value) {
            let measurement: Measurement<UnitTemperature> = .init(value: value, unit: unit.measuremntUnit)
            
            let message = MeasurementFormatter()
            self.value = message.string(from: measurement)
        } else {
            self.value = value
        }
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            Text(value)
        }
    }
}

struct DataDistanceRowView: View {
    var icon: IconName
    var label: String
    var value: String
    
    init(
        icon: IconName = .car,
        label: String = "Distance",
        value: Int,
        unit: DistanceUnit
    ) {
        self.icon = icon
        self.label = label
        let measurement: Measurement<UnitLength> = .init(value: Double(value), unit: unit.measuremntUnit)
        let message = MeasurementFormatter()
        self.value = message.string(from: measurement)
    }
    
    init(
        icon: IconName = .car,
        label: String = "Distance",
        value: Double,
        unit: DistanceUnit
    ) {
        self.icon = icon
        self.label = label
        let measurement: Measurement<UnitLength> = .init(value: Double(value), unit: unit.measuremntUnit)
        let message = MeasurementFormatter()
        self.value = message.string(from: measurement)
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            Text(value)
        }
    }
}

struct DataEconomyRowView: View {
    var icon: IconName
    var label: String
    var value: String
    
    init(
        icon: IconName = .charger,
        label: String = "Economy",
        value: Double,
        unit: EconomyUnit
    ) {
        self.icon = icon
        self.label = label
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        self.value = (numberFormatter.string(from: value as NSNumber) ?? "") + " " + unit.unitTitle
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            Text(value)
        }
    }
}

struct DataEnergyRowView: View {
    var icon: IconName
    var label: String
    var value: String
    
    init(
        icon: IconName = .charger,
        label: String = "Capacity",
        value: Double
    ) {
        self.icon = icon
        self.label = label
        let measurement: Measurement<UnitEnergy> = .init(value: value, unit: .kilojoules)
        let message = MeasurementFormatter()
        message.unitOptions = .providedUnit
        self.value = message.string(from: measurement.converted(to: .kilowattHours))
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            Text(value)
        }
    }
}

struct DataTimeRowView: View {
    var icon: IconName
    var label: String
    var value: String
    
    init(
        icon: IconName = .clock,
        label: String,
        value: Int,
        unit: TimeUnit
    ) {
        self.icon = icon
        self.label = label
        let measurement: Measurement<UnitDuration> = .init(value: Double(value), unit: unit.unitDuration)
        let message = MeasurementFormatter()
        message.unitOptions = .providedUnit
        self.value = message.string(from: measurement)
    }
    
    init(
        icon: IconName = .clock,
        label: String,
        value: Double,
        unit: TimeUnit
    ) {
        self.icon = icon
        self.label = label
        let measurement: Measurement<UnitDuration> = .init(value: value, unit: unit.unitDuration)
        let message = MeasurementFormatter()
        message.unitOptions = .providedUnit
        self.value = message.string(from: measurement)
    }
    
    var body: some View {
        DataRowView(icon: icon, label: label) {
            Text(value)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        DataRowView(
            icon: .battery,
            label: "Simple",
            content: { Text("Text value") }
        )
        DataProgressRowView(
            icon: .battery,
            label: "Progress",
            value: 0.8
        )
        
        Spacer()
    }
    .padding()
}
