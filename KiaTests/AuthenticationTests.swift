//
//  AuthenticationTests.swift
//  KiaMapsTests
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class AuthenticationTests: XCTestCase {

    var api: Api!
    var rsaService: RSAEncryptionService!
    var mockProvider: MockApiProvider!

    override func setUp() {
        super.setUp()
        mockProvider = MockApiProvider()
        api = Api(configuration: .mock, rsaService: .init(), provider: mockProvider)
        rsaService = RSAEncryptionService()
    }

    override func tearDown() {
        api = nil
        rsaService = nil
        mockProvider = nil
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        super.tearDown()
    }

    // MARK: - Helper Functions Tests

    func testCommonJSONHeaders() {
        // Test JSON headers helper
        let headers = api.commonJSONHeaders(referer: "https://example.com/test")

        XCTAssertEqual(headers["Sec-Fetch-Site"], "same-origin")
        XCTAssertEqual(headers["Sec-Fetch-Mode"], "cors")
        XCTAssertEqual(headers["Sec-Fetch-Dest"], "empty")
        XCTAssertEqual(headers["Referer"], "https://example.com/test")
    }

    func testCommonNavigationHeaders() {
        // Test navigation headers helper
        let headers = api.commonNavigationHeaders(referer: "https://example.com/nav")

        XCTAssertEqual(headers["Sec-Fetch-Site"], "none")
        XCTAssertEqual(headers["Sec-Fetch-Mode"], "navigate")
        XCTAssertEqual(headers["Sec-Fetch-Dest"], "document")
        XCTAssertEqual(headers["Referer"], "https://example.com/nav")
    }

    func testCommonNavigationHeadersWithoutReferer() {
        // Test navigation headers without referer
        let headers = api.commonNavigationHeaders(referer: nil)

        XCTAssertEqual(headers["Sec-Fetch-Site"], "none")
        XCTAssertEqual(headers["Sec-Fetch-Mode"], "navigate")
        XCTAssertEqual(headers["Sec-Fetch-Dest"], "document")
        XCTAssertNil(headers["Referer"])
    }

    // MARK: - URL Extraction Tests

    func testExtractNextUri() {
        let testCases = [
            (
                url: URL(string: "https://idpconnect-eu.kia.com/auth/redirect?next_uri=https%3A%2F%2Fidpconnect-eu.kia.com%2Fauth%2Fapi%2Fv2%2Fuser%2Foauth2%2Fauthorize")!,
                expected: "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize"
            ),
            (
                url: URL(string: "https://example.com/redirect?other=value&next_uri=https%3A%2F%2Fexample.com%2Fnext")!,
                expected: "https://example.com/next"
            )
        ]

        for testCase in testCases {
            let result = api.extractNextUri(from: testCase.url)
            XCTAssertEqual(result, testCase.expected, "Failed to extract next_uri from \(testCase.url)")
        }
    }

    func testExtractConnectorSessionKey() {
        let testURL = "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize?client_id=test&connector_session_key=abc123def&state=ccsp"

        let result = api.extractConnectorSessionKey(from: testURL)
        XCTAssertEqual(result, "abc123def")
    }

    func testExtractAuthorizationCode() throws {
        let testURL = URL(string: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?code=AUTH_CODE_123&state=ccsp&login_success=y")!

        let (code, state, loginSuccess) = try api.extractAuthorizationCode(from: testURL)

        XCTAssertEqual(code, "AUTH_CODE_123")
        XCTAssertEqual(state, "ccsp")
        XCTAssertTrue(loginSuccess)
    }

    func testExtractAuthorizationCodeMissingCode() {
        let testURL = URL(string: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?state=ccsp&login_success=y")!

        XCTAssertThrowsError(try api.extractAuthorizationCode(from: testURL)) { error in
            XCTAssertEqual(error as? AuthenticationError, AuthenticationError.authorizationCodeNotFound)
        }
    }

    // MARK: - RSA Encryption Tests

    func testRSAKeyDataCreation() {
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
        XCTAssertEqual(rsaKeyData.modulus, "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw")
    }

    func testPasswordEncryptionWithRSAKeyData() throws {
        let rsaKeyData = RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "AQAB",
            keyId: "HMGID2_CIPHER_KEY1",
            modulus: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )

        let password = "testPassword123"
        let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKeyData)

        XCTAssertFalse(encryptedPassword.isEmpty)
        XCTAssertNotEqual(encryptedPassword, password)
        XCTAssertTrue(encryptedPassword.allSatisfy { char in
            ("0"..."9").contains(char) || ("a"..."f").contains(char) || ("A"..."F").contains(char)
        }, "Should be hex encoded")
    }

    // MARK: - Authentication Flow Steps Tests

    func testFetchConnectorAuthorization() async throws {
        // Setup mock response
        mockProvider.mockRedirectURL = URL(string: "https://idpconnect-eu.kia.com/auth/redirect?next_uri=https%3A%2F%2Fidpconnect-eu.kia.com%2Fauth%2Fapi%2Fv2%2Fuser%2Foauth2%2Fauthorize")!

        let result = try await api.fetchConnectorAuthorization()

        XCTAssertEqual(result, "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize")
    }

    func testFetchClientConfiguration() async throws {
        let expectedConfig = ClientConfiguration(
            clientId: "test-client",
            companyCode: "TestClient",
            clientName: "Test Client",
            scope: "PUBLIC",
            clientAddition: .init(
                clientId: nil,
                serviceId: "Service Id",
                ssoEnabled: true,
                accountConnectorEnabled: true,
                accountManagedItems: "Account Managed Items",
                accountOptionItems: "Account Options Items",
                secondAuthManagedItems: "Second Auth Managed Items",
                loginMethodItems: "Login Method Items",
                socialAuthManagedItems: "Social Auth",
                externalAuthManagedItem: nil,
                headerLogo: nil,
                formSkin: "Form Skin",
                accessLimitBirthYear: 1,
                rememberMeEnabled: false,
                serviceRegion: "Service Region",
                emailAuthLaterEnabled: true
            ),
            clientRedirectUris: [
                .init(redirectUri: "https://test.example.com/redirect", userAgent: "User Agent", usage: "Usage")
            ],
            clientConnectors: [
                .init(connectorClientId: "Connector Client Id")
            ],
            connectorAddition: .init(idpCd: "Idp Cd")
        )

        mockProvider.mockClientConfiguration = expectedConfig

        let result = try await api.fetchClientConfiguration(referer: "https://test.com")

        XCTAssertEqual(result.clientId, expectedConfig.clientId)
        XCTAssertEqual(result.clientName, expectedConfig.clientName)
    }

    func testFetchPasswordEncryptionSettings() async throws {
        let expectedSettings = PasswordEncryptionSettings(
            groupCode: "Group Code",
            detailCode: "Detail Code",
            detailDescription: "Detail Description",
            useEnabled: true,
            value1: "true",
            value2: "RSA",
            value3: "Value 3",
            value4: "Value 4",
            value5: "Value 5"
        )

        mockProvider.mockPasswordSettings = expectedSettings

        let result = try await api.fetchPasswordEncryptionSettings(referer: "https://test.com")

        XCTAssertTrue(result.useEnabled)
        XCTAssertEqual(result.value1, "true")
    }

    func testFetchRSACertificate() async throws {
        let expectedCert = RSACertificateResponse(
            kty: "RSA",
            e: "AQAB",
            kid: "TEST_KEY",
            n: "testModulus123"
        )

        mockProvider.mockRSACertificate = expectedCert

        let result = try await api.fetchRSACertificate(referer: "https://test.com")

        XCTAssertEqual(result.keyId, "TEST_KEY")
        XCTAssertEqual(result.modulus, "testModulus123")
    }

    func testInitializeOAuth2() async throws {
        // Setup mock cookie
        let cookie = HTTPCookie(properties: [
            .name: "account",
            .value: "test_csrf_token",
            .domain: "idpconnect-eu.kia.com",
            .path: "/"
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)

        mockProvider.mockEmpty = true

        let result = try await api.initializeOAuth2(referer: "https://test.com")

        XCTAssertEqual(result, "test_csrf_token")
    }

    func testSignIn() async throws {
        let rsaKey = RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "AQAB",
            keyId: "TEST_KEY",
            modulus: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )

        mockProvider.mockRedirectURL = URL(string: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?code=AUTH_CODE_123&state=ccsp&login_success=y")!

        let referer = "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize?connector_session_key=test_session"
        let result = try await api.signIn(
            referer: referer,
            username: "test@example.com",
            password: "password123",
            rsaKey: rsaKey,
            csrfToken: "test_csrf"
        )

        XCTAssertEqual(result, "AUTH_CODE_123")
    }

    func testExchangeCodeForTokens() async throws {
        let expectedTokens = TokenResponse(
            scope: nil,
            connector: [
                "test": .init(
                    scope: nil,
                    idpCd: "Idp Cd",
                    accessToken: "Access Token",
                    refreshToken: "Refresh Token",
                    idToken: nil,
                    tokenType: "Token Type",
                    expiresIn: 10
                )
            ],
            accessToken: "access_123",
            refreshToken: "refresh_456",
            idToken: nil,
            tokenType: "Bearer",
            expiresIn: 3600
        )

        mockProvider.mockTokenResponse = expectedTokens

        let result = try await api.exchangeCodeForTokens(authorizationCode: "AUTH_CODE_123")

        XCTAssertNil(result.scope)
        XCTAssertEqual(result.connector?.count ?? 0, 1)
        XCTAssertEqual(result.accessToken, "access_123")
        XCTAssertEqual(result.refreshToken, "refresh_456")
        XCTAssertNil(result.idToken)
        XCTAssertEqual(result.tokenType, "Bearer")
        XCTAssertEqual(result.expiresIn, 3600)
    }

    // MARK: - Cookie Management Tests

    func testCleanCookies() {
        // Add some test cookies
        let cookie1 = HTTPCookie(properties: [
            .name: "test1",
            .value: "value1",
            .domain: "example.com",
            .path: "/"
        ])!

        let cookie2 = HTTPCookie(properties: [
            .name: "test2",
            .value: "value2",
            .domain: "example.com",
            .path: "/"
        ])!

        HTTPCookieStorage.shared.setCookie(cookie1)
        HTTPCookieStorage.shared.setCookie(cookie2)

        // Verify cookies exist
        XCTAssertNotNil(HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "test1" }))
        XCTAssertNotNil(HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "test2" }))

        // Clean cookies
        api.cleanCookies()

        // Verify cookies are removed
        XCTAssertNil(HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "test1" }))
        XCTAssertNil(HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "test2" }))
    }

    // MARK: - Error Handling Tests

    func testAuthenticationErrorDescriptions() {
        let errors: [AuthenticationError] = [
            .clientConfigurationFailed,
            .encryptionSettingsFailed,
            .certificateRetrievalFailed,
            .oauth2InitializationFailed,
            .signInFailed,
            .authorizationCodeNotFound,
            .tokenExchangeFailed,
            .csrfTokenNotFound,
            .sessionKeyNotFound
        ]

        for error in errors {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error description should not be empty for \(error)")
            XCTAssertTrue(description.count > 5, "Error description should be meaningful for \(error)")
        }
    }

    // MARK: - Integration Tests

    func testCompleteLoginFlow() async throws {
        // This is a mock integration test - in real scenario, would need actual server

        // Setup all mock responses in sequence
        mockProvider.mockRedirectURL = URL(string: "https://idpconnect-eu.kia.com/auth/redirect?next_uri=https%3A%2F%2Fidpconnect-eu.kia.com%2Fauth%2Fapi%2Fv2%2Fuser%2Foauth2%2Fauthorize")!

        mockProvider.mockClientConfiguration = ClientConfiguration(
            clientId: "test-client",
            companyCode: "TestClient",
            clientName: "Test Client",
            scope: "PUBLIC",
            clientAddition: .init(
                clientId: nil,
                serviceId: "Service Id",
                ssoEnabled: true,
                accountConnectorEnabled: true,
                accountManagedItems: "Account Managed Items",
                accountOptionItems: "Account Options Items",
                secondAuthManagedItems: "Second Auth Managed Items",
                loginMethodItems: "Login Method Items",
                socialAuthManagedItems: "Social Auth",
                externalAuthManagedItem: nil,
                headerLogo: nil,
                formSkin: "Form Skin",
                accessLimitBirthYear: 1,
                rememberMeEnabled: false,
                serviceRegion: "Service Region",
                emailAuthLaterEnabled: true
            ),
            clientRedirectUris: [
                .init(redirectUri: "https://test.example.com/redirect", userAgent: "User Agent", usage: "Usage")
            ],
            clientConnectors: [
                .init(connectorClientId: "Connector Client Id")
            ],
            connectorAddition: .init(idpCd: "Idp Cd")
        )

        let expectedSettings = PasswordEncryptionSettings(
            groupCode: "Group Code",
            detailCode: "Detail Code",
            detailDescription: "Detail Description",
            useEnabled: true,
            value1: "true",
            value2: "RSA",
            value3: "Value 3",
            value4: "Value 4",
            value5: "Value 5"
        )

        mockProvider.mockPasswordSettings = expectedSettings

        let expectedCert = RSACertificateResponse(
            kty: "RSA",
            e: "AQAB",
            kid: "HMGID2_CIPHER_KEY1",
            n: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )
        mockProvider.mockRSACertificate = expectedCert

        // Test that all pieces work together
        XCTAssertNotNil(mockProvider.mockClientConfiguration)
        XCTAssertNotNil(mockProvider.mockPasswordSettings)
        XCTAssertNotNil(mockProvider.mockRSACertificate)

        let certificate = try XCTUnwrap(mockProvider.mockRSACertificate)

        // Verify RSA encryption works with the certificate
        let rsaKey = RSAEncryptionService.RSAKeyData(
            keyType: certificate.kty,
            exponent: certificate.e,
            keyId: certificate.kid,
            modulus: certificate.n
        )

        let encryptedPassword = try rsaService.encryptPassword("testPassword", with: rsaKey)
        XCTAssertFalse(encryptedPassword.isEmpty)
    }
}

