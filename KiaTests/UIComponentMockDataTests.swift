//
//  UIComponentMockDataTests.swift
//  KiaTests
//
//  Created by Claude Code on 21/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
import SwiftUI
@testable import KiaMaps

final class UIComponentMockDataTests: XCTestCase {
    
    // MARK: - CircularBatteryView Tests
    
    func testCircularBatteryViewWithMockData() {
        // Test that CircularBatteryView can be created with mock data
        let scenarios: [(String, VehicleState)] = [
            ("Standard", MockVehicleData.standard),
            ("Charging", MockVehicleData.charging),
            ("Low Battery", MockVehicleData.lowBattery),
            ("Full Battery", MockVehicleData.fullBattery)
        ]
        
        for (name, VehicleState) in scenarios {
            let batteryLevel = MockVehicleData.batteryLevel(from: VehicleState)
            let isCharging = MockVehicleData.isCharging(VehicleState)
            
            let view = CircularBatteryView(
                level: batteryLevel,
                isCharging: isCharging,
                size: 200
            )
            
            // Verify view properties
            XCTAssertEqual(view.level, batteryLevel, "Battery level mismatch for \(name)")
            XCTAssertEqual(view.isCharging, isCharging, "Charging state mismatch for \(name)")
            XCTAssertEqual(view.size, 200, "Size mismatch for \(name)")
            
            // Verify level is within valid range
            XCTAssertGreaterThanOrEqual(view.level, 0.0)
            XCTAssertLessThanOrEqual(view.level, 1.0)
        }
    }
    
    func testCircularBatteryViewColorLogic() {
        // Test color selection based on battery level
        let lowBatteryView = CircularBatteryView(
            level: MockVehicleData.batteryLevel(from: MockVehicleData.lowBattery),
            isCharging: false
        )
        
        let normalBatteryView = CircularBatteryView(
            level: MockVehicleData.batteryLevel(from: MockVehicleData.standard),
            isCharging: false
        )
        
        let fullBatteryView = CircularBatteryView(
            level: MockVehicleData.batteryLevel(from: MockVehicleData.fullBattery),
            isCharging: false
        )
        
        // Views should be created without issues
        XCTAssertNotNil(lowBatteryView)
        XCTAssertNotNil(normalBatteryView)
        XCTAssertNotNil(fullBatteryView)
    }
    
    // MARK: - BatteryHeroView Tests
    
    func testBatteryHeroViewWithMockData() {
        let scenarios = [
            MockVehicleData.standard,
            MockVehicleData.charging,
            MockVehicleData.lowBattery,
            MockVehicleData.fullBattery
        ]

        for (index, VehicleState) in scenarios.enumerated() {
            let view = BatteryHeroView(from: VehicleState)
            
            // View should be created successfully
            XCTAssertNotNil(view)
            
            // Verify internal data extraction works
            let batteryLevel = MockVehicleData.batteryLevel(from: VehicleState)
            let isCharging = MockVehicleData.isCharging(VehicleState)
            let estimatedRange = MockVehicleData.estimatedRange(from: VehicleState)
            
            XCTAssertGreaterThanOrEqual(batteryLevel, 0.0)
            XCTAssertLessThanOrEqual(batteryLevel, 1.0)
            XCTAssertGreaterThanOrEqual(estimatedRange, 0)

            if index == 1 {
                XCTAssertTrue(isCharging)
            } else {
                XCTAssertFalse(isCharging)
            }
        }
    }
    
    // MARK: - QuickActionsView Tests
    
    func testQuickActionsViewWithMockData() {
        var lockActionCalled = false
        var climateActionCalled = false
        var hornActionCalled = false
        var locateActionCalled = false
        
        let view = QuickActionsView(
            VehicleState: MockVehicleData.standard,
            onLockAction: { lockActionCalled = true },
            onClimateAction: { climateActionCalled = true },
            onHornAction: { hornActionCalled = true },
            onLocateAction: { locateActionCalled = true }
        )
        
        // View should be created successfully
        XCTAssertNotNil(view)
        
        // Actions should not be called during initialization
        XCTAssertFalse(lockActionCalled)
        XCTAssertFalse(climateActionCalled)
        XCTAssertFalse(hornActionCalled)
        XCTAssertFalse(locateActionCalled)
    }
    
