import Foundation

/// Concrete implementation of ApiRequest protocol
/// Handles HTTP request construction, execution, and response parsing
struct ApiRequestImpl: ApiRequest {
    /// API caller providing configuration and authentication
    let caller: ApiCaller
    /// HTTP method for the request
    let method: ApiMethod
    /// API endpoint to call
    let endpoint: any ApiEndpointProtocol
    /// URL query parameters
    let queryItems: [URLQueryItem]
    /// HTTP headers
    let headers: Headers
    /// Request body data
    let body: Data?
    /// Request timeout in seconds
    let timeout: TimeInterval
    /// If we should set authorization header
    let authorization: Bool

    /// Character set used for form data encoding
    static func encodeForm(_ form: Form) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return Data(form.sorted { $0.key < $1.key }.map { key, value in
            let key = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            let value = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(key)=\(value)"
        }.joined(separator: "&").utf8)
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        encodable: Encodable,
        timeout: TimeInterval,
        authorization: Bool
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
        self.authorization = authorization
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        body: Data?,
        timeout: TimeInterval,
        authorization: Bool
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
        self.authorization = authorization
    }

    init(
        caller: ApiCaller,
        method: ApiMethod?,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem],
        headers: Headers,
        form: Form,
        timeout: TimeInterval,
        authorization: Bool
    ) {
        var headers = Self.commonFormHeaders.merging(headers) { _, supplied in supplied }
        if headers["User-Agent"] == nil { headers["User-Agent"] = caller.configuration.userAgent }
        if headers["Accept"] == nil { headers["Accept"] = "*/*" }
        if headers["Accept-Language"] == nil { headers["Accept-Language"] = "en-GB,en;q=0.9" }
        let formData = Self.encodeForm(form)

        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        body = formData
        self.timeout = timeout
        self.authorization = authorization
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
            if let authorization = caller.authorization, self.authorization {
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
        try await callRequest(acceptStatusCodes: [acceptStatusCode])
    }

    func string(acceptStatusCodes: Set<Int>) async throws -> String {
        let (data, _) = try await callRequest(acceptStatusCodes: acceptStatusCodes)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        logDebug("\(String(describing: endpoint)) - result: \(string)", category: .api)
        return string
    }

    func httpResponse(acceptStatusCodes: Set<Int>) async throws -> HTTPURLResponse {
        let (_, response) = try await callRequest(acceptStatusCodes: acceptStatusCodes)
        logDebug("\(String(describing: endpoint)) - result: \(String(describing: response))", category: .api)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.cannotDecodeContentData)
        }
        return response
    }

    func data<Data: Decodable>(acceptStatusCodes: Set<Int>) async throws -> Data {
        let data = try await rawData(acceptStatusCodes: acceptStatusCodes)
        let result = try JSONDecoders.default.decode(Data.self, from: data)
        logDebug("\(String(describing: endpoint)) - result: \(String(describing: result))", category: .api)
        return result
    }

    func rawData(acceptStatusCodes: Set<Int>) async throws -> Data {
        let (data, _) = try await callRequest(acceptStatusCodes: acceptStatusCodes)
        return data
    }

    func referalUrl(acceptStatusCodes: Set<Int>) async throws -> URL {
        let httpResponse = try await httpResponse(acceptStatusCodes: acceptStatusCodes)
        guard let location = httpResponse.allHeaderFields["Location"] as? String,
              let url = URL(string: location)
        else {
            throw URLError(.cannotDecodeContentData)
        }
        return url
    }

    @discardableResult
    private func callRequest(acceptStatusCodes: Set<Int>) async throws -> (Data, URLResponse) {
        let urlRequest = try self.urlRequest
        logDebug("\(String(describing: endpoint)) - request: \(String(describing: urlRequest.url)) \(String(describing: urlRequest.allHTTPHeaderFields))", category: .api)

        let (data, response) = try await caller.urlSession.data(for: urlRequest)
        logDebug("\(String(describing: endpoint)) - response: \(String(describing: response))", category: .api)

        guard (200 ... 399).contains(response.status ?? 0) else {
            if response.status == 401 {
                throw ApiError.unauthorized
            } else {
                throw ApiError.unexpectedStatusCode(response.status)
            }
        }

        guard acceptStatusCodes.contains(response.status ?? 0) else {
            throw ApiError.unexpectedStatusCode(response.status)
        }
        return (data, response)
    }
}
