//
//  BluetoothManager.swift
//  KiaMaps
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import CoreBluetooth
import ExternalAccessory
import os.log

/// Manages Bluetooth device discovery and identifies potential vehicle head units
class BluetoothManager: NSObject {
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager?
    private var connectedDevices: [CBPeripheral] = []
    private var deviceIdentifiers: [String: String] = [:] // Name -> Identifier mapping
    
    /// Known automotive Bluetooth device name patterns
    private let automotivePatterns = [
        "CAR", "AUTO", "VEHICLE", "INFOTAINMENT",
        "KIA", "HYUNDAI", "GENESIS", "PORSCHE",
        "CARPLAY", "ANDROID AUTO", "HEAD UNIT",
        "MY CAR", "BLUETOOTH AUDIO"
    ]
    
    override init() {
        super.init()
    }
    
    /// Start Bluetooth scanning for connected devices
    func startScanning() {
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    /// Get connected automotive devices
    func connectedAutomotiveDevices() -> [(name: String, identifier: String)] {
        var automotiveDevices: [(name: String, identifier: String)] = []
        
        // Check External Accessory devices (for iAP2)
        let connectedAccessories = EAAccessoryManager.shared().connectedAccessories
        for accessory in connectedAccessories {
            if isAutomotiveDevice(name: accessory.name) {
                automotiveDevices.append((
                    name: accessory.name,
                    identifier: accessory.serialNumber
                ))
                os_log(.info, log: Logger.bluetooth, "Found automotive accessory: %{public}@ - %{public}@", accessory.name, accessory.serialNumber)
            }
        }
        
        // Add discovered Bluetooth devices
        for (name, identifier) in deviceIdentifiers {
            if isAutomotiveDevice(name: name) {
                automotiveDevices.append((name: name, identifier: identifier))
            }
        }
        
        return automotiveDevices
    }
    
    /// Get Bluetooth identifier for a specific vehicle based on its name or VIN
    func bluetoothIdentifier(for vehicleName: String) -> String? {
        let devices = connectedAutomotiveDevices()
        
        // Try exact match first
        if let device = devices.first(where: { $0.name.localizedCaseInsensitiveContains(vehicleName) }) {
            return device.identifier
        }
        
        // Try partial match with vehicle make
        let vehicleMake = vehicleName.components(separatedBy: " ").first ?? ""
        if !vehicleMake.isEmpty,
           let device = devices.first(where: { $0.name.localizedCaseInsensitiveContains(vehicleMake) }) {
            return device.identifier
        }
        
        // Return first automotive device if only one is found
        if devices.count == 1 {
            return devices.first?.identifier
        }
        
        return nil
    }
    
    /// Get iAP2 identifier from connected accessories
    func iAP2Identifier(for vehicleName: String) -> String? {
        let accessories = EAAccessoryManager.shared().connectedAccessories
        
        // Look for accessories that match the vehicle
        for accessory in accessories {
            if accessory.name.localizedCaseInsensitiveContains(vehicleName) ||
               isAutomotiveDevice(name: accessory.name) {
                // Use protocol identifier or serial number
                if let protocolString = accessory.protocolStrings.first {
                    return protocolString
                }
                return accessory.serialNumber
            }
        }
        
        return nil
    }
    
    private func isAutomotiveDevice(name: String) -> Bool {
        let uppercasedName = name.uppercased()
        return automotivePatterns.contains { pattern in
            uppercasedName.contains(pattern)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            os_log(.info, log: Logger.bluetooth, "Bluetooth is powered on")
            // Retrieve connected peripherals
            let connectedPeripherals = central.retrieveConnectedPeripherals(withServices: [])
            self.connectedDevices = connectedPeripherals
            
            // Store device information
            for peripheral in connectedPeripherals {
                let name = peripheral.name ?? "Unknown Device"
                let identifier = peripheral.identifier.uuidString
                deviceIdentifiers[name] = identifier
                os_log(.info, log: Logger.bluetooth, "Connected device: %{public}@ - %{public}@", name, identifier)
            }
            
        case .poweredOff:
            os_log(.info, log: Logger.bluetooth, "Bluetooth is powered off")
        case .unauthorized:
            os_log(.error, log: Logger.bluetooth, "Bluetooth access is unauthorized")
        case .unsupported:
            os_log(.error, log: Logger.bluetooth, "Bluetooth is not supported")
        default:
            os_log(.debug, log: Logger.bluetooth, "Bluetooth state: %{public}d", central.state.rawValue)
        }
    }
}

// MARK: - Vehicle Extension
extension Vehicle {
    /// Get Bluetooth and iAP2 identifiers for this vehicle
    func headUnitIdentifiers() -> (bluetooth: String?, iap2: String?) {
        let bluetoothId = BluetoothManager.shared.bluetoothIdentifier(for: self.nickname)
        let iap2Id = BluetoothManager.shared.iAP2Identifier(for: self.nickname)
        
        // Fallback to TMU number if no Bluetooth device found
        let finalBluetoothId = bluetoothId ?? (bluetoothId == nil ? nil : self.tmuNumber)
        
        return (bluetooth: finalBluetoothId, iap2: iap2Id)
    }
}