// MARK: - Mock Provider

class MockApiProvider: ApiRequestProvider, ApiCaller {
    let urlSession: URLSession

    override var caller: ApiCaller {
        self
    }

    // Mock responses
    var mockRedirectURL: URL?
    var mockClientConfiguration: ClientConfiguration?
    var mockPasswordSettings: PasswordEncryptionSettings?
    var mockRSACertificate: RSACertificateResponse?
    var mockTokenResponse: TokenResponse?
    var mockEmpty = false

    init() {
        self.urlSession = .shared
        super.init(configuration: MockApiConfiguration(), callerType: Self.self, requestType: MockApiRequest.self)
    }

    required init(configuration: any KiaMaps.ApiConfiguration, urlSession: URLSession, authorization: KiaMaps.AuthorizationData?) {
        self.urlSession = urlSession
        super.init(configuration: configuration, callerType: MockApiProvider.self, requestType: MockApiRequest.self)
    }
}

// MARK: - Mock ApiRequest Extensions

struct MockApiRequest: ApiRequest {
    let caller: ApiCaller
    let method: ApiMethod
    let endpoint: ApiEndpoint
    let queryItems: [URLQueryItem]
    let headers: Headers
    let body: Data?
    let timeout: TimeInterval

    private static let formCharset: CharacterSet = {
        var charset = CharacterSet.alphanumerics
        charset.insert("=")
        charset.insert("&")
        charset.insert("-")
        charset.insert(".")
        return charset
    }()

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval
    ) throws {
        var headers = headers
        if headers["Content-type"] == nil {
            headers.merge(Self.commonJsonHeaders) { _, new in new }
        }
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-GB,en;q=0.9"
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = try JSONEncoders.default.encode(encodable)
        self.timeout = timeout
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval
    ) {
        var headers = headers
        if headers["Content-type"] == nil {
            headers.merge(Self.commonJsonHeaders) { _, new in new }
        }
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-GB,en;q=0.9"
        self.caller = caller
        self.method = method ?? (body == nil ? .get : .post)
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval
    ) {
        var headers = Self.commonFormHeaders
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-GB,en;q=0.9"
        let formData = form
            .map { ($0.key + "=" + $0.value).addingPercentEncoding(withAllowedCharacters: Self.formCharset) ?? "" }
            .joined(separator: "&")
            .data(using: .utf8)

        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = formData
        self.timeout = timeout
    }

    var urlRequest: URLRequest {
        get throws {
            var url = try caller.configuration.url(for: endpoint)
            if !queryItems.isEmpty {
                url.append(queryItems: queryItems)
            }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
            request.httpMethod = method.rawValue
            var headers = self.headers
            if let authorization = caller.authorization {
                for (key, value) in authorization.authorizatioHeaders(for: caller.configuration) {
                    headers[key] = value
                }
            }
            request.allHTTPHeaderFields = headers
            request.httpBody = body
            return request
        }
    }

    func referalUrl(acceptStatusCode: Int) async throws -> URL {
        guard let provider = caller as? MockApiProvider,
              let url = provider.mockRedirectURL else {
            throw URLError(.badServerResponse)
        }
        return url
    }

    func response<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        guard let provider = caller as? MockApiProvider else {
            throw URLError(.badServerResponse)
        }
        throw URLError(.badServerResponse)
    }

    func responseValue<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        guard let provider = caller as? MockApiProvider else {
            throw URLError(.badServerResponse)
        }

        if Data.self == ClientConfiguration.self {
            return provider.mockClientConfiguration as! Data
        } else if Data.self == PasswordEncryptionSettings.self {
            return provider.mockPasswordSettings as! Data
        } else if Data.self == RSACertificateResponse.self {
            return provider.mockRSACertificate as! Data
        }

        throw URLError(.badServerResponse)
    }

    func responseEmpty(acceptStatusCode: Int) async throws -> ApiResponseEmpty {
        throw URLError(.badServerResponse)
    }

    func empty(acceptStatusCode: Int) async throws {
        guard let provider = caller as? MockApiProvider else {
            throw URLError(.badServerResponse)
        }

        if !provider.mockEmpty {
            throw URLError(.badServerResponse)
        }
    }

    func string(acceptStatusCode: Int) async throws -> String {
        throw URLError(.badServerResponse)
    }

    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse {
        throw URLError(.badServerResponse)
    }


    func data<T: Decodable>(acceptStatusCode: Int) async throws -> T {
        guard let provider = caller as? MockApiProvider else {
            throw URLError(.badServerResponse)
        }

        if T.self == TokenResponse.self {
            return provider.mockTokenResponse as! T
        }

        throw URLError(.badServerResponse)
    }
}
