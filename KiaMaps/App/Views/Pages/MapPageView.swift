//
//  MapPageView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Map page for vehicle location and navigation
//

import SwiftUI

/// Map page showing vehicle location and navigation
struct MapPageView: View {
    let vehicle: Vehicle
    let vehicleStatus: VehicleStatus
    let vehicleLocation: Location
    let isActive: Bool
    
    var body: some View {
        VehicleMapView(
            vehicle: vehicle,
            vehicleStatus: vehicleStatus,
            vehicleLocation: vehicleLocation
        )
        .background(KiaDesign.Colors.background)
    }
}

// MARK: - Preview

#Preview("Map Page View") {
    MapPageView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleStatus: MockVehicleData.standard,
        vehicleLocation: MockVehicleData.standard.location!,
        isActive: true
    )
}
