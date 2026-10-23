//
//  LocalCredentialServerTests.swift
//  KiaMapsTests
//
//  Created by Claude on 26.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
import Network
@testable import KiaMaps

final class LocalCredentialServerTests: XCTestCase {
    var server: LocalCredentialServer!
    let testPort: UInt16 = 8766
    let testPassword = "test"
    
    override func setUpWithError() throws {
        server = LocalCredentialServer(port: testPort, password: testPassword)
        Authorization.remove()
        SharedVehicleManager.shared.selectedVehicleVIN = nil
        UserDefaults.standard.removeObject(forKey: "selectedVehicleVIN")
    }
    
    override func tearDownWithError() throws {
        server.stop()
        Authorization.remove()
        SharedVehicleManager.shared.selectedVehicleVIN = nil
        UserDefaults.standard.removeObject(forKey: "selectedVehicleVIN")
        server = nil
    }
    
    func testServerStartsAndStops() throws {
        // Test that server can start without errors
        server.start()
        
        // Give server time to start
        Thread.sleep(forTimeInterval: 0.5)
        
        // Test that server can stop without errors
        server.stop()
    }
    
    func testServerRespondsToValidRequest() async throws {
        server.start()
        try await Task.sleep(for: .milliseconds(500))

        // Create test authorization data
        let testAuth = AuthorizationData(
            stamp: "test-stamp",
            deviceId: UUID(),
            accessToken: "test-token",
            expiresIn: 3600,
            refreshToken: "test-refresh",
            isCcuCCS2Supported: true
        )
        
        // Store test data
        Authorization.store(data: testAuth)
        SharedVehicleManager.shared.selectedVehicleVIN = "TEST123VIN"
        
        // Create client to test server
        let client = LocalCredentialClient(
            extensionIdentifier: "TestExtension",
            serverPort: testPort,
            serverPassword: testPassword
        )
        
        let credentials = try await client.fetchCredentials()
        XCTAssertNotNil(credentials)
        XCTAssertEqual(credentials.authorization?.accessToken, "test-token")

        // Cleanup
        Authorization.remove()
        server.stop()
    }
    
    func testServerRejectsInvalidPassword() async throws {
        server.start()
        try await Task.sleep(for: .milliseconds(500))

        let client = LocalCredentialClient(
            extensionIdentifier: "TestExtension",
            serverPort: testPort,
            serverPassword: "wrong-password"
        )

        do {
            _ = try await client.fetchCredentials()
            XCTFail("Expected invalid password error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Invalid password"))
        }

        server.stop()
    }
    
    func testServerHandlesMultipleClients() async throws {
        server.start()
        try await Task.sleep(for: .milliseconds(500))

        // Store test data
        let testAuth = AuthorizationData(
            stamp: "test-stamp",
            deviceId: UUID(),
            accessToken: "test-token",
            expiresIn: 3600,
            refreshToken: "test-refresh",
            isCcuCCS2Supported: true
        )
        Authorization.store(data: testAuth)

        async let response1 = LocalCredentialClient(
            extensionIdentifier: "TestExtension1",
            serverPort: testPort,
            serverPassword: testPassword
        ).fetchCredentials()
        async let response2 = LocalCredentialClient(
            extensionIdentifier: "TestExtension2",
            serverPort: testPort,
            serverPassword: testPassword
        ).fetchCredentials()

        let credentials = try await [response1, response2]
        XCTAssertEqual(credentials.count, 2)
        XCTAssertTrue(credentials.allSatisfy { $0.authorization?.accessToken == "test-token" })

        // Cleanup
        Authorization.remove()
        server.stop()
    }
    
    func testServerHandlesNoCredentials() async throws {
        server.start()
        try await Task.sleep(for: .milliseconds(500))

        // Ensure no credentials are stored
        Authorization.remove()

        let client = LocalCredentialClient(
            extensionIdentifier: "TestExtension",
            serverPort: testPort,
            serverPassword: ""
        )

        // Server should still respond, but with nil authorization
        do {
            _ = try await client.fetchCredentials()
            XCTFail("It should fail to continue")
        } catch let error {
            let error = try XCTUnwrap(error as? LocalCredentialClientError)
            switch error {
            case .noCredentials:
                break
            default:
                XCTFail("Unknown error \(error)")
            }
        }

        server.stop()
    }
}
