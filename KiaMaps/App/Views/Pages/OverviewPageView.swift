//
//  OverviewPageView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Overview page for vehicle status
//

import SwiftUI
import Combine

/// Overview page showing battery hero, quick actions, and vehicle status
struct OverviewPageView: View {
    let brandName: String
    let vehicle: Vehicle
    let status: VehicleStatus
    let lastUpdateTime: Date
    let isActive: Bool
    let mqttConnectionStatus: MQTTConnectionStatus
    let receivedMQTTUpdate: Bool
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
                VehicleStateGrid
                
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
                    vehicleState: status,
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
                            vehicleState: status
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
                VehicleState: status,
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
    
    private var VehicleStateGrid: some View {
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
            
            // Last Update - show MQTT indicator if receiving real-time data
            statusCard(
                icon: receivedMQTTUpdate ? "antenna.radiowaves.left.and.right" : "clock.fill",
                title: receivedMQTTUpdate ? "Live" : "Updated",
                value: receivedMQTTUpdate ? "Real-time" : timeAgoString(from: lastUpdateTime),
                color: receivedMQTTUpdate ? KiaDesign.Colors.primary : KiaDesign.Colors.textSecondary
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
                        value: brandName
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
                    
                    // Last update time from API or MQTT
                    diagnosticItem("Last Updated", receivedMQTTUpdate ? "Real-time" : timeAgoString(from: lastUpdateTime))
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
                        let timeText = receivedMQTTUpdate ? "Live" : "Now"
                        activityItem("Currently charging (\(batteryLevel)%)", timeText, "bolt.circle.fill", KiaDesign.Colors.charging)
                    } else {
                        let batteryLevel = Int(status.green.batteryManagement.batteryRemain.ratio)
                        let timeText = receivedMQTTUpdate ? "Live" : timeAgoString(from: lastUpdateTime)
                        activityItem("Battery at \(batteryLevel)%", timeText, "battery.100", KiaDesign.Colors.success)
                    }
                    
                    // Vehicle ready status
                    if status.drivingReady {
                        let timeText = receivedMQTTUpdate ? "Live" : timeAgoString(from: lastUpdateTime)
                        activityItem("Vehicle ready", timeText, "car.fill", KiaDesign.Colors.primary)
                    } else {
                        let timeText = receivedMQTTUpdate ? "Live" : timeAgoString(from: lastUpdateTime)
                        activityItem("Vehicle parked", timeText, "car.side.fill", KiaDesign.Colors.textSecondary)
                    }
                    
                    // MQTT connection status
                    if status.isCharging && mqttConnectionStatus == .connected {
                        activityItem("MQTT connected", "Real-time updates active", "antenna.radiowaves.left.and.right", KiaDesign.Colors.primary)
                    }
                    
                    // Last status update
                    let updateText = receivedMQTTUpdate ? "Real-time updates" : "Status updated"
                    let updateTime = receivedMQTTUpdate ? "Active" : timeAgoString(from: lastUpdateTime)
                    activityItem(updateText, updateTime, "arrow.clockwise", KiaDesign.Colors.textSecondary)
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
}

// MARK: - Preview

#Preview("Overview Page View") {
    OverviewPageView(
        brandName: "Mocker",
        vehicle: MockVehicleData.mockVehicle,
        status: KiaVehicleStatusMapper.map(state: MockVehicleData.lowTirePressure),
        lastUpdateTime: .now,
        isActive: true,
        mqttConnectionStatus: .disconnected,
        receivedMQTTUpdate: false,
        onRefresh: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    )
}
