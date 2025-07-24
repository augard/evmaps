//
//  OverviewPageView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Overview page for vehicle status
//

import SwiftUI

/// Overview page showing battery hero, quick actions, and vehicle status
struct OverviewPageView: View {
    let vehicle: Vehicle
    let status: VehicleStatusResponse
    let isActive: Bool
    let onRefresh: () async -> Void
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: KiaDesign.Spacing.xl) {
                // Hero Battery Section
                BatteryHeroView(from: status)
                
                // Quick Actions
                quickActionsSection
                
                // Vehicle Status Grid
                vehicleStatusGrid
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
        .refreshable {
            await onRefresh()
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        KiaCard {
            QuickActionsView(
                vehicleStatus: status,
                onLockAction: {
                    // Lock vehicle action
                },
                onClimateAction: {
                    // Climate control action
                },
                onHornAction: {
                    // Horn and lights action
                },
                onLocateAction: {
                    // Locate vehicle action
                }
            )
        }
    }
    
    // MARK: - Vehicle Status Grid
    
    private var vehicleStatusGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.medium) {
            // Doors Status - using the available lock data from cabin
            let row1 = status.state.vehicle.cabin.door.row1
            let row2 = status.state.vehicle.cabin.door.row2
            let doorsLocked = !row1.driver.lock && !row1.passenger.lock && !row2.left.lock && !row2.right.lock
            
            statusCard(
                icon: "car.side.lock.fill",
                title: "Doors",
                value: doorsLocked ? "Locked" : "Unlocked",
                color: doorsLocked ? KiaDesign.Colors.success : KiaDesign.Colors.warning
            )
            
            // Driving Ready Status
            statusCard(
                icon: "power",
                title: "Ready",
                value: status.state.vehicle.drivingReady ? "Ready" : "Off",
                color: status.state.vehicle.drivingReady ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary
            )
            
            // Battery Health
            let batteryHealth = status.state.vehicle.green.batteryManagement.soH.ratio / 100.0
            statusCard(
                icon: "battery.100",
                title: "Health",
                value: "\(Int(batteryHealth * 100))%",
                color: batteryHealth > 0.9 ? KiaDesign.Colors.success : 
                       batteryHealth > 0.8 ? KiaDesign.Colors.warning : KiaDesign.Colors.error
            )
            
            // Last Update
            statusCard(
                icon: "clock.fill",
                title: "Updated",
                value: timeAgoString(from: status.lastUpdateTime),
                color: KiaDesign.Colors.textSecondary
            )
        }
    }
    
    // MARK: - Helper Views
    
    private func statusCard(icon: String, title: String, value: String, color: Color) -> some View {
        KiaCard {
            VStack(spacing: KiaDesign.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                
                VStack(spacing: 2) {
                    Text(value)
                        .font(KiaDesign.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text(title)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KiaDesign.Spacing.small)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("Overview Page View") {
    OverviewPageView(
        vehicle: MockVehicleData.mockVehicle,
        status: MockVehicleData.standardResponse,
        isActive: true,
        onRefresh: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}