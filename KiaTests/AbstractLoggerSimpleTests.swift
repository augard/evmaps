//
//  AbstractLoggerSimpleTests.swift
//  KiaTests
//
//  Created by Claude on 18.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

/// Simplified tests for AbstractLogger that focus on core functionality
/// These tests can run without complex dependencies
final class AbstractLoggerSimpleTests: XCTestCase {
    
    // MARK: - Log Level Tests
    
    func testLogLevelEnumeration() {
        // Verify all log levels exist
        XCTAssertNotNil(AbstractLogLevel.debug)
        XCTAssertNotNil(AbstractLogLevel.info)
        XCTAssertNotNil(AbstractLogLevel.warning)
        XCTAssertNotNil(AbstractLogLevel.error)
        XCTAssertNotNil(AbstractLogLevel.fault)
    }
    
    func testLogCategoryEnumeration() {
        // Verify all categories exist
        XCTAssertNotNil(LogCategory.api)
        XCTAssertNotNil(LogCategory.auth)
        XCTAssertNotNil(LogCategory.server)
        XCTAssertNotNil(LogCategory.app)
        XCTAssertNotNil(LogCategory.ui)
        XCTAssertNotNil(LogCategory.bluetooth)
        XCTAssertNotNil(LogCategory.mqtt)
        XCTAssertNotNil(LogCategory.keychain)
        XCTAssertNotNil(LogCategory.vehicle)
        XCTAssertNotNil(LogCategory.ext)
        XCTAssertNotNil(LogCategory.general)
    }
    
    func testSharedLoggerExists() {
        // Verify SharedLogger singleton exists
        let logger = SharedLogger.shared
        XCTAssertNotNil(logger)
        
        // Verify it's a singleton
        let logger2 = SharedLogger.shared
        XCTAssertTrue(logger === logger2)
    }
    
    func testGlobalFunctionsExist() {
        // Verify global logging functions are available
        // We can't test their actual output here, but we can verify they compile
        
        // These should compile without errors
        logDebug("Test debug", category: .general)
        logInfo("Test info", category: .general)
        logWarning("Test warning", category: .general)
        logError("Test error", category: .general)
        logFault("Test fault", category: .general)
        
        // Test passed if we got here
        XCTAssertTrue(true)
    }
    
    func testLogCategoryRawValues() {
        // Test that raw values are as expected
        XCTAssertEqual(LogCategory.api.rawValue, "API")
        XCTAssertEqual(LogCategory.auth.rawValue, "Auth")
        XCTAssertEqual(LogCategory.server.rawValue, "Server")
        XCTAssertEqual(LogCategory.app.rawValue, "App")
        XCTAssertEqual(LogCategory.ui.rawValue, "UI")
        XCTAssertEqual(LogCategory.bluetooth.rawValue, "Bluetooth")
        XCTAssertEqual(LogCategory.mqtt.rawValue, "MQTT")
        XCTAssertEqual(LogCategory.keychain.rawValue, "Keychain")
        XCTAssertEqual(LogCategory.vehicle.rawValue, "Vehicle")
        XCTAssertEqual(LogCategory.ext.rawValue, "Extension")
        XCTAssertEqual(LogCategory.general.rawValue, "General")
    }
}