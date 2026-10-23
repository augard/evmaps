import CryptoKit
import Foundation

/// Kia EU OneApp login. The legacy CCSP OAuth client is rejected by IDPConnect.
/// Protocol reference: hyundai_kia_connect_api/KiaUvoApiEU.py and cci_fingerprint.py.
final class KiaOneAppAuthentication {
    static let clientID = "01b36c86-79e8-486c-8009-15f2ad88d670"
    static let redirectURI = "https://oneapp.kia.com/redirect"
    static let identityHost = "https://idpconnect-eu.kia.com"
    static let tokenHost = "https://cci-api-eu.kia.com"
    private static let browserAgent = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36_CCS_APP_AOS"

    let state: String
    private let configuration: ApiConfiguration
    private let rsaService: RSAEncryptionService
    private let session: URLSession

    init(configuration: ApiConfiguration, rsaService: RSAEncryptionService,
         sessionConfiguration: URLSessionConfiguration = .ephemeral, state: String = UUID().uuidString) {
        self.configuration = configuration
        self.rsaService = rsaService
        self.session = URLSession(configuration: sessionConfiguration, delegate: KiaLoginRedirectDelegate(), delegateQueue: nil)
        self.state = state
    }

    deinit { session.invalidateAndCancel() }

    func authorizationURL() throws -> URL {
        try makeURL(host: Self.identityHost, path: "/auth/api/v2/user/oauth2/authorize", query: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "country", value: "de")
        ])
    }

    func isCallback(_ url: URL) -> Bool {
        Self.isCallbackURL(url)
    }

    static func isCallbackURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "oneapp.kia.com" && url.path == "/redirect"
            && (url.port == nil || url.port == 443)
    }

    func authorizationCode(from url: URL) throws -> String {
        guard isCallback(url), let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == state else {
            throw KiaLoginError.invalidCallback
        }
        guard items.first(where: { $0.name == "error" }) == nil,
              let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw KiaLoginError.credentialsRejected
        }
        // OneApp callbacks do not include the legacy login_success=y flag.
        return code
    }

    func login(username: String, password: String) async throws -> AuthorizationData {
        let (rsaKey, referer) = try await prepareLogin()
        let encrypted = try rsaService.encryptPassword(password, with: rsaKey)

        var request = URLRequest(url: try makeURL(host: Self.identityHost, path: "/auth/account/signin"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.identityHost, forHTTPHeaderField: "Origin")
        request.setValue(referer?.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = ApiRequestImpl.encodeForm([
            "client_id": Self.clientID, "encryptedPassword": "true", "password": encrypted,
            "redirect_uri": Self.redirectURI, "scope": "", "nonce": "", "state": state,
            "username": username, "connector_session_key": "", "kid": rsaKey.keyId, "_csrf": ""
        ])
        let (_, signIn) = try await send(request, status: 302)
        guard let location = signIn.value(forHTTPHeaderField: "Location"),
              let redirect = URL(string: location, relativeTo: signIn.url)?.absoluteURL else {
            throw KiaLoginError.credentialsRejected
        }
        if redirect.path.contains("/user/authorization") {
            throw KiaLoginError.consentRequired
        }
        guard isCallback(redirect) else { throw KiaLoginError.credentialsRejected }
        return try await login(authorizationCode: authorizationCode(from: redirect))
    }

    /// Public login bootstrap only; no credentials submitted. Also used for live protocol checks.
    func prepareLogin() async throws -> (RSAEncryptionService.RSAKeyData, URL?) {
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        let (page, response) = try await send(URLRequest(url: authorizationURL()), status: 200)
        if String(decoding: page, as: UTF8.self).localizedCaseInsensitiveContains("abusing")
            || response.url?.path == "/error" {
            throw KiaLoginError.clientRejected
        }

        let certURL = try makeURL(host: Self.identityHost, path: "/auth/api/v1/accounts/certs")
        let (certData, _) = try await send(URLRequest(url: certURL), status: 200)
        let certificate = try JSONDecoder().decode(CertificateEnvelope.self, from: certData).retValue
        let key = RSAEncryptionService.RSAKeyData(
            keyType: certificate.kty, exponent: certificate.e, keyId: certificate.kid, modulus: certificate.n
        )
        return (key, response.url)
    }

    func login(authorizationCode: String) async throws -> AuthorizationData {
        guard !authorizationCode.isEmpty else { throw KiaLoginError.invalidCallback }
        // CCI accepts an installation UUID; legacy push registration must not gate login.
        let deviceID = UUID()
        var request = URLRequest(url: try makeURL(host: Self.tokenHost, path: "/auth/v1/token", query: [
            URLQueryItem(name: "code", value: authorizationCode)
        ]))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = Self.fingerprintHeaders(deviceID: deviceID)
        let (tokenData, _) = try await send(request, status: 200)
        let tokens = try JSONDecoder().decode(OneAppTokens.self, from: tokenData)
        guard !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty else {
            throw KiaLoginError.missingTokens
        }

        // A OneApp access token cannot be used directly with the vehicle API.
        request = URLRequest(url: try makeURL(host: Self.tokenHost, path: "/auth/v1/token-exchange", query: [
            URLQueryItem(name: "serviceType", value: "CCS")
        ]))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = Self.fingerprintHeaders(deviceID: deviceID)
        request.setValue("Bearer \(Self.bareToken(tokens.accessToken))", forHTTPHeaderField: "Authorization")
        request.setValue(tokens.nonCcsToken ?? "", forHTTPHeaderField: "Authentication")
        if let exchangeable = tokens.exchangeableAccessToken, !exchangeable.isEmpty {
            request.setValue(exchangeable, forHTTPHeaderField: "exchangeable-token")
            request.setValue(tokens.nonCcsToken ?? "", forHTTPHeaderField: "non-ccs-token")
        }
        let (ccsData, _) = try await send(request, status: 200)
        let ccs = try JSONDecoder().decode(CCSToken.self, from: ccsData)
        let accessToken = Self.bareToken(ccs.accessToken)
        guard !accessToken.isEmpty else { throw KiaLoginError.missingTokens }
        return AuthorizationData(
            stamp: AuthorizationData.generateStamp(for: configuration), deviceId: deviceID,
            accessToken: accessToken, expiresIn: ccs.expiresIn, refreshToken: tokens.refreshToken,
            isCcuCCS2Supported: true
        )
    }

    /// OneApp Android 1.4.0 identity and signing constants from cci_fingerprint.py.
    static func fingerprintHeaders(deviceID: UUID, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> [String: String] {
        var headers = [
            "client-id": "com.kia.oneapp.eu", "client-name": "KiaEU", "client-version": "1.4.0",
            "client-os-code": "android", "client-os-version": "14", "client-device-model": "SM-S918B",
            "client-device-id": deviceID.uuidString.lowercased(), "client-notification-provider-type": "FCM",
            "locale": "EN", "timezone": timezoneOffset(), "X-Brand": "Kia", "X-Region": "eu",
            "App-Request-Id": "\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))_\(deviceID.uuidString.replacingOccurrences(of: "-", with: "").lowercased())_AOS",
            "User-Agent": "okhttp/4.12.0", "Accept": "*/*", "Accept-Language": "en",
            "X-Timestamp": String(timestamp)
        ]
        let identity = ["client-id", "client-name", "client-version", "client-os-code"].map { headers[$0]! }.joined()
        let key = SymmetricKey(data: Data((identity + "yb4Z1n2nlKeukNilE7QEdbKB34nStPVa").utf8))
        let message = identity + headers["client-os-version"]! + String(timestamp)
        headers["X-Fingerprint"] = Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)).hexEncodedString()
        return headers
    }

    private static func timezoneOffset() -> String {
        let seconds = TimeZone(identifier: "Europe/Berlin")!.secondsFromGMT()
        return String(format: "%@%02d:%02d", seconds < 0 ? "-" : "+", abs(seconds) / 3600, abs(seconds) % 3600 / 60)
    }

    private static func bareToken(_ token: String) -> String {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.hasPrefix("Bearer ") ? String(token.dropFirst(7)) : token
    }

    private func makeURL(host: String, path: String, query: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: host + path) else { throw URLError(.badURL) }
        if !query.isEmpty { components.queryItems = query }
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private func send(_ original: URLRequest, status: Int) async throws -> (Data, HTTPURLResponse) {
        var request = original
        request.timeoutInterval = 30
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(Self.browserAgent, forHTTPHeaderField: "User-Agent")
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard response.statusCode == status else {
            if request.url?.path == "/auth/account/signin", response.statusCode == 200 {
                throw KiaLoginError.credentialsRejected
            }
            if response.statusCode == 401 || response.statusCode == 403 {
                throw KiaLoginError.clientRejected
            }
            throw KiaLoginError.unexpectedStatus(response.statusCode)
        }
        // Never log authentication URLs, headers, response bodies, or tokens.
        return (data, response)
    }
}