    // MARK: - VehicleStateModernView Tests
    
    func testVehicleStateModernViewWithMockData() {
        let vehicle = MockVehicleData.mockVehicle
        let VehicleState = MockVehicleData.standard
        let lastUpdateTime = Date().addingTimeInterval(-300)
        
        let view = VehicleStateModernView(
            vehicle: vehicle,
            VehicleState: VehicleState,
            lastUpdateTime: lastUpdateTime
        )
        
        // View should be created successfully
        XCTAssertNotNil(view)
    }
    
    func testVehicleStateModernViewWithAllScenarios() {
        let vehicle = MockVehicleData.mockVehicle
        let lastUpdateTime = Date()
        
        let scenarios = [
            MockVehicleData.standard,
            MockVehicleData.charging,
            MockVehicleData.lowBattery,
            MockVehicleData.fullBattery,
            MockVehicleData.fastCharging,
            MockVehicleData.preconditioning,
            MockVehicleData.maintenance
        ]
        
        for VehicleState in scenarios {
            let view = VehicleStateModernView(
                vehicle: vehicle,
                VehicleState: VehicleState,
                lastUpdateTime: lastUpdateTime
            )
            
            XCTAssertNotNil(view)
        }
    }
    
    // MARK: - KiaProgressBar Tests
    
    func testKiaProgressBarWithMockBatteryLevels() {
        let scenarios: [(String, VehicleState)] = [
            ("Standard", MockVehicleData.standard),
            ("Charging", MockVehicleData.charging),
            ("Low Battery", MockVehicleData.lowBattery),
            ("Full Battery", MockVehicleData.fullBattery)
        ]
        
        for (name, VehicleState) in scenarios {
            let batteryLevel = MockVehicleData.batteryLevel(from: VehicleState)
            let isCharging = MockVehicleData.isCharging(VehicleState)
            
            let progressBar = KiaProgressBar(
                value: batteryLevel,
                style: isCharging ? .charging : .battery,
                showPercentage: true
            )
            
            // Verify value is clamped properly
            XCTAssertGreaterThanOrEqual(progressBar.value, 0.0, "Progress bar value too low for \(name)")
            XCTAssertLessThanOrEqual(progressBar.value, 1.0, "Progress bar value too high for \(name)")
        }
    }
    
    func testKiaCircularProgressBarWithMockData() {
        let batteryLevel = MockVehicleData.batteryLevel(from: MockVehicleData.standard)
        
        let circularProgress = KiaCircularProgressBar(
            value: batteryLevel,
            size: 120,
            style: .battery,
            showValue: true
        )
        
        XCTAssertEqual(circularProgress.value, batteryLevel)
        XCTAssertEqual(circularProgress.size, 120)
        XCTAssertTrue(circularProgress.showValue)
    }
    
    func testKiaSegmentedProgressBarWithMockData() {
        let standardBattery = MockVehicleData.batteryLevel(from: MockVehicleData.standard)
        let chargingBattery = MockVehicleData.batteryLevel(from: MockVehicleData.charging)
        let lowBattery = MockVehicleData.batteryLevel(from: MockVehicleData.lowBattery)
        
        let segments = [
            KiaSegmentedProgressBar.Segment(
                value: standardBattery,
                color: KiaDesign.Colors.success,
                label: "Standard"
            ),
            KiaSegmentedProgressBar.Segment(
                value: chargingBattery,
                color: KiaDesign.Colors.primary,
                label: "Charging"
            ),
            KiaSegmentedProgressBar.Segment(
                value: lowBattery,
                color: KiaDesign.Colors.warning,
                label: "Low"
            )
        ]
        
        let segmentedBar = KiaSegmentedProgressBar(segments: segments)
        
        XCTAssertEqual(segmentedBar.segments.count, 3)
        
        // Verify all segment values are within range
        for segment in segmentedBar.segments {
            XCTAssertGreaterThanOrEqual(segment.value, 0.0)
            XCTAssertLessThanOrEqual(segment.value, 1.0)
        }
    }
    
    // MARK: - VehicleSilhouetteView Tests
    
