//
//  ApiRequest.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Centralized JSON decoders for consistent date parsing across the app
public enum JSONDecoders {
    /// Default JSON decoder with custom date formatting for API responses
    public static let `default`: JSONDecoder = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }()
}

/// Centralized JSON encoders for consistent API request formatting
enum JSONEncoders {
    /// Default JSON encoder with ISO8601 dates and sorted keys for debugging
    public static let `default`: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

/// API-specific errors that can occur during HTTP requests
enum ApiError: Error {
    /// No data received in response
    case noData
    /// Unexpected HTTP status code received
    case unexpectedStatusCode(Int?)
    /// Authentication failed (401 status)
    case unauthorized

    /// Human-readable error descriptions
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

/// HTTP methods supported by the API client
enum ApiMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

/// Default timeout for API requests in seconds
let ApiDefaultTimeout: TimeInterval = 60

extension ApiConfiguration {
    /// Generates the complete URL for a given API endpoint
    /// - Parameter endpoint: The endpoint to generate URL for
    /// - Returns: Complete URL for the endpoint
    /// - Throws: URLError.badURL if URL construction fails
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

    /// Base API URL constructed from host and port
    private var baseUrl: URL? {
        URL(string: baseHost + ":\(port)")
    }

    /// Login URL for authentication flows
    private var loginUrl: URL? {
        URL(string: loginHost)
    }

    /// Single Page Application API URL
    private var spaUrl: URL? {
        URL(string: baseHost + ":\(port)" + "/api/v1/spa/")
    }

    /// User-specific API URL
    private var userUrl: URL? {
        URL(string: baseHost + ":\(port)" + "/api/v1/user/")
    }
}

/// Protocol defining the interface for HTTP API requests with various response types
/// Supports JSON, form data, and raw body requests with flexible response handling
protocol ApiRequest {
    /// Type alias for HTTP headers dictionary
    typealias Headers = [String: String]
    /// Type alias for form data dictionary
    typealias Form = [String: String]

    /// Initializer for requests with Codable body data
    /// - Parameters:
    ///   - caller: API caller with configuration and authentication
    ///   - method: HTTP method (defaults to POST for body data)
    ///   - endpoint: API endpoint to call
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - encodable: Codable object to encode as JSON body
    ///   - timeout: Request timeout in seconds
    /// - Throws: Encoding errors if encodable cannot be serialized
    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval
    ) throws

    /// Initializer for requests with raw Data body
    /// - Parameters:
    ///   - caller: API caller with configuration and authentication
    ///   - method: HTTP method (defaults based on body presence)
    ///   - endpoint: API endpoint to call
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - body: Raw data for request body
    ///   - timeout: Request timeout in seconds
    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval
    )

    /// Initializer for form-encoded requests
    /// - Parameters:
    ///   - caller: API caller with configuration and authentication
    ///   - method: HTTP method (defaults to POST)
    ///   - endpoint: API endpoint to call
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - form: Form data dictionary
    ///   - timeout: Request timeout in seconds
    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval
    )

    /// The configured URLRequest ready for execution
    var urlRequest: URLRequest { get throws }

    /// Executes request expecting 200 status and ApiResponse wrapper
    func response<Data: Decodable>() async throws -> Data
    /// Executes request with custom status code and ApiResponse wrapper
    func response<Data: Decodable>(acceptStatusCode: Int) async throws -> Data

    /// Executes request expecting 200 status and ApiResponseValue wrapper
    func responseValue<Data: Decodable>() async throws -> Data
    /// Executes request with custom status code and ApiResponseValue wrapper
    func responseValue<Data: Decodable>(acceptStatusCode: Int) async throws -> Data

    /// Executes request expecting 200 status and empty response
    func responseEmpty() async throws -> ApiResponseEmpty
    /// Executes request with custom status code and empty response
    func responseEmpty(acceptStatusCode: Int) async throws -> ApiResponseEmpty

    /// Executes request expecting 204 status with no response data
    func empty() async throws
    /// Executes request with custom status code and no response data
    func empty(acceptStatusCode: Int) async throws

    /// Executes request expecting 200 status and returns raw string
    func string() async throws -> String
    /// Executes request with custom status code and returns raw string
    func string(acceptStatusCode: Int) async throws -> String

    /// Executes request expecting 200 status and returns HTTPURLResponse
    func httpResponse() async throws -> HTTPURLResponse
    /// Executes request with custom status code and returns HTTPURLResponse
    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse

    /// Executes request expecting 200 status and returns decoded data directly
    func data<Data: Decodable>() async throws -> Data
    /// Executes request with custom status code and returns decoded data directly
    func data<Data: Decodable>(acceptStatusCode: Int) async throws -> Data

    /// Executes request expecting 302 redirect and returns redirect URL
    func referalUrl() async throws -> URL
    /// Executes request with custom status code and returns redirect URL
    func referalUrl(acceptStatusCode: Int) async throws -> URL
}

extension ApiRequest {
    /// Standard headers for JSON requests
    static var commonJsonHeaders: Headers {
        var headers: Headers = [:]
        headers["Content-type"] = "application/json"
        headers["Accept"] = "application/json"
        return headers
    }

