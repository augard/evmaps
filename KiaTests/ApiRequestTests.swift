import XCTest
@testable import KiaMaps

final class ApiRequestTests: XCTestCase {
    func testFormValuesRoundTripAndPreserveNavigationHeaders() throws {
        let form = ["email": "driver+ev&maps@example.com", "password": "a=b&c+ d%é", "key&=": "value"]
        let caller = RequestTestCaller(configuration: MockApiConfiguration(), urlSession: .shared, authorization: nil)
        let request = try ApiRequestImpl(caller: caller, method: .post, endpoint: KiaApiEndpoint.loginSignin, queryItems: [],
                                        headers: ["Origin": "https://example.com", "Referer": "https://example.com/login"],
                                        form: form, timeout: 30, authorization: false).urlRequest
        let encoded = String(decoding: request.httpBody!, as: UTF8.self)
        let pairs = encoded.split(separator: "&").map { pair -> (String, String) in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts[0]).removingPercentEncoding!, String(parts[1]).removingPercentEncoding!)
        }
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: pairs), form)
        XCTAssertTrue(encoded.contains("%2B"))
        XCTAssertTrue(encoded.contains("%26"))
        XCTAssertTrue(encoded.contains("%3D"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://example.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://example.com/login")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")!.hasPrefix("application/x-www-form-urlencoded"))
    }

    func testUnexpectedSuccessfulHTTPStatusIsRejected() async throws {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [UnexpectedStatusProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        defer { session.invalidateAndCancel() }
        let caller = RequestTestCaller(configuration: MockApiConfiguration(), urlSession: session, authorization: nil)
        let request = ApiRequestImpl(caller: caller, method: .get, endpoint: KiaApiEndpoint.loginCertificates,
                                     queryItems: [], headers: [:], body: nil, timeout: 30, authorization: false)
        do {
            _ = try await request.httpResponse(acceptStatusCode: 200)
            XCTFail("HTTP 201 must not satisfy an expected HTTP 200 response")
        } catch ApiError.unexpectedStatusCode(let code) {
            XCTAssertEqual(code, 201)
        }
    }
}

private struct RequestTestCaller: ApiCaller {
    let configuration: ApiConfiguration
    let urlSession: URLSession
    let authorization: AuthorizationData?
}

private final class UnexpectedStatusProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
