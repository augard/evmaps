//
//  HMGClientTests.swift
//  KiaTests
//
//  Created by Codex on 09.03.2026.
//

import XCTest
@testable import KiaMaps

final class HMGAuthClientTests: XCTestCase {
    func testMakeAuthorizeURLUsesHMGAuthorizeEndpointAndQuery() throws {
        let provider = MockApiProvider()
        let client = HMGAuthClient(configuration: MockApiConfiguration(), provider: provider, rsaService: .init())

        let url = try XCTUnwrap(client.makeAuthorizeURL())
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.host, "idpconnect-mock.test.com")
        XCTAssertEqual(url.path, "/auth/api/v2/user/oauth2/authorize")
        XCTAssertEqual(items["client_id"], "mock-service-id-123")
        XCTAssertEqual(items["redirect_uri"], "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["lang"], "en")
        XCTAssertEqual(items["state"], "ccsp")
    }

    func testExtractAuthorizationCodeParsesExpectedFields() throws {
        let client = HMGAuthClient(configuration: MockApiConfiguration(), provider: MockApiProvider(), rsaService: .init())
        let callback = try XCTUnwrap(URL(string: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?code=AUTH_CODE_123&state=ccsp&login_success=y"))

        let result = try client.extractAuthorizationCode(from: callback)

        XCTAssertEqual(result.code, "AUTH_CODE_123")
        XCTAssertEqual(result.state, "ccsp")
        XCTAssertTrue(result.loginSuccess)
    }

    func testExtractAuthorizationCodeThrowsWhenCodeMissing() throws {
        let client = HMGAuthClient(configuration: MockApiConfiguration(), provider: MockApiProvider(), rsaService: .init())
        let callback = try XCTUnwrap(URL(string: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?state=ccsp&login_success=y"))

        XCTAssertThrowsError(try client.extractAuthorizationCode(from: callback)) { error in
            XCTAssertEqual(error as? AuthenticationError, .authorizationCodeNotFound)
        }
    }

    func testRefreshAuthorizationPreservesDeviceAndSourceWithoutAuthorizationHeader() async throws {
        let provider = MQTTStubApiProvider(configuration: MockApiConfiguration())
        let deviceId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        provider.authorization = AuthorizationData(
            stamp: "stamp",
            deviceId: deviceId,
            accessToken: "old-access",
            expiresIn: 60,
            refreshToken: "old-refresh",
            isCcuCCS2Supported: false,
            source: .legacy
        )
        provider.tokenResponse = TokenResponse(
            scope: nil,
            connector: nil,
            accessToken: "new-access",
            refreshToken: nil,
            idToken: nil,
            tokenType: "Bearer",
            expiresIn: 3600
        )
        let client = HMGAuthClient(configuration: MockApiConfiguration(), provider: provider, rsaService: .init())

        let refreshed = try await client.refreshAuthorization(try XCTUnwrap(provider.authorization))

        XCTAssertEqual(refreshed.accessToken, "new-access")
        XCTAssertEqual(refreshed.expiresIn, 3600)
        XCTAssertEqual(refreshed.refreshToken, "old-refresh")
        XCTAssertEqual(refreshed.deviceId, deviceId)
        XCTAssertEqual(refreshed.stamp, "stamp")
        XCTAssertFalse(refreshed.isCcuCCS2Supported)
        XCTAssertEqual(refreshed.source, .legacy)
        XCTAssertEqual(provider.recordedAuthorizationFlags, [false])

        let request = try XCTUnwrap(provider.recordedRequests.first)
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("grant_type=refresh_token"))
        XCTAssertTrue(body.contains("refresh_token=old-refresh"))
    }
}

final class HMGMQTTClientTests: XCTestCase {
    func testApiFetchMQTTDeviceHostThrowsUnsupportedForPorscheBeforeRequest() async {
        let provider = MQTTStubApiProvider(configuration: PorscheApiConfiguration.europe)
        let api = Api(configuration: PorscheApiConfiguration.europe, rsaService: .init(), provider: provider)

        do {
            _ = try await api.fetchMQTTDeviceHost()
            XCTFail("Expected MQTT unsupported error")
        } catch let error as ApiError {
            guard case let .unsupported(message) = error else {
                return XCTFail("Expected unsupported error, got \(error)")
            }
            XCTAssertEqual(message, "MQTT is not supported for Porsche.")
            XCTAssertEqual(provider.requestCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchDeviceHostMapsResponse() async throws {
        let provider = MQTTStubApiProvider(configuration: MockApiConfiguration())
        provider.authorization = makeAuthorizationData()
        provider.hostResponse = MQTTHostResponse(
            http: .init(name: "http", protocol: "https", host: "http.example.com", port: 443, ssl: true),
            mqtt: .init(name: "mqtt", protocol: "mqtt", host: "broker.example.com", port: 8883, ssl: true)
        )
        let client = HMGMQTTClient(configuration: MockApiConfiguration(), provider: provider)

        let response = try await client.fetchDeviceHost()

        XCTAssertEqual(response.host, "broker.example.com")
        XCTAssertEqual(response.port, 8883)
        XCTAssertTrue(response.ssl)
        XCTAssertEqual(provider.recordedRequests.first?.url?.path, "/api/v3/servicehub/device/host")
    }

    func testRegisterDeviceReturnsIdsAndGeneratedUUIDSuffix() async throws {
        let provider = MQTTStubApiProvider(configuration: MockApiConfiguration())
        provider.authorization = makeAuthorizationData()
        provider.deviceRegisterResponse = DeviceRegisterResponse(clientId: "client-123", deviceId: "device-456")
        let client = HMGMQTTClient(configuration: MockApiConfiguration(), provider: provider)

        let response = try await client.registerDevice()

        XCTAssertEqual(response.clientId, "client-123")
        XCTAssertEqual(response.deviceId, "device-456")
        XCTAssertTrue(response.uuid.hasSuffix("_UVO"))
        XCTAssertEqual(provider.recordedRequests.first?.url?.path, "/api/v3/servicehub/device/register")
    }

    private func makeAuthorizationData() -> AuthorizationData {
        AuthorizationData(
            stamp: "stamp",
            deviceId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            accessToken: "access-token",
            expiresIn: 3600,
            refreshToken: "refresh-token",
            isCcuCCS2Supported: true
        )
    }
}

private final class MQTTStubApiProvider: ApiRequestProvider, ApiCaller, @unchecked Sendable {
    let urlSession: URLSession

    override var caller: ApiCaller {
        self
    }

    var requestCount = 0
    var recordedRequests: [URLRequest] = []
    var recordedAuthorizationFlags: [Bool] = []
    var tokenResponse: TokenResponse?
    var hostResponse: MQTTHostResponse?
    var deviceRegisterResponse: DeviceRegisterResponse?

    init(configuration: ApiConfiguration) {
        urlSession = .shared
        super.init(configuration: configuration, callerType: Self.self, requestType: MQTTStubApiRequest.self)
    }

    required init(configuration: any ApiConfiguration, urlSession: URLSession, authorization: AuthorizationData?) {
        self.urlSession = urlSession
        super.init(configuration: configuration, callerType: Self.self, requestType: MQTTStubApiRequest.self)
        self.authorization = authorization
    }
}

private struct MQTTStubApiRequest: ApiRequest {
    let caller: ApiCaller
    let method: ApiMethod
    let endpoint: any ApiEndpointProtocol
    let queryItems: [URLQueryItem]
    let headers: Headers
    let body: Data?
    let timeout: TimeInterval
    let authorization: Bool

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
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = try JSONEncoders.default.encode(AnyEncodable(encodable))
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
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = form
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
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
            request.allHTTPHeaderFields = headers
            request.httpBody = body
            return request
        }
    }

    func referalUrl(acceptStatusCode _: Int) async throws -> URL {
        throw URLError(.badServerResponse)
    }

    func referalUrl(acceptStatusCodes _: Set<Int>) async throws -> URL {
        throw URLError(.badServerResponse)
    }

    func response<Data: Decodable>(acceptStatusCode _: Int) async throws -> Data {
        throw URLError(.badServerResponse)
    }

    func responseValue<Data: Decodable>(acceptStatusCode _: Int) async throws -> Data {
        throw URLError(.badServerResponse)
    }

    func responseEmpty(acceptStatusCode _: Int) async throws -> ApiResponseEmpty {
        throw URLError(.badServerResponse)
    }

    func empty(acceptStatusCode _: Int) async throws {
        _ = try recordRequest()
    }

    func string(acceptStatusCode _: Int) async throws -> String {
        throw URLError(.badServerResponse)
    }

    func string(acceptStatusCodes _: Set<Int>) async throws -> String {
        throw URLError(.badServerResponse)
    }

    func httpResponse(acceptStatusCode _: Int) async throws -> HTTPURLResponse {
        throw URLError(.badServerResponse)
    }

    func httpResponse(acceptStatusCodes _: Set<Int>) async throws -> HTTPURLResponse {
        throw URLError(.badServerResponse)
    }

    func data<T: Decodable>(acceptStatusCode _: Int) async throws -> T {
        let provider = try recordRequest()

        if T.self == MQTTHostResponse.self, let response = provider.hostResponse {
            return response as! T
        }

        if T.self == DeviceRegisterResponse.self, let response = provider.deviceRegisterResponse {
            return response as! T
        }

        if T.self == TokenResponse.self, let response = provider.tokenResponse {
            return response as! T
        }

        throw URLError(.badServerResponse)
    }

    func data<T: Decodable>(acceptStatusCodes _: Set<Int>) async throws -> T {
        try await data(acceptStatusCode: 200)
    }

    func rawData(acceptStatusCodes _: Set<Int>) async throws -> Data {
        throw URLError(.badServerResponse)
    }

    private func recordRequest() throws -> MQTTStubApiProvider {
        guard let provider = caller as? MQTTStubApiProvider else {
            throw URLError(.badServerResponse)
        }
        provider.requestCount += 1
        provider.recordedRequests.append(try urlRequest)
        provider.recordedAuthorizationFlags.append(authorization)
        return provider
    }
}

private struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeImpl = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}