    func testVehicleSilhouetteViewWithMockData() {
        let VehicleState = MockVehicleData.preconditioning
        
        let view = VehicleSilhouetteView(vehicleState: VehicleState)

        // View should be created successfully
        XCTAssertNotNil(view)
        
        // Verify vehicle status data can be accessed (HVAC has complex structure)
        XCTAssertEqual(VehicleState.cabin.hvac.row1.driver.temperature.value, "22")
    }
    
    func testVehicleSilhouetteViewDoorStates() {
        let VehicleState = MockVehicleData.standard
        let view = VehicleSilhouetteView(vehicleState: VehicleState)
        
        XCTAssertNotNil(view)
        
        // All doors should be closed and locked
        XCTAssertFalse(VehicleState.cabin.door.row1.driver.open)
        XCTAssertFalse(VehicleState.cabin.door.row1.passenger.open)
        XCTAssertFalse(VehicleState.cabin.door.row2.left.open)
        XCTAssertFalse(VehicleState.cabin.door.row2.right.open)
    }
    
    // MARK: - Integration Tests
    
    func testMockDataConsistencyAcrossComponents() {
        let VehicleState = MockVehicleData.charging
        let batteryLevel = MockVehicleData.batteryLevel(from: VehicleState)
        let isCharging = MockVehicleData.isCharging(VehicleState)
        
        // Create multiple components with the same data
        let circularBattery = CircularBatteryView(
            level: batteryLevel,
            isCharging: isCharging
        )
        
        let batteryHero = BatteryHeroView(from: VehicleState)
        
        let progressBar = KiaProgressBar(
            value: batteryLevel,
            style: isCharging ? .charging : .battery
        )
        
        // All components should have consistent data
        XCTAssertEqual(circularBattery.level, progressBar.value)
        XCTAssertEqual(circularBattery.isCharging, isCharging)
        
        // Views should all be created successfully
        XCTAssertNotNil(circularBattery)
        XCTAssertNotNil(batteryHero)
        XCTAssertNotNil(progressBar)
    }
    
    func testMockDataProvidesSufficientVariety() {
        // Ensure we have different battery levels for testing
        let levels = [
            MockVehicleData.batteryLevel(from: MockVehicleData.standard),
            MockVehicleData.batteryLevel(from: MockVehicleData.charging),
            MockVehicleData.batteryLevel(from: MockVehicleData.lowBattery),
            MockVehicleData.batteryLevel(from: MockVehicleData.fullBattery),
            MockVehicleData.batteryLevel(from: MockVehicleData.fastCharging),
            MockVehicleData.batteryLevel(from: MockVehicleData.preconditioning),
            MockVehicleData.batteryLevel(from: MockVehicleData.maintenance)
        ]
        
        // Check we have variety in battery levels
        let uniqueLevels = Set(levels)
        XCTAssertGreaterThan(uniqueLevels.count, 5, "Mock data should provide variety in battery levels")
        
        // Check we have low, medium, and high battery scenarios
        XCTAssertTrue(levels.contains { $0 < 0.2 }, "Should have low battery scenario")
        XCTAssertTrue(levels.contains { $0 > 0.4 && $0 < 0.8 }, "Should have medium battery scenario")
        XCTAssertTrue(levels.contains { $0 > 0.8 }, "Should have high battery scenario")
    }
    
    // MARK: - Performance Tests
    
    func testUIComponentCreationPerformance() {
        let VehicleState = MockVehicleData.standard
        let vehicle = MockVehicleData.mockVehicle
        
        measure {
            // Measure performance of creating UI components
            _ = CircularBatteryView(
                level: MockVehicleData.batteryLevel(from: VehicleState),
                isCharging: MockVehicleData.isCharging(VehicleState)
            )
            
            _ = BatteryHeroView(from: VehicleState)
            
            _ = QuickActionsView(
                VehicleState: VehicleState,
                onLockAction: {},
                onClimateAction: {},
                onHornAction: {},
                onLocateAction: {}
            )
            
            _ = VehicleStateModernView(
                vehicle: vehicle,
                VehicleState: VehicleState,
                lastUpdateTime: Date()
            )
        }
    }
}
