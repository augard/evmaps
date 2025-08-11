//
//  DetailsPageView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Details page for vehicle information and diagnostics
//

import SwiftUI

/// Details page showing vehicle information and diagnostics
struct DetailsPageView: View {
    let vehicle: Vehicle
    let status: VehicleStatusResponse
    let isActive: Bool
    let onRefresh: () async -> Void
    let apiConfigurationName: String
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: KiaDesign.Spacing.xl) {
                // Vehicle Details Card
                vehicleDetailsCard
                
                // Additional vehicle information
                additionalVehicleInfo
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
        .refreshable {
            await onRefresh()
        }
    }
    
    // MARK: - Vehicle Details Card
    
    private var vehicleDetailsCard: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Vehicle Information")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                VStack(spacing: KiaDesign.Spacing.small) {
                    vehicleDetailRow(
                        icon: "car.fill",
                        title: "Model",
                        value: "\(vehicle.nickname) (\(vehicle.year))"
                    )
                    
                    vehicleDetailRow(
                        icon: "barcode",
                        title: "VIN",
                        value: vehicle.vin
                    )
                    
                    vehicleDetailRow(
                        icon: "tag.fill",
                        title: "Brand",
                        value: apiConfigurationName
                    )
                }
            }
        }
    }
    
    // MARK: - Additional Vehicle Info
    
    private var additionalVehicleInfo: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            // Vehicle Diagnostics
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Diagnostics")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.small) {
                        // Real odometer data from API
                        diagnosticItem("Odometer", formatDistance(status.state.vehicle.drivetrain.odometer))
                        
                        // Engine hours - not available in API for EVs
                        diagnosticItem("System Hours", "N/A")
                        
                        // Service data - not available in current API response
                        diagnosticItem("Service Due", "Check app")
                        
                        // Last update time from API
                        diagnosticItem("Last Updated", formatTimeAgo(status.lastUpdateTime))
                    }
                }
            }
            
            // Recent Activity
            KiaCard {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                    Text("Recent Activity")
                        .font(KiaDesign.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    VStack(spacing: KiaDesign.Spacing.xs) {
                        // Generate activity based on current vehicle status
                        if status.state.vehicle.isCharging {
                            let batteryLevel = Int(status.state.vehicle.green.batteryManagement.batteryRemain.ratio)
                            activityItem("Currently charging (\(batteryLevel)%)", "Now", "bolt.circle.fill", KiaDesign.Colors.charging)
                        } else {
                            let batteryLevel = Int(status.state.vehicle.green.batteryManagement.batteryRemain.ratio)
                            activityItem("Battery at \(batteryLevel)%", formatTimeAgo(status.lastUpdateTime), "battery.100", KiaDesign.Colors.success)
                        }
                        
                        // Vehicle ready status
                        if status.state.vehicle.drivingReady {
                            activityItem("Vehicle ready", formatTimeAgo(status.lastUpdateTime), "car.fill", KiaDesign.Colors.primary)
                        } else {
                            activityItem("Vehicle parked", formatTimeAgo(status.lastUpdateTime), "car.side.fill", KiaDesign.Colors.textSecondary)
                        }
                        
                        // Last status update
                        activityItem("Status updated", formatTimeAgo(status.lastUpdateTime), "arrow.clockwise", KiaDesign.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func vehicleDetailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: KiaDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(KiaDesign.Typography.body)
                .fontWeight(.medium)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
        }
    }
    
    private func diagnosticItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(KiaDesign.Typography.body)
                .fontWeight(.semibold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
            
            Text(label)
                .font(KiaDesign.Typography.caption)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func activityItem(_ title: String, _ time: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: KiaDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KiaDesign.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text(time)
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, KiaDesign.Spacing.xs)
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDistance(_ distance: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        if let formattedNumber = formatter.string(from: NSNumber(value: distance)) {
            return "\(formattedNumber) km"
        }
        return "\(Int(distance)) km"
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("Details Page View") {
    DetailsPageView(
        vehicle: MockVehicleData.mockVehicle,
        status: MockVehicleData.standardResponse,
        isActive: true,
        onRefresh: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        },
        apiConfigurationName: "Kia"
    )
}