    /// Standard headers for form-encoded requests
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

/// Concrete implementation of ApiRequest protocol
/// Handles HTTP request construction, execution, and response parsing
struct ApiRequestImpl: ApiRequest {
    /// API caller providing configuration and authentication
    let caller: ApiCaller
    /// HTTP method for the request
    let method: ApiMethod
    /// API endpoint to call
    let endpoint: ApiEndpoint
    /// URL query parameters
    let queryItems: [URLQueryItem]
    /// HTTP headers
    let headers: Headers
    /// Request body data
    let body: Data?
    /// Request timeout in seconds
    let timeout: TimeInterval

    /// Character set used for form data encoding
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
        os_log(.debug, log: Logger.api, "%{public}@ - result: %{private}@", String(describing: endpoint), string)
        return string
    }

    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse {
        let (_, response) = try await callRequest(acceptStatusCode: acceptStatusCode)
        os_log(.debug, log: Logger.api, "%{public}@ - result: %{private}@", String(describing: endpoint), String(describing: response))
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.cannotDecodeContentData)
        }
        return response
    }

    func data<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        let (data, _) = try await callRequest(acceptStatusCode: acceptStatusCode)
        let result = try JSONDecoders.default.decode(Data.self, from: data)
        os_log(.debug, log: Logger.api, "%{public}@ - result: %{private}@", String(describing: endpoint), String(describing: result))
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
        os_log(.debug, log: Logger.api, "%{public}@ - request: %{private}@ %{private}@", String(describing: endpoint), String(describing: urlRequest.url), String(describing: urlRequest.allHTTPHeaderFields))

        let (data, response) = try await caller.urlSession.data(for: urlRequest)
        os_log(.debug, log: Logger.api, "%{public}@ - response: %{private}@", String(describing: endpoint), String(describing: response))

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

/// Protocol defining the context needed for API requests
/// Provides configuration, network session, and authentication data
protocol ApiCaller {
    /// API configuration with endpoints and credentials
    var configuration: ApiConfiguration { get }
    /// URL session for network requests
    var urlSession: URLSession { get }
    /// Optional authorization data for authenticated requests
    var authorization: AuthorizationData? { get }

    /// Initializer for API caller instances
    /// - Parameters:
    ///   - configuration: API configuration
    ///   - urlSession: URL session for requests
    ///   - authorization: Optional authorization data
    init(configuration: ApiConfiguration, urlSession: URLSession, authorization: AuthorizationData?)
}

/// Main API request factory and provider
/// Manages URL session, configuration, and creates typed requests
class ApiRequestProvider: NSObject {
    /// Default implementation of ApiCaller protocol
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

    /// Current authorization data for requests
    var authorization: AuthorizationData?
    /// Creates caller instances with current state
    var caller: ApiCaller {
        callerType.init(configuration: configuration, urlSession: urlSession, authorization: authorization)
    }
    
    /// API configuration for endpoints and settings
    let configuration: ApiConfiguration
    /// Type of caller to create (for dependency injection)
    let callerType: ApiCaller.Type
    /// Type of request to create (for dependency injection)
    let requestType: ApiRequest.Type

    /// Shared URL session with custom delegate for redirect handling
    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    /// Initializes the API request provider
    /// - Parameters:
    ///   - configuration: API configuration
    ///   - callerType: Type of caller to create (defaults to internal Caller)
    ///   - requestType: Type of request to create (defaults to ApiRequestImpl)
    init(
        configuration: ApiConfiguration,
        callerType: ApiCaller.Type = Caller.self,
        requestType: ApiRequest.Type = ApiRequestImpl.self
    ) {
        self.configuration = configuration
        self.callerType = callerType
        self.requestType = requestType
    }

    /// Creates a request with a Codable body
    /// - Parameters:
    ///   - method: HTTP method (optional)
    ///   - endpoint: API endpoint
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - encodable: Object to encode as JSON body
    ///   - timeout: Request timeout
    /// - Returns: Configured API request
    /// - Throws: Encoding errors
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

    /// Creates a request with raw Data body
    /// - Parameters:
    ///   - method: HTTP method (optional)
    ///   - endpoint: API endpoint
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - body: Raw body data
    ///   - timeout: Request timeout
    /// - Returns: Configured API request
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

    /// Creates a request with string body
    /// - Parameters:
    ///   - method: HTTP method (optional)
    ///   - endpoint: API endpoint
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - string: String to encode as UTF-8 body
    ///   - timeout: Request timeout
    /// - Returns: Configured API request
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

    /// Creates a request with form-encoded body
    /// - Parameters:
    ///   - method: HTTP method (optional)
    ///   - endpoint: API endpoint
    ///   - queryItems: URL query parameters
    ///   - headers: HTTP headers
    ///   - form: Form data dictionary
    ///   - timeout: Request timeout
    /// - Returns: Configured API request
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

    /// Fetches raw data from a URL without API configuration
    /// - Parameter url: URL to fetch data from
    /// - Returns: Raw response data
    /// - Throws: Network errors
    @discardableResult
    func data(url: URL) async throws -> Data {
        let urlRequest = URLRequest(url: url)
        let (data, _) = try await caller.urlSession.data(for: urlRequest)
        return data
    }
}

extension ApiRequestProvider: URLSessionTaskDelegate {
    /// Handles HTTP redirects, preventing automatic redirects for authentication endpoints
    /// - Parameters:
    ///   - session: The URL session
    ///   - task: The URL session task
    ///   - response: The HTTP response triggering the redirect
    ///   - request: The proposed new request
    ///   - completionHandler: Completion handler with the request to follow (nil to prevent redirect)
    func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let lastPathComponent = task.originalRequest?.url?.lastPathComponent
        if ["signin", "authorize"].contains(lastPathComponent) {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}

