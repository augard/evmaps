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

    func testWebLoginURLBuildsAuthorizeRequest() throws {
        let url = try XCTUnwrap(api.webLoginUrl())
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.host, "idpconnect-mock.test.com")
        XCTAssertEqual(url.path, "/auth/api/v2/user/oauth2/authorize")
        XCTAssertEqual(items["client_id"], mockProvider.configuration.serviceId)
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["state"], "ccsp")
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
    func testMockCertificateStillEncryptsPassword() throws {
        let certificate = RSACertificateResponse(
            kty: "RSA",
            e: "AQAB",
            kid: "HMGID2_CIPHER_KEY1",
            n: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        )

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
    let endpoint: any ApiEndpointProtocol
    let queryItems: [URLQueryItem]
    let headers: Headers
    let body: Data?
    let timeout: TimeInterval
    let authorization: Bool

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
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval,
        authorization: Bool
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
        self.authorization = authorization
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval,
        authorization: Bool
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
        self.authorization = authorization
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval,
        authorization: Bool
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
        self.authorization = authorization
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
            if let authorization = caller.authorization, self.authorization {
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

    func referalUrl(acceptStatusCodes _: Set<Int>) async throws -> URL {
        try await referalUrl(acceptStatusCode: 302)
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

    func string(acceptStatusCodes _: Set<Int>) async throws -> String {
        throw URLError(.badServerResponse)
    }

    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse {
        throw URLError(.badServerResponse)
    }

    func httpResponse(acceptStatusCodes _: Set<Int>) async throws -> HTTPURLResponse {
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

    func data<T: Decodable>(acceptStatusCodes _: Set<Int>) async throws -> T {
        try await data(acceptStatusCode: 200)
    }

    func rawData(acceptStatusCodes _: Set<Int>) async throws -> Data {
        throw URLError(.badServerResponse)
    }
}
