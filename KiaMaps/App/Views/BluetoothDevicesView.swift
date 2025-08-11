//
//  BluetoothDevicesView.swift
//  KiaMaps
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import SwiftUI

struct BluetoothDevicesView: View {
    @State private var automotiveDevices: [(name: String, identifier: String)] = []
    @State private var isScanning = false
    
    var body: some View {
        List {
            Section("Connected Automotive Devices") {
                if automotiveDevices.isEmpty {
                    Text("No automotive Bluetooth devices found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(automotiveDevices, id: \.identifier) { device in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.headline)
                            Text(device.identifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section("Instructions") {
                Text("1. Connect your phone to your car's Bluetooth")
                Text("2. Make sure you're in the car with the infotainment system on")
                Text("3. The app will automatically detect automotive devices")
                Text("4. These identifiers will be used for CarPlay integration")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .navigationTitle("Bluetooth Devices")
        .onAppear {
            refreshDevices()
        }
        .refreshable {
            refreshDevices()
        }
    }
    
    private func refreshDevices() {
        // Start scanning if not already
        if !isScanning {
            BluetoothManager.shared.startScanning()
            isScanning = true
        }
        
        // Get connected automotive devices after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            automotiveDevices = BluetoothManager.shared.connectedAutomotiveDevices()
        }
    }
}

struct BluetoothDevicesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BluetoothDevicesView()
        }
    }
}
