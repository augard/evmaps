//
//  MockVehicleDataTests.swift
//  KiaTests
//
//  Created by Claude Code on 21/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class MockVehicleDataTests: XCTestCase {
    
    // MARK: - Data Integrity Tests
    
    func testStandardScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.standard
        
        // Verify battery level
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 75)
        
        // Verify not charging
        XCTAssertEqual(vehicleStatus.location.heading, 0)
        
        // Verify driving ready
        XCTAssertEqual(vehicleStatus.green.drivingReady, true)
        XCTAssertEqual(vehicleStatus.drivingReady, true)
        
        // Verify basic structure exists
        XCTAssertNotNil(vehicleStatus.body)
        XCTAssertNotNil(vehicleStatus.cabin)
        XCTAssertNotNil(vehicleStatus.chassis)
        XCTAssertNotNil(vehicleStatus.drivetrain)
        XCTAssertNotNil(vehicleStatus.electronics)
        XCTAssertNotNil(vehicleStatus.green)
        XCTAssertNotNil(vehicleStatus.service)
        XCTAssertNotNil(vehicleStatus.remoteControl)
        XCTAssertNotNil(vehicleStatus.location)
    }
    
    func testChargingScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.charging
        
        // Verify battery level
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 45)
        
        // Verify charging (heading > 0 indicates charging in mock)
        XCTAssertEqual(vehicleStatus.location.heading, 180)
        
        // Verify not driving ready when charging
        XCTAssertEqual(vehicleStatus.green.drivingReady, false)
        XCTAssertEqual(vehicleStatus.drivingReady, false)
        
        // Verify charging times are set
        XCTAssertGreaterThan(vehicleStatus.green.chargingInformation.estimatedTime.iccb, 0)
        XCTAssertGreaterThan(vehicleStatus.green.chargingInformation.estimatedTime.standard, 0)
        XCTAssertGreaterThan(vehicleStatus.green.chargingInformation.estimatedTime.quick, 0)
    }
    
    func testLowBatteryScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.lowBattery
        
        // Verify low battery level
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 12)
        
        // Verify not charging
        XCTAssertEqual(vehicleStatus.location.heading, 0)
        
        // Verify still driving ready despite low battery
        XCTAssertEqual(vehicleStatus.green.drivingReady, true)
        
        // Verify battery pre-warning for low battery
        XCTAssertEqual(vehicleStatus.electronics.autoCut.batteryPreWarning, true)
    }
    
    func testFullBatteryScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.fullBattery
        
        // Verify full battery
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 100)
        
        // Verify not charging (finished)
        XCTAssertEqual(vehicleStatus.location.heading, 0)
        
        // Verify driving ready
        XCTAssertEqual(vehicleStatus.green.drivingReady, true)
        
        // Verify battery pre-warning is not active
        XCTAssertEqual(vehicleStatus.electronics.autoCut.batteryPreWarning, false)
    }
    
    func testFastChargingScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.fastCharging
        
        // Verify battery level
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 67)
        
        // Verify charging
        XCTAssertEqual(vehicleStatus.location.heading, 180)
        
        // Verify not driving ready
        XCTAssertEqual(vehicleStatus.green.drivingReady, false)
        
        // Verify charging information exists
        XCTAssertNotNil(vehicleStatus.green.chargingInformation)
        
        // Verify driving mode is Sport for fast charging scenario
        XCTAssertEqual(vehicleStatus.chassis.drivingMode.state, "Sport")
    }
    
    func testPreconditioningScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.preconditioning
        
        // Verify battery level
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 82)
        
        // Verify not charging
        XCTAssertEqual(vehicleStatus.location.heading, 0)
        
        // Verify driving ready
        XCTAssertEqual(vehicleStatus.green.drivingReady, true)
        
        // Verify HVAC temperatures and fan settings
        XCTAssertEqual(vehicleStatus.cabin.hvac.row1.driver.temperature.value, "22")
        XCTAssertEqual(vehicleStatus.cabin.hvac.row1.driver.blower.speedLevel, 3)
        
        // Verify seat climate is active
        XCTAssertGreaterThan(vehicleStatus.cabin.seat.row1.driver.climate.state, 0)
        
        // Verify steering wheel heating (if available)
        if let steeringWheelHeat = vehicleStatus.cabin.steeringWheel.heat {
            XCTAssertEqual(steeringWheelHeat.state, true)
        }
        
        // Verify reservation schedule is enabled
        XCTAssertEqual(vehicleStatus.green.reservation.departure.schedule1.enable, true)
    }
    
    func testMaintenanceScenarioDataIntegrity() throws {
        let vehicleStatus = MockVehicleData.maintenance
        
        // Verify battery level
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 58)
        
        // Verify not driving ready (maintenance mode)
        XCTAssertEqual(vehicleStatus.green.drivingReady, false)
        
        // Verify maintenance indicators
        XCTAssertEqual(vehicleStatus.body.windshield.front.washerFluid.levelLow, true)
        XCTAssertEqual(vehicleStatus.chassis.axle.row1.right.tire.pressureLow, true)

        // Verify brake fluid warning (no direct level property)
        XCTAssertNotNil(vehicleStatus.chassis.brake.fluid)
        
        // Verify battery state of health
        XCTAssertLessThan(vehicleStatus.green.batteryManagement.soH.ratio, 100.0)
    }
    
    // MARK: - Helper Method Tests
    
    func testBatteryLevelHelperMethod() {
        // Test various scenarios
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.standard), 0.75, accuracy: 0.01)
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.charging), 0.45, accuracy: 0.01)
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.lowBattery), 0.12, accuracy: 0.01)
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.fullBattery), 1.0, accuracy: 0.01)
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.fastCharging), 0.67, accuracy: 0.01)
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.preconditioning), 0.82, accuracy: 0.01)
        XCTAssertEqual(MockVehicleData.batteryLevel(from: MockVehicleData.maintenance), 0.58, accuracy: 0.01)
    }
    
    func testIsChargingHelperMethod() {
        // Verify charging detection based on heading
        XCTAssertFalse(MockVehicleData.isCharging(MockVehicleData.standard))
        XCTAssertTrue(MockVehicleData.isCharging(MockVehicleData.charging))
        XCTAssertFalse(MockVehicleData.isCharging(MockVehicleData.lowBattery))
        XCTAssertFalse(MockVehicleData.isCharging(MockVehicleData.fullBattery))
        XCTAssertTrue(MockVehicleData.isCharging(MockVehicleData.fastCharging))
        XCTAssertFalse(MockVehicleData.isCharging(MockVehicleData.preconditioning))
        XCTAssertFalse(MockVehicleData.isCharging(MockVehicleData.maintenance))
    }
    
    func testEstimatedRangeHelperMethod() {
        // Test range calculation (ratio * 4)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.standard), 300)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.charging), 180)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.lowBattery), 48)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.fullBattery), 400)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.fastCharging), 268)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.preconditioning), 328)
        XCTAssertEqual(MockVehicleData.estimatedRange(from: MockVehicleData.maintenance), 232)
    }
    
    // MARK: - JSON Decoding Tests
    
    func testVehicleStatusJSONDecoding() throws {
        // Test that custom JSON can be decoded properly
        let testJSON = MockVehicleData.createVehicleStatusJSON(
            batteryLevel: 50,
            isCharging: true,
            drivingReady: false,
            scenario: "test"
        )
        
        let jsonData = testJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Should not throw
        let vehicleStatus = try decoder.decode(VehicleStatus.self, from: jsonData)
        
        // Verify decoded values
        XCTAssertEqual(vehicleStatus.green.batteryManagement.batteryRemain.ratio, 50)
        XCTAssertEqual(vehicleStatus.location.heading, 180) // Charging
        XCTAssertEqual(vehicleStatus.green.drivingReady, false)
    }
    
    // MARK: - VehicleStatusResponse Tests
    
    func testVehicleStatusResponseCreation() {
        let standardResponse = MockVehicleData.standardResponse
        
        XCTAssertEqual(standardResponse.resultCode, "0000")
        XCTAssertEqual(standardResponse.serviceNumber, "VehicleStatus")
        XCTAssertEqual(standardResponse.returnCode, "S")
        XCTAssertNotNil(standardResponse.lastUpdateTime)
        XCTAssertNotNil(standardResponse.state.vehicle)
        
        // Verify vehicle data matches
        XCTAssertEqual(standardResponse.state.vehicle.green.batteryManagement.batteryRemain.ratio, 75)
    }
    
    // MARK: - Mock Vehicle Tests
    
    func testMockVehicleCreation() {
        let vehicle = MockVehicleData.mockVehicle
        
        XCTAssertEqual(vehicle.vin, "KNDC14CXPPH000123")
        XCTAssertEqual(vehicle.vehicleId.uuidString, "12345678-1234-1234-1234-123456789012")
        XCTAssertEqual(vehicle.vehicleName, "Kia - EV9 GT")
        XCTAssertEqual(vehicle.year, "2024")
        XCTAssertNotNil(vehicle.detailInfo)
    }
    
    // MARK: - Preview Extension Tests
    
    func testVehicleStatusPreviewExtensions() {
        // Test all preview extensions exist and return expected data
        XCTAssertEqual(VehicleStatus.preview.green.batteryManagement.batteryRemain.ratio, 75)
        XCTAssertEqual(VehicleStatus.chargingPreview.green.batteryManagement.batteryRemain.ratio, 45)
        XCTAssertEqual(VehicleStatus.lowBatteryPreview.green.batteryManagement.batteryRemain.ratio, 12)
        XCTAssertEqual(VehicleStatus.fullBatteryPreview.green.batteryManagement.batteryRemain.ratio, 100)
        XCTAssertEqual(VehicleStatus.fastChargingPreview.green.batteryManagement.batteryRemain.ratio, 67)
        XCTAssertEqual(VehicleStatus.preconditioningPreview.green.batteryManagement.batteryRemain.ratio, 82)
        XCTAssertEqual(VehicleStatus.maintenancePreview.green.batteryManagement.batteryRemain.ratio, 58)
    }
    
    func testVehicleStatusResponsePreviewExtensions() {
        XCTAssertEqual(VehicleStatusResponse.preview.state.vehicle.green.batteryManagement.batteryRemain.ratio, 75)
        XCTAssertEqual(VehicleStatusResponse.chargingPreview.state.vehicle.green.batteryManagement.batteryRemain.ratio, 45)
        XCTAssertEqual(VehicleStatusResponse.lowBatteryPreview.state.vehicle.green.batteryManagement.batteryRemain.ratio, 12)
    }
    
    func testVehiclePreviewExtension() {
        XCTAssertEqual(Vehicle.preview.vin, "KNDC14CXPPH000123")
        XCTAssertEqual(Vehicle.preview.vehicleName, "Kia - EV9 GT")
    }
    
    // MARK: - Location Data Tests
    
    func testLocationDataForScenarios() {
        // Verify different scenarios have different locations
        let standardLat = MockVehicleData.standard.location.geoCoordinate.latitude
        let chargingLat = MockVehicleData.charging.location.geoCoordinate.latitude
        let maintenanceLat = MockVehicleData.maintenance.location.geoCoordinate.latitude
        
        XCTAssertEqual(standardLat, chargingLat)
        XCTAssertNotEqual(standardLat, maintenanceLat)
        XCTAssertNotEqual(chargingLat, maintenanceLat)
        
        // Verify speed is 0 when charging
        XCTAssertEqual(MockVehicleData.charging.location.speed.value, 0)
        XCTAssertEqual(MockVehicleData.fastCharging.location.speed.value, 0)
    }
    
    // MARK: - Door and Lock State Tests
    
    func testDoorAndLockStates() {
        // All scenarios should have doors locked
        let scenarios = [
            MockVehicleData.standard,
            MockVehicleData.charging,
            MockVehicleData.lowBattery,
            MockVehicleData.fullBattery,
            MockVehicleData.fastCharging,
            MockVehicleData.preconditioning,
            MockVehicleData.maintenance
        ]
        
        for scenario in scenarios {
            // Check all doors are locked
            XCTAssertEqual(scenario.cabin.door.row1.driver.lock, true)
            XCTAssertEqual(scenario.cabin.door.row1.passenger.lock, true)
            XCTAssertEqual(scenario.cabin.door.row2.left.lock, true)
            XCTAssertEqual(scenario.cabin.door.row2.right.lock, true)
            
            // Check all doors are closed
            XCTAssertEqual(scenario.cabin.door.row1.driver.open, false)
            XCTAssertEqual(scenario.cabin.door.row1.passenger.open, false)
            XCTAssertEqual(scenario.cabin.door.row2.left.open, false)
            XCTAssertEqual(scenario.cabin.door.row2.right.open, false)
        }
    }
    
    // MARK: - Tire Pressure Tests
    
    func testTirePressureData() {
        // Standard scenario should have normal tire pressure
        let standard = MockVehicleData.standard
        XCTAssertGreaterThanOrEqual(standard.chassis.axle.row1.left.tire.pressure, 30)
        XCTAssertGreaterThanOrEqual(standard.chassis.axle.row1.right.tire.pressure, 30)
        XCTAssertGreaterThanOrEqual(standard.chassis.axle.row2.left.tire.pressure, 30)
        XCTAssertGreaterThanOrEqual(standard.chassis.axle.row2.right.tire.pressure, 30)
        
        // Maintenance scenario should have low pressure warning
        let maintenance = MockVehicleData.maintenance
        XCTAssertEqual(maintenance.chassis.axle.row1.right.tire.pressureLow, true)
        XCTAssertLessThan(maintenance.chassis.axle.row1.right.tire.pressure, 30)
    }
    
    // MARK: - Performance Tests
    
    func testMockDataCreationPerformance() {
        measure {
            // Measure performance of creating mock data
            _ = MockVehicleData.standard
            _ = MockVehicleData.charging
            _ = MockVehicleData.lowBattery
            _ = MockVehicleData.fullBattery
            _ = MockVehicleData.fastCharging
            _ = MockVehicleData.preconditioning
            _ = MockVehicleData.maintenance
        }
    }
    
    func testJSONDecodingPerformance() {
        let jsonString = MockVehicleData.createVehicleStatusJSON(
            batteryLevel: 75,
            isCharging: false,
            drivingReady: true,
            scenario: "performance"
        )
        let jsonData = jsonString.data(using: .utf8)!
        
        measure {
            let decoder = JSONDecoder()
            _ = try? decoder.decode(VehicleStatus.self, from: jsonData)
        }
    }
}
