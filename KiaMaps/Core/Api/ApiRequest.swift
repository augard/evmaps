//
//  ApiRequest.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

public enum JSONDecoders {
    public static let `default`: JSONDecoder = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()
}

enum JSONEncoders {
    public static let `default`: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

enum ApiError: Error {
    case noData
    case unexpectedStatusCode(Int?)
    case unauthorized

    var localizedDescription: String {
        switch self {
        case .noData:
            "noData"
        case let .unexpectedStatusCode(int):
            "unexpectedStatusCode:\(String(describing: int))"
        case .unauthorized:
            "unauthorized"
        }
    }
}

enum ApiMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

let ApiDefaultTimeout: TimeInterval = 60

extension ApiConfiguration {
    func url(for endpoint: ApiEndpoint) throws -> URL {
        let result: URL?
        let (path, base) = endpoint.path
        switch base {
        case .base:
            result = URL(string: path, relativeTo: baseUrl)
        case .login:
            result = URL(string: path, relativeTo: loginUrl)
        case .spa:
            result = URL(string: path, relativeTo: spaUrl)
        case .user:
            result = URL(string: path, relativeTo: userUrl)
        }
        guard let result = result else { throw URLError(.badURL) }
        return result
    }

    private var baseUrl: URL? {
        URL(string: baseHost + ":\(port)")
    }

    private var loginUrl: URL? {
        URL(string: loginHost)
    }

    private var spaUrl: URL? {
        URL(string: baseHost + ":\(port)" + "/api/v1/spa/")
    }

    private var userUrl: URL? {
        URL(string: baseHost + ":\(port)" + "/api/v1/user/")
    }
}

protocol ApiRequest {
    typealias Headers = [String: String]
    typealias Form = [String: String]

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval
    ) throws

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval
    )

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval
    )

    var urlRequest: URLRequest { get throws }

    func response<Data: Decodable>() async throws -> Data
    func response<Data: Decodable>(acceptStatusCode: Int) async throws -> Data

    func responseValue<Data: Decodable>() async throws -> Data
    func responseValue<Data: Decodable>(acceptStatusCode: Int) async throws -> Data

    func responseEmpty() async throws -> ApiResponseEmpty
    func responseEmpty(acceptStatusCode: Int) async throws -> ApiResponseEmpty

    func empty() async throws
    func empty(acceptStatusCode: Int) async throws

    func string() async throws -> String
    func string(acceptStatusCode: Int) async throws -> String

    func httpResponse() async throws -> HTTPURLResponse
    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse

    func data<Data: Decodable>() async throws -> Data
    func data<Data: Decodable>(acceptStatusCode: Int) async throws -> Data

    func referalUrl() async throws -> URL
    func referalUrl(acceptStatusCode: Int) async throws -> URL
}

extension ApiRequest {
    static var commonJsonHeaders: Headers {
        var headers: Headers = [:]
        headers["Content-type"] = "application/json"
        headers["Accept"] = "application/json"
        return headers
    }

    static var commonFormHeaders: Headers {
        var headers: Headers = [:]
        headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"
        return headers
    }

    func response<Data: Decodable>() async throws -> Data {
        try await response(acceptStatusCode: 200)
    }

    func responseValue<Data: Decodable>() async throws -> Data {
        try await responseValue(acceptStatusCode: 200)
    }

    func responseEmpty() async throws -> ApiResponseEmpty {
        try await responseEmpty(acceptStatusCode: 200)
    }

    func empty() async throws {
        try await empty(acceptStatusCode: 204)
    }

    func string() async throws -> String {
        try await string(acceptStatusCode: 200)
    }

    func httpResponse() async throws -> HTTPURLResponse {
        try await httpResponse(acceptStatusCode: 200)
    }

    func data<Data: Decodable>() async throws -> Data {
        try await data(acceptStatusCode: 200)
    }

    func referalUrl() async throws -> URL {
        try await referalUrl(acceptStatusCode: 302)
    }
}

struct ApiRequestImpl: ApiRequest {
    let caller: ApiCaller
    let method: ApiMethod
    let endpoint: ApiEndpoint
    let queryItems: [URLQueryItem]
    let headers: Headers
    let body: Data?
    let timeout: TimeInterval

