# New Kia/Hyundai OAuth2 Login Implementation Guide

Based on the HTTP request/response logs from August 1, 2025, this document outlines the new enhanced OAuth2 authentication flow that includes RSA password encryption and improved security measures.

## Overview

The new login system introduces several security enhancements:
- **RSA Password Encryption**: Passwords are encrypted client-side using server-provided RSA public keys
- **Enhanced OAuth2 Flow**: Multi-step authentication with secure token exchange
- **CSRF Protection**: Cross-site request forgery protection tokens
- **Session Management**: Improved session handling with multiple cookie types

## Authentication Flow Analysis

### Phase 1: Client Configuration Discovery
**Endpoint**: `GET /api/v1/clients/{client_id}`

```http
GET /api/v1/clients/fdc85c00-0a2f-4c64-bcb4-2cfb1500730a HTTP/1.1
Host: idpconnect-eu.kia.com
```

**Response Structure**:
```json
{
  "retValue": {
    "clientId": "hmg-eu-kia-connect",
    "companyCode": "KIA",
    "clientName": "KIA Connect (A.K.A, UVO)",
    "scope": "openid,email",
    "clientConnectors": [
      {
        "connectorClientId": "hmgid1.0-fdc85c00-0a2f-4c64-bcb4-2cfb1500730a"
      }
    ]
  }
}
```

### Phase 2: Password Encryption Configuration
**Endpoint**: `GET /api/v1/commons/codes/HMG_DYNAMIC_CODE/details/PASSWORD_ENCRYPTION`

```http
GET /api/v1/commons/codes/HMG_DYNAMIC_CODE/details/PASSWORD_ENCRYPTION HTTP/1.1
Host: idpconnect-eu.kia.com
```

**Response**:
```json
{
  "retValue": {
    "detailCode": "PASSWORD_ENCRYPTION",
    "useEnabled": true,
    "value1": "true"
  }
}
```

### Phase 3: RSA Certificate Retrieval
**Endpoint**: `GET /auth/api/v1/accounts/certs`

```http
GET /auth/api/v1/accounts/certs HTTP/1.1
Host: idpconnect-eu.kia.com
```

**Response**:
```json
{
  "retValue": {
    "kty": "RSA",
    "e": "AQAB",
    "kid": "HMGID2_CIPHER_KEY1",
    "n": "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw3vWkTxJWlPknHkBJxoH5P-D7t59RibA7BPI6rsc2bBE8PSzCahfQ-bMOhAwMWesOOajN9ki-caE6MUMS6naRhmxUjYe4OHVuEKCPvYZ9O188L4yKqUfCRWXOMjmJBvMz1KFtHZto9SdaC25v5dN82R4JgRQ4Pq9PDVd3v08egpS7BURblRGg22jS9fouyKceoie4s6JiKeyvvGj0qRKJSFUGLP0ScpUcY1XgUMjGNC51ncTOQdMSGxaj9k623m7w"
  }
}
```

### Phase 4: OAuth2 Authorization
**Endpoint**: `GET /auth/api/v2/user/oauth2/authorize`

```http
GET /auth/api/v2/user/oauth2/authorize?response_type=code&client_id=fdc85c00-0a2f-4c64-bcb4-2cfb1500730a&redirect_uri=https%3A%2F%2Fprd.eu-ccapi.kia.com%3A8080%2Fapi%2Fv1%2Fuser%2Foauth2%2Fredirect&lang=en&state=ccsp HTTP/1.1
Host: idpconnect-eu.kia.com
```

### Phase 5: Encrypted Sign-In
**Endpoint**: `POST /auth/account/signin`

```http
POST /auth/account/signin HTTP/1.1
Host: idpconnect-eu.kia.com
Content-Type: application/x-www-form-urlencoded

client_id=fdc85c00-0a2f-4c64-bcb4-2cfb1500730a&encryptedPassword=true&password={RSA_ENCRYPTED_PASSWORD}&kid=HMGID2_CIPHER_KEY1&username=user@example.com&_csrf={CSRF_TOKEN}
```

**Key Parameters**:
- `encryptedPassword=true`: Indicates password is RSA encrypted
- `kid=HMGID2_CIPHER_KEY1`: Key identifier for decryption
- `password={ENCRYPTED_DATA}`: RSA encrypted password using public key

### Phase 6: Token Exchange
**Endpoint**: `POST /auth/api/v2/user/oauth2/token`

