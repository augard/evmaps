#!/usr/bin/env swift

//
//  test_local_server.swift
//  KiaMaps Test Script
//
//  Created by Claude on 26.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import Network

// Simple test script to verify local server communication
// This can be run independently to test the server functionality

struct TestCredentialRequest: Codable {
    let password: String
    let extensionIdentifier: String
}

struct TestCredentialResponse: Codable {
    let authorization: TestAuthorizationData?
    let selectedVIN: String?
    let timestamp: Date
}

struct TestAuthorizationData: Codable {
    let stamp: String
    let deviceId: String
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String
    let isCcuCCS2Supported: Bool
}

func testLocalServer() {
    print("🧪 Testing KiaMaps Local Credential Server...")
    
    let connection = NWConnection(
        host: "127.0.0.1",
        port: 8765,
        using: .tcp
    )
    
    let semaphore = DispatchSemaphore(value: 0)
    var testResult = false
    
    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            print("✅ Connected to server")
            
            // Send test request
            let request = TestCredentialRequest(
                password: ProcessInfo.processInfo.environment["KIAMAPS_SERVER_PASSWORD"] ?? "KiaMapsSecurePassword2025",
                extensionIdentifier: "TestScript"
            )
            
            do {
                let requestData = try JSONEncoder().encode(request)
                
                connection.send(content: requestData, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ Send error: \(error)")
                        semaphore.signal()
                        return
                    }
                    
                    // Receive response
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                        defer { 
                            connection.cancel()
                            semaphore.signal()
                        }
                        
                        if let error = error {
                            print("❌ Receive error: \(error)")
                            return
                        }
                        
                        guard let data = data, !data.isEmpty else {
                            print("❌ No data received")
                            return
                        }
                        
                        // Try to decode as error response first
                        if let errorDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                           let errorMessage = errorDict["error"] {
                            print("❌ Server error: \(errorMessage)")
                            return
                        }
                        
                        // Decode as credential response
                        do {
                            let response = try JSONDecoder().decode(TestCredentialResponse.self, from: data)
                            
                            if let auth = response.authorization {
                                print("✅ Received credentials:")
                                print("   Access Token: \(auth.accessToken.prefix(10))...")
                                print("   Device ID: \(auth.deviceId)")
                                print("   Expires In: \(auth.expiresIn)")
                                testResult = true
                            } else {
                                print("⚠️ No authorization data (main app may not be logged in)")
                                testResult = true  // Still a valid response
                            }
                            
                            if let vin = response.selectedVIN {
                                print("   Selected VIN: \(vin)")
                            } else {
                                print("   No vehicle selected")
                            }
                            
                            print("   Timestamp: \(response.timestamp)")
                            
                        } catch {
                            print("❌ Decode error: \(error)")
                        }
                    }
                })
            } catch {
                print("❌ Encode error: \(error)")
                connection.cancel()
                semaphore.signal()
            }
            
        case .failed(let error):
            print("❌ Connection failed: \(error)")
            print("   Make sure the KiaMaps app is running")
            semaphore.signal()
            
        case .cancelled:
            print("🔄 Connection cancelled")
            semaphore.signal()
            
        default:
            break
        }
    }
    
    print("🔄 Connecting to local server...")
    connection.start(queue: DispatchQueue.global())
    
    // Wait for completion with timeout
    if semaphore.wait(timeout: .now() + 5.0) == .timedOut {
        print("⏰ Test timed out")
        connection.cancel()
    }
    
    if testResult {
        print("🎉 Local server communication test PASSED")
    } else {
        print("💥 Local server communication test FAILED")
    }
}

// Run the test
print("KiaMaps Local Server Communication Test")
print("=====================================")
testLocalServer()