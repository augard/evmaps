#!/usr/bin/env swift

import Foundation

// Simple test script to test the NewAuthenticationAPI connector authorization
// This would be run as a standalone Swift script for testing

@available(macOS 10.15, iOS 13.0, *)
func testConnectorAuthorization() async {
    print("🔧 Testing NewAuthenticationAPI Connector Authorization")
    
    do {
        // Initialize the API with default configuration
        let authAPI = NewAuthenticationAPI()
        
        print("📡 Calling getConnectorAuthorization()...")
        
        // This will make the request and handle the 302 redirect
        let nxtUri = try await authAPI.getConnectorAuthorization()
        
        print("✅ Success! Retrieved nxt_uri: \(nxtUri)")
        
        // The nxt_uri should contain the URL to proceed with authentication
        if nxtUri.contains("idpconnect-eu.kia.com") {
            print("🎯 nxt_uri looks valid - contains expected domain")
        } else {
            print("⚠️  nxt_uri may be unexpected: \(nxtUri)")
        }
        
    } catch {
        print("❌ Error: \(error)")
        
        if let authError = error as? NewAuthenticationError {
            print("🔍 Authentication Error Details: \(authError.localizedDescription)")
        }
    }
}

// Usage example showing expected behavior:
print("""
🚀 NewAuthenticationAPI Connector Test

This test will:
1. Create a request to /api/v1/user/oauth2/connector/common/authorize
2. Handle the 302 redirect response  
3. Extract the 'nxt_uri' parameter from the Location header
4. Return the nxt_uri for the next authentication step

Expected flow:
- Request → 302 Redirect → Extract nxt_uri → Success ✅

Running test...
""")

if #available(macOS 10.15, iOS 13.0, *) {
    Task {
        await testConnectorAuthorization()
        exit(0)
    }
    
    // Keep the script running for async operation
    RunLoop.main.run()
} else {
    print("❌ This test requires macOS 10.15+ or iOS 13.0+ for async/await support")
}