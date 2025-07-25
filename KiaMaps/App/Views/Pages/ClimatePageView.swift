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
                ClimateControlView(
                    vehicleStatus: status.state.vehicle,
                    unit: .celsius
                )
                
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
                        value: interiorTemperatureValue
                    )
                    
                    climateStatusRow(
                        label: "System Status",
                        value: hvacSystemStatus,
                        valueColor: hvacSystemColor
                    )
                    
                    climateStatusRow(
                        label: "Fan Speed",
                        value: fanSpeedValue
                    )
                    
                    climateStatusRow(
                        label: "Defrost",
                        value: defrostStatus
                    )
                    
                    climateStatusRow(
                        label: "Heated Seats",
                        value: heatedSeatsStatus
                    )
                }
            }
        }
    }
    
    // MARK: - Climate Data Properties
    
    private var interiorTemperatureValue: String {
        let hvac = status.state.vehicle.cabin.hvac
        let tempValue = hvac.row1.driver.temperature.value
        let tempUnit = hvac.row1.driver.temperature.unit
        
        // Convert hex temperature to readable format if needed
        if let intValue = Int(tempValue, radix: 16) {
            let celsiusTemp = Double(intValue) / 2.0 // Assuming hex represents half degrees
            return String(format: "%.1f°%@", celsiusTemp, tempUnit == .celsius ? "C" : "F")
        } else {
            // If hex conversion fails, try direct string interpretation
            return "\(tempValue)°\(tempUnit == .celsius ? "C" : "F")"
        }
    }
    
    private var hvacSystemStatus: String {
        let hvac = status.state.vehicle.cabin.hvac
        let isHvacOn = hvac.row1.driver.blower.speedLevel > 0
        
        if !isHvacOn {
            return "Off"
        } else {
            // Since we don't have autoMode in the API, just indicate it's active
            return "Active"
        }
    }
    
    private var hvacSystemColor: Color {
        let isHvacOn = status.state.vehicle.cabin.hvac.row1.driver.blower.speedLevel > 0
        return isHvacOn ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary
    }
    
    private var fanSpeedValue: String {
        let speedLevel = status.state.vehicle.cabin.hvac.row1.driver.blower.speedLevel
        return speedLevel > 0 ? "Level \(speedLevel)" : "Off"
    }
    
    private var defrostStatus: String {
        // Defrost information not available in current HVAC API structure
        // Use air cleaning indicator from ventilation as a proxy
        let airCleaning = status.state.vehicle.cabin.hvac.ventilation.airCleaning.indicator
        return airCleaning > 0 ? "Active" : "Off"
    }
    
    private var heatedSeatsStatus: String {
        let seat = status.state.vehicle.cabin.seat
        let driverState = seat.row1.driver.climate.state
        let passengerState = seat.row1.passenger.climate.state
        
        // RESTMode uses state as Int where 0 = off, higher values = heating levels
        if driverState > 0 && passengerState > 0 {
            return "Driver: Level \(driverState), Passenger: Level \(passengerState)"
        } else if driverState > 0 {
            return "Driver: Level \(driverState)"
        } else if passengerState > 0 {
            return "Passenger: Level \(passengerState)"
        } else {
            return "Off"
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