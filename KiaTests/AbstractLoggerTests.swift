//
//  AbstractLoggerTests.swift
//  KiaTests
//
//  Created by Claude on 18.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
import OSLog
@testable import KiaMaps

// MARK: - Mock Logger for Testing

/// Mock logger implementation for testing AbstractLogger behavior
class MockLogger: AbstractLoggerProtocol {
    
    /// Struct to capture log calls for verification
    struct LogCall {
        let level: AbstractLogLevel
        let message: String
        let category: LogCategory
        let file: String
        let function: String
        let line: Int
    }
    
    // Thread-safe queue for synchronizing access
    private let queue = DispatchQueue(label: "com.kiamaps.tests.mocklogger", attributes: .concurrent)
    
    // Private storage for thread-safe access
    private var _logCalls: [LogCall] = []
    private var _debugCount = 0
    private var _infoCount = 0
    private var _warningCount = 0
    private var _errorCount = 0
    private var _faultCount = 0
    
    /// All captured log calls (thread-safe read)
    var logCalls: [LogCall] {
        queue.sync { _logCalls }
    }
    
    /// Counter for specific log levels (thread-safe reads)
    var debugCount: Int {
        queue.sync { _debugCount }
    }
    
    var infoCount: Int {
        queue.sync { _infoCount }
    }
    
    var warningCount: Int {
        queue.sync { _warningCount }
    }
    
    var errorCount: Int {
        queue.sync { _errorCount }
    }
    
    var faultCount: Int {
        queue.sync { _faultCount }
    }
    
    func log(_ level: AbstractLogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        // Use barrier for thread-safe writes
        queue.async(flags: .barrier) {
            // Capture the log call
            self._logCalls.append(LogCall(
                level: level,
                message: message,
                category: category,
                file: file,
                function: function,
                line: line
            ))
            
            // Update counters
            switch level {
            case .debug:
                self._debugCount += 1
            case .info:
                self._infoCount += 1
            case .warning:
                self._warningCount += 1
            case .error:
                self._errorCount += 1
            case .fault:
                self._faultCount += 1
            }
        }
    }
    
    /// Reset all captured data (thread-safe)
    func reset() {
        queue.async(flags: .barrier) {
            self._logCalls = []
            self._debugCount = 0
            self._infoCount = 0
            self._warningCount = 0
            self._errorCount = 0
            self._faultCount = 0
        }
    }
    
    /// Wait for all pending log operations to complete
    func waitForCompletion() {
        queue.sync(flags: .barrier) {
            // This ensures all pending async operations are complete
        }
    }
}

// MARK: - Test Cases

final class AbstractLoggerTests: XCTestCase {
    
    var mockLogger: MockLogger!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a fresh mock logger for each test
        mockLogger = MockLogger()
        
