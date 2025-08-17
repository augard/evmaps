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
    let status: VehicleStatus
    let lastUpdateTime: Date
    let isActive: Bool
    let onRefresh: () async -> Void
    
    @State private var showClimateModal = false
    @State private var showLocationModal = false
    @State private var showLockModal = false
    @State private var showMoreDetails = false
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: KiaDesign.Spacing.xl) {
                // Hero Battery Section
                BatteryHeroView(from: status)
                
                // Quick Actions
                quickActionsSection
                
                // Vehicle Status Grid
                vehicleStatusGrid
                
                // More Details Button
                moreDetailsButton
                
                // Expandable Details Section
                if showMoreDetails {
                    detailsSection
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                }
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
        .refreshable {
            await onRefresh()
        }
        .sheet(isPresented: $showClimateModal) {
            NavigationView {
                ClimatePageView(status: status, isActive: isActive)
                    .navigationTitle("Climate Control")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showClimateModal = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLocationModal) {
            NavigationView {
                VehicleMapView(
                    vehicle: vehicle,
                    vehicleStatus: status,
                    vehicleLocation: status.location!,
                    onChargingStationTap: { station in
                        // Handle charging station tap
                        print("Charging station tapped: \(station.name)")
                    },
                    onVehicleTap: {
                        // Handle vehicle annotation tap
                        print("Vehicle tapped on map")
                    }
                )
                .navigationTitle("Vehicle Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showLocationModal = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(KiaDesign.Colors.textSecondary)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLockModal) {
            NavigationView {
                ScrollView {
                    VStack(spacing: KiaDesign.Spacing.xl) {
                        InteractiveVehicleSilhouetteView(
                            vehicleStatus: status
                        )
                    }
                    .padding(KiaDesign.Spacing.large)
                    .frame(maxWidth: .infinity)
                }
                .background(KiaDesign.Colors.background)
                .navigationTitle("Vehicle Status")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showLockModal = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(KiaDesign.Colors.textSecondary)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        KiaCard {
            QuickActionsView(
                vehicleStatus: status,
                onLockAction: {
                    // Show vehicle silhouette modal
                    showLockModal = true
                },
                onClimateAction: {
                    // Climate action - just show modal immediately
                    showClimateModal = true
                },
                onHornAction: {
                    // Horn and lights action - simulate API call
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                },
                onLocateAction: {
                    // Show location modal
                    showLocationModal = true
                }
            )
        }
    }
    
    // MARK: - Vehicle Status Grid
    
    private var vehicleStatusGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.medium) {
            // Doors Status - using the available lock data from cabin
            let row1 = status.cabin.door.row1
            let row2 = status.cabin.door.row2
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
                value: status.drivingReady ? "Ready" : "Off",
                color: status.drivingReady ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary
            )
            
            // Battery Health
            let batteryHealth = status.green.batteryManagement.soH.ratio / 100.0
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
                value: timeAgoString(from: lastUpdateTime),
                color: KiaDesign.Colors.textSecondary
            )
        }
    }
    
    // MARK: - More Details Button
    
    private var moreDetailsButton: some View {
        KiaButton(
            showMoreDetails ? "Show Less" : "More Details",
            icon: showMoreDetails ? "chevron.up" : "chevron.down",
            style: .secondary,
            size: .large,
            hapticFeedback: .light,
            action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMoreDetails.toggle()
                }
            }
        )
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Vehicle Information
            vehicleDetailsCard
            
            // Diagnostics
            diagnosticsCard
            
            // Recent Activity
            recentActivityCard
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showMoreDetails)
    }
    
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
                        value: getBrandName()
                    )
                }
            }
        }
    }
    
    private var diagnosticsCard: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Diagnostics")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KiaDesign.Spacing.small) {
                    // Real odometer data from API
                    diagnosticItem("Odometer", formatDistance(status.drivetrain.odometer))

                    // Engine hours - not available in API for EVs
                    diagnosticItem("System Hours", "N/A")
                    
                    // Service data - not available in current API response
                    diagnosticItem("Service Due", "Check app")
                    
                    // Last update time from API
                    diagnosticItem("Last Updated", timeAgoString(from: lastUpdateTime))
                }
            }
        }
    }
    
    private var recentActivityCard: some View {
        KiaCard {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
                Text("Recent Activity")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                VStack(spacing: KiaDesign.Spacing.xs) {
                    // Generate activity based on current vehicle status
                    if status.isCharging {
                        let batteryLevel = Int(status.green.batteryManagement.batteryRemain.ratio)
                        activityItem("Currently charging (\(batteryLevel)%)", "Now", "bolt.circle.fill", KiaDesign.Colors.charging)
                    } else {
                        let batteryLevel = Int(status.green.batteryManagement.batteryRemain.ratio)
                        activityItem("Battery at \(batteryLevel)%", timeAgoString(from: lastUpdateTime), "battery.100", KiaDesign.Colors.success)
                    }
                    
                    // Vehicle ready status
                    if status.drivingReady {
                        activityItem("Vehicle ready", timeAgoString(from: lastUpdateTime), "car.fill", KiaDesign.Colors.primary)
                    } else {
                        activityItem("Vehicle parked", timeAgoString(from: lastUpdateTime), "car.side.fill", KiaDesign.Colors.textSecondary)
                    }
                    
                    // Last status update
                    activityItem("Status updated", timeAgoString(from: lastUpdateTime), "arrow.clockwise", KiaDesign.Colors.textSecondary)
                }
            }
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
    
    private func formatDistance(_ distance: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        if let formattedNumber = formatter.string(from: NSNumber(value: distance)) {
            return "\(formattedNumber) km"
        }
        return "\(Int(distance)) km"
    }
    
    private func getBrandName() -> String {
        // Determine brand based on vehicle parameters or API configuration
        // This is a simplified version - in a real app, this would come from proper configuration
        return "Kia"
    }
}

// MARK: - Preview

#Preview("Overview Page View") {
    OverviewPageView(
        vehicle: MockVehicleData.mockVehicle,
        status: MockVehicleData.lowTirePressure,
        lastUpdateTime: .now,
        isActive: true,
        onRefresh: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}