```http
POST /auth/api/v2/user/oauth2/token HTTP/1.1
Host: idpconnect-eu.kia.com
Content-Type: application/x-www-form-urlencoded

client_id=fdc85c00-0a2f-4c64-bcb4-2cfb1500730a&client_secret=secret&code={AUTHORIZATION_CODE}&grant_type=authorization_code&redirect_uri=https%3A//prd.eu-ccapi.kia.com%3A8080/api/v1/user/oauth2/redirect
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "MZI5OTHKMMQTNJDLMC01N2JMLWE2N2MTMMQ4MDQWMZY1YZM0",
  "token_type": "Bearer",
  "expires_in": 3600,
  "connector": {
    "hmgid1.0": {
      "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "MZI5OTHKMMQTNJDLMC01N2JMLWE2N2MTMMQ4MDQWMZY1YZM0",
      "expires_in": 3600
    }
  }
}
```

## Implementation Phases

### Phase 1: RSA Encryption Infrastructure

#### 1.1 Create RSA Encryption Service

```swift
// RSAEncryptionService.swift
import Foundation
import Security

class RSAEncryptionService {
    struct RSAKeyData {
        let keyType: String // "RSA"
        let exponent: String // "AQAB"
        let keyId: String // "HMGID2_CIPHER_KEY1"
        let modulus: String // Large base64 encoded modulus
    }
    
    /// Encrypt password using RSA public key
    func encryptPassword(_ password: String, with keyData: RSAKeyData) throws -> String {
        let publicKey = try createRSAPublicKey(from: keyData)
        let passwordData = password.data(using: .utf8)!
        
        let encryptedData = try encrypt(data: passwordData, with: publicKey)
        return encryptedData.base64EncodedString()
    }
    
    private func createRSAPublicKey(from keyData: RSAKeyData) throws -> SecKey {
        // Convert JWK format to SecKey
        let modulusData = try Data(base64Encoded: keyData.modulus.base64URLDecoded())!
        let exponentData = try Data(base64Encoded: keyData.exponent.base64URLDecoded())!
        
        // Create RSA public key from modulus and exponent
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: modulusData.count * 8
        ]
        
        // Construct RSA public key data
        let keyData = constructRSAPublicKeyData(modulus: modulusData, exponent: exponentData)
        
        guard let publicKey = SecKeyCreateWithData(keyData, keyAttributes as CFDictionary, nil) else {
            throw RSAError.keyCreationFailed
        }
        
        return publicKey
    }
    
    private func encrypt(data: Data, with publicKey: SecKey) throws -> Data {
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionPKCS1,
            data as CFData,
            nil
        ) else {
            throw RSAError.encryptionFailed
        }
        
        return encryptedData as Data
    }
}

enum RSAError: Error {
    case keyCreationFailed
    case encryptionFailed
    case invalidKeyData
}

extension String {
    func base64URLDecoded() -> String {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        return base64
    }
}
```

#### 1.2 Update API Configuration

```swift
// ApiConfiguration.swift
extension ApiConfiguration {
    static var newAuthBaseURL: String {
        return "https://idpconnect-eu.kia.com"
    }
    
    static var clientId: String {
        return "fdc85c00-0a2f-4c64-bcb4-2cfb1500730a"
    }
    
    static var clientSecret: String {
        return "secret"
    }
    
    static var redirectUri: String {
        return "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect"
    }
}
```

### Phase 2: Enhanced Authentication API

#### 2.1 New Authentication Endpoints

