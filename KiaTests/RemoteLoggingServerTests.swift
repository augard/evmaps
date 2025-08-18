//
//  RemoteLoggingServerTests.swift
//  KiaTests
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
import Network
import Combine
@testable import KiaMaps

@MainActor
final class RemoteLoggingServerTests: XCTestCase {
    
    var server: RemoteLoggingServer!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        server = RemoteLoggingServer.shared
        cancellables = Set<AnyCancellable>()
        
        // Ensure server is stopped before each test
        server.stop()
        server.clearLogs()
    }
    
    override func tearDownWithError() throws {
        server?.stop()
        server?.clearLogs()
        cancellables?.removeAll()
        
        try super.tearDownWithError()
    }
    
    func testServerInitialization() {
        // Given/When - Server is a singleton
        let server1 = RemoteLoggingServer.shared
        let server2 = RemoteLoggingServer.shared
        
        // Then
        XCTAssertTrue(server1 === server2, "RemoteLoggingServer should be a singleton")
        XCTAssertFalse(server.isRunning, "Server should start in stopped state")
        XCTAssertEqual(server.connectionCount, 0, "Server should start with 0 connections")
        XCTAssertTrue(server.logs.isEmpty, "Server should start with no logs")
    }
    
    func testStartStopServer() {
        // Given
        XCTAssertFalse(server.isRunning)
        
        // When - Start server
        server.start()
        
        // Then
        XCTAssertTrue(server.isRunning)
        
        // When - Stop server
        server.stop()
        
        // Then
        XCTAssertFalse(server.isRunning)
        XCTAssertEqual(server.connectionCount, 0)
    }
    
    func testStartServerTwice() {
        // Given - Server is not running
        XCTAssertFalse(server.isRunning)
        
        // When - Start server twice
        server.start()
        let wasRunningAfterFirst = server.isRunning
        server.start() // Should not crash or create issues
        
        // Then
        XCTAssertTrue(wasRunningAfterFirst)
        XCTAssertTrue(server.isRunning)
    }
    
    func testClearLogs() {
        // Given - Add some test logs
        let testLogs = [
            LogEntry(category: "Test1", level: .info, message: "Message 1", source: .mainApp),
            LogEntry(category: "Test2", level: .error, message: "Message 2", source: .siriExtension)
        ]
        
        // Add test logs using helper method
        server.addTestLogs(testLogs)
        
        XCTAssertEqual(server.logs.count, 2)
        
        // When
        server.clearLogs()
        
        // Then
        XCTAssertTrue(server.logs.isEmpty)
    }
    
    func testExportLogs() {
        // Given - Add some test logs
        let testLogs = [
            LogEntry(category: "Test1", level: .info, message: "Message 1", source: .mainApp),
            LogEntry(category: "Test2", level: .error, message: "Message 2", source: .siriExtension)
        ]
        
        server.addTestLogs(testLogs)
        
        // When
        let exported = server.exportLogs()
        
        // Then
        XCTAssertFalse(exported.isEmpty)
        XCTAssertTrue(exported.contains("Message 1"))
        XCTAssertTrue(exported.contains("Message 2"))
        XCTAssertTrue(exported.contains("[MainApp]"))
        XCTAssertTrue(exported.contains("[SiriExtension]"))
    }
    
    func testLogFiltering() {
        // Given - Add test logs with different properties
        let testLogs = [
            LogEntry(category: "API", level: .info, message: "API message", source: .mainApp),
            LogEntry(category: "Auth", level: .error, message: "Auth error", source: .siriExtension),
            LogEntry(category: "API", level: .debug, message: "API debug", source: .carPlayExtension),
            LogEntry(category: "UI", level: .info, message: "UI message", source: .mainApp)
        ]
        
        server.addTestLogs(testLogs)
        
        // Test filter by level
        server.selectedLevel = .info
        server.selectedSource = nil
        var filtered = server.filteredLogs
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.level == .info })
        
        // Test filter by source
        server.selectedLevel = nil
        server.selectedSource = .mainApp
        filtered = server.filteredLogs
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.source == .mainApp })
        
        // Test filter by category
        server.selectedSource = nil
        server.selectedCategory = "API"
        filtered = server.filteredLogs
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "API" })
        
        // Test filter by text
        server.selectedCategory = nil
        server.filterText = "error"
        filtered = server.filteredLogs
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.message, "Auth error")
        
        // Test combined filters
        server.filterText = "API"
        server.selectedLevel = .info
        filtered = server.filteredLogs
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.message, "API message")
    }
    
    func testAvailableCategories() {
        // Given - Add logs with different categories
        let testLogs = [
            LogEntry(category: "API", level: .info, message: "Message 1", source: .mainApp),
            LogEntry(category: "Auth", level: .error, message: "Message 2", source: .siriExtension),
            LogEntry(category: "API", level: .debug, message: "Message 3", source: .mainApp), // Duplicate category
            LogEntry(category: "UI", level: .info, message: "Message 4", source: .mainApp)
        ]
        
        server.addTestLogs(testLogs)
        
        // When
        let categories = server.availableCategories
        
        // Then
        XCTAssertEqual(Set(categories), Set(["API", "Auth", "UI"]))
        XCTAssertEqual(categories, categories.sorted()) // Should be sorted
    }
    
    func testMaxLogLimit() {
        // Given - Create more logs than the max limit (1000)
        let maxLogs = 1000
        let excessLogs = 50
        
        var testLogs: [LogEntry] = []
        for i in 0..<(maxLogs + excessLogs) {
            testLogs.append(LogEntry(
                category: "Test",
                level: .info,
                message: "Message \(i)",
                source: .mainApp
            ))
        }
        
        // When - Add test logs using helper method (which includes trimming logic)
        server.addTestLogs(testLogs)
        
        // Then
        XCTAssertEqual(server.logs.count, maxLogs)
        
        // The remaining logs should be the most recent ones
        XCTAssertEqual(server.logs.first?.message, "Message \(excessLogs)")
        XCTAssertEqual(server.logs.last?.message, "Message \(maxLogs + excessLogs - 1)")
    }
    
    func testPublishedPropertiesChanges() {
        let expectation = XCTestExpectation(description: "Published properties should notify changes")
        expectation.expectedFulfillmentCount = 5

        // Given - Subscribe to published properties
        var isRunningValues: [Bool] = []
        var connectionCountValues: [Int] = []
        var logCountValues: [Int] = []
        
        server.$isRunning
            .sink { value in
                isRunningValues.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        server.$connectionCount
            .sink { value in
                connectionCountValues.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        server.$logs
            .sink { value in
                logCountValues.append(value.count)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When - Make changes that should trigger publications
        DispatchQueue.main.async {
            self.server.start() // Should change isRunning
            
            // Simulate connection count change (in real implementation, this happens through connections)
            // We can't easily test this without more complex setup
            
            // Add a log
            let testLog = LogEntry(category: "Test", level: .info, message: "Test", source: .mainApp)
            self.server.addTestLog(testLog)
        }
        
        // Then
        wait(for: [expectation], timeout: 3.0)

        XCTAssertTrue(isRunningValues.contains(true), "isRunning should have changed to true")
        XCTAssertTrue(logCountValues.contains(1), "Log count should have changed to 1")
    }
    
    func testHandleLogBatch() {
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
        
        let batch = LogBatch(entries: entries, deviceInfo: deviceInfo)
        
        // When - Simulate handling log batch using test helper
        server.addTestLogs(batch.entries)
        
        // Then
        XCTAssertEqual(server.logs.count, 2)
        XCTAssertEqual(server.logs[0].message, "Message 1")
        XCTAssertEqual(server.logs[1].message, "Message 2")
    }
}