    private static let formCharset: CharacterSet = {
        var charset = CharacterSet.alphanumerics
        charset.insert("=")
        charset.insert("&")
        charset.insert("-")
        charset.insert(".")
        return charset
    }()

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval
    ) throws {
        var headers = headers
        if headers["Content-type"] == nil {
            headers.merge(Self.commonJsonHeaders) { _, new in new }
        }
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-GB,en;q=0.9"
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = try JSONEncoders.default.encode(encodable)
        self.timeout = timeout
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval
    ) {
        var headers = headers
        if headers["Content-type"] == nil {
            headers.merge(Self.commonJsonHeaders) { _, new in new }
        }
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-GB,en;q=0.9"
        self.caller = caller
        self.method = method ?? (body == nil ? .get : .post)
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval
    ) {
        var headers = Self.commonFormHeaders
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-GB,en;q=0.9"
        let formData = form
            .map { ($0.key + "=" + $0.value).addingPercentEncoding(withAllowedCharacters: Self.formCharset) ?? "" }
            .joined(separator: "&")
            .data(using: .utf8)

        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = formData
        self.timeout = timeout
    }

    var urlRequest: URLRequest {
        get throws {
            var url = try caller.configuration.url(for: endpoint)
            if !queryItems.isEmpty {
                url.append(queryItems: queryItems)
            }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
            request.httpMethod = method.rawValue
            var headers = self.headers
            if let authorization = caller.authorization {
                for (key, value) in authorization.authorizatioHeaders(for: caller.configuration) {
                    headers[key] = value
                }
            }
            request.allHTTPHeaderFields = headers
            request.httpBody = body
            return request
        }
    }

    func response<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        let response: ApiResponse<Data> = try await data(acceptStatusCode: acceptStatusCode)
        return response.result
    }

    func responseValue<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        let response: ApiResponseValue<Data> = try await data(acceptStatusCode: acceptStatusCode)
        return response.returnValue
    }

    func responseEmpty(acceptStatusCode: Int) async throws -> ApiResponseEmpty {
        try await data(acceptStatusCode: acceptStatusCode)
    }

    func empty(acceptStatusCode: Int) async throws {
        try await callRequest(acceptStatusCode: acceptStatusCode)
    }

    func string(acceptStatusCode: Int) async throws -> String {
        let (data, _) = try await callRequest(acceptStatusCode: acceptStatusCode)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        os_log(.debug, log: Logger.api, "%{public}@ - result: %{public}@", String(describing: endpoint), string)
        return string
    }

    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse {
        let (_, response) = try await callRequest(acceptStatusCode: acceptStatusCode)
        os_log(.debug, log: Logger.api, "%{public}@ - result: %{public}@", String(describing: endpoint), String(describing: response))
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.cannotDecodeContentData)
        }
        return response
    }

    func data<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        let (data, _) = try await callRequest(acceptStatusCode: acceptStatusCode)
        let result = try JSONDecoders.default.decode(Data.self, from: data)
        os_log(.debug, log: Logger.api, "%{public}@ - result: %{public}@", String(describing: endpoint), String(describing: result))
        return result
    }

    func referalUrl(acceptStatusCode: Int) async throws -> URL {
        let httpResponse = try await httpResponse(acceptStatusCode: acceptStatusCode)
        guard let location = httpResponse.allHeaderFields["Location"] as? String,
              let url = URL(string: location)
        else {
            throw URLError(.cannotDecodeContentData)
        }
        return url
    }

    @discardableResult
    private func callRequest(acceptStatusCode: Int) async throws -> (Data, URLResponse) {
        let urlRequest = try self.urlRequest
        os_log(.debug, log: Logger.api, "%{public}@ - request: %{public}@ %{public}@", String(describing: endpoint), String(describing: urlRequest.url), String(describing: urlRequest.allHTTPHeaderFields))

        let (data, response) = try await caller.urlSession.data(for: urlRequest)
        os_log(.debug, log: Logger.api, "%{public}@ - response: %{public}@", String(describing: endpoint), String(describing: response))

        guard (200 ... 399).contains(response.status ?? 0) else {
            if response.status == 401 {
                throw ApiError.unauthorized
            } else {
                throw ApiError.unexpectedStatusCode(response.status)
            }
        }

        guard acceptStatusCode == acceptStatusCode else {
            throw ApiError.unexpectedStatusCode(response.status)
        }
        return (data, response)
    }
}

protocol ApiCaller {
    var configuration: ApiConfiguration { get }
    var urlSession: URLSession { get }
    var authorization: AuthorizationData? { get }

    init(configuration: ApiConfiguration, urlSession: URLSession, authorization: AuthorizationData?)
}

class ApiRequestProvider: NSObject {
    private struct Caller: ApiCaller {
        let configuration: ApiConfiguration
        let urlSession: URLSession
        let authorization: AuthorizationData?

        init(configuration: ApiConfiguration, urlSession: URLSession, authorization: AuthorizationData?) {
            self.configuration = configuration
            self.urlSession = urlSession
            self.authorization = authorization
        }
    }

    var authorization: AuthorizationData?
    var caller: ApiCaller {
        callerType.init(configuration: configuration, urlSession: urlSession, authorization: authorization)
    }
    
    let configuration: ApiConfiguration
    let callerType: ApiCaller.Type
    let requestType: ApiRequest.Type

    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    init(
        configuration: ApiConfiguration,
        callerType: ApiCaller.Type = Caller.self,
        requestType: ApiRequest.Type = ApiRequestImpl.self
    ) {
        self.configuration = configuration
        self.callerType = callerType
        self.requestType = requestType
    }

    func request(
        with method: ApiMethod? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        encodable: Encodable,
        timeout: TimeInterval = ApiDefaultTimeout
    ) throws -> ApiRequest {
        try requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            encodable: encodable,
            timeout: timeout
        )
    }

    func request(
        with method: ApiMethod? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        body: Data? = nil,
        timeout: TimeInterval = ApiDefaultTimeout
    ) -> ApiRequest {
        requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            body: body,
            timeout: timeout
        )
    }

    func request(
        with method: ApiMethod? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        string: String,
        timeout: TimeInterval = ApiDefaultTimeout
    ) -> ApiRequest {
        requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            body: string.data(using: .utf8),
            timeout: timeout
        )
    }

    func request(
        with method: ApiMethod? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        form: ApiRequest.Form,
        timeout: TimeInterval = ApiDefaultTimeout
    ) -> ApiRequest {
        requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            form: form,
            timeout: timeout
        )
    }

    @discardableResult
    func data(url: URL) async throws -> Data {
        let urlRequest = URLRequest(url: url)
        let (data, _) = try await caller.urlSession.data(for: urlRequest)
        return data
    }
}

extension ApiRequestProvider: URLSessionTaskDelegate {
    func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let lastPathComponent = task.originalRequest?.url?.lastPathComponent
        if ["signin", "authorize"].contains(lastPathComponent) {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}