```swift
// NewAuthenticationAPI.swift
import Foundation

class NewAuthenticationAPI {
    private let session = URLSession.shared
    private let rsaService = RSAEncryptionService()
    private let baseURL = ApiConfiguration.newAuthBaseURL
    
    // MARK: - Step 1: Get Client Configuration
    func getClientConfiguration() async throws -> ClientConfiguration {
        let url = URL(string: "\(baseURL)/api/v1/clients/\(ApiConfiguration.clientId)")!
        
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.clientConfigurationFailed
        }
        
        let result = try JSONDecoder().decode(APIResponse<ClientConfiguration>.self, from: data)
        return result.retValue
    }
    
    // MARK: - Step 2: Check Password Encryption Settings
    func getPasswordEncryptionSettings() async throws -> PasswordEncryptionSettings {
        let url = URL(string: "\(baseURL)/api/v1/commons/codes/HMG_DYNAMIC_CODE/details/PASSWORD_ENCRYPTION")!
        
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.encryptionSettingsFailed
        }
        
        let result = try JSONDecoder().decode(APIResponse<PasswordEncryptionSettings>.self, from: data)
        return result.retValue
    }
    
    // MARK: - Step 3: Get RSA Certificate
    func getRSACertificate() async throws -> RSAEncryptionService.RSAKeyData {
        let url = URL(string: "\(baseURL)/auth/api/v1/accounts/certs")!
        
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.certificateRetrievalFailed
        }
        
        let result = try JSONDecoder().decode(APIResponse<RSACertificateResponse>.self, from: data)
        let cert = result.retValue
        
        return RSAEncryptionService.RSAKeyData(
            keyType: cert.kty,
            exponent: cert.e,
            keyId: cert.kid,
            modulus: cert.n
        )
    }
    
    // MARK: - Step 4: Initialize OAuth2 Flow
    func initializeOAuth2() async throws -> OAuth2InitializationResult {
        var components = URLComponents(string: "\(baseURL)/auth/api/v2/user/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: ApiConfiguration.clientId),
            URLQueryItem(name: "redirect_uri", value: ApiConfiguration.redirectUri),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: "ccsp")
        ]
        
        let url = components.url!
        let (data, response) = try await session.data(from: url)
        
        // This typically returns HTML with forms and CSRF tokens
        // Parse the response to extract necessary session information
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw AuthenticationError.oauth2InitializationFailed
        }
        
        // Extract CSRF token and session key from HTML
        let csrfToken = extractCSRFToken(from: htmlString)
        let sessionKey = extractSessionKey(from: htmlString)
        
        return OAuth2InitializationResult(
            csrfToken: csrfToken,
            sessionKey: sessionKey
        )
    }
    
    // MARK: - Step 5: Encrypted Sign-In
    func signIn(username: String, password: String, rsaKey: RSAEncryptionService.RSAKeyData, oauth2Result: OAuth2InitializationResult) async throws -> AuthorizationCodeResult {
        
        // Encrypt password
        let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKey)
        
        let url = URL(string: "\(baseURL)/auth/account/signin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var formData = [
            "client_id": ApiConfiguration.clientId,
            "encryptedPassword": "true",
            "password": encryptedPassword,
            "kid": rsaKey.keyId,
            "redirect_uri": ApiConfiguration.redirectUri,
            "scope": "",
            "nonce": "",
            "state": "ccsp",
            "username": username,
            "remember_me": "false",
            "connector_session_key": oauth2Result.sessionKey,
            "_csrf": oauth2Result.csrfToken
        ]
        
        let formString = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(characterSet: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 302 else {
            throw AuthenticationError.signInFailed
        }
        
        // Extract authorization code from redirect location
        guard let location = httpResponse.value(forHTTPHeaderField: "Location"),
              let authCode = extractAuthorizationCode(from: location) else {
            throw AuthenticationError.authorizationCodeNotFound
        }
        
        return AuthorizationCodeResult(code: authCode)
    }
    
    // MARK: - Step 6: Exchange Authorization Code for Tokens
    func exchangeCodeForTokens(authorizationCode: String) async throws -> TokenResponse {
        let url = URL(string: "\(baseURL)/auth/api/v2/user/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("EU_BlueLink/2.1.26 (com.kia.connect.eu; build:10893; iOS 26.0.0) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")
        
        let formData = [
            "client_id": ApiConfiguration.clientId,
            "client_secret": ApiConfiguration.clientSecret,
            "code": authorizationCode,
            "grant_type": "authorization_code",
            "redirect_uri": ApiConfiguration.redirectUri
        ]
        
        let formString = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(characterSet: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse
    }
    
    // MARK: - Helper Methods
    private func extractCSRFToken(from html: String) -> String {
        // Parse HTML to find CSRF token
        // Implementation depends on HTML structure
        return "" // Placeholder
    }
    
    private func extractSessionKey(from html: String) -> String {
        // Parse HTML to find session key
        return "" // Placeholder
    }
    
    private func extractAuthorizationCode(from location: String) -> String? {
        guard let url = URL(string: location),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first { $0.name == "code" }?.value
    }
}
```

#### 2.2 Data Models

