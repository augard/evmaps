//
//  PorscheAuthClient.swift
//  KiaMaps
//
//  Created by Codex on 06.03.2026.
//

import Foundation

struct PorscheHTTPTransportResponse {
    let data: Data
    let response: HTTPURLResponse
}

typealias PorscheHTTPTransport = (URLRequest) async throws -> PorscheHTTPTransportResponse

private final class PorscheNoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

struct PorscheAuthClient {
    let configuration: PorscheApiConfiguration
    private let transport: PorscheHTTPTransport
    private let now: () -> Date

    init(
        configuration: PorscheApiConfiguration,
        transport: PorscheHTTPTransport? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.transport = transport ?? Self.makeDefaultTransport()
        self.now = now
    }

    static func makeDefaultTransport() -> PorscheHTTPTransport {
        let session = URLSession(configuration: .ephemeral)
        return { request in
            let (data, response) = try await session.data(for: request, delegate: PorscheNoRedirectDelegate())
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return PorscheHTTPTransportResponse(data: data, response: httpResponse)
        }
    }

    func makeAuthorizeURL(state: String = UUID().uuidString) throws -> URL {
        let endpointURL = try configuration.url(for: PorscheApiEndpoint.authorize)
        guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: true) else {
            throw PorscheAuthError.invalidRedirect
        }
        components.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: configuration.authClientId),
            .init(name: "redirect_uri", value: configuration.redirectUri),
            .init(name: "audience", value: configuration.audience),
            .init(name: "scope", value: configuration.scope),
            .init(name: "state", value: state),
            .init(name: "ui_locales", value: configuration.locale),
        ]
        guard let url = components.url else {
            throw PorscheAuthError.invalidRedirect
        }
        return url
    }

    func authenticate(username: String, password: String, state: String = UUID().uuidString) async throws -> PorscheTokenSet {
        let initialRedirect = try await authorize(state: state)
        if let code = queryValue(named: "code", in: initialRedirect), !code.isEmpty {
            return try await exchangeAuthorizationCode(code)
        }
        if let challenge = mfaChallenge(from: initialRedirect) {
            throw PorscheAuthError.mfaRequired(challenge)
        }

        let loginState = queryValue(named: "state", in: initialRedirect) ?? state
        try await submitIdentifier(username: username, state: loginState)
        let passwordRedirect = try await submitPassword(username: username, password: password, state: loginState)
        if let challenge = mfaChallenge(from: passwordRedirect) {
            throw PorscheAuthError.mfaRequired(challenge)
        }

        let callback = try await resumeAuthorization(from: passwordRedirect)
        switch try parseRedirect(callback) {
        case let .authorizationCode(code):
            return try await exchangeAuthorizationCode(code)
        case let .mfaRequired(challenge):
            throw PorscheAuthError.mfaRequired(challenge)
        }
    }

    func exchangeAuthorizationCode(_ authorizationCode: String) async throws -> PorscheTokenSet {
        let response: PorscheTokenResponse = try await formRequest(
            endpoint: PorscheApiEndpoint.token,
            form: [
                "client_id": configuration.authClientId,
                "grant_type": "authorization_code",
                "code": authorizationCode,
                "redirect_uri": configuration.redirectUri,
            ]
        )
        return response.tokenSet(obtainedAt: now())
    }

    func refreshToken(_ refreshToken: String) async throws -> PorscheTokenSet {
        let response: PorscheTokenResponse = try await formRequest(
            endpoint: PorscheApiEndpoint.token,
            form: [
                "client_id": configuration.authClientId,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
            ]
        )
        return response.tokenSet(obtainedAt: now())
    }

    func parseAuthorizationCallback(_ callback: URL) throws -> PorscheAuthorizationCallback {
        try parseRedirect(callback)
    }

    func authorizationCallback(from url: URL) throws -> AuthorizationCallback? {
        let callbackURL = URL(string: configuration.redirectUri)
        guard url.scheme == callbackURL?.scheme, url.host == callbackURL?.host,
              url.path == callbackURL?.path else { return nil }
        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "state" })?.value ?? ""
        switch try parseRedirect(url) {
        case let .authorizationCode(code):
            return (code, state, true)
        case let .mfaRequired(challenge):
            throw PorscheAuthError.mfaRequired(challenge)
        }
    }

    func mapMFASubmitResult(_ result: PorscheMFASubmitResult) throws {
        switch result {
        case .success:
            return
        case .invalidCode:
            throw PorscheAuthError.invalidMFACode
        }
    }

    private func authorize(state: String) async throws -> URL {
        let request = try request(url: makeAuthorizeURL(state: state))
        let response = try await send(request, accept: [302])
        return try redirectURL(from: response.response)
    }

    private func submitIdentifier(username: String, state: String) async throws {
        let response = try await send(
            request(
                endpoint: PorscheApiEndpoint.loginIdentifier,
                queryItems: [.init(name: "state", value: state)],
                form: [
                    "state": state,
                    "username": username,
                    "js-available": "true",
                    "webauthn-available": "false",
                    "is-brave": "false",
                    "webauthn-platform-available": "false",
                    "action": "default",
                ]
            ),
            accept: [200, 204, 400, 401]
        )

        switch response.response.statusCode {
        case 200, 204:
            return
        case 400:
            if let html = String(data: response.data, encoding: .utf8), html.localizedCaseInsensitiveContains("captcha") {
                throw PorscheApiError.blockedByCaptchaOrDeviceBinding
            }
            throw PorscheAuthError.backendError("identifier_failed")
        case 401:
            throw PorscheAuthError.invalidCredentials
        default:
            throw ApiError.unexpectedStatusCode(response.response.statusCode)
        }
    }

    private func submitPassword(username: String, password: String, state: String) async throws -> URL {
        let response = try await send(
            request(
                endpoint: PorscheApiEndpoint.loginPassword,
                queryItems: [.init(name: "state", value: state)],
                form: [
                    "state": state,
                    "username": username,
                    "password": password,
                    "action": "default",
                ]
            ),
            accept: [302, 400]
        )

        if response.response.statusCode == 400 {
            throw PorscheAuthError.invalidCredentials
        }
        return try redirectURL(from: response.response)
    }

    private func resumeAuthorization(from redirect: URL) async throws -> URL {
        let request = try request(url: absoluteIdentityURL(for: redirect))
        let response = try await send(request, accept: [302])
        return try redirectURL(from: response.response)
    }

    private func parseRedirect(_ redirect: URL) throws -> PorscheAuthorizationCallback {
        if let challenge = mfaChallenge(from: redirect) {
            return .mfaRequired(challenge)
        }

        guard let components = URLComponents(url: redirect, resolvingAgainstBaseURL: false) else {
            throw PorscheAuthError.invalidRedirect
        }
        let queryItems = components.queryItems ?? []

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            if error == "mfa_required" {
                let state = queryItems.first(where: { $0.name == "state" })?.value ?? ""
                return .mfaRequired(.init(state: state, challengeType: "otp"))
            }
            throw PorscheAuthError.backendError(error)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw PorscheAuthError.missingAuthorizationCode
        }
        return .authorizationCode(code)
    }

    private func formRequest<Response: Decodable>(endpoint: PorscheApiEndpoint, form: [String: String]) async throws -> Response {
        let request = request(endpoint: endpoint, form: form)
        let response = try await send(request, accept: [200])
        do {
            return try JSONDecoder().decode(Response.self, from: response.data)
        } catch {
            throw PorscheApiError.decodingFailed(error.localizedDescription)
        }
    }

    private func send(_ request: URLRequest, accept statusCodes: Set<Int>) async throws -> PorscheHTTPTransportResponse {
        let response = try await transport(request)
        guard statusCodes.contains(response.response.statusCode) else {
            if response.response.statusCode == 401 {
                throw ApiError.unauthorized
            }
            throw ApiError.unexpectedStatusCode(response.response.statusCode)
        }
        return response
    }

    private func request(
        endpoint: PorscheApiEndpoint,
        queryItems: [URLQueryItem] = [],
        form: [String: String]? = nil
    ) -> URLRequest {
        let baseURL = try! configuration.url(for: endpoint)
        return request(url: baseURL, queryItems: queryItems, form: form)
    }

    private func request(
        url: URL,
        queryItems: [URLQueryItem] = [],
        form: [String: String]? = nil
    ) -> URLRequest {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty {
            var mergedItems = components.queryItems ?? []
            mergedItems.append(contentsOf: queryItems)
            components.queryItems = mergedItems
        }

        var request = URLRequest(url: components.url ?? url)
        request.httpMethod = form == nil ? "GET" : "POST"
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(configuration.xClientId, forHTTPHeaderField: "X-Client-ID")
        if let form {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let body = form
                .sorted(by: { $0.key < $1.key })
                .map { key, value in
                    "\(percentEncode(key))=\(percentEncode(value))"
                }
                .joined(separator: "&")
            request.httpBody = body.data(using: .utf8)
        }
        return request
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(.init(charactersIn: "+&=?"))) ?? value
    }

    private func redirectURL(from response: HTTPURLResponse) throws -> URL {
        guard let location = response.value(forHTTPHeaderField: "Location"),
              let url = URL(string: location)
        else {
            if let location = response.value(forHTTPHeaderField: "Location") {
                return absoluteIdentityURL(for: URL(string: location)!)
            }
            throw PorscheAuthError.invalidRedirect
        }
        return absoluteIdentityURL(for: url)
    }

    private func absoluteIdentityURL(for url: URL) -> URL {
        if url.host != nil {
            return url
        }
        return URL(string: url.relativeString, relativeTo: URL(string: configuration.loginHost)) ?? url
    }

    private func queryValue(named name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private func mfaChallenge(from redirect: URL) -> PorscheMFAChallenge? {
        if redirect.path.contains("mfa-otp-challenge") {
            let state = queryValue(named: "state", in: redirect) ?? ""
            return .init(state: state, challengeType: "otp")
        }
        if queryValue(named: "error", in: redirect) == "mfa_required" {
            let state = queryValue(named: "state", in: redirect) ?? ""
            return .init(state: state, challengeType: "otp")
        }
        return nil
    }
}
