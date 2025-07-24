//
//  VehicleSelectionView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Vehicle selection view for MainView
//

import SwiftUI

/// Vehicle selection view displayed when user has multiple vehicles
struct VehicleSelectionView: View {
    let vehicles: [Vehicle]
    let onRefresh: () async -> Void
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: KiaDesign.Spacing.xl) {
                vehicleSelectionSection
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
        .refreshable {
            await onRefresh()
        }
    }
    
    // MARK: - Vehicle Selection Section
    
    private var vehicleSelectionSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.large) {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Your Vehicles")
                        .font(KiaDesign.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("Select a vehicle to view its status and controls")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                LazyVStack(spacing: KiaDesign.Spacing.medium) {
                    ForEach(vehicles) { vehicle in
                        modernVehicleRow(vehicle)
                    }
                }
            }
        }
    }
    
    // MARK: - Vehicle Row
    
    private func modernVehicleRow(_ vehicle: Vehicle) -> some View {
        Button(action: {
            // Vehicle selection would go here - keeping existing logic
            UISelectionFeedbackGenerator().selectionChanged()
        }) {
            HStack(spacing: KiaDesign.Spacing.medium) {
                // Vehicle icon
                ZStack {
                    Circle()
                        .fill(KiaDesign.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(KiaDesign.Colors.primary)
                }
                
                // Vehicle details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vehicle.nickname) (\(vehicle.year))")
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text("VIN: \(vehicle.vin)")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
            }
            .padding(KiaDesign.Spacing.medium)
            .background(KiaDesign.Colors.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Vehicle Selection View") {
    VehicleSelectionView(
        vehicles: [MockVehicleData.mockVehicle],
        onRefresh: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}