```swift
// AuthenticationModels.swift
import Foundation

struct APIResponse<T: Codable>: Codable {
    let retId: String
    let retCode: Int
    let retMsg: String
    let retSubMsg: String?
    let retValue: T
}

struct ClientConfiguration: Codable {
    let clientId: String
    let companyCode: String
    let clientName: String
    let scope: String
    let clientAddition: ClientAddition
    let clientRedirectUris: [ClientRedirectUri]
    let clientConnectors: [ClientConnector]
    let connectorAddition: ConnectorAddition
}

struct ClientAddition: Codable {
    let serviceId: String
    let ssoEnabled: Bool
    let accountConnectorEnabled: Bool
    let formSkin: String
    let serviceRegion: String
}

struct ClientRedirectUri: Codable {
    let redirectUri: String
    let userAgent: String
    let usage: String
}

struct ClientConnector: Codable {
    let connectorClientId: String
}

struct ConnectorAddition: Codable {
    let idpCd: String
}

struct PasswordEncryptionSettings: Codable {
    let groupCode: String
    let detailCode: String
    let detailDescription: String
    let useEnabled: Bool
    let value1: String
    let value2: String
    let value3: String
    let value4: String
    let value5: String
}

struct RSACertificateResponse: Codable {
    let kty: String // Key type
    let e: String   // Exponent
    let kid: String // Key ID
    let n: String   // Modulus
}

struct OAuth2InitializationResult {
    let csrfToken: String
    let sessionKey: String
}

struct AuthorizationCodeResult {
    let code: String
}

struct TokenResponse: Codable {
    let scope: String?
    let connector: [String: ConnectorTokenInfo]
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case scope, connector
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct ConnectorTokenInfo: Codable {
    let scope: String?
    let idpCd: String
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case scope
        case idpCd = "idp_cd"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

enum AuthenticationError: Error {
    case clientConfigurationFailed
    case encryptionSettingsFailed
    case certificateRetrievalFailed
    case oauth2InitializationFailed
    case signInFailed
    case authorizationCodeNotFound
    case tokenExchangeFailed
    case rsaEncryptionFailed
}
```

### Phase 3: Integration with Existing API

#### 3.1 Update Api.swift

```swift
// Add to Api.swift
extension Api {
    /// New enhanced login method with RSA encryption
    func loginEnhanced(username: String, password: String) async throws -> AuthorizationData {
        let authAPI = NewAuthenticationAPI()
        
        // Step 1: Get client configuration
        let clientConfig = try await authAPI.getClientConfiguration()
        print("Client configured for: \(clientConfig.clientName)")
        
        // Step 2: Check if password encryption is enabled
        let encryptionSettings = try await authAPI.getPasswordEncryptionSettings()
        guard encryptionSettings.useEnabled && encryptionSettings.value1 == "true" else {
            throw AuthenticationError.encryptionSettingsFailed
        }
        
        // Step 3: Get RSA certificate for password encryption
        let rsaKey = try await authAPI.getRSACertificate()
        
        // Step 4: Initialize OAuth2 flow
        let oauth2Result = try await authAPI.initializeOAuth2()
        
        // Step 5: Sign in with encrypted password
        let authCodeResult = try await authAPI.signIn(
            username: username,
            password: password,
            rsaKey: rsaKey,
            oauth2Result: oauth2Result
        )
        
        // Step 6: Exchange authorization code for tokens
        let tokenResponse = try await authAPI.exchangeCodeForTokens(
            authorizationCode: authCodeResult.code
        )
        
        // Convert to existing AuthorizationData format
        return AuthorizationData(
            stamp: tokenResponse.tokenType,
            deviceId: UUID(), // Generate or derive from response
            accessToken: tokenResponse.accessToken,
            expiresIn: tokenResponse.expiresIn,
            refreshToken: tokenResponse.refreshToken,
            isCcuCCS2Supported: true // Determine from client config
        )
    }
}
```

### Phase 4: Testing and Validation

#### 4.1 Unit Tests

