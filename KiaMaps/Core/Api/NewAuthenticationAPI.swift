//
//  NewAuthenticationAPI.swift
//  KiaMaps
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation

/// Enhanced authentication API with RSA encryption support
final class NewAuthenticationAPI: NSObject {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private let rsaService = RSAEncryptionService()
    private let baseURL: String
    private let clientId: String
    private let clientSecret: String
    private let redirectUri: String
    
    init(configuration: ApiConfiguration = AppConfiguration.apiConfiguration) {
        self.baseURL = "https://idpconnect-eu.\(configuration.key).com"
        self.clientId = configuration.serviceId
        self.clientSecret = "secret"
        self.redirectUri = "\(configuration.baseUrl):\(configuration.port)/api/v1/user/oauth2/redirect"
        super.init()
    }

    // MARK: - Step 0: Get Connector Authorization
    
    func getConnectorAuthorization() async throws -> String {
        // Build the state parameter (base64 encoded JSON)
        let stateObject = ConnectorAuthorizationState(
            scope: nil,
            state: nil,
            lang: nil,
            cert: "",
            action: "idpc_auth_endpoint",
            clientId: clientId,
            redirectUri: "https://idpconnect-eu.kia.com/auth/redirect",
            responseType: "code",
            signupLink: nil,
            hmgid2ClientId: clientId,
            hmgid2RedirectUri: redirectUri,
            hmgid2Scope: nil,
            hmgid2State: "ccsp",
            hmgid2UiLocales: nil
        )
        
        let stateData = try JSONEncoder().encode(stateObject)
        let stateString = stateData.base64EncodedString()
        
        // Build URL components
        var components = URLComponents(string: "\(redirectUri.replacingOccurrences(of: ":8080/api/v1/user/oauth2/redirect", with: ":8080/api/v1/user/oauth2/connector/common/authorize"))")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: "https://idpconnect-eu.kia.com/auth/redirect"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: stateString),
            URLQueryItem(name: "cert", value: ""),
            URLQueryItem(name: "action", value: "idpc_auth_endpoint"),
            URLQueryItem(name: "sso_session_reset", value: "true")
        ]
        
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewAuthenticationError.invalidResponse
        }
        
        // Expect 302 redirect
        guard httpResponse.statusCode == 302 else {
            throw NewAuthenticationError.oauth2InitializationFailed
        }
        
        // Extract next_uri from Location header
        guard let location = httpResponse.value(forHTTPHeaderField: "Location"),
              let nxtUri = extractNextUri(from: location) else {
            throw NewAuthenticationError.oauth2InitializationFailed
        }
        
        return nxtUri
    }

    // MARK: - Step 1: Get Client Configuration
    
    func getClientConfiguration(referer: String) async throws -> ClientConfiguration {
        let url = URL(string: "\(baseURL)/api/v1/clients/\(clientId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewAuthenticationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NewAuthenticationError.clientConfigurationFailed
        }
        
        let result = try JSONDecoder().decode(ApiResponseValue<ClientConfiguration>.self, from: data)
        guard result.returnCode == 0 else {
            throw NewAuthenticationError.clientConfigurationFailed
        }
        
        return result.returnValue
    }
    
    // MARK: - Step 2: Check Password Encryption Settings
    
    func getPasswordEncryptionSettings(referer: String) async throws -> PasswordEncryptionSettings {
        let url = URL(string: "\(baseURL)/api/v1/commons/codes/HMG_DYNAMIC_CODE/details/PASSWORD_ENCRYPTION")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NewAuthenticationError.encryptionSettingsFailed
        }
        
        let result = try JSONDecoder().decode(ApiResponseValue<PasswordEncryptionSettings>.self, from: data)
        guard result.returnCode == 0 else {
            throw NewAuthenticationError.encryptionSettingsFailed
        }
        
        return result.returnValue
    }
    
    // MARK: - Step 3: Get RSA Certificate
    
    func getRSACertificate(referer: String) async throws -> RSAEncryptionService.RSAKeyData {
        let url = URL(string: "\(baseURL)/auth/api/v1/accounts/certs")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NewAuthenticationError.certificateRetrievalFailed
        }
        
        let result = try JSONDecoder().decode(ApiResponseValue<RSACertificateResponse>.self, from: data)
        guard result.returnCode == 0 else {
            throw NewAuthenticationError.certificateRetrievalFailed
        }
        
        let cert = result.returnValue
        return RSAEncryptionService.RSAKeyData(
            keyType: cert.kty,
            exponent: cert.e,
            keyId: cert.kid,
            modulus: cert.n
        )
    }
    
    // MARK: - Step 4: Initialize OAuth2 Flow
    
    func initializeOAuth2(referer: String) async throws -> OAuth2InitializationResult {
        var components = URLComponents(string: "\(baseURL)/auth/api/v2/user/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: "ccsp")
        ]
        
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        
        guard let _ = response as? HTTPURLResponse else {
            throw NewAuthenticationError.oauth2InitializationFailed
        }
        
        // Store cookies from response
        // let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
        let cookies = HTTPCookieStorage.shared.cookies

        // Parse HTML response to extract CSRF token and session key
        guard let _ = String(data: data, encoding: .utf8), let cookie = cookies?.first(where: { $0.name == "account" }) else {
            throw NewAuthenticationError.oauth2InitializationFailed
        }
        
        return OAuth2InitializationResult(
            csrfToken: cookie.value,
            sessionKey: "account",
            cookies: cookies ?? []
        )
    }
    
    // MARK: - Step 5: Encrypted Sign-In
    
    func signIn(referer: String, username: String, password: String, rsaKey: RSAEncryptionService.RSAKeyData, oauth2Result: OAuth2InitializationResult) async throws -> AuthorizationCodeResult {
        // Encrypt password
        let encryptedPassword = try rsaService.encryptPassword(password, with: rsaKey)
        
        let url = URL(string: "\(baseURL)/auth/account/signin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")

        // Set cookies from OAuth2 initialization
        if let cookieHeader = HTTPCookie.requestHeaderFields(with: oauth2Result.cookies)["Cookie"] {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        guard let connectorSessionKey = extractConnectorSessionKey(from: referer) else {
            throw NewAuthenticationError.signInFailed
        }

        // Prepare form data
        let formData: [String: String] = [
            "client_id": clientId,
            "encryptedPassword": "true",
            "orgHmgSid": "",
            "password": encryptedPassword,
            "kid": rsaKey.keyId,
            "redirect_uri": redirectUri,
            "scope": "",
            "nonce": "",
            "state": "ccsp",
            "username": username,
            "remember_me": "false",
            "connector_session_key": connectorSessionKey,
            "_csrf": oauth2Result.csrfToken
        ]
        
        let formString = formData
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewAuthenticationError.signInFailed
        }
        
        // Expect 302 redirect with authorization code
        guard httpResponse.statusCode == 302 else {
            throw NewAuthenticationError.signInFailed
        }
        
        // Extract authorization code from redirect location
        guard let location = httpResponse.value(forHTTPHeaderField: "Location") else {
            throw NewAuthenticationError.authorizationCodeNotFound
        }
        
        let (code, state, loginSuccess) = try extractAuthorizationCode(from: location)
        
        return AuthorizationCodeResult(
            code: code,
            state: state,
            loginSuccess: loginSuccess
        )
    }
    
    // MARK: - Step 6: Exchange Authorization Code for Tokens
    
    func exchangeCodeForTokens(authorizationCode: String) async throws -> TokenResponse {
        let url = URL(string: "\(baseURL)/auth/api/v2/user/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB;q=1.0", forHTTPHeaderField: "Accept-Language")
        request.setValue("br;q=1.0, gzip;q=0.9, deflate;q=0.8", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("EU_BlueLink/2.1.26 (com.kia.connect.eu; build:10893; iOS 26.0.0) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")
        
        let formData: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": authorizationCode,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]
        
        let formString = formData
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NewAuthenticationError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse
    }
    
    // MARK: - Helper Methods
    
    private func extractCSRFToken(from html: String) throws -> String {
        // Look for CSRF token in various patterns
        let patterns = [
            #"name="_csrf"\s+value="([^"]+)""#,
            #"<input[^>]*name=['"]_csrf['"][^>]*value=['"]([^'"]+)['"]"#,
            #"_csrf['"]\s*:\s*['"]([^'"]+)['"]"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        // If not found in HTML, it might be empty or handled differently
        print("Warning: CSRF token not found in HTML, using empty string")
        return ""
    }
    
    private func extractSessionKey(from html: String) throws -> String {
        // Look for connector_session_key in the HTML/URL
        let patterns = [
            #"connector_session_key=([a-f0-9-]+)"#,
            #"connector_session_key['"]:\s*['"]([^'"]+)['"]"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        
        // Generate a new session key if not found
        return UUID().uuidString.lowercased()
    }
    
    private func extractNextUri(from location: String) -> String? {
        guard let url = URL(string: location),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        // Look for next_uri parameters
        return queryItems.first(where: {  $0.name == "next_uri" })?.value
    }

    private func extractConnectorSessionKey(from location: String) -> String? {
        guard let url = URL(string: location),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        // Look for both next_uri parameters
        return queryItems.first(where: { $0.name == "connector_session_key" })?.value
    }

    private func extractAuthorizationCode(from location: String) throws -> (code: String, state: String, loginSuccess: Bool) {
        guard let url = URL(string: location),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw NewAuthenticationError.authorizationCodeNotFound
        }
        
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw NewAuthenticationError.authorizationCodeNotFound
        }
        
        let state = queryItems.first(where: { $0.name == "state" })?.value ?? "ccsp"
        let loginSuccess = queryItems.first(where: { $0.name == "login_success" })?.value == "y"
        
        return (code: code, state: state, loginSuccess: loginSuccess)
    }
    
    // MARK: - Constants
    
    private enum Constants {
        static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148_CCS_APP_iOS"
    }
}

// MARK: - Connector Authorization State

/// State object for connector authorization request
private struct ConnectorAuthorizationState: Codable {
    let scope: String?
    let state: String?
    let lang: String?
    let cert: String
    let action: String
    let clientId: String
    let redirectUri: String
    let responseType: String
    let signupLink: String?
    let hmgid2ClientId: String
    let hmgid2RedirectUri: String
    let hmgid2Scope: String?
    let hmgid2State: String
    let hmgid2UiLocales: String?
    
    enum CodingKeys: String, CodingKey {
        case scope
        case state
        case lang
        case cert
        case action
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case responseType = "response_type"
        case signupLink = "signup_link"
        case hmgid2ClientId = "hmgid2_client_id"
        case hmgid2RedirectUri = "hmgid2_redirect_uri"
        case hmgid2Scope = "hmgid2_scope"
        case hmgid2State = "hmgid2_state"
        case hmgid2UiLocales = "hmgid2_ui_locales"
    }
}

extension NewAuthenticationAPI: URLSessionTaskDelegate {
    func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let lastPathComponent = task.originalRequest?.url?.lastPathComponent
        if ["signin", "authorize"].contains(lastPathComponent) {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}
