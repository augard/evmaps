//
//  ClimatePageView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Climate control page for vehicle
//

import SwiftUI

/// Climate control page with temperature dial and status
struct ClimatePageView: View {
    let status: VehicleStatusResponse
    let isActive: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: KiaDesign.Spacing.xl) {
                ClimateControlView(unit: .celsius)
                
                // Additional climate features based on vehicle status
                climateStatusSection
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
    }
    
    // MARK: - Climate Status Section
    
    private var climateStatusSection: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Climate Status")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    climateStatusRow(
                        label: "Interior Temperature",
                        value: "22°C"
                    )
                    
                    climateStatusRow(
                        label: "System Status",
                        value: "Auto",
                        valueColor: KiaDesign.Colors.success
                    )
                    
                    climateStatusRow(
                        label: "Fan Speed",
                        value: "Level 3"
                    )
                    
                    climateStatusRow(
                        label: "Defrost",
                        value: "Off"
                    )
                    
                    climateStatusRow(
                        label: "Heated Seats",
                        value: "Driver: Level 2"
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func climateStatusRow(
        label: String,
        value: String,
        valueColor: Color = KiaDesign.Colors.textPrimary
    ) -> some View {
        HStack {
            Text(label)
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(KiaDesign.Typography.body)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Preview

#Preview("Climate Page View") {
    ClimatePageView(
        status: MockVehicleData.standardResponse,
        isActive: true
    )
}