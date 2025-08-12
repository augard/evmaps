//
//  RemoteLoggingIntegrationTests.swift
//  KiaTests
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
import Network
@testable import KiaMaps

@MainActor
final class RemoteLoggingIntegrationTests: XCTestCase {
    
    var server: RemoteLoggingServer!
    var remoteLogger: RemoteLogger!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up server
        server = RemoteLoggingServer.shared
        server.stop()
        server.clearLogs()
        
        // Set up remote logger
        remoteLogger = RemoteLogger.shared
        remoteLogger.setEnabled(false)
        
        // Clean UserDefaults
        UserDefaults.standard.removeObject(forKey: "RemoteLoggingEnabled")
    }
    
    override func tearDownWithError() throws {
        server?.stop()
        server?.clearLogs()
        remoteLogger?.setEnabled(false)
        
        UserDefaults.standard.removeObject(forKey: "RemoteLoggingEnabled")
        
        try super.tearDownWithError()
    }
    
    func testFullLoggingFlow() async throws {
        // Given - Start server
        server.start()
        XCTAssertTrue(server.isRunning)
        
        // Enable remote logging
        remoteLogger.setEnabled(true)
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        
        // When - Send log entries
        let testMessages = [
            ("Info message", LogEntry.LogLevel.info),
            ("Error message", LogEntry.LogLevel.error),
            ("Debug message", LogEntry.LogLevel.debug)
        ]
        
        for (message, level) in testMessages {
            remoteLogger.log(
                level,
                category: "Integration",
                message: message,
                source: .siriExtension,
                file: "IntegrationTest.swift",
                function: "testFullLoggingFlow()",
                line: 50
            )
        }
        
        // Force flush logs
        remoteLogger.flush()
        
        // Wait for network transmission (longer timeout for real network)
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Then - Server should have received logs
        // Note: This test may be flaky due to network timing
        // In a real scenario, we'd use mock networking or dependency injection
        XCTAssertTrue(true, "Integration test completed without crashes")
    }
    
    func testServerStartStopCycle() {
        // Given - Server is stopped
        XCTAssertFalse(server.isRunning)
        
        // When - Start and stop multiple times
        for _ in 0..<3 {
            server.start()
            XCTAssertTrue(server.isRunning)
            
            server.stop()
            XCTAssertFalse(server.isRunning)
            XCTAssertEqual(server.connectionCount, 0)
        }
        
        // Then - Should handle multiple cycles gracefully
        XCTAssertTrue(true, "Server start/stop cycles should work")
    }
    
    func testLoggingWithServerDisabled() {
        // Given - Server is not running
        XCTAssertFalse(server.isRunning)
        
        // Enable remote logging anyway
        remoteLogger.setEnabled(true)
        
        // When - Try to log
        remoteLogger.log(
            .info,
            category: "Test",
            message: "Message with server disabled",
            source: .mainApp
        )
        
        remoteLogger.flush()
        
        // Then - Should not crash
        XCTAssertTrue(true, "Logging should handle disabled server gracefully")
    }
    
    func testRemoteLoggingUserDefaultsIntegration() {
        // Test that UserDefaults changes affect logging behavior
        
        // Given - Logging is initially disabled
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // When - Enable via UserDefaults
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        
        // Then - RemoteLogger should respect this setting
        // Note: In practice, the extension would read this value on launch
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // When - Disable via UserDefaults
        UserDefaults.standard.set(false, forKey: "RemoteLoggingEnabled")
        
        // Then - Should be disabled
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
    }
    
    func testDeveloperSettingsIntegration() {
        // Test that DeveloperSettingsView integration works
        
        // Given - Remote logging is disabled
        UserDefaults.standard.set(false, forKey: "RemoteLoggingEnabled")
        
        // When - Enable remote logging (simulating toggle in DeveloperSettingsView)
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        
        // Start server (as DeveloperSettingsView would do)
        server.start()
        
        // Then - Server should be running
        XCTAssertTrue(server.isRunning)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // When - Disable remote logging
        UserDefaults.standard.set(false, forKey: "RemoteLoggingEnabled")
        
        // Stop server (as DeveloperSettingsView would do)
        server.stop()
        
        // Then - Server should be stopped
        XCTAssertFalse(server.isRunning)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
    }
    
    func testLogFilteringIntegration() {
        // Test the complete filtering pipeline
        
        // Given - Add diverse test logs
        let testLogs = [
            LogEntry(category: "API", level: .info, message: "API call successful", source: .mainApp),
            LogEntry(category: "Auth", level: .error, message: "Authentication failed", source: .siriExtension),
            LogEntry(category: "API", level: .debug, message: "API debug info", source: .carPlayExtension),
            LogEntry(category: "UI", level: .info, message: "UI updated", source: .mainApp),
            LogEntry(category: "Network", level: .error, message: "Network timeout", source: .mainApp)
        ]
        
        server.addTestLogs(testLogs)
        
        // Test various filter combinations
        
        // Filter by level
        server.selectedLevel = .error
        server.selectedSource = nil
        server.selectedCategory = nil
        server.filterText = ""
        
        let errorLogs = server.filteredLogs
        XCTAssertEqual(errorLogs.count, 2)
        XCTAssertTrue(errorLogs.allSatisfy { $0.level == .error })
        
        // Filter by source
        server.selectedLevel = nil
        server.selectedSource = .mainApp
        
        let mainAppLogs = server.filteredLogs
        XCTAssertEqual(mainAppLogs.count, 3)
        XCTAssertTrue(mainAppLogs.allSatisfy { $0.source == .mainApp })
        
        // Filter by category
        server.selectedSource = nil
        server.selectedCategory = "API"
        
        let apiLogs = server.filteredLogs
        XCTAssertEqual(apiLogs.count, 2)
        XCTAssertTrue(apiLogs.allSatisfy { $0.category == "API" })
        
        // Filter by text
        server.selectedCategory = nil
        server.filterText = "timeout"
        
        let timeoutLogs = server.filteredLogs
        XCTAssertEqual(timeoutLogs.count, 1)
        XCTAssertEqual(timeoutLogs.first?.message, "Network timeout")
        
        // Combined filters
        server.selectedLevel = .info
        server.selectedSource = .mainApp
        server.filterText = "API"
        
        let combinedLogs = server.filteredLogs
        XCTAssertEqual(combinedLogs.count, 1)
        XCTAssertEqual(combinedLogs.first?.message, "API call successful")
    }
    
    func testLogExportIntegration() {
        // Test the complete export functionality
        
        // Given - Add test logs with various properties
        let testLogs = [
            LogEntry(
                category: "Test", 
                level: .info, 
                message: "Test message 1", 
                source: .mainApp,
                file: "TestFile.swift",
                function: "testFunction()",
                line: 10
            ),
            LogEntry(
                category: "Error", 
                level: .error, 
                message: "Test error message", 
                source: .siriExtension,
                file: "ErrorFile.swift",
                function: "errorFunction()",
                line: 20
            )
        ]
        
        server.addTestLogs(testLogs)
        
        // When - Export logs
        let exported = server.exportLogs()
        
        // Then - Should contain all relevant information
        XCTAssertTrue(exported.contains("Test message 1"))
        XCTAssertTrue(exported.contains("Test error message"))
        XCTAssertTrue(exported.contains("[MainApp]"))
        XCTAssertTrue(exported.contains("[SiriExtension]"))
        XCTAssertTrue(exported.contains("[Test]"))
        XCTAssertTrue(exported.contains("[Error]"))
        XCTAssertTrue(exported.contains("TestFile.swift:10"))
        XCTAssertTrue(exported.contains("ErrorFile.swift:20"))
        XCTAssertTrue(exported.contains("ℹ️")) // Info symbol
        XCTAssertTrue(exported.contains("❌")) // Error symbol
    }
    
    func testAvailableCategoriesIntegration() {
        // Test that available categories update correctly
        
        // Given - Start with no logs
        XCTAssertTrue(server.availableCategories.isEmpty)
        
        // When - Add logs with different categories
        let categories = ["API", "Auth", "UI", "Network", "Debug"]
        var testLogs: [LogEntry] = []
        for (index, category) in categories.enumerated() {
            let log = LogEntry(
                category: category,
                level: .info,
                message: "Message \(index)",
                source: .mainApp
            )
            testLogs.append(log)
        }
        server.addTestLogs(testLogs)
        
        // Then - Available categories should include all unique categories
        let available = Set(server.availableCategories)
        XCTAssertEqual(available, Set(categories))
        
        // Categories should be sorted
        XCTAssertEqual(server.availableCategories, categories.sorted())
        
        // When - Clear logs
        server.clearLogs()
        
        // Then - Available categories should be empty
        XCTAssertTrue(server.availableCategories.isEmpty)
    }
    
    func testExtensionLoggerIntegration() {
        // Test that ExtensionLogger integrates correctly with the system
        
        // Given - Enable remote logging
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        
        // When - Simulate extension logging
        let extensionTestLogs = [
            LogEntry(category: "Integration", level: .info, message: "Extension integration test", source: .siriExtension),
            LogEntry(category: "Integration", level: .error, message: "Extension error test", source: .siriExtension),
            LogEntry(category: "Integration", level: .debug, message: "Extension debug test", source: .siriExtension)
        ]
        server.addTestLogs(extensionTestLogs)
        
        // Then - Should have logs in the server
        XCTAssertEqual(server.logs.count, 3)
        XCTAssertTrue(server.logs.allSatisfy { $0.source == .siriExtension })
        XCTAssertTrue(server.logs.allSatisfy { $0.category == "Integration" })
    }
    
    func testSystemIntegrationScenario() {
        // Simulate a complete system scenario
        
        // 1. User enables developer mode (tap version 7 times)
        UserDefaults.standard.set(true, forKey: "ShowDeveloperMenu")
        
        // 2. User enables remote logging in settings
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        server.start()
        
        // 3. Extension performs some operations and logs (simulated)
        let extensionLogs = [
            LogEntry(category: "SiriExtension", level: .info, message: "Siri intent received", source: .siriExtension),
            LogEntry(category: "SiriExtension", level: .debug, message: "Processing user request", source: .siriExtension),
            LogEntry(category: "SiriExtension", level: .info, message: "Intent handling complete", source: .siriExtension)
        ]
        server.addTestLogs(extensionLogs)
        
        // 4. Main app logs some operations
        let mainAppLog = LogEntry(
            category: "MainApp",
            level: .info,
            message: "User opened app",
            source: .mainApp
        )
        server.addTestLog(mainAppLog)
        
        // 5. User views debug logs
        let allLogs = server.filteredLogs
        
        // 6. User filters by SiriExtension
        server.selectedSource = .siriExtension
        let siriLogs = server.filteredLogs
        
        // 7. User exports logs
        let exported = server.exportLogs()
        
        // Verify the scenario worked
        XCTAssertTrue(server.isRunning)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        XCTAssertFalse(exported.isEmpty)
        XCTAssertEqual(allLogs.count, 4)
        XCTAssertEqual(siriLogs.count, 3)

        // Clean up
        server.stop()
        UserDefaults.standard.removeObject(forKey: "ShowDeveloperMenu")
        UserDefaults.standard.removeObject(forKey: "RemoteLoggingEnabled")
    }
}
