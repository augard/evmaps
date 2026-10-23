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
    let vehicleState: VehicleStatus
    let vehicleLocation: VehicleStatus.Location
    let isActive: Bool
    
    var body: some View {
        VehicleMapView(
            vehicle: vehicle,
            vehicleState: vehicleState,
            vehicleLocation: vehicleLocation
        )
        .background(KiaDesign.Colors.background)
    }
}

// MARK: - Preview

#Preview("Map Page View") {
    MapPageView(
        vehicle: MockVehicleData.mockVehicle,
        vehicleState: KiaVehicleStatusMapper.map(state: MockVehicleData.standard),
        vehicleLocation: KiaVehicleStatusMapper.map(state: MockVehicleData.standard).location!,
        isActive: true
    )
}
