//
//  ApiRequest.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

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
        case .unexpectedStatusCode(let int):
            "unexpectedStatusCode:\(String(describing: int))"
        case .unauthorized:
            "unauthorized"
        }
    }
}

struct ApiRequest {
    typealias Headers = [String: String]
    typealias Form = [String: String]
    
    static let DefaultTimeout: TimeInterval = 60
    
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
    }
    
    let caller: ApiRequestProvider.Caller
    let method: Method
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
    
    static func url(for endpoint: ApiEndpoint, configuration: ApiConfiguration) throws -> URL {
        let result: URL?
        let (path, base) = endpoint.path
        switch base {
        case .base:
            result = URL(string: path, relativeTo: baseUrl(for: configuration))
        case .login:
            result = URL(string: path, relativeTo: loginUrl(for: configuration))
        case .spa:
            result = URL(string: path, relativeTo: spaUrl(for: configuration))
        case .user:
            result = URL(string: path, relativeTo: userUrl(for: configuration))
        }
        guard let result = result else { throw URLError(.badURL) }
        return result
    }
    
    
    init(
        caller: ApiRequestProvider.Caller,
        method: Method?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval
    ) throws {
        var headers = headers
        if headers["Content-type"] == nil {
            headers["Content-type"] = "application/json"
        }
        headers["User-Agent"] = caller.configuration.userAgent
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = try JSONEncoders.default.encode(encodable)
        self.timeout = timeout
    }
    
    init(
        caller: ApiRequestProvider.Caller,
        method: Method?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval
    ) {
        var headers = headers
        headers["User-Agent"] = caller.configuration.userAgent
        self.caller = caller
        self.method = method ?? (body == nil ? .get : .post)
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
    
    init(
        caller: ApiRequestProvider.Caller,
        method: Method?,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval
    ) {
        var headers = headers
        headers["User-Agent"] = caller.configuration.userAgent
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        let formData = form
            .map { ($0.key + "=" + $0.value).addingPercentEncoding(withAllowedCharacters: Self.formCharset) ?? "" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = formData
        self.timeout = timeout
    }
    
    var urlRequest: URLRequest {
        get throws {
            var url = try Self.url(for: endpoint, configuration: caller.configuration)
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
    
    func response<Data: Decodable>(acceptStatusCode: Int = 200) async throws -> Data {
        let response: ApiResponse<Data> = try await data(acceptStatusCode: acceptStatusCode)
        return response.result
    }
    
    func empty(acceptStatusCode: Int = 204) async throws {
        try await callRequest(acceptStatusCode: acceptStatusCode)
    }
    
    func string(acceptStatusCode: Int = 200) async throws -> String {
        let (data, _) = try await callRequest(acceptStatusCode: acceptStatusCode)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        print("\(endpoint) - result: \(string)")
        return string
    }
    
    func data<Data: Decodable>(acceptStatusCode: Int = 200) async throws -> Data {
        let (data, _) = try await callRequest(acceptStatusCode: acceptStatusCode)
        let result = try JSONDecoders.default.decode(Data.self, from: data)
        print("\(endpoint) - result: \(result)")
        return result
    }
    
    func referalUrl(acceptStatusCode: Int = 302) async throws -> URL {
        let (_, response) = try await callRequest(acceptStatusCode: acceptStatusCode)
        guard let response = response as? HTTPURLResponse, let location = response.allHeaderFields["Location"] as? String, let url = URL(string: location) else {
            throw URLError(.cannotDecodeContentData)
        }
        return url
    }

    private static func baseUrl(for configuration: ApiConfiguration) -> URL? {
        URL(string: configuration.baseUrl + ":\(configuration.port)" + "/api/v1/")
    }
    
    private static func loginUrl(for configuration: ApiConfiguration) -> URL? {
        URL(string: configuration.loginUrl + "/auth/realms/eu" + configuration.key + "idm/")
    }
    
    private static func spaUrl(for configuration: ApiConfiguration) -> URL? {
        URL(string: configuration.baseUrl + ":\(configuration.port)" + "/api/v1/spa/")
    }
    
    private static func userUrl(for configuration: ApiConfiguration) -> URL? {
        URL(string: configuration.baseUrl + ":\(configuration.port)" + "/api/v1/user/")
    }
        
    @discardableResult
    private func callRequest(acceptStatusCode: Int) async throws -> (Data, URLResponse) {
        let urlRequest = try self.urlRequest
        print("\(endpoint) - request: \(String(describing: urlRequest.url)) \(String(describing: urlRequest.allHTTPHeaderFields))")
        
        let (data, response) = try await caller.urlSession.data(for: urlRequest)
        print("\(endpoint) - response: \(response)")
        
        guard (200...399).contains(response.status ?? 0) else {
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

class ApiRequestProvider: NSObject {
    struct Caller {
        let configuration: ApiConfiguration
        let urlSession: URLSession
        let authorization: AuthorizationData?
    }
    
    var authorization: AuthorizationData?
    
    private let configuration: ApiConfiguration
    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var caller: Caller {
        .init(configuration: configuration, urlSession: urlSession, authorization: authorization)
    }
    
    init(configuration: ApiConfiguration) {
        self.configuration = configuration
    }
    
    func request(
        with method: ApiRequest.Method? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        encodable: Encodable,
        timeout: TimeInterval = ApiRequest.DefaultTimeout
    ) throws -> ApiRequest {
        try ApiRequest(
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
        with method: ApiRequest.Method? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        body: Data? = nil,
        timeout: TimeInterval = ApiRequest.DefaultTimeout
    ) -> ApiRequest {
        ApiRequest(
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
        with method: ApiRequest.Method? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        string: String,
        timeout: TimeInterval = ApiRequest.DefaultTimeout
    ) -> ApiRequest {
        ApiRequest(
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
        with method: ApiRequest.Method? = nil,
        endpoint: ApiEndpoint,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        form: ApiRequest.Form,
        timeout: TimeInterval = ApiRequest.DefaultTimeout
    ) -> ApiRequest {
        ApiRequest(
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
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let lastPathComponent = task.originalRequest?.url?.lastPathComponent
        if ["authenticate"].contains(lastPathComponent) {
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }
}
