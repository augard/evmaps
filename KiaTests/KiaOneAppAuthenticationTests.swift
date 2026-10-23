import XCTest
@testable import KiaMaps

final class KiaOneAppAuthenticationTests: XCTestCase {
    private var login: KiaOneAppAuthentication!
    private let state = "test-login-state"
    private var requests: [URLRequest] = []

    override func setUp() {
        super.setUp()
        requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [KiaLoginURLProtocol.self]
        login = KiaOneAppAuthentication(configuration: ApiConfigurationEurope.kia, rsaService: .init(),
                                         sessionConfiguration: configuration, state: state)
        KiaLoginURLProtocol.handler = { [unowned self] request in
            self.requests.append(request)
            return try self.response(for: request)
        }
    }

    override func tearDown() {
        KiaLoginURLProtocol.handler = nil
        login = nil
        super.tearDown()
    }

    func testWebLoginUsesOneAppClientAndCallback() throws {
        let url = try login.authorizationURL()
        let parameters = query(url)
        XCTAssertEqual(url.host, "idpconnect-eu.kia.com")
        XCTAssertEqual(parameters["client_id"], "01b36c86-79e8-486c-8009-15f2ad88d670")
        XCTAssertEqual(parameters["redirect_uri"], "https://oneapp.kia.com/redirect")
        XCTAssertEqual(parameters["state"], state)

        let api = Api(configuration: ApiConfigurationEurope.kia, rsaService: .init())
        let webURL = try XCTUnwrap(api.webLoginUrl())
        let callback = URL(string: "https://oneapp.kia.com/redirect?code=web-code&state=\(query(webURL)["state"]!)")!
        XCTAssertTrue(api.isLoginCallback(callback))
        let result = try api.extractAuthorizationCode(from: callback)
        XCTAssertEqual(result.code, "web-code")
        XCTAssertTrue(result.loginSuccess)
    }

    func testCallbackDoesNotRequireLegacyLoginSuccessFlag() throws {
        XCTAssertEqual(try login.authorizationCode(from: callback()), "auth-code")
    }

    func testCallbackRejectsWrongStateHostAndEmptyCode() {
        for value in [
            "https://oneapp.kia.com/redirect?code=code&state=wrong",
            "https://example.com/redirect?code=code&state=\(state)",
            "https://oneapp.kia.com/redirect?code=&state=\(state)",
            "https://oneapp.kia.com/redirect?error=access_denied&state=\(state)"
        ] {
            XCTAssertThrowsError(try login.authorizationCode(from: URL(string: value)!))
        }
    }

    func testFingerprintMatchesPythonReferenceVector() {
        let deviceID = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let headers = KiaOneAppAuthentication.fingerprintHeaders(deviceID: deviceID, timestamp: 1792767600000)
        // Independent HMAC-SHA256 vector from upstream cci_fingerprint.py.
        XCTAssertEqual(headers["X-Fingerprint"], "708676aa562e5fed81712397126787f30938e60fd5f1cbfb6a40ed165c3adf78")
        XCTAssertEqual(headers["X-Timestamp"], "1792767600000")
        XCTAssertEqual(headers["client-device-id"], deviceID.uuidString.lowercased())
        XCTAssertEqual(headers["client-name"], "KiaEU")
    }

    func testPasswordLoginExchangesOneAppTokensForVehicleToken() async throws {
        let auth = try await login.login(username: "driver+ev&maps@example.com", password: "private-password")
        XCTAssertEqual(requests.map { $0.url!.path }, [
            "/auth/api/v2/user/oauth2/authorize", "/auth/api/v1/accounts/certs", "/auth/account/signin",
            "/auth/v1/token", "/auth/v1/token-exchange"
        ])
        let signIn = requests[2]
        let form = query(URL(string: "https://example.com/?" + String(decoding: body(signIn), as: UTF8.self))!)
        XCTAssertEqual(form["username"], "driver+ev&maps@example.com")
        XCTAssertEqual(form["client_id"], KiaOneAppAuthentication.clientID)
        XCTAssertEqual(form["redirect_uri"], KiaOneAppAuthentication.redirectURI)
        XCTAssertEqual(form["connector_session_key"], "")
        XCTAssertEqual(form["_csrf"], "")
        XCTAssertEqual(form["encryptedPassword"], "true")
        XCTAssertFalse(form["password"]!.contains("private-password"))
        XCTAssertEqual(form["password"]!.count, 128)
        XCTAssertEqual(signIn.value(forHTTPHeaderField: "Origin"), "https://idpconnect-eu.kia.com")

        XCTAssertEqual(auth.accessToken, "ccs-vehicle-token")
        XCTAssertEqual(auth.refreshToken, "cci-refresh")
        XCTAssertEqual(auth.expiresIn, 86400)
        XCTAssertEqual(auth.authorizatioHeaders(for: ApiConfigurationEurope.kia)["Authorization"], "Bearer ccs-vehicle-token")
        let tokenRequest = requests[3]
        XCTAssertEqual(query(tokenRequest.url!)["code"], "auth-code")
        XCTAssertEqual(tokenRequest.url?.host, "cci-api-eu.kia.com")
        XCTAssertEqual(tokenRequest.value(forHTTPHeaderField: "client-device-id"), auth.deviceId.uuidString.lowercased())
        XCTAssertNotNil(tokenRequest.value(forHTTPHeaderField: "X-Fingerprint"))
        XCTAssertTrue(body(tokenRequest).isEmpty)
        let exchange = requests[4]
        XCTAssertEqual(query(exchange.url!)["serviceType"], "CCS")
        XCTAssertEqual(exchange.value(forHTTPHeaderField: "Authorization"), "Bearer cci-access")
        XCTAssertEqual(exchange.value(forHTTPHeaderField: "Authentication"), "non-ccs")
        XCTAssertEqual(exchange.value(forHTTPHeaderField: "exchangeable-token"), "exchangeable")
        XCTAssertEqual(exchange.value(forHTTPHeaderField: "non-ccs-token"), "non-ccs")
    }

