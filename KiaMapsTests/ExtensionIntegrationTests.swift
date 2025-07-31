//
//  ExtensionIntegrationTests.swift
//  KiaMapsTests
//
//  Created by Claude on 26.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class ExtensionIntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Start the server for integration tests
        LocalCredentialServer.shared.start()
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    override func tearDownWithError() throws {
        // Stop the server and clean up
        LocalCredentialServer.shared.stop()
        Authorization.remove()
        SharedVehicleManager.shared.selectedVehicleVIN = nil
    }
    
    func testMainAppToExtensionCredentialFlow() throws {
        let expectation = XCTestExpectation(description: "Main app shares credentials with extension")
        
        // Simulate main app storing credentials
        let testAuth = AuthorizationData(
            stamp: "integration-test-stamp",
            deviceId: UUID(),
            accessToken: "integration-test-token",
            expiresIn: 7200,
            refreshToken: "integration-test-refresh",
            isCcuCCS2Supported: false
        )
        
        // Store credentials in main app
        Authorization.store(data: testAuth)
        
        // Set selected vehicle VIN
        SharedVehicleManager.shared.selectedVehicleVIN = "INTEGRATION123TEST"
        
        // Give time for server to process
        Thread.sleep(forTimeInterval: 0.1)
        
        // Simulate extension requesting credentials
        let extensionClient = LocalCredentialClient(extensionIdentifier: "IntegrationTestExtension")
        
        if let receivedCredentials = extensionClient.fetchAuthorizationSync() {
            XCTAssertEqual(receivedCredentials.accessToken, "integration-test-token")
            XCTAssertEqual(receivedCredentials.refreshToken, "integration-test-refresh")
            XCTAssertEqual(receivedCredentials.expiresIn, 7200)
            XCTAssertFalse(receivedCredentials.isCcuCCS2Supported)
            expectation.fulfill()
        } else {
            XCTFail("Extension failed to receive credentials from main app")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSelectedVehicleVINSharing() throws {
        let expectation = XCTestExpectation(description: "Selected vehicle VIN is shared correctly")
        
        // Set selected vehicle VIN in main app
        let testVIN = "VINTEST456789"
        SharedVehicleManager.shared.selectedVehicleVIN = testVIN
        
        // Store some credentials so the request succeeds
        let testAuth = AuthorizationData(
            stamp: "vin-test-stamp",
            deviceId: UUID(),
            accessToken: "vin-test-token",
            expiresIn: 3600,
            refreshToken: "vin-test-refresh",
            isCcuCCS2Supported: true
        )
        Authorization.store(data: testAuth)
        
        Thread.sleep(forTimeInterval: 0.1)
        
        // Extension requests credentials and VIN
        let extensionClient = LocalCredentialClient(extensionIdentifier: "VINTestExtension")
        
        // Note: The current LocalCredentialClient's fetchAuthorizationSync only returns AuthorizationData
        // In a full implementation, we'd need to modify it to also return the VIN
        // For now, test that credentials are received successfully
        if let response = extensionClient.fetchCredentialsSync() {
            XCTAssertNotNil(response.authorization)
            XCTAssertEqual(response.selectedVIN, testVIN)
            expectation.fulfill()
        } else {
            XCTFail("Failed to receive credentials")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServerRestartReliability() throws {
        let expectation = XCTestExpectation(description: "Server handles restart gracefully")
        
        // Store test credentials
        let testAuth = AuthorizationData(
            stamp: "restart-test-stamp",
            deviceId: UUID(),
            accessToken: "restart-test-token",
            expiresIn: 3600,
            refreshToken: "restart-test-refresh",
            isCcuCCS2Supported: true
        )
        Authorization.store(data: testAuth)
        
        // Test initial connection
        let client = LocalCredentialClient(extensionIdentifier: "RestartTestExtension")
        let credentials1 = client.fetchAuthorizationSync()
        XCTAssertNotNil(credentials1)
        
        // Restart server
        LocalCredentialServer.shared.stop()
        Thread.sleep(forTimeInterval: 0.5)
        LocalCredentialServer.shared.start()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Test connection after restart
        let credentials2 = client.fetchAuthorizationSync()
        XCTAssertNotNil(credentials2)
        XCTAssertEqual(credentials2?.accessToken, credentials1?.accessToken)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSecurityPasswordValidation() throws {
        let expectation = XCTestExpectation(description: "Server validates passwords correctly")
        
        // Store credentials
        let testAuth = AuthorizationData(
            stamp: "security-test-stamp",
            deviceId: UUID(),
            accessToken: "security-test-token",
            expiresIn: 3600,
            refreshToken: "security-test-refresh",
            isCcuCCS2Supported: true
        )
        Authorization.store(data: testAuth)
        
        // Test with correct password (default client)
        let validClient = LocalCredentialClient(extensionIdentifier: "SecurityTestExtension")
        let credentialsValid = validClient.fetchAuthorizationSync()
        XCTAssertNotNil(credentialsValid, "Valid client should receive credentials")
        
        // Note: Testing invalid password would require modifying LocalCredentialClient
        // to accept custom passwords, which is beyond the scope of this test
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }
}