//
//  SimpleMockTest.swift
//  KiaTests
//
//  Created by Claude Code on 21/7/25.
//  Simple test to verify MockVehicleData basics
//

import XCTest
@testable import KiaMaps

final class SimpleMockTest: XCTestCase {
    
    func testBasicMockDataCreation() {
        // Test that we can create basic mock data without errors
        let standard = MockVehicleData.standard
        
        // Basic assertions that should always work
        XCTAssertNotNil(standard)
        XCTAssertNotNil(standard.green)
        XCTAssertNotNil(standard.green.batteryManagement)
        XCTAssertNotNil(standard.green.batteryManagement.batteryRemain)
        
        // Test battery level is reasonable
        let batteryLevel = standard.green.batteryManagement.batteryRemain.ratio
        XCTAssertGreaterThan(batteryLevel, 0)
        XCTAssertLessThanOrEqual(batteryLevel, 100)
        
        // Test that the battery level helper works
        let helperLevel = MockVehicleData.batteryLevel(from: standard)
        XCTAssertGreaterThan(helperLevel, 0)
        XCTAssertLessThanOrEqual(helperLevel, 1.0)
    }
    
    func testAllMockScenariosExist() {
        // Test that all scenarios can be created
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
            XCTAssertNotNil(scenario)
            XCTAssertNotNil(scenario.green.batteryManagement.batteryRemain)
        }
    }
}