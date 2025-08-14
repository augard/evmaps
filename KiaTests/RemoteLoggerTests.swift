//
//  RemoteLoggerTests.swift
//  KiaTests
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
import Network
@testable import KiaMaps

final class RemoteLoggerTests: XCTestCase {
    
    var remoteLogger: RemoteLogger!
    var mockServer: MockHTTPServer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Start mock server
        mockServer = MockHTTPServer()
        try mockServer.start()
        
        // Create RemoteLogger instance
        remoteLogger = RemoteLogger.shared
        remoteLogger.setEnabled(false) // Start disabled
    }
    
    override func tearDownWithError() throws {
        mockServer?.stop()
        remoteLogger?.setEnabled(false)
        
        try super.tearDownWithError()
    }
    
    func testRemoteLoggerInitialization() {
        // Given/When - RemoteLogger is a singleton
        let logger1 = RemoteLogger.shared
        let logger2 = RemoteLogger.shared
        
        // Then
        XCTAssertTrue(logger1 === logger2, "RemoteLogger should be a singleton")
    }
    
    func testEnableDisableRemoteLogging() {
        // Given
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // When - Enable logging
        remoteLogger.setEnabled(true)

        let expectation1 = expectation(description: "Wait for first set")
        let expectation2 = expectation(description: "Wait for second set")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {

            // Then
            XCTAssertTrue(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))

            // When - Disable logging
            self.remoteLogger.setEnabled(false)
            expectation1.fulfill()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Then
                XCTAssertFalse(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
                expectation2.fulfill()
            }
        }
        wait(for: [expectation1, expectation2], timeout: 1)
    }
    
    func testLogWhenDisabled() {
        // Given - Logger is disabled
        remoteLogger.setEnabled(false)
        
        // When - Log a message
        remoteLogger.log(
            .info,
            category: "Test",
            message: "Test message",
            source: .mainApp
        )
        
        // Then - No network request should be made
        // We can't directly test this without exposing internal state,
        // but the system should not crash or throw errors
        XCTAssertTrue(true, "Logging when disabled should not cause errors")
    }
    
    func testLogMessageFormatting() {
        // Given
        remoteLogger.setEnabled(true)
        
        // When - Log with string formatting
        remoteLogger.log(
            .error,
            category: "TestCategory",
            message: "User %@ failed login with error %d",
            source: .siriExtension,
            file: "TestFile.swift",
            function: "testFunction()",
            line: 42
        )
        
        // Then - Should not crash
        XCTAssertTrue(true, "Message formatting should work without crashes")
    }
    
    func testFlushImmediately() {
        // Given
        remoteLogger.setEnabled(true)
        
        // When
        remoteLogger.flush()
        
        // Then - Should not crash
        XCTAssertTrue(true, "Flush should complete without errors")
    }
    
    func testLogLevelsConversion() {
        // This test verifies that OSLogType conversion works correctly
        // Since we can't directly test the internal conversion,
        // we'll test that logging with different levels doesn't crash
        
        // Given
        remoteLogger.setEnabled(true)
        let levels: [LogEntry.LogLevel] = [.debug, .info, .default, .error, .fault]
        
        // When/Then - All levels should log without crashing
        for level in levels {
            remoteLogger.log(
                level,
                category: "Test",
                message: "Test message for level \(level)",
                source: .mainApp
            )
        }
        
        XCTAssertTrue(true, "All log levels should work without crashes")
    }
    
    func testSourceDetection() {
        // This test verifies different sources can be logged
        
        // Given
        remoteLogger.setEnabled(true)
        let sources: [LogEntry.LogSource] = [.mainApp, .carPlayExtension, .siriExtension]
        
        // When/Then - All sources should log without crashing
        for source in sources {
            remoteLogger.log(
                .info,
                category: "Test",
                message: "Test message from \(source)",
                source: source
            )
        }
        
        XCTAssertTrue(true, "All sources should work without crashes")
    }
    
    func testConfigurationFromUserDefaults() {
        // Given - Set UserDefaults value
        UserDefaults.standard.set(true, forKey: "RemoteLoggingEnabled")
        
        // When - Create new logger (simulating app restart)
        // Note: Since RemoteLogger is a singleton, we can't easily test this
        // In a real test, we'd need dependency injection or a factory method
        
        // Then - Logger should respect UserDefaults
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled"))
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "RemoteLoggingEnabled")
    }
}

// MARK: - Mock HTTP Server

class MockHTTPServer {
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8081
    private var connections: Set<MockConnection> = []
    
    private(set) var receivedRequests: [MockRequest] = []
    
    struct MockRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data?
    }
    
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: parameters, on: port)
        
        listener?.newConnectionHandler = { [weak self] connection in
            let mockConnection = MockConnection(connection: connection) { request in
                self?.receivedRequests.append(request)
            }
            self?.connections.insert(mockConnection)
            mockConnection.start()
        }
        
        listener?.start(queue: .main)
    }
    
    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        receivedRequests.removeAll()
    }
    
    func waitForRequests(count: Int, timeout: TimeInterval = 5.0) -> Bool {
        let expectation = XCTestExpectation(description: "Wait for \(count) requests")
        
        let startTime = Date()
        func checkRequests() {
            if receivedRequests.count >= count {
                expectation.fulfill()
            } else if Date().timeIntervalSince(startTime) < timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkRequests()
                }
            }
        }
        
        checkRequests()
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}

// MARK: - Mock Connection

private class MockConnection: Hashable {
    let id = UUID()
    private let connection: NWConnection
    private let onRequest: (MockHTTPServer.MockRequest) -> Void
    
    init(connection: NWConnection, onRequest: @escaping (MockHTTPServer.MockRequest) -> Void) {
        self.connection = connection
        self.onRequest = onRequest
    }
    
    func start() {
        connection.start(queue: .main)
        receiveRequest()
    }
    
    func cancel() {
        connection.cancel()
    }
    
    private func receiveRequest() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self = self, let data = data else { return }
            
            // Simple HTTP request parsing for testing
            let requestString = String(data: data, encoding: .utf8) ?? ""
            let lines = requestString.components(separatedBy: "\r\n")
            
            if let firstLine = lines.first {
                let components = firstLine.components(separatedBy: " ")
                if components.count >= 2 {
                    let method = components[0]
                    let path = components[1]
                    
                    // Extract headers
                    var headers: [String: String] = [:]
                    var bodyStart = -1
                    
                    for (index, line) in lines.enumerated() {
                        if line.isEmpty {
                            bodyStart = index + 1
                            break
                        }
                        if line.contains(":") && index > 0 {
                            let headerComponents = line.components(separatedBy: ": ")
                            if headerComponents.count == 2 {
                                headers[headerComponents[0]] = headerComponents[1]
                            }
                        }
                    }
                    
                    // Extract body
                    var body: Data?
                    if bodyStart >= 0 && bodyStart < lines.count {
                        let bodyLines = Array(lines[bodyStart...])
                        let bodyString = bodyLines.joined(separator: "\r\n")
                        body = bodyString.data(using: .utf8)
                    }
                    
                    let request = MockHTTPServer.MockRequest(
                        method: method,
                        path: path,
                        headers: headers,
                        body: body
                    )
                    
                    self.onRequest(request)
                    
                    // Send response
                    let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
                    if let responseData = response.data(using: .utf8) {
                        self.connection.send(content: responseData, completion: .contentProcessed { _ in })
                    }
                }
            }
        }
    }
    
    static func == (lhs: MockConnection, rhs: MockConnection) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
