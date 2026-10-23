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
    let url: URL?
    let navigationDelegate: WKNavigationDelegate

    func makeUIView(context: Context) -> WKWebView {
        Self.makeWebView(navigationDelegate: navigationDelegate)
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
        guard let url = url, webView.url == nil else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

class LoginWebViewDelegate: NSObject, WKNavigationDelegate {
    typealias Callback = (_ code: String, _ state: String, _ loginSuccess: Bool) -> Void

    let api: Api
    var callback: Callback?

    init(api: Api, callback: Callback?) {
        self.api = api
        self.callback = callback
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let url = navigationAction.request.url, api.isLoginCallback(url) {
            guard let extract = try? api.extractAuthorizationCode(from: url) else {
                callback?("", "", false)
                return .cancel
            }
            callback?(extract.code, extract.state, extract.loginSuccess)
            return .cancel
        } else {
            print(navigationAction.request.url?.path ?? "no path")
            return .allow
        }
    }
}

struct WebLoginView: View {
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false

    let configuration: AppConfiguration.Type
    let api: Api
    let onLoginSuccess: (AuthorizationData) -> Void
    let delegateObject: LoginWebViewDelegate

    init(configuration: AppConfiguration.Type, onLoginSuccess: @escaping (AuthorizationData) -> Void) {
        let api = Api(configuration: configuration.apiConfiguration, rsaService: .init())
        self.configuration = configuration
        self.api = api
        self.onLoginSuccess = onLoginSuccess
        self.delegateObject = LoginWebViewDelegate(api: api, callback: nil)
    }

    var body: some View {
        VStack {
            if showError && !errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(KiaDesign.Colors.error)

                    Text(errorMessage)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.error)

                    Spacer()
                }
                .padding(.horizontal, KiaDesign.Spacing.large)
                .padding(.top, KiaDesign.Spacing.small)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isLoading {
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
            } else {
                LoginWebView(url: try? api.webLoginUrl(), navigationDelegate: delegateObject)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            self.delegateObject.callback = { code, _, success in
                guard success else {
                    showError(message: "Login failed. Please try again.")
                    return
                }
                self.finishLogin(code: code)
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
