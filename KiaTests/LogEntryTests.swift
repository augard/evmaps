//
//  LogEntryTests.swift
//  KiaTests
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class LogEntryTests: XCTestCase {
    
    func testLogEntryCreation() {
        // Given
        let category = "TestCategory"
        let level = LogEntry.LogLevel.info
        let message = "Test message"
        let source = LogEntry.LogSource.siriExtension
        
        // When
        let entry = LogEntry(
            category: category,
            level: level,
            message: message,
            source: source
        )
        
        // Then
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.category, category)
        XCTAssertEqual(entry.level, level)
        XCTAssertEqual(entry.message, message)
        XCTAssertEqual(entry.source, source)
        XCTAssertNotNil(entry.timestamp)
        
        // Check that timestamp is recent (within 1 second)
        let timeDiff = Date().timeIntervalSince(entry.timestamp)
        XCTAssertTrue(timeDiff < 1.0, "Timestamp should be recent")
        XCTAssertTrue(timeDiff >= 0, "Timestamp should not be in the future")
    }
    
    func testLogLevelSortOrder() {
        // Given
        let levels: [LogEntry.LogLevel] = [.fault, .debug, .error, .info, .default]
        
        // When
        let sortedLevels = levels.sorted { $0.sortOrder < $1.sortOrder }
        
        // Then
        let expectedOrder: [LogEntry.LogLevel] = [.debug, .info, .default, .error, .fault]
        XCTAssertEqual(sortedLevels, expectedOrder)
    }
    
    func testLogLevelSymbols() {
        // Test that each level has a symbol
        XCTAssertEqual(LogEntry.LogLevel.debug.symbolName, "🔍")
        XCTAssertEqual(LogEntry.LogLevel.info.symbolName, "ℹ️")
        XCTAssertEqual(LogEntry.LogLevel.default.symbolName, "⚠️")
        XCTAssertEqual(LogEntry.LogLevel.error.symbolName, "❌")
        XCTAssertEqual(LogEntry.LogLevel.fault.symbolName, "💥")
    }
    
    func testFormattedTimestamp() {
        // Given
        let entry = LogEntry(
            category: "Test",
            level: .info,
            message: "Test",
            source: .mainApp
        )
        
        // When
        let formatted = entry.formattedTimestamp
        
        // Then
        // Should match HH:mm:ss.SSS format
        let regex = try! NSRegularExpression(pattern: "^\\d{2}:\\d{2}:\\d{2}\\.\\d{3}$")
        let range = NSRange(location: 0, length: formatted.count)
        XCTAssertTrue(regex.firstMatch(in: formatted, range: range) != nil,
                     "Formatted timestamp should match HH:mm:ss.SSS pattern: \(formatted)")
    }
    
    func testFormattedLocation() {
        // Given - entry with file and line
        let entry1 = LogEntry(
            category: "Test",
            level: .info,
            message: "Test",
            source: .mainApp,
            file: "/path/to/TestFile.swift",
            function: "testFunction()",
            line: 42
        )
        
        // Given - entry without file
        let entry2 = LogEntry(
            category: "Test",
            level: .info,
            message: "Test",
            source: .mainApp,
            file: nil,
            function: "testFunction()",
            line: 42
        )
        
        // When
        let location1 = entry1.formattedLocation
        let location2 = entry2.formattedLocation
        
        // Then
        XCTAssertEqual(location1, "TestFile.swift:42")
        XCTAssertNil(location2)
    }
    
    func testFormattedLogLine() {
        // Given
        let entry = LogEntry(
            category: "TestCategory",
            level: .error,
            message: "Test error message",
            source: .siriExtension,
            file: "TestFile.swift",
            function: "testFunction()",
            line: 100
        )
        
        // When
        let logLine = entry.formattedLogLine
        
        // Then
        XCTAssertTrue(logLine.contains("[SiriExtension]"))
        XCTAssertTrue(logLine.contains("[TestCategory]"))
        XCTAssertTrue(logLine.contains("❌")) // Error symbol
        XCTAssertTrue(logLine.contains("Test error message"))
        XCTAssertTrue(logLine.contains("TestFile.swift:100"))
    }
    
    func testLogEntryCodable() throws {
        // Given
        let originalEntry = LogEntry(
            category: "TestCategory",
            level: .default,
            message: "Test message",
            source: .carPlayExtension,
            file: "TestFile.swift",
            function: "testFunction()",
            line: 50
        )
        
        // When - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEntry)
        
        // Then - Decode
        let decoder = JSONDecoder()
        let decodedEntry = try decoder.decode(LogEntry.self, from: data)
        
        // Verify all properties match
        XCTAssertEqual(decodedEntry.id, originalEntry.id)
        XCTAssertEqual(decodedEntry.category, originalEntry.category)
        XCTAssertEqual(decodedEntry.level, originalEntry.level)
        XCTAssertEqual(decodedEntry.message, originalEntry.message)
        XCTAssertEqual(decodedEntry.source, originalEntry.source)
        XCTAssertEqual(decodedEntry.file, originalEntry.file)
        XCTAssertEqual(decodedEntry.function, originalEntry.function)
        XCTAssertEqual(decodedEntry.line, originalEntry.line)
        
        // Timestamps should be equal (within millisecond precision)
        let timeDiff = abs(decodedEntry.timestamp.timeIntervalSince(originalEntry.timestamp))
        XCTAssertTrue(timeDiff < 0.001, "Timestamps should be nearly identical")
    }
    
    func testLogBatchCodable() throws {
        // Given
        let entries = [
            LogEntry(category: "Test1", level: .info, message: "Message 1", source: .mainApp),
            LogEntry(category: "Test2", level: .error, message: "Message 2", source: .siriExtension)
        ]
        
        let deviceInfo = LogBatch.DeviceInfo(
            deviceModel: "iPhone",
            osVersion: "17.0",
            appVersion: "1.0.0"
        )
        
        let originalBatch = LogBatch(entries: entries, deviceInfo: deviceInfo)
        
        // When - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalBatch)
        
        // Then - Decode
        let decoder = JSONDecoder()
        let decodedBatch = try decoder.decode(LogBatch.self, from: data)
        
        // Verify
        XCTAssertEqual(decodedBatch.entries.count, 2)
        XCTAssertEqual(decodedBatch.entries[0].category, "Test1")
        XCTAssertEqual(decodedBatch.entries[1].category, "Test2")
        XCTAssertEqual(decodedBatch.deviceInfo?.deviceModel, "iPhone")
        XCTAssertEqual(decodedBatch.deviceInfo?.osVersion, "17.0")
        XCTAssertEqual(decodedBatch.deviceInfo?.appVersion, "1.0.0")
    }
    
    func testDeviceInfoCurrent() {
        // When
        let deviceInfo = LogBatch.DeviceInfo.current
        
        // Then
        XCTAssertFalse(deviceInfo.deviceModel.isEmpty)
        XCTAssertFalse(deviceInfo.osVersion.isEmpty)
        XCTAssertFalse(deviceInfo.appVersion.isEmpty)
        
        // Device model should be something like "iPhone" or "iPad"
        XCTAssertTrue(deviceInfo.deviceModel.contains("iPhone") || 
                     deviceInfo.deviceModel.contains("iPad") ||
                     deviceInfo.deviceModel.contains("iPod"))
    }
}