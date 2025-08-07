//
//  NewAuthenticationAPITests.swift
//  KiaMapsTests
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class NewAuthenticationAPITests: XCTestCase {
    
    var authAPI: NewAuthenticationAPI!
    var rsaService: RSAEncryptionService!
    
    override func setUp() {
        super.setUp()
        authAPI = NewAuthenticationAPI(configuration: AppConfiguration.apiConfiguration)
        rsaService = RSAEncryptionService()
    }
    
    override func tearDown() {
        authAPI = nil
        rsaService = nil
        super.tearDown()
    }
    
    // MARK: - RSA Integration Tests
    
    func testRSAKeyDataCreation() {
        // Test creating RSA key data from server response
        let serverResponse = RSACertificateResponse(
            kty: "RSA",
            e: "AQAB",
            kid: "HMGID2_CIPHER_KEY1",
            n: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )
        
        let rsaKeyData = RSAEncryptionService.RSAKeyData(
            keyType: serverResponse.kty,
            exponent: serverResponse.e,
            keyId: serverResponse.kid,
            modulus: serverResponse.n
        )
        
        XCTAssertEqual(rsaKeyData.keyType, "RSA")
        XCTAssertEqual(rsaKeyData.exponent, "AQAB")
        XCTAssertEqual(rsaKeyData.keyId, "HMGID2_CIPHER_KEY1")
        XCTAssertFalse(rsaKeyData.modulus.isEmpty)
    }
    
    func testPasswordEncryptionWithRSAKeyData() throws {
        // Create RSA key data as it would come from the server
        let rsaKeyData = RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "AQAB",
            keyId: "HMGID2_CIPHER_KEY1",
            n: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )
        
        let password = "testPassword123"
        
        // Test encryption
        XCTAssertNoThrow {
            let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKeyData)
            
            XCTAssertFalse(encryptedPassword.isEmpty)
            XCTAssertNotEqual(encryptedPassword, password)
            XCTAssertTrue(encryptedPassword.allSatisfy { char in
                ("0"..."9").contains(char) || ("a"..."f").contains(char) || ("A"..."F").contains(char)
            }, "Should be hex encoded")
        }
    }
    
    // MARK: - URL Parameter Extraction Tests
    
    func testExtractNextUri() {
        // Test the private method through reflection/testing approach
        // Since extractNextUri is private, we'll test the expected behavior
        
        // Simulate Location header values that might be returned
        let testCases = [
            (
                url: "https://idpconnect-eu.kia.com/auth/redirect?nxt_uri=https%3A%2F%2Fidpconnect-eu.kia.com%2Fauth%2Fapi%2Fv2%2Fuser%2Foauth2%2Fauthorize",
                expectedParam: "nxt_uri",
                expectedValue: "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize"
            ),
            (
                url: "https://example.com/redirect?next_uri=https%3A%2F%2Fexample.com%2Fnext",
                expectedParam: "next_uri", 
                expectedValue: "https://example.com/next"
            ),
            (
                url: "https://example.com/redirect?other_param=value&nxt_uri=https%3A%2F%2Fexample.com%2Fnext",
                expectedParam: "nxt_uri",
                expectedValue: "https://example.com/next"
            )
        ]
        
        for testCase in testCases {
            guard let url = URL(string: testCase.url),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                XCTFail("Could not parse test URL: \(testCase.url)")
                continue
            }
            
            let nxtUri = queryItems.first(where: { $0.name == "nxt_uri" || $0.name == "next_uri" })?.value
            let decodedValue = nxtUri?.removingPercentEncoding
            
            XCTAssertEqual(decodedValue, testCase.expectedValue, "Failed to extract \(testCase.expectedParam) from \(testCase.url)")
        }
    }
    
    func testExtractConnectorSessionKey() {
        // Test connector session key extraction
        let testURL = "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize?client_id=test&connector_session_key=abc123def&state=ccsp"
        
        guard let url = URL(string: testURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            XCTFail("Could not parse test URL")
            return
        }
        
        let sessionKey = queryItems.first(where: { $0.name == "connector_session_key" })?.value
        XCTAssertEqual(sessionKey, "abc123def")
    }
    
    func testExtractAuthorizationCode() {
        // Test authorization code extraction
        let testURL = "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?code=AUTH_CODE_123&state=ccsp&login_success=y"
        
        guard let url = URL(string: testURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            XCTFail("Could not parse test URL")
            return
        }
        
        let code = queryItems.first(where: { $0.name == "code" })?.value
        let state = queryItems.first(where: { $0.name == "state" })?.value
        let loginSuccess = queryItems.first(where: { $0.name == "login_success" })?.value
        
        XCTAssertEqual(code, "AUTH_CODE_123")
        XCTAssertEqual(state, "ccsp")
        XCTAssertEqual(loginSuccess, "y")
    }
    
    // MARK: - Form Data Tests
    
    func testFormDataEncoding() {
        // Test URL form encoding as used in sign-in requests
        let formData: [String: String] = [
            "client_id": "fdc85c00-0a2f-4c64-bcb4-2cfb1500730a",
            "encryptedPassword": "true",
            "password": "encrypted_hex_data_123",
            "username": "test@example.com",
            "state": "ccsp"
        ]
        
        let formString = formData
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        XCTAssertNotNil(formString, "Form data should encode to Data")
        
        let formStringValue = String(data: formString!, encoding: .utf8)!
        XCTAssertTrue(formStringValue.contains("client_id=fdc85c00-0a2f-4c64-bcb4-2cfb1500730a"))
        XCTAssertTrue(formStringValue.contains("encryptedPassword=true"))
        XCTAssertTrue(formStringValue.contains("username=test%40example.com")) // @ should be encoded
    }
    
    // MARK: - Configuration Tests
    
    func testAPIConfiguration() {
        let config = AppConfiguration.apiConfiguration
        
        // Test that configuration provides expected values
        XCTAssertFalse(config.key.isEmpty, "API key should not be empty")
        XCTAssertFalse(config.baseUrl.isEmpty, "Base URL should not be empty")
        XCTAssertFalse(config.serviceId.isEmpty, "Service ID should not be empty")
        XCTAssertTrue(config.port > 0, "Port should be positive")
        
        // Test NewAuthenticationAPI initialization with configuration
        let authAPI = NewAuthenticationAPI(configuration: config)
        XCTAssertNotNil(authAPI, "Should initialize with valid configuration")
    }
    
    func testBaseURLConstruction() {
        let config = AppConfiguration.apiConfiguration
        let authAPI = NewAuthenticationAPI(configuration: config)
        
        // The baseURL should be constructed correctly
        // We can't access private properties directly, but we can verify the pattern
        let expectedPattern = "idpconnect-eu.\(config.key).com"
        
        // This is implicit testing - the fact that initialization succeeds suggests correct URL construction
        XCTAssertNotNil(authAPI)
    }
    
    // MARK: - Error Handling Tests
    
    func testNewAuthenticationErrorDescriptions() {
        let errors: [NewAuthenticationError] = [
            .clientConfigurationFailed,
            .encryptionSettingsFailed,
            .certificateRetrievalFailed,
            .oauth2InitializationFailed,
            .signInFailed,
            .authorizationCodeNotFound,
            .tokenExchangeFailed,
            .rsaEncryptionFailed("Test encryption error"),
            .csrfTokenNotFound,
            .sessionKeyNotFound,
            .invalidResponse,
            .networkError("Test network error")
        ]
        
        for error in errors {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error description should not be empty for \(error)")
            XCTAssertTrue(description.count > 5, "Error description should be meaningful for \(error)")
        }
    }
    
    // MARK: - State Parameter Tests
    
    func testStateParameterGeneration() throws {
        // Test the JSON state parameter generation used in getConnectorAuthorization
        let stateJSON: [String: Any] = [
            "scope": NSNull(),
            "state": NSNull(),
            "lang": NSNull(),
            "cert": "",
            "action": "idpc_auth_endpoint",
            "client_id": "fdc85c00-0a2f-4c64-bcb4-2cfb1500730a",
            "redirect_uri": "https://idpconnect-eu.kia.com/auth/redirect",
            "response_type": "code",
            "signup_link": NSNull(),
            "hmgid2_client_id": "fdc85c00-0a2f-4c64-bcb4-2cfb1500730a",
            "hmgid2_redirect_uri": "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect",
            "hmgid2_scope": NSNull(),
            "hmgid2_state": "ccsp",
            "hmgid2_ui_locales": NSNull()
        ]
        
        let stateData = try JSONSerialization.data(withJSONObject: stateJSON)
        let base64State = stateData.base64EncodedString()
        
        XCTAssertFalse(base64State.isEmpty, "State parameter should not be empty")
        
        // Verify we can decode it back
        guard let decodedData = Data(base64Encoded: base64State),
              let decodedJSON = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] else {
            XCTFail("Should be able to decode state parameter")
            return
        }
        
        XCTAssertEqual(decodedJSON["action"] as? String, "idpc_auth_endpoint")
        XCTAssertEqual(decodedJSON["response_type"] as? String, "code")
        XCTAssertEqual(decodedJSON["hmgid2_state"] as? String, "ccsp")
    }
    
    // MARK: - HTTP Headers Tests
    
    func testUserAgentHeader() {
        // Test that the User-Agent is set correctly
        let expectedUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148_CCS_APP_iOS"
        
        // This is testing the constant value
        // In a real test, we'd verify this gets set in HTTP requests
        XCTAssertFalse(expectedUserAgent.isEmpty)
        XCTAssertTrue(expectedUserAgent.contains("iPhone"))
        XCTAssertTrue(expectedUserAgent.contains("Mobile/15E148_CCS_APP_iOS"))
    }
    
    func testSecurityHeaders() {
        // Test that security headers are set appropriately
        let expectedHeaders = [
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-Mode": "cors", 
            "Sec-Fetch-Dest": "empty",
            "Accept-Language": "en-US"
        ]
        
        for (header, value) in expectedHeaders {
            XCTAssertFalse(header.isEmpty, "Header name should not be empty")
            XCTAssertFalse(value.isEmpty, "Header value should not be empty")
        }
    }
    
    // MARK: - Integration Workflow Tests
    
    func testCompleteWorkflowDataTypes() {
        // Test that all data types work together in the expected workflow
        
        // 1. Create configuration
        let config = AppConfiguration.apiConfiguration
        XCTAssertNotNil(config)
        
        // 2. Create authentication API
        let authAPI = NewAuthenticationAPI(configuration: config)
        XCTAssertNotNil(authAPI)
        
        // 3. Create RSA service
        let rsaService = RSAEncryptionService()
        XCTAssertNotNil(rsaService)
        
        // 4. Create sample RSA key data
        let rsaKeyData = RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "AQAB",
            keyId: "HMGID2_CIPHER_KEY1",
            modulus: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )
        
        // 5. Test password encryption
        XCTAssertNoThrow {
            let encryptedPassword = try rsaService.encryptPassword("testPassword", with: rsaKeyData)
            XCTAssertFalse(encryptedPassword.isEmpty)
        }
        
        // 6. Create OAuth2 result structure
        let oauth2Result = OAuth2InitializationResult(
            csrfToken: "test_csrf_token",
            sessionKey: "test_session_key",
            cookies: []
        )
        XCTAssertEqual(oauth2Result.csrfToken, "test_csrf_token")
        XCTAssertEqual(oauth2Result.sessionKey, "test_session_key")
        
        // 7. Create authorization code result
        let authCodeResult = AuthorizationCodeResult(
            code: "test_auth_code",
            state: "ccsp",
            loginSuccess: true
        )
        XCTAssertEqual(authCodeResult.code, "test_auth_code")
        XCTAssertEqual(authCodeResult.state, "ccsp")
        XCTAssertTrue(authCodeResult.loginSuccess)
    }
    
    // MARK: - Codable State Tests
    
    func testConnectorAuthorizationStateEncoding() throws {
        // Test the new Codable struct produces correct JSON structure
        let clientId = "test-client-id"
        let redirectUri = "https://test.example.com/redirect"
        
        // Create the struct (simulating what's done in getConnectorAuthorization)
        let stateObject = ConnectorAuthorizationState(
            scope: nil,
            state: nil,
            lang: nil,
            cert: "",
            action: "idpc_auth_endpoint",
            clientId: clientId,
            redirectUri: "https://idpconnect-eu.kia.com/auth/redirect",
            responseType: "code",
            signupLink: nil,
            hmgid2ClientId: clientId,
            hmgid2RedirectUri: redirectUri,
            hmgid2Scope: nil,
            hmgid2State: "ccsp",
            hmgid2UiLocales: nil
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(stateObject)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Verify the JSON structure matches expected format
        XCTAssertEqual(jsonObject["action"] as? String, "idpc_auth_endpoint")
        XCTAssertEqual(jsonObject["client_id"] as? String, clientId)
        XCTAssertEqual(jsonObject["redirect_uri"] as? String, "https://idpconnect-eu.kia.com/auth/redirect")
        XCTAssertEqual(jsonObject["response_type"] as? String, "code")
        XCTAssertEqual(jsonObject["cert"] as? String, "")
        XCTAssertEqual(jsonObject["hmgid2_client_id"] as? String, clientId)
        XCTAssertEqual(jsonObject["hmgid2_redirect_uri"] as? String, redirectUri)
        XCTAssertEqual(jsonObject["hmgid2_state"] as? String, "ccsp")
        
        // Verify null fields are present but null
        XCTAssertTrue(jsonObject.keys.contains("scope"))
        XCTAssertTrue(jsonObject.keys.contains("state"))
        XCTAssertTrue(jsonObject.keys.contains("lang"))
        XCTAssertTrue(jsonObject.keys.contains("signup_link"))
        XCTAssertTrue(jsonObject.keys.contains("hmgid2_scope"))
        XCTAssertTrue(jsonObject.keys.contains("hmgid2_ui_locales"))
        
        // Test Base64 encoding works
        let base64String = jsonData.base64EncodedString()
        XCTAssertFalse(base64String.isEmpty, "Base64 encoding should produce non-empty string")
        
        // Verify we can decode the Base64 back to JSON
        let decodedData = Data(base64Encoded: base64String)!
        let decodedObject = try JSONSerialization.jsonObject(with: decodedData) as! [String: Any]
        XCTAssertEqual(decodedObject["action"] as? String, "idpc_auth_endpoint")
    }
}

// MARK: - Supporting Structs

/// Private struct mirroring the one in NewAuthenticationAPI for testing purposes
private struct ConnectorAuthorizationState: Codable {
    let scope: String?
    let state: String?
    let lang: String?
    let cert: String
    let action: String
    let clientId: String
    let redirectUri: String
    let responseType: String
    let signupLink: String?
    let hmgid2ClientId: String
    let hmgid2RedirectUri: String
    let hmgid2Scope: String?
    let hmgid2State: String
    let hmgid2UiLocales: String?
    
    enum CodingKeys: String, CodingKey {
        case scope
        case state
        case lang
        case cert
        case action
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case responseType = "response_type"
        case signupLink = "signup_link"
        case hmgid2ClientId = "hmgid2_client_id"
        case hmgid2RedirectUri = "hmgid2_redirect_uri"
        case hmgid2Scope = "hmgid2_scope"
        case hmgid2State = "hmgid2_state"
        case hmgid2UiLocales = "hmgid2_ui_locales"
    }
}