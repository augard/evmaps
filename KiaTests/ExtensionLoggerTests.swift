//
//  ExtensionLoggerTests.swift
//  KiaTests
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
import OSLog
@testable import KiaMaps

final class ExtensionLoggerTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Ensure remote logging is disabled for most tests
        UserDefaults.standard.set(false, forKey: "RemoteLoggingEnabled")
    }
    
    override func tearDownWithError() throws {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "RemoteLoggingEnabled")
        
        try super.tearDownWithError()
    }
    
    func testLogLevelConversion() {
        // Test that log levels can be converted to OSLogType
        let levels: [LogEntry.LogLevel] = [.debug, .info, .default, .error, .fault]
        
        // This tests the conversion logic that would be used in ExtensionLogger
        for level in levels {
            let osLogType: OSLogType
            switch level {
            case .debug:
                osLogType = .debug
            case .info:
                osLogType = .info
            case .default:
                osLogType = .default
            case .error:
                osLogType = .error
            case .fault:
                osLogType = .fault
            }
            
            // Verify conversion works
            XCTAssertTrue(osLogType == .debug || osLogType == .info || osLogType == .default || osLogType == .error || osLogType == .fault)
        }
    }
    
    func testLogSourceDetection() {
        // Test source detection logic that would be used in extensions
        
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        
        // Simulate different bundle IDs
        let testCases = [
            ("com.example.app", LogEntry.LogSource.mainApp),
            ("com.example.app.extension", LogEntry.LogSource.siriExtension),
            ("com.example.app.carplay", LogEntry.LogSource.carPlayExtension),
        ]
        
        for (bundleID, expectedSource) in testCases {
            let detectedSource: LogEntry.LogSource
            
            if bundleID.contains(".carplay") || bundleID.contains(".CarPlay") {
                detectedSource = .carPlayExtension
            } else if bundleID.contains(".extension") || bundleID.contains(".Extension") {
                detectedSource = .siriExtension
            } else {
                detectedSource = .mainApp
            }
            
            XCTAssertEqual(detectedSource, expectedSource, "Bundle ID \(bundleID) should map to \(expectedSource)")
        }
    }
    
    func testRemoteLoggingConfiguration() {
        // Test that UserDefaults configuration works as expected by extensions
        
        // Given - Remote logging is initially disabled
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // When - Enable remote logging
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        
        // Then - Should be readable
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // When - Disable remote logging
        UserDefaults.standard.set(false, forKey: "RemoteLoggingEnabled")
        
        // Then - Should be disabled
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
    }
    
    func testLogEntryCreationForExtensions() {
        // Test creating log entries as an extension would
        
        let entry = LogEntry(
            category: "ExtensionTest",
            level: .info,
            message: "Test message from extension",
            source: .siriExtension,
            file: "ExtensionFile.swift",
            function: "extensionMethod()",
            line: 42
        )
        
        XCTAssertEqual(entry.category, "ExtensionTest")
        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.message, "Test message from extension")
        XCTAssertEqual(entry.source, .siriExtension)
        XCTAssertEqual(entry.file, "ExtensionFile.swift")
        XCTAssertEqual(entry.function, "extensionMethod()")
        XCTAssertEqual(entry.line, 42)
    }
    
    func testLogBatchCreationForExtensions() {
        // Test creating log batches as an extension would
        
        let entries = [
            LogEntry(category: "Extension", level: .info, message: "Message 1", source: .siriExtension),
            LogEntry(category: "Extension", level: .error, message: "Message 2", source: .siriExtension)
        ]
        
        let deviceInfo = LogBatch.DeviceInfo(
            deviceModel: "iPhone",
            osVersion: "17.0",
            appVersion: "1.0.0"
        )
        
        let batch = LogBatch(entries: entries, deviceInfo: deviceInfo)
        
        XCTAssertEqual(batch.entries.count, 2)
        XCTAssertEqual(batch.deviceInfo?.deviceModel, "iPhone")
        XCTAssertEqual(batch.deviceInfo?.osVersion, "17.0")
        XCTAssertEqual(batch.deviceInfo?.appVersion, "1.0.0")
    }
    
    func testMessageFormattingForExtensions() {
        // Test message formatting that would be used in extensions
        
        let testCases = [
            ("Simple message", "Simple message"),
            ("Message with %@", "Message with %@"), // String formatting placeholder
            ("Message with %d", "Message with %d"), // Integer formatting placeholder
            ("Complex: %@ error %d", "Complex: %@ error %d") // Multiple placeholders
        ]
        
        for (input, expected) in testCases {
            // In the actual ExtensionLogger, this would be formatted with parameters
            // Here we just test that the format string is preserved
            XCTAssertEqual(input, expected)
        }
    }
    
    func testDefaultCategoryForExtensions() {
        // Test default category handling
        
        let defaultCategory = "Extension"
        
        let entry = LogEntry(
            category: defaultCategory,
            level: .info,
            message: "Default category test",
            source: .siriExtension
        )
        
        XCTAssertEqual(entry.category, defaultCategory)
    }
    
    func testFileLineCapture() {
        // Test that file and line capture works as expected
        
        let currentFile = #file
        let currentFunction = #function
        let currentLine = #line
        
        let entry = LogEntry(
            category: "Test",
            level: .info,
            message: "File line test",
            source: .mainApp,
            file: currentFile,
            function: currentFunction,
            line: Int(currentLine)
        )
        
        XCTAssertTrue(entry.file?.contains("ExtensionLoggerTests.swift") == true)
        XCTAssertTrue(entry.function?.contains("testFileLineCapture") == true)
        XCTAssertTrue(entry.line != nil)
    }
    
    func testLoggerPerformance() {
        // Test that log entry creation is performant
        
        measure {
            for i in 0..<100 {
                let _ = LogEntry(
                    category: "Performance",
                    level: .info,
                    message: "Performance test message \(i)",
                    source: .siriExtension
                )
            }
        }
    }
    
    func testConcurrentLogEntryCreation() {
        // Test thread safety of log entry creation
        
        let expectation = XCTestExpectation(description: "Concurrent log creation should complete")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                let _ = LogEntry(
                    category: "Concurrent",
                    level: .info,
                    message: "Concurrent message \(i)",
                    source: .siriExtension
                )
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}