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
    let status: VehicleStatusResponse
    let isActive: Bool
    
    var body: some View {
        VehicleMapView(
            vehicle: vehicle,
            vehicleStatus: status.state.vehicle,
        )
        .background(KiaDesign.Colors.background)
    }
}

// MARK: - Preview

#Preview("Map Page View") {
    MapPageView(
        vehicle: MockVehicleData.mockVehicle,
        status: MockVehicleData.standardResponse,
        isActive: true
    )
}