private final class KiaLoginRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Read the sign-in callback locally, without navigating to OneApp with the code.
        if task.originalRequest?.url?.path == "/auth/account/signin" || request.url.map(KiaOneAppAuthentication.isCallbackURL) == true {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}

private struct CertificateEnvelope: Decodable {
    let retValue: RSACertificateResponse
}

private struct OneAppTokens: Decodable {
    let accessToken: String
    let refreshToken: String
    let nonCcsToken: String?
    let exchangeableAccessToken: String?
}

private struct CCSToken: Decodable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey { case accessToken, ccsAccessToken, expiresTime }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let access = try values.decodeIfPresent(String.self, forKey: .accessToken)
        accessToken = try (access?.isEmpty == false ? access : nil)
            ?? values.decodeIfPresent(String.self, forKey: .ccsAccessToken) ?? ""
        let seconds = (try? values.decode(Int.self, forKey: .expiresTime))
            ?? (try? values.decode(String.self, forKey: .expiresTime)).flatMap(Int.init) ?? 3600
        expiresIn = seconds > 0 ? seconds : 3600
    }
}

enum KiaLoginError: LocalizedError {
    case clientRejected, invalidCallback, credentialsRejected, consentRequired, missingTokens
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .clientRejected:
            "Kia rejected the login request. Its login service may have changed; please check for an app update."
        case .invalidCallback:
            "Kia returned an invalid login response. Please start login again."
        case .credentialsRejected:
            "Kia could not sign you in. Check your email and password, or try Web Login."
        case .consentRequired:
            "Kia requires account consent. Use Web Login to accept the terms, then try again."
        case .missingTokens:
            "Kia did not return the tokens needed to connect your vehicle. Please try again."
        case .unexpectedStatus(let status):
            "Kia login returned HTTP \(status). Please try again later."
        }
    }
}
