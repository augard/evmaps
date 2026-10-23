import Foundation

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
    ///   - authorization: If authorization header should be set
    /// - Returns: Configured API request
    /// - Throws: Encoding errors
    func request(
        with method: ApiMethod? = nil,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        encodable: Encodable,
        timeout: TimeInterval = ApiDefaultTimeout,
        authorization: Bool = true
    ) throws -> ApiRequest {
        try requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            encodable: encodable,
            timeout: timeout,
            authorization: authorization
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
    ///   - authorization: If authorization header should be set
    /// - Returns: Configured API request
    func request(
        with method: ApiMethod? = nil,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        body: Data? = nil,
        timeout: TimeInterval = ApiDefaultTimeout,
        authorization: Bool = true
    ) -> ApiRequest {
        requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            body: body,
            timeout: timeout,
            authorization: authorization
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
    ///   - authorization: If authorization header should be set
    /// - Returns: Configured API request
    func request(
        with method: ApiMethod? = nil,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        string: String,
        timeout: TimeInterval = ApiDefaultTimeout,
        authorization: Bool = true
    ) -> ApiRequest {
        requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            body: string.data(using: .utf8),
            timeout: timeout,
            authorization: authorization
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
    ///   - authorization: If authorization header should be set
    /// - Returns: Configured API request
    func request(
        with method: ApiMethod? = nil,
        endpoint: any ApiEndpointProtocol,
        queryItems: [URLQueryItem] = [],
        headers: ApiRequest.Headers = [:],
        form: ApiRequest.Form,
        timeout: TimeInterval = ApiDefaultTimeout,
        authorization: Bool = true
    ) -> ApiRequest {
        requestType.init(
            caller: caller,
            method: method,
            endpoint: endpoint,
            queryItems: queryItems,
            headers: headers,
            form: form,
            timeout: timeout,
            authorization: authorization
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