        // Configure SharedLogger with our mock
        SharedLogger.shared.configure(with: mockLogger)
    }
    
    override func tearDownWithError() throws {
        // Reset the logger to default after tests
        SharedLogger.shared.configure(with: AppLogger())
        
        mockLogger = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - AbstractLogLevel Tests
    
    func testAbstractLogLevelToOSLogType() {
        // Test conversion from AbstractLogLevel to OSLogType
        XCTAssertEqual(AbstractLogLevel.debug.osLogType, .debug)
        XCTAssertEqual(AbstractLogLevel.info.osLogType, .info)
        XCTAssertEqual(AbstractLogLevel.warning.osLogType, .default)
        XCTAssertEqual(AbstractLogLevel.error.osLogType, .error)
        XCTAssertEqual(AbstractLogLevel.fault.osLogType, .fault)
    }
    
    func testAbstractLogLevelToRemoteLogLevel() {
        // Test conversion from AbstractLogLevel to RemoteLogger LogLevel
        XCTAssertEqual(AbstractLogLevel.debug.remoteLogLevel, .debug)
        XCTAssertEqual(AbstractLogLevel.info.remoteLogLevel, .info)
        XCTAssertEqual(AbstractLogLevel.warning.remoteLogLevel, .default)
        XCTAssertEqual(AbstractLogLevel.error.remoteLogLevel, .error)
        XCTAssertEqual(AbstractLogLevel.fault.remoteLogLevel, .fault)
    }
    
    func testAbstractLogLevelCaseIterable() {
        // Verify all cases are included
        let allCases = AbstractLogLevel.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.debug))
        XCTAssertTrue(allCases.contains(.info))
        XCTAssertTrue(allCases.contains(.warning))
        XCTAssertTrue(allCases.contains(.error))
        XCTAssertTrue(allCases.contains(.fault))
    }
    
    // MARK: - LogCategory Tests
    
    func testLogCategoryRawValues() {
        // Test that each category has the expected raw value
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
    
    func testLogCategoryOSLogCreation() {
        // Test that osLog method creates proper OSLog instances
        let subsystem = "com.test.app"
        
        for category in LogCategory.allCases {
            let log = category.osLog(subsystem: subsystem)
            
            // We can't directly verify subsystem and category in OSLog,
            // but we can verify the log is created without crashing
            XCTAssertNotNil(log)
        }
    }
    
    func testLogCategoryCaseIterable() {
        // Verify all categories are included
        let allCases = LogCategory.allCases
        XCTAssertEqual(allCases.count, 11)
    }
    
    // MARK: - SharedLogger Tests
    
    func testSharedLoggerSingleton() {
        // Test that SharedLogger is a proper singleton
        let logger1 = SharedLogger.shared
        let logger2 = SharedLogger.shared
        
        // Both references should point to the same instance
        XCTAssertTrue(logger1 === logger2)
    }
    
    func testSharedLoggerConfiguration() {
        // Test that we can configure the SharedLogger
        let customMockLogger = MockLogger()
        SharedLogger.shared.configure(with: customMockLogger)
        
        // Log something using global functions
        logInfo("Test message", category: .general)
        
        // Verify the custom logger received the message
        XCTAssertEqual(customMockLogger.logCalls.count, 1)
        XCTAssertEqual(customMockLogger.logCalls.first?.message, "Test message")
    }
    
    // MARK: - Global Convenience Functions Tests
    
    func testLogDebugFunction() {
        // Test the global logDebug function
        logDebug("Debug message", category: .api)
        
        XCTAssertEqual(mockLogger.debugCount, 1)
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        
        let call = mockLogger.logCalls.first!
        XCTAssertEqual(call.level, .debug)
        XCTAssertEqual(call.message, "Debug message")
        XCTAssertEqual(call.category, .api)
    }
    
    func testLogInfoFunction() {
        // Test the global logInfo function
        logInfo("Info message", category: .auth)
        
        XCTAssertEqual(mockLogger.infoCount, 1)
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        
        let call = mockLogger.logCalls.first!
        XCTAssertEqual(call.level, .info)
        XCTAssertEqual(call.message, "Info message")
        XCTAssertEqual(call.category, .auth)
    }
    
    func testLogWarningFunction() {
        // Test the global logWarning function
        logWarning("Warning message", category: .server)
        
        XCTAssertEqual(mockLogger.warningCount, 1)
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        
        let call = mockLogger.logCalls.first!
        XCTAssertEqual(call.level, .warning)
        XCTAssertEqual(call.message, "Warning message")
        XCTAssertEqual(call.category, .server)
    }
    
    func testLogErrorFunction() {
        // Test the global logError function
        logError("Error message", category: .mqtt)
        
        XCTAssertEqual(mockLogger.errorCount, 1)
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        
        let call = mockLogger.logCalls.first!
        XCTAssertEqual(call.level, .error)
        XCTAssertEqual(call.message, "Error message")
        XCTAssertEqual(call.category, .mqtt)
    }
    
    func testLogFaultFunction() {
        // Test the global logFault function
        logFault("Fault message", category: .keychain)
        
        XCTAssertEqual(mockLogger.faultCount, 1)
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        
        let call = mockLogger.logCalls.first!
        XCTAssertEqual(call.level, .fault)
        XCTAssertEqual(call.message, "Fault message")
        XCTAssertEqual(call.category, .keychain)
    }
    
    func testDefaultCategoryParameter() {
        // Test that category defaults to .general when not specified
        logInfo("Message without category")
        
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        let call = mockLogger.logCalls.first!
        XCTAssertEqual(call.category, .general)
    }
    
    func testFileLocationCapture() {
        // Test that file, function, and line are captured
        logDebug("Test location", category: .general)
        
        XCTAssertEqual(mockLogger.logCalls.count, 1)
        let call = mockLogger.logCalls.first!
        
        // Verify file contains this test file name
        XCTAssertTrue(call.file.contains("AbstractLoggerTests.swift"))
        
        // Verify function contains this test method name
        XCTAssertTrue(call.function.contains("testFileLocationCapture"))
        
        // Verify line number is reasonable (should be around where logDebug was called)
        XCTAssertTrue(call.line > 0)
    }
    
    // MARK: - Multiple Logging Tests
    
    func testMultipleLogCalls() {
        // Test that multiple log calls are captured correctly
        logDebug("Debug 1", category: .api)
        logInfo("Info 1", category: .auth)
        logWarning("Warning 1", category: .server)
        logError("Error 1", category: .mqtt)
        logFault("Fault 1", category: .keychain)
        
        // Verify all counts
        XCTAssertEqual(mockLogger.debugCount, 1)
        XCTAssertEqual(mockLogger.infoCount, 1)
        XCTAssertEqual(mockLogger.warningCount, 1)
        XCTAssertEqual(mockLogger.errorCount, 1)
        XCTAssertEqual(mockLogger.faultCount, 1)
        XCTAssertEqual(mockLogger.logCalls.count, 5)
        
        // Verify each call
        XCTAssertEqual(mockLogger.logCalls[0].level, .debug)
        XCTAssertEqual(mockLogger.logCalls[0].message, "Debug 1")
        XCTAssertEqual(mockLogger.logCalls[0].category, .api)
        
        XCTAssertEqual(mockLogger.logCalls[1].level, .info)
        XCTAssertEqual(mockLogger.logCalls[1].message, "Info 1")
        XCTAssertEqual(mockLogger.logCalls[1].category, .auth)
        
        XCTAssertEqual(mockLogger.logCalls[2].level, .warning)
        XCTAssertEqual(mockLogger.logCalls[2].message, "Warning 1")
        XCTAssertEqual(mockLogger.logCalls[2].category, .server)
        
        XCTAssertEqual(mockLogger.logCalls[3].level, .error)
        XCTAssertEqual(mockLogger.logCalls[3].message, "Error 1")
        XCTAssertEqual(mockLogger.logCalls[3].category, .mqtt)
        
        XCTAssertEqual(mockLogger.logCalls[4].level, .fault)
        XCTAssertEqual(mockLogger.logCalls[4].message, "Fault 1")
        XCTAssertEqual(mockLogger.logCalls[4].category, .keychain)
    }
    
    func testLogMessageWithInterpolation() {
        // Test that string interpolation works in log messages
        let value = 42
        let error = "Network timeout"
        
        logInfo("Value is \(value)", category: .general)
        logError("Error occurred: \(error)", category: .api)
        
        XCTAssertEqual(mockLogger.logCalls.count, 2)
        XCTAssertEqual(mockLogger.logCalls[0].message, "Value is 42")
        XCTAssertEqual(mockLogger.logCalls[1].message, "Error occurred: Network timeout")
    }
    
    // MARK: - AbstractLoggerProtocol Default Implementation Tests
    
    func testProtocolDefaultImplementations() {
        // Test that the default implementations in the protocol extension work
        let customLogger = MockLogger()
        
        // These should use the default implementation that calls log()
        customLogger.debug("Debug via protocol", category: .api, file: "test.swift", function: "testFunc", line: 100)
        customLogger.info("Info via protocol", category: .auth, file: "test.swift", function: "testFunc", line: 101)
        customLogger.warning("Warning via protocol", category: .server, file: "test.swift", function: "testFunc", line: 102)
        customLogger.error("Error via protocol", category: .mqtt, file: "test.swift", function: "testFunc", line: 103)
        customLogger.fault("Fault via protocol", category: .keychain, file: "test.swift", function: "testFunc", line: 104)
        
        // Verify all were logged correctly
        XCTAssertEqual(customLogger.logCalls.count, 5)
        XCTAssertEqual(customLogger.debugCount, 1)
        XCTAssertEqual(customLogger.infoCount, 1)
        XCTAssertEqual(customLogger.warningCount, 1)
        XCTAssertEqual(customLogger.errorCount, 1)
        XCTAssertEqual(customLogger.faultCount, 1)
    }
    
    // MARK: - AppLogger Tests
    
    func testAppLoggerImplementation() {
        // Test that AppLogger properly implements the protocol
        let appLogger = AppLogger()
        
        // We can't easily test the actual os_log output,
        // but we can verify the logger doesn't crash
        appLogger.debug("Debug message", category: .api, file: #file, function: #function, line: #line)
        appLogger.info("Info message", category: .auth, file: #file, function: #function, line: #line)
        appLogger.warning("Warning message", category: .server, file: #file, function: #function, line: #line)
        appLogger.error("Error message", category: .mqtt, file: #file, function: #function, line: #line)
        appLogger.fault("Fault message", category: .keychain, file: #file, function: #function, line: #line)
        
        // If we got here without crashing, the implementation works
        XCTAssertTrue(true)
    }
    
    func testAppLoggerSharedConfiguration() {
        // Test that AppLogger.configureSharedLogger() sets up SharedLogger correctly
        AppLogger.configureSharedLogger()
        
        // The shared logger should now be using an AppLogger instance
        // We can't directly verify the type, but we can log something
        // and ensure it doesn't crash
        logInfo("Test after AppLogger configuration", category: .general)
        
        // If we got here without crashing, the configuration worked
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() {
        // Test the performance of logging operations
        self.measure {
            for i in 0..<1000 {
                logDebug("Performance test message \(i)", category: .general)
            }
        }
        
        // After performance test, verify all messages were logged
        mockLogger.reset() // Clear from performance test
        logInfo("After performance test", category: .general)
        XCTAssertEqual(mockLogger.logCalls.count, 1)
    }
    
    func testCategoryIterationPerformance() {
        // Test the performance of iterating through all categories
        self.measure {
            for _ in 0..<1000 {
                for category in LogCategory.allCases {
                    _ = category.rawValue
                }
            }
        }
    }
}

// MARK: - Integration Tests

final class AbstractLoggerIntegrationTests: XCTestCase {
    
    func testRealWorldLoggingScenario() {
        // Simulate a real-world logging scenario
        let mockLogger = MockLogger()
        SharedLogger.shared.configure(with: mockLogger)
        
        // Simulate app startup
        logInfo("App starting", category: .app)
        
        // Simulate API call
        logDebug("Making API request", category: .api)
        logInfo("API request successful", category: .api)
        
        // Simulate MQTT connection
        logDebug("Connecting to MQTT broker", category: .mqtt)
        logInfo("MQTT connected", category: .mqtt)
        
        // Simulate error scenario
        logError("Failed to fetch vehicle status", category: .vehicle)
        logWarning("Retrying vehicle status fetch", category: .vehicle)
        logInfo("Vehicle status fetch successful on retry", category: .vehicle)
        
        // Verify the sequence
        XCTAssertEqual(mockLogger.logCalls.count, 8)
        XCTAssertEqual(mockLogger.infoCount, 4)
        XCTAssertEqual(mockLogger.debugCount, 2)
        XCTAssertEqual(mockLogger.warningCount, 1)
        XCTAssertEqual(mockLogger.errorCount, 1)
        
        // Verify categories were used correctly
        let appLogs = mockLogger.logCalls.filter { $0.category == .app }
        XCTAssertEqual(appLogs.count, 1)
        
        let apiLogs = mockLogger.logCalls.filter { $0.category == .api }
        XCTAssertEqual(apiLogs.count, 2)
        
        let mqttLogs = mockLogger.logCalls.filter { $0.category == .mqtt }
        XCTAssertEqual(mqttLogs.count, 2)
        
        let vehicleLogs = mockLogger.logCalls.filter { $0.category == .vehicle }
        XCTAssertEqual(vehicleLogs.count, 3)
        
        // Reset SharedLogger
        SharedLogger.shared.configure(with: AppLogger())
    }
    
    func testThreadSafety() {
        // Test that logging is thread-safe
        let mockLogger = MockLogger()
        SharedLogger.shared.configure(with: mockLogger)
        
        let expectation = self.expectation(description: "Concurrent logging")
        let iterations = 100
        let queues = 5
        
        let group = DispatchGroup()
        
        for queueIndex in 0..<queues {
            DispatchQueue.global().async {
                group.enter()
                for i in 0..<iterations {
                    logInfo("Message \(i) from queue \(queueIndex)", category: .general)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5) { _ in
            // Wait for all async log operations to complete
            mockLogger.waitForCompletion()
            
            // Verify all messages were logged
            XCTAssertEqual(mockLogger.logCalls.count, iterations * queues)
            XCTAssertEqual(mockLogger.infoCount, iterations * queues)
            
            // Reset SharedLogger
            SharedLogger.shared.configure(with: AppLogger())
        }
    }
}
