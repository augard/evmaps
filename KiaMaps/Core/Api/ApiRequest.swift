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
enum ApiError: LocalizedError {
    /// No data received in response
    case noData
    /// Unexpected HTTP status code received
    case unexpectedStatusCode(Int?)
    /// Authentication failed (401 status)
    case unauthorized
    /// Feature unavailable for active API provider
    case unsupported(String)

    var errorDescription: String? { localizedDescription }

    /// Human-readable error descriptions
    var localizedDescription: String {
        switch self {
        case .noData:
            "noData"
        case let .unexpectedStatusCode(int):
            "unexpectedStatusCode:\(String(describing: int))"
        case .unauthorized:
            "unauthorized"
        case let .unsupported(message):
            message
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
    func url(for endpoint: any ApiEndpointProtocol) throws -> URL {
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
        case .mqtt:
            result = URL(string: path, relativeTo: mqttUrl)
        }
        guard let result = result else { throw URLError(.badURL) }
        return result
    }

    /// Base API URL constructed from host and port
    private var baseUrl: URL? {
        if let configuration = self as? PorscheApiConfiguration {
            let normalizedBase = configuration.appApiBaseURL.hasSuffix("/") ? configuration.appApiBaseURL : configuration.appApiBaseURL + "/"
            return URL(string: normalizedBase)
        }
        return URL(string: baseHost + ":\(port)")
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
        if let configuration = self as? PorscheApiConfiguration {
            let normalizedBase = configuration.loginHost.hasSuffix("/") ? configuration.loginHost : configuration.loginHost + "/"
            return URL(string: normalizedBase)
        }
        return URL(string: baseHost + ":\(port)" + "/api/v1/user/")
    }

    /// MQTT API URL
    private var mqttUrl: URL? {
        URL(string: mqttHost)
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
    ///   - authorization: If we should set authorization header
    /// - Throws: Encoding errors if encodable cannot be serialized
    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval,
        authorization: Bool
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
    ///   - authorization: If we should set authorization header
    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval,
        authorization: Bool
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
    ///   - authorization: If we should set authorization header
    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval,
        authorization: Bool
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
    /// Executes request with accepted status codes and returns raw string
    func string(acceptStatusCodes: Set<Int>) async throws -> String

    /// Executes request expecting 200 status and returns HTTPURLResponse
    func httpResponse() async throws -> HTTPURLResponse
    /// Executes request with custom status code and returns HTTPURLResponse
    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse
    /// Executes request with accepted status codes and returns HTTPURLResponse
    func httpResponse(acceptStatusCodes: Set<Int>) async throws -> HTTPURLResponse

    /// Executes request expecting 200 status and returns decoded data directly
    func data<Data: Decodable>() async throws -> Data
    /// Executes request with custom status code and returns decoded data directly
    func data<Data: Decodable>(acceptStatusCode: Int) async throws -> Data
    /// Executes request with accepted status codes and returns decoded data directly
    func data<Data: Decodable>(acceptStatusCodes: Set<Int>) async throws -> Data
    /// Executes request with accepted status codes and returns raw body data
    func rawData(acceptStatusCodes: Set<Int>) async throws -> Data

    /// Executes request expecting 302 redirect and returns redirect URL
    func referalUrl() async throws -> URL
    /// Executes request with custom status code and returns redirect URL
    func referalUrl(acceptStatusCode: Int) async throws -> URL
    /// Executes request with accepted status codes and returns redirect URL
    func referalUrl(acceptStatusCodes: Set<Int>) async throws -> URL
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

    func string(acceptStatusCode: Int) async throws -> String {
        try await string(acceptStatusCodes: [acceptStatusCode])
    }

    func httpResponse() async throws -> HTTPURLResponse {
        try await httpResponse(acceptStatusCode: 200)
    }

    func httpResponse(acceptStatusCode: Int) async throws -> HTTPURLResponse {
        try await httpResponse(acceptStatusCodes: [acceptStatusCode])
    }

    func data<Data: Decodable>() async throws -> Data {
        try await data(acceptStatusCode: 200)
    }

    func data<Data: Decodable>(acceptStatusCode: Int) async throws -> Data {
        try await data(acceptStatusCodes: [acceptStatusCode])
    }

    func referalUrl() async throws -> URL {
        try await referalUrl(acceptStatusCode: 302)
    }

    func referalUrl(acceptStatusCode: Int) async throws -> URL {
        try await referalUrl(acceptStatusCodes: [acceptStatusCode])
    }
}