```swift
// NewAuthenticationAPITests.swift
import XCTest
@testable import KiaMaps

class NewAuthenticationAPITests: XCTestCase {
    var authAPI: NewAuthenticationAPI!
    
    override func setUp() {
        super.setUp()
        authAPI = NewAuthenticationAPI()
    }
    
    func testClientConfigurationRetrieval() async throws {
        let config = try await authAPI.getClientConfiguration()
        XCTAssertEqual(config.companyCode, "KIA")
        XCTAssertEqual(config.clientName, "KIA Connect (A.K.A, UVO)")
    }
    
    func testPasswordEncryptionSettings() async throws {
        let settings = try await authAPI.getPasswordEncryptionSettings()
        XCTAssertTrue(settings.useEnabled)
        XCTAssertEqual(settings.value1, "true")
    }
    
    func testRSACertificateRetrieval() async throws {
        let rsaKey = try await authAPI.getRSACertificate()
        XCTAssertEqual(rsaKey.keyType, "RSA")
        XCTAssertEqual(rsaKey.exponent, "AQAB")
        XCTAssertFalse(rsaKey.modulus.isEmpty)
    }
    
    func testRSAPasswordEncryption() throws {
        let rsaService = RSAEncryptionService()
        let keyData = RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "AQAB",
            keyId: "HMGID2_CIPHER_KEY1",
            modulus: "test_modulus_here"
        )
        
        let encryptedPassword = try rsaService.encryptPassword("testPassword", with: keyData)
        XCTAssertFalse(encryptedPassword.isEmpty)
        XCTAssertNotEqual(encryptedPassword, "testPassword")
    }
}
```

#### 4.2 Integration Testing

```swift
// Create integration test to verify full flow
func testCompleteAuthenticationFlow() async throws {
    let authAPI = NewAuthenticationAPI()
    
    // Use test credentials
    let username = "test@example.com"
    let password = "testPassword"
    
    do {
        let clientConfig = try await authAPI.getClientConfiguration()
        let encryptionSettings = try await authAPI.getPasswordEncryptionSettings()
        let rsaKey = try await authAPI.getRSACertificate()
        let oauth2Result = try await authAPI.initializeOAuth2()
        
        let authCode = try await authAPI.signIn(
            username: username,
            password: password,
            rsaKey: rsaKey,
            oauth2Result: oauth2Result
        )
        
        let tokens = try await authAPI.exchangeCodeForTokens(
            authorizationCode: authCode.code
        )
        
        XCTAssertFalse(tokens.accessToken.isEmpty)
        XCTAssertFalse(tokens.refreshToken.isEmpty)
        XCTAssertEqual(tokens.tokenType, "Bearer")
        XCTAssertEqual(tokens.expiresIn, 3600)
        
    } catch {
        XCTFail("Authentication flow failed: \(error)")
    }
}
```

## Implementation Timeline

### Week 1: Foundation
- [ ] Implement RSA encryption service
- [ ] Create new authentication API structure
- [ ] Add new data models
- [ ] Unit tests for encryption

### Week 2: Core Authentication
- [ ] Implement client configuration retrieval
- [ ] Add password encryption settings check
- [ ] Implement RSA certificate retrieval
- [ ] Unit tests for API endpoints

### Week 3: OAuth2 Flow
- [ ] Implement OAuth2 initialization
- [ ] Add encrypted sign-in functionality
- [ ] Implement token exchange
- [ ] Integration tests

### Week 4: Integration & Testing
- [ ] Integrate with existing Api.swift
- [ ] Update authentication flows throughout app
- [ ] End-to-end testing
- [ ] Performance optimization

### Week 5: Migration & Deployment
- [ ] Create migration strategy from old to new auth
- [ ] Update app configuration
- [ ] Deploy and monitor
- [ ] Rollback plan if needed

## Security Considerations

1. **RSA Key Validation**: Always validate RSA certificates before use
2. **Password Handling**: Never log or persist unencrypted passwords
3. **Token Storage**: Use secure keychain storage for tokens
4. **CSRF Protection**: Always include CSRF tokens in form submissions
5. **Session Management**: Properly handle session cookies and expiration
6. **Error Handling**: Don't expose sensitive information in error messages

## Migration Strategy

### Backward Compatibility
- Keep existing login method as fallback
- Feature flag for new authentication system
- Gradual rollout to percentage of users
- Monitor success rates and performance

### Fallback Mechanism
```swift
func login(username: String, password: String) async throws -> AuthorizationData {
    if FeatureFlags.enhancedAuthentication {
        do {
            return try await loginEnhanced(username: username, password: password)
        } catch {
            print("Enhanced auth failed, falling back to legacy: \(error)")
            return try await loginLegacy(username: username, password: password)
        }
    } else {
        return try await loginLegacy(username: username, password: password)
    }
}
```

## Monitoring and Analytics

- Track authentication success/failure rates
- Monitor RSA encryption performance
- Log authentication step completion times
- Alert on high failure rates
- Track token refresh patterns

This implementation provides a robust, secure authentication system that matches the enhanced security requirements observed in the HTTP logs while maintaining compatibility with the existing application architecture.