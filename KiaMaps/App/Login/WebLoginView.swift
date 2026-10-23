//
//  WebLoginView.swift
//  KiaMaps
//
//  Created by Lukáš Foldýna on 1/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI
import WebKit

struct LoginWebView: UIViewRepresentable {
    let url: URL
    let api: Api
    let onAuthorization: LoginWebViewDelegate.Callback
    let onFailure: (String) -> Void
    let onLoadingChange: (Bool) -> Void

    func makeCoordinator() -> LoginWebViewDelegate {
        LoginWebViewDelegate(api: api, callback: nil)
    }

    func makeUIView(context: Context) -> WKWebView {
        Self.makeWebView(navigationDelegate: context.coordinator)
    }

    static func makeWebView(navigationDelegate: WKNavigationDelegate) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.applicationNameForUserAgent = "15E148_CCS_APP_iOS"
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        webView.navigationDelegate = navigationDelegate
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let delegate = context.coordinator
        delegate.callback = onAuthorization
        delegate.onFailure = onFailure
        delegate.onLoadingChange = onLoadingChange
        delegate.loadIfNeeded(url, in: webView)
    }
}

@MainActor
class LoginWebViewDelegate: NSObject, WKNavigationDelegate {
    typealias Callback = (_ code: String, _ state: String, _ loginSuccess: Bool) -> Void

    let api: Api
    var callback: Callback?
    var onFailure: ((String) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    private var requestedURL: URL?

    init(api: Api, callback: Callback?) {
        self.api = api
        self.callback = callback
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        return policy(for: url)
    }

    func loadIfNeeded(_ url: URL, in webView: WKWebView) {
        // Compare the requested URL, not webView.url: OAuth redirects change the latter.
        guard requestedURL != url else { return }
        requestedURL = url
        webView.load(URLRequest(url: url))
    }

    func policy(for url: URL) -> WKNavigationActionPolicy {
        if url.host == URL(string: api.configuration.loginHost)?.host, url.path == "/error" {
            let description = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "error_description" })?.value ?? ""
            let blocked = description.replacingOccurrences(of: "+", with: " ")
                .localizedCaseInsensitiveContains("abusing request")
            fail(blocked
                 ? "\(api.configuration.brandName) blocked this login request. Sign-in here is currently unavailable. Check your account in the official \(api.configuration.brandName) app."
                 : "\(api.configuration.brandName) rejected the login request. Check your account in the official app.")
            return .cancel
        }

        do {
            guard let extract = try api.authorizationCallback(from: url) else { return .allow }
            guard !extract.code.isEmpty, extract.loginSuccess else {
                fail("Login failed. The provider did not confirm a successful sign-in.")
                return .cancel
            }
            onLoadingChange?(false)
            callback?(extract.code, extract.state, true)
        } catch {
            fail("Login failed. The provider did not return an authorization code.")
        }
        return .cancel
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse,
           response.statusCode >= 400 {
            fail("The login page returned HTTP \(response.statusCode). Please try again later.")
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange?(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange?(false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        fail("The login page stopped responding. Please reopen sign-in.")
    }

    func navigationFailed(_ error: Error) {
        let error = error as NSError
        // Cancelling navigation is expected when intercepting the OAuth callback.
        guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else { return }
        fail("Unable to load the login page. \(error.localizedDescription)")
    }

    private func fail(_ message: String) {
        onLoadingChange?(false)
        onFailure?(message)
    }
}

struct WebLoginView: View {
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var loginURL: URL?
    @State private var isPageLoading: Bool = false

    let configuration: AppConfiguration.Type
    let api: Api
    let onLoginSuccess: (AuthorizationData) -> Void

    init(configuration: AppConfiguration.Type, onLoginSuccess: @escaping (AuthorizationData) -> Void) {
        let api = Api(configuration: configuration.apiConfiguration, rsaService: .init())
        self.configuration = configuration
        self.api = api
        self.onLoginSuccess = onLoginSuccess
    }

    var body: some View {
        VStack {
            if showError {
                ContentUnavailableView("Unable to sign in", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if isLoading {
                VStack(spacing: KiaDesign.Spacing.medium) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: KiaDesign.Colors.primary))
                        .scaleEffect(1.2)

                    Text("Completing login...")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KiaDesign.Colors.background)
            } else if let loginURL {
                LoginWebView(
                    url: loginURL,
                    api: api,
                    onAuthorization: { code, _, _ in finishLogin(code: code) },
                    onFailure: { message in showError(message: message) },
                    onLoadingChange: { isPageLoading = $0 }
                )
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        if isPageLoading {
                            ProgressView("Loading sign-in...")
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
            } else {
                ProgressView("Preparing sign-in...")
            }
        }
        .onAppear {
            guard loginURL == nil, !showError else { return }
            do {
                guard let url = try api.webLoginUrl() else {
                    showError(message: "Unable to create the login page URL.")
                    return
                }
                loginURL = url
            } catch {
                showError(message: "Unable to create the login page URL.")
            }
        }
    }

    private func finishLogin(code: String) {
        errorMessage = ""
        showError = false
        isLoading = true

        Task {
            do {
                // Login to get tokens
                let authorizationData = try await api.login(authorizationCode: code)

                // Call success callback with authorization data
                await MainActor.run {
                    isLoading = false
                    onLoginSuccess(authorizationData)
                }
            } catch let apiError as ApiError {
                await MainActor.run {
                    isLoading = false
                    showError(message: apiError.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    WebLoginView(configuration: AppConfiguration.self) { authData in
        logInfo("Login successful for user", category: .auth)
    }
}
