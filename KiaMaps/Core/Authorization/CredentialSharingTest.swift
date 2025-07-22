//
//  CredentialSharingTest.swift
//  KiaMaps
//
//  Created by Claude on 21.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation

/// Test utility for verifying credential sharing between app and extensions
enum CredentialSharingTest {
    
    /// Test scenarios for credential sharing
    enum TestScenario {
        case storeCredentials
        case retrieveCredentials
        case updateCredentials
        case clearCredentials
        case darwinNotificationPosting
        case darwinNotificationReceiving
    }
    
    /// Run all credential sharing tests
    static func runAllTests() {
        print("🧪 Running Credential Sharing Tests...")
        
        testStoreAndRetrieveCredentials()
        testCredentialUpdates()
        testCredentialClearing()
        testDarwinNotifications()
        
        print("✅ All Credential Sharing Tests Completed")
    }
    
    /// Test basic credential storage and retrieval
    private static func testStoreAndRetrieveCredentials() {
        print("📝 Testing credential storage and retrieval...")
        
        // Create test authorization data
        let testAuth = AuthorizationData(
            stamp: "test_stamp_\(Date().timeIntervalSince1970)",
            deviceId: UUID(),
            accessToken: "test_access_token_\(UUID().uuidString)",
            expiresIn: 3600,
            refreshToken: "test_refresh_token_\(UUID().uuidString)",
            isCcuCCS2Supported: true
        )
        
        // Store credentials
        Authorization.store(data: testAuth)
        print("   ✓ Stored test credentials")
        
        // Verify credentials can be retrieved
        guard let retrievedAuth = Authorization.authorization else {
            print("   ❌ Failed to retrieve stored credentials")
            return
        }
        
        // Verify data integrity
        if retrievedAuth.accessToken == testAuth.accessToken &&
           retrievedAuth.refreshToken == testAuth.refreshToken &&
           retrievedAuth.deviceId == testAuth.deviceId {
            print("   ✓ Retrieved credentials match stored data")
        } else {
            print("   ❌ Retrieved credentials do not match stored data")
        }
        
        // Verify isAuthorized works
        if Authorization.isAuthorized {
            print("   ✓ Authorization.isAuthorized returns true")
        } else {
            print("   ❌ Authorization.isAuthorized returns false despite stored credentials")
        }
    }
    
    /// Test credential updates
    private static func testCredentialUpdates() {
        print("🔄 Testing credential updates...")
        
        guard let currentAuth = Authorization.authorization else {
            print("   ❌ No existing credentials to update")
            return
        }
        
        // Update CCS2 protocol support
        let originalSupport = currentAuth.isCcuCCS2Supported
        Authorization.setCcuCCS2Protocol(isSupported: !originalSupport)
        
        guard let updatedAuth = Authorization.authorization else {
            print("   ❌ Failed to retrieve updated credentials")
            return
        }
        
        if updatedAuth.isCcuCCS2Supported == !originalSupport {
            print("   ✓ CCS2 protocol support updated successfully")
        } else {
            print("   ❌ CCS2 protocol support update failed")
        }
        
        // Restore original state
        Authorization.setCcuCCS2Protocol(isSupported: originalSupport)
    }
    
    /// Test credential clearing
    private static func testCredentialClearing() {
        print("🧹 Testing credential clearing...")
        
        // Ensure we have credentials first
        if !Authorization.isAuthorized {
            print("   ⚠️ No credentials to clear, skipping test")
            return
        }
        
        // Clear credentials
        Authorization.remove()
        print("   ✓ Called Authorization.remove()")
        
        // Verify credentials are cleared
        if Authorization.authorization == nil {
            print("   ✓ Credentials successfully cleared")
        } else {
            print("   ❌ Credentials still present after clearing")
        }
        
        // Verify isAuthorized returns false
        if !Authorization.isAuthorized {
            print("   ✓ Authorization.isAuthorized returns false after clearing")
        } else {
            print("   ❌ Authorization.isAuthorized still returns true after clearing")
        }
    }
    
    /// Test Darwin notification system
    private static func testDarwinNotifications() {
        print("📡 Testing Darwin notifications...")
        
        var receivedUpdatedNotification = false
        var receivedClearedNotification = false
        
        // Set up observers
        DarwinNotificationHelper.observe(name: DarwinNotificationHelper.NotificationName.credentialsUpdated) {
            receivedUpdatedNotification = true
            print("   ✓ Received credentials updated notification")
        }
        
        DarwinNotificationHelper.observe(name: DarwinNotificationHelper.NotificationName.credentialsCleared) {
            receivedClearedNotification = true
            print("   ✓ Received credentials cleared notification")
        }
        
        // Test posting notifications
        print("   📤 Posting test notifications...")
        DarwinNotificationHelper.post(name: DarwinNotificationHelper.NotificationName.credentialsUpdated)
        DarwinNotificationHelper.post(name: DarwinNotificationHelper.NotificationName.credentialsCleared)
        
        // Give a small delay for notifications to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if receivedUpdatedNotification {
                print("   ✓ Darwin notification for credentials updated works")
            } else {
                print("   ❌ Darwin notification for credentials updated failed")
            }
            
            if receivedClearedNotification {
                print("   ✓ Darwin notification for credentials cleared works")
            } else {
                print("   ❌ Darwin notification for credentials cleared failed")
            }
        }
    }
    
    /// Test keychain access group functionality
    static func testKeychainAccessGroup() {
        print("🔑 Testing keychain access group functionality...")
        
        // Test direct keychain access with access group
        let testValue = "test_value_\(UUID().uuidString)"
        
        // Store value using keychain access group
        Keychain<TestKey>.store(value: testValue, path: .testCredential)
        print("   ✓ Stored test value in shared keychain")
        
        // Retrieve value
        let retrievedValue: String? = Keychain<TestKey>.value(for: .testCredential)
        
        if let retrievedValue = retrievedValue, retrievedValue == testValue {
            print("   ✓ Successfully retrieved value from shared keychain")
        } else {
            print("   ❌ Failed to retrieve value from shared keychain")
        }
        
        // Clean up
        Keychain<TestKey>.removeVakue(at: .testCredential)
        print("   ✓ Cleaned up test data")
    }
    
    /// Display current configuration
    static func displayConfiguration() {
        print("⚙️ Current Configuration:")
        print("   Access Group ID: \(AppConfiguration.accessGroupId)")
        print("   API Configuration: \(AppConfiguration.apiConfiguration.name)")
        print("   Authorization Status: \(Authorization.isAuthorized ? "✓ Authorized" : "❌ Not Authorized")")
        
        if let auth = Authorization.authorization {
            print("   Device ID: \(auth.deviceId)")
            print("   CCS2 Support: \(auth.isCcuCCS2Supported ? "✓ Enabled" : "❌ Disabled")")
            print("   Access Token: \(String(auth.accessToken.prefix(20)))...")
        }
    }
}

/// Test key enum for keychain testing
private enum TestKey: String {
    case testCredential = "test_credential"
}