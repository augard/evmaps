import XCTest
import WebKit
@testable import KiaMaps

@MainActor
final class WebLoginNavigationTests: XCTestCase {
    private func makeDelegate() -> LoginWebViewDelegate {
        let configuration = ApiBrand.kia.configuration(for: .europe)
        let api = Api(configuration: configuration, rsaService: .init())
        return LoginWebViewDelegate(api: api, callback: nil)
    }

    private func callbackURL(for delegate: LoginWebViewDelegate, query: String) throws -> URL {
        let url = try XCTUnwrap(delegate.api.webLoginUrl())
        let state = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "state" })?.value)
        return try XCTUnwrap(URL(string: "https://oneapp.kia.com/redirect?state=\(state)&\(query)"))
    }

    func testBlockedRedirectReportsFailureEvenWhenErrorPageReturnsHTTP200() throws {
        let delegate = makeDelegate()
        var failure: String?
        var loading: Bool?
        delegate.onFailure = { failure = $0 }
        delegate.onLoadingChange = { loading = $0 }
        let url = try XCTUnwrap(URL(string: "https://idpconnect-eu.kia.com/error?status=400&error=Bad+Request&error_description=Bad+Request.+It+was+classified+as+an+abusing+request+and+blocked."))

        XCTAssertEqual(delegate.policy(for: url), .cancel)
        XCTAssertTrue(try XCTUnwrap(failure).contains("blocked this login request"))
        XCTAssertEqual(loading, false)
    }

    func testOrdinaryLoginNavigationIsAllowed() throws {
        let delegate = makeDelegate()
        delegate.onFailure = { XCTFail($0) }
        let url = try XCTUnwrap(URL(string: "https://idpconnect-eu.kia.com/auth/api/v2/user/oauth2/authorize"))
        XCTAssertEqual(delegate.policy(for: url), .allow)
    }

    func testValidCallbackCompletesLogin() throws {
        let delegate = makeDelegate()
        var receivedCode: String?
        delegate.callback = { code, _, success in
            receivedCode = code
            XCTAssertTrue(success)
        }
        delegate.onFailure = { XCTFail($0) }
        let url = try callbackURL(for: delegate, query: "code=test-code")

        XCTAssertEqual(delegate.policy(for: url), .cancel)
        XCTAssertEqual(receivedCode, "test-code")
    }

    func testMissingCallbackCodeReportsFailureInsteadOfSilentlyCancelling() throws {
        let delegate = makeDelegate()
        var failure: String?
        delegate.onFailure = { failure = $0 }
        delegate.callback = { _, _, _ in XCTFail("Malformed callback must not complete login") }
        let url = try callbackURL(for: delegate, query: "login_success=y")

        XCTAssertEqual(delegate.policy(for: url), .cancel)
        XCTAssertTrue(try XCTUnwrap(failure).contains("did not return an authorization code"))
    }

    func testUnsuccessfulCallbackDoesNotExchangeCode() throws {
        let delegate = makeDelegate()
        var failure: String?
        delegate.onFailure = { failure = $0 }
        delegate.callback = { _, _, _ in XCTFail("Failed callback must not complete login") }
        let url = try callbackURL(for: delegate, query: "error=access_denied")

        XCTAssertEqual(delegate.policy(for: url), .cancel)
        XCTAssertNotNil(failure)
    }

    func testCallbackPathFromAnotherOriginDoesNotCompleteLogin() throws {
        let delegate = makeDelegate()
        delegate.callback = { _, _, _ in XCTFail("Untrusted origin must not complete login") }
        delegate.onFailure = { XCTFail($0) }
        for origin in ["https://example.test", "http://oneapp.kia.com", "https://oneapp.kia.com:8080"] {
            let url = try XCTUnwrap(URL(string: "\(origin)/redirect?code=test-code&login_success=y"))
            XCTAssertEqual(delegate.policy(for: url), .allow)
        }
    }

    func testSwiftUIUpdatesDoNotRestartLoginNavigation() throws {
        let delegate = makeDelegate()
        let webView = RecordingLoginWebView(frame: .zero)
        let url = try XCTUnwrap(URL(string: "https://example.test/login"))
        delegate.loadIfNeeded(url, in: webView)
        delegate.loadIfNeeded(url, in: webView)
        delegate.loadIfNeeded(url, in: webView)
        XCTAssertEqual(webView.requests.map(\.url), [url])
    }

    func testNetworkFailureStopsLoadingAndCancellationDoesNotReplaceIt() throws {
        let delegate = makeDelegate()
        var failures: [String] = []
        var loading: Bool?
        delegate.onFailure = { failures.append($0) }
        delegate.onLoadingChange = { loading = $0 }
        delegate.navigationFailed(URLError(.notConnectedToInternet))
        delegate.navigationFailed(URLError(.cancelled))

        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(try XCTUnwrap(failures.first).contains("Unable to load the login page"))
        XCTAssertEqual(loading, false)
    }
    func testPorscheCallbackCompletesLogin() throws {
        let api = Api(configuration: PorscheApiConfiguration.europe, rsaService: .init())
        let delegate = LoginWebViewDelegate(api: api, callback: nil)
        var received: (code: String, state: String)?
        delegate.callback = { code, state, success in
            received = (code, state)
            XCTAssertTrue(success)
        }
        delegate.onFailure = { XCTFail($0) }
        let url = try XCTUnwrap(URL(string: "my-porsche-app://auth0/callback?code=porsche-code&state=s1"))

        XCTAssertEqual(delegate.policy(for: url), .cancel)
        XCTAssertEqual(received?.code, "porsche-code")
        XCTAssertEqual(received?.state, "s1")
    }

    func testPorscheProviderIgnoresHMGCallback() throws {
        let api = Api(configuration: PorscheApiConfiguration.europe, rsaService: .init())
        let delegate = LoginWebViewDelegate(api: api, callback: nil)
        delegate.callback = { _, _, _ in XCTFail("HMG callback must not complete Porsche login") }
        delegate.onFailure = { XCTFail($0) }
        let url = try XCTUnwrap(URL(string: "https://prd.eu-ccapi.kia.com:8080/api/v1/user/oauth2/redirect?code=test-code&login_success=y"))

        XCTAssertEqual(delegate.policy(for: url), .allow)
    }

}

@MainActor
private final class RecordingLoginWebView: WKWebView {
    var requests: [URLRequest] = []

    override func load(_ request: URLRequest) -> WKNavigation? {
        requests.append(request)
        return nil // Offline test: no request reaches the network.
    }
}