    func testWebCodeUsesSameExchangeAndAcceptsAlternateTokenAndStringTTL() async throws {
        let normalHandler = KiaLoginURLProtocol.handler!
        KiaLoginURLProtocol.handler = { request in
            if request.url?.path == "/auth/v1/token-exchange" {
                return (200, [:], Data(#"{"ccsAccessToken":"Bearer alternate-token","expiresTime":"7200"}"#.utf8))
            }
            return try normalHandler(request)
        }
        let auth = try await login.login(authorizationCode: "web+code&=")
        XCTAssertEqual(auth.accessToken, "alternate-token")
        XCTAssertEqual(auth.expiresIn, 7200)
        XCTAssertEqual(query(requests[0].url!)["code"], "web+code&=")
    }

    func testBlockedLoginPageStopsBeforeSendingCredentials() async {
        KiaLoginURLProtocol.handler = { _ in (200, [:], Data("Abusing request".utf8)) }
        do {
            _ = try await login.login(username: "driver@example.com", password: "private-password")
            XCTFail("Blocked page must fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Kia rejected"))
        }
    }

    func testConsentRedirectGivesActionableError() async {
        let normalHandler = KiaLoginURLProtocol.handler!
        KiaLoginURLProtocol.handler = { request in
            if request.url?.path == "/auth/account/signin" {
                return (302, ["Location": "/web/v1/user/authorization"], Data())
            }
            return try normalHandler(request)
        }
        do {
            _ = try await login.login(username: "driver@example.com", password: "password")
            XCTFail("Consent must be completed in Web Login")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Use Web Login to accept the terms"))
            XCTAssertEqual(requests.count, 2)
        }
    }

    func testMissingVehicleTokenCannotCompleteLogin() async {
        let normalHandler = KiaLoginURLProtocol.handler!
        KiaLoginURLProtocol.handler = { request in
            if request.url?.path == "/auth/v1/token-exchange" { return (200, [:], Data("{}".utf8)) }
            return try normalHandler(request)
        }
        do {
            _ = try await login.login(authorizationCode: "code")
            XCTFail("Missing vehicle token must fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("tokens needed"))
        }
    }

    func testAccountWithoutAuxiliaryTokensCanExchangeVehicleToken() async throws {
        let normalHandler = KiaLoginURLProtocol.handler!
        KiaLoginURLProtocol.handler = { request in
            if request.url?.path == "/auth/v1/token" {
                return (200, [:], Data(#"{"accessToken":"cci-access","refreshToken":"cci-refresh"}"#.utf8))
            }
            return try normalHandler(request)
        }
        let auth = try await login.login(authorizationCode: "code")
        XCTAssertEqual(auth.accessToken, "ccs-vehicle-token")
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "exchangeable-token"))
    }

    func testLiveKiaLoginBootstrap() async throws {
        guard ProcessInfo.processInfo.environment["KIAMAPS_LIVE_AUTH_CHECK"] == "1" else {
            throw XCTSkip("Opt-in public Kia endpoint check; no account credentials submitted")
        }
        let live = KiaOneAppAuthentication(configuration: ApiConfigurationEurope.kia, rsaService: .init())
        let (key, referer) = try await live.prepareLogin()
        XCTAssertEqual(referer?.host, "prd.eu-ccapi.kia.com")
        XCTAssertEqual(referer?.path, "/web/v1/user/authorize")
        XCTAssertEqual(key.keyType, "RSA")
        XCTAssertFalse(try RSAEncryptionService().encryptPassword("bootstrap-test", with: key).isEmpty)
    }

    private func callback() -> URL {
        URL(string: "https://oneapp.kia.com/redirect?code=auth-code&state=\(state)")!
    }

    private func query(_ url: URL) -> [String: String] {
        Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map {
            ($0.name, $0.value ?? "")
        })
    }

    private func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    private func response(for request: URLRequest) throws -> (Int, [String: String], Data) {
        switch request.url!.path {
        case "/auth/api/v2/user/oauth2/authorize":
            return (200, [:], Data("Kia login".utf8))
        case "/auth/api/v1/accounts/certs":
            let cert = #"{"retValue":{"kty":"RSA","e":"AQAB","kid":"test-key","n":"o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"}}"#
            return (200, [:], Data(cert.utf8))
        case "/auth/account/signin":
            return (302, ["Location": callback().absoluteString], Data())
        case "/auth/v1/token":
            let tokens = #"{"accessToken":"cci-access","refreshToken":"cci-refresh","nonCcsToken":"non-ccs","exchangeableAccessToken":"exchangeable"}"#
            return (200, [:], Data(tokens.utf8))
        case "/auth/v1/token-exchange":
            return (200, [:], Data(#"{"accessToken":"ccs-vehicle-token","expiresTime":86400}"#.utf8))
        default:
            throw URLError(.unsupportedURL)
        }
    }
}

private final class KiaLoginURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.unsupportedURL) }
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}
