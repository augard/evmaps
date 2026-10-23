import WebKit
import XCTest
@testable import KiaMaps

final class KiaWebLoginTests: XCTestCase {
    @MainActor
    func testLiveWebLoginRendersAccountForm() async throws {
        guard ProcessInfo.processInfo.environment["KIAMAPS_LIVE_AUTH_CHECK"] == "1" else {
            throw XCTSkip("Opt-in real Kia page check in simulator WebKit; no credentials submitted")
        }
        let api = Api(configuration: KiaApiConfigurationEurope.kia, rsaService: .init())
        let delegate = LoginWebViewDelegate(api: api, callback: nil)
        let webView = LoginWebView.makeWebView(navigationDelegate: delegate)
        webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = webView.frame
        let controller = UIViewController()
        controller.view = webView
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            webView.stopLoading()
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        webView.load(URLRequest(url: try XCTUnwrap(api.webLoginUrl())))

        let deadline = Date().addingTimeInterval(45)
        var formLoaded = false
        while Date() < deadline {
            formLoaded = (try? await webView.evaluateJavaScript(
                "Boolean(document.querySelector('input[type=email]') && document.querySelector('input[type=password]'))"
            )) as? Bool == true
            if formLoaded { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertTrue(formLoaded, "Kia account email/password form should render in the app's WKWebView")
        XCTAssertEqual(webView.url?.host, "idpconnect-eu.kia.com")
        XCTAssertEqual(webView.title, "LOGIN")
        if formLoaded {
            let image = try await webView.takeSnapshot(configuration: nil)
            let attachment = XCTAttachment(image: image)
            attachment.name = "Kia OneApp login in simulator"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
