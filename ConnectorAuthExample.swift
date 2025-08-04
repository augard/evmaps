//
//  ConnectorAuthExample.swift
//  KiaMaps
//
//  Example demonstrating NewAuthenticationAPI connector authorization
//  This shows how to call the API and handle the 302 redirect to extract nxt_uri
//

import Foundation

@available(iOS 13.0, macOS 10.15, *)
class ConnectorAuthExample {
    
    /// Example method showing how to use NewAuthenticationAPI.getConnectorAuthorization()
    /// This method:
    /// 1. Creates a request to /api/v1/user/oauth2/connector/common/authorize
    /// 2. Handles the 302 redirect response
    /// 3. Extracts the 'nxt_uri' parameter from the Location header
    /// 4. Returns the nxt_uri for the next authentication step
    func demonstrateConnectorAuth() async {
        print("🚀 Starting NewAuthenticationAPI Connector Authorization Demo")
        
        do {
            // Initialize the authentication API with default Kia configuration
            let authAPI = NewAuthenticationAPI(configuration: AppConfiguration.apiConfiguration)
            
            print("📡 Making request to connector/common/authorize...")
            print("   Expected: HTTP 302 redirect with nxt_uri in Location header")
            
            // This call will:
            // 1. Build the proper state parameter (base64 encoded JSON)
            // 2. Make GET request to /api/v1/user/oauth2/connector/common/authorize
            // 3. Handle 302 redirect response
            // 4. Extract nxt_uri from Location header
            let nxtUri = try await authAPI.getConnectorAuthorization()
            
            print("✅ Success! Retrieved nxt_uri:")
            print("   \(nxtUri)")
            
            // Validate the nxt_uri format
            if nxtUri.contains("idpconnect-eu.kia.com") {
                print("🎯 nxt_uri format looks correct - contains expected domain")
            }
            
            if nxtUri.contains("auth") {
                print("🔐 nxt_uri contains auth path - ready for next step")
            }
            
            print("📋 Next steps would be:")
            print("   1. Use nxt_uri to initialize OAuth2 flow")
            print("   2. Get RSA certificate for password encryption") 
            print("   3. Continue with encrypted sign-in process")
            
        } catch let error as NewAuthenticationError {
            print("❌ NewAuthenticationError: \(error.localizedDescription)")
            handleAuthError(error)
            
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }
    
    /// Handle specific authentication errors with helpful messages
    private func handleAuthError(_ error: NewAuthenticationError) {
        switch error {
        case .oauth2InitializationFailed:
            print("🔍 This could mean:")
            print("   • Server didn't return expected 302 redirect")
            print("   • nxt_uri parameter missing from Location header")
            print("   • Network connectivity issues")
            
        case .invalidResponse:
            print("🔍 This could mean:")
            print("   • Server returned malformed response")
            print("   • HTTP response couldn't be parsed")
            
        case .networkError(let message):
            print("🔍 Network error details: \(message)")
            
        default:
            print("🔍 See NewAuthenticationError enum for more details")
        }
    }
}

// MARK: - Usage Example

/*
Usage in your app:

import Foundation

@available(iOS 13.0, macOS 10.15, *)
func testConnectorAuth() {
    Task {
        let example = ConnectorAuthExample()
        await example.demonstrateConnectorAuth()
    }
}

// Call from your app:
if #available(iOS 13.0, macOS 10.15, *) {
    testConnectorAuth()
}
*/

// MARK: - Expected Request/Response Flow

/*
Expected HTTP flow:

1. REQUEST:
GET /api/v1/user/oauth2/connector/common/authorize?client_id=fdc85c00-0a2f-4c64-bcb4-2cfb1500730a&redirect_uri=https%3A%2F%2Fidpconnect-eu.kia.com%2Fauth%2Fredirect&response_type=code&state=eyJzY29wZSI6bnVsbCwic3RhdGUiOm51bGwsImxhbmciOm51bGwsImNlcnQiOiIiLCJhY3Rpb24iOiJpZHBjX2F1dGhfZW5kcG9pbnQiLCJjbGllbnRfaWQiOiJmZGM4NWMwMC0wYTJmLTRjNjQtYmNiNC0yY2ZiMTUwMDczMGEiLCJyZWRpcmVjdF91cmkiOiJodHRwczovL2lkcGNvbm5lY3QtZXUua2lhLmNvbS9hdXRoL3JlZGlyZWN0IiwicmVzcG9uc2VfdHlwZSI6ImNvZGUiLCJzaWdudXBfbGluayI6bnVsbCwiaG1naWQyX2NsaWVudF9pZCI6ImZkYzg1YzAwLTBhMmYtNGM2NC1iY2I0LTJjZmIxNTAwNzMwYSIsImhtZ2lkMl9yZWRpcmVjdF91cmkiOiJodHRwczovL3ByZC5ldS1jY2FwaS5raWEuY29tOjgwODAvYXBpL3YxL3VzZXIvb2F1dGgyL3JlZGlyZWN0IiwiaG1naWQyX3Njb3BlIjpudWxsLCJobWdpZDJfc3RhdGUiOiJjY3NwIiwiaG1naWQyX3VpX2xvY2FsZXMiOm51bGx9&cert=&action=idpc_auth_endpoint&sso_session_reset=true HTTP/1.1
Host: prd.eu-ccapi.kia.com:8080

2. RESPONSE:
HTTP/1.1 302 Found
Location: https://idpconnect-eu.kia.com/auth/redirect?nxt_uri=https%3A%2F%2Fidpconnect-eu.kia.com%2Fauth%2Fapi%2Fv2%2Fuser%2Foauth2%2Fauthorize%3Fclient_id%3Dfdc85c00-0a2f-4c64-bcb4-2cfb1500730a%26redirect_uri%3Dhttps%253A%252F%252Fprd.eu-ccapi.kia.com%253A8080%252Fapi%252Fv1%252Fuser%252Foauth2%252Fredirect%26response_type%3Dcode%26state%3Dccsp%26lang%3Den

3. RESULT:
Extracted nxt_uri: https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize?client_id=fdc85c00-0a2f-4c64-bcb4-2cfb1500730a&redirect_uri=https%3A%2F%2Fprd.eu-ccapi.kia.com%3A8080%2Fapi%2Fv1%2Fuser%2Foauth2%2Fredirect&response_type=code&state=ccsp&lang=en
*/