//
//  PorscheAuthClientTests.swift
//  KiaTests
//
//  Created by Codex on 06.03.2026.
//

import XCTest
@testable import KiaMaps

private final class PorscheTransportStub {
    struct StubResponse {
        let statusCode: Int
        let headers: [String: String]
        let body: Data

        init(statusCode: Int, headers: [String: String] = [:], json: Any? = nil) {
            self.statusCode = statusCode
            self.headers = headers
            if let json {
                self.body = try! JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            } else {
                self.body = Data()
            }
        }
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [StubResponse]

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func transport(_ request: URLRequest) async throws -> PorscheHTTPTransportResponse {
        requests.append(request)
        let response = responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: response.headers
        )!
        return PorscheHTTPTransportResponse(data: response.body, response: httpResponse)
    }
}

final class PorscheAuthClientTests: XCTestCase {
    func testAuthorizeURLContainsExpectedQueryForEU() throws {
        let client = PorscheAuthClient(configuration: .europe)
        let url = try client.makeAuthorizeURL(state: "state-eu")

        XCTAssertEqual(url.host, "identity.porsche.com")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["client_id"], PorscheApiConfiguration.europe.authClientId)
        XCTAssertEqual(items["redirect_uri"], PorscheApiConfiguration.europe.redirectUri)
        XCTAssertEqual(items["audience"], PorscheApiConfiguration.europe.audience)
        XCTAssertEqual(items["scope"], PorscheApiConfiguration.europe.scope)
        XCTAssertEqual(items["state"], "state-eu")
        XCTAssertEqual(items["ui_locales"], "de_DE")
    }

    func testAuthorizeURLContainsExpectedQueryForUS() throws {
        let client = PorscheAuthClient(configuration: .usa)
        let url = try client.makeAuthorizeURL(state: "state-us")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["ui_locales"], "en_US")
        XCTAssertEqual(items["state"], "state-us")
    }

    func testAuthenticateRunsIdentifierFirstFlowAndExchangesToken() async throws {
        let stub = PorscheTransportStub(responses: [
            .init(statusCode: 302, headers: ["Location": "/u/login/identifier?state=state-eu"]),
            .init(statusCode: 200),
            .init(statusCode: 302, headers: ["Location": "/authorize/resume?state=state-eu"]),
            .init(statusCode: 302, headers: ["Location": "my-porsche-app://auth0/callback?code=abc123&state=state-eu"]),
            .init(statusCode: 200, json: [
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "token_type": "Bearer",
                "expires_in": 3600,
                "scope": "openid cars",
            ]),
        ])
        let now = Date(timeIntervalSince1970: 1_773_000_000)
        let client = PorscheAuthClient(configuration: .europe, transport: stub.transport, now: { now })

        let token = try await client.authenticate(username: "test@example.com", password: "secret", state: "state-eu")

        XCTAssertEqual(token.accessToken, "access-token")
        XCTAssertEqual(token.refreshToken, "refresh-token")
        XCTAssertEqual(token.scope, "openid cars")
        XCTAssertEqual(token.obtainedAt, now)
        XCTAssertEqual(stub.requests.count, 5)
        XCTAssertEqual(stub.requests[1].url?.path, "/u/login/identifier")
        XCTAssertEqual(stub.requests[2].url?.path, "/u/login/password")
        XCTAssertEqual(stub.requests[4].url?.path, "/oauth/token")
    }

    func testAuthenticateThrowsMFAChallengeWhenPasswordRedirectRequestsOTP() async throws {
        let stub = PorscheTransportStub(responses: [
            .init(statusCode: 302, headers: ["Location": "/u/login/identifier?state=s-mfa"]),
            .init(statusCode: 200),
            .init(statusCode: 302, headers: ["Location": "/u/mfa-otp-challenge?state=s-mfa"]),
        ])
        let client = PorscheAuthClient(configuration: .europe, transport: stub.transport)

        await XCTAssertThrowsErrorAsync(try await client.authenticate(username: "test@example.com", password: "secret", state: "s-mfa")) { error in
            XCTAssertEqual(error as? PorscheAuthError, .mfaRequired(.init(state: "s-mfa", challengeType: "otp")))
        }
    }

    func testRefreshTokenUsesRefreshGrant() async throws {
        let stub = PorscheTransportStub(responses: [
            .init(statusCode: 200, json: [
                "access_token": "new-access",
                "refresh_token": "new-refresh",
                "token_type": "Bearer",
                "expires_in": 7200,
                "scope": "openid profile",
            ]),
        ])
        let client = PorscheAuthClient(configuration: .europe, transport: stub.transport, now: { Date(timeIntervalSince1970: 42) })

        let token = try await client.refreshToken("refresh-1")

        XCTAssertEqual(token.accessToken, "new-access")
        let body = String(decoding: stub.requests[0].httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains("grant_type=refresh_token"))
        XCTAssertTrue(body.contains("refresh_token=refresh-1"))
    }

    func testParseAuthorizationCallbackCode() throws {
        let client = PorscheAuthClient(configuration: .europe)
        let callback = try XCTUnwrap(URL(string: "my-porsche-app://auth0/callback?code=abc123&state=s1"))
        let result = try client.parseAuthorizationCallback(callback)
        XCTAssertEqual(result, .authorizationCode("abc123"))
    }

    func testParseAuthorizationCallbackMFA() throws {
        let client = PorscheAuthClient(configuration: .europe)
        let callback = try XCTUnwrap(URL(string: "my-porsche-app://auth0/callback?error=mfa_required&state=s-mfa"))
        let result = try client.parseAuthorizationCallback(callback)
        XCTAssertEqual(result, .mfaRequired(.init(state: "s-mfa", challengeType: "otp")))
    }

    func testTokenExpiryHandling() {
        let token = PorscheTokenSet(
            accessToken: "a",
            refreshToken: "r",
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: nil,
            obtainedAt: Date().addingTimeInterval(-3500)
        )
        XCTAssertTrue(token.isExpired(leeway: 120))
        XCTAssertFalse(token.isExpired(leeway: 10))
    }

    func testMFAResultMapping() throws {
        let client = PorscheAuthClient(configuration: .europe)
        XCTAssertNoThrow(try client.mapMFASubmitResult(.success))
        XCTAssertThrowsError(try client.mapMFASubmitResult(.invalidCode)) { error in
            XCTAssertEqual(error as? PorscheAuthError, .invalidMFACode)
        }
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
