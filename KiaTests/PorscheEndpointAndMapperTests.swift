//
//  PorscheEndpointAndMapperTests.swift
//  KiaTests
//
//  Created by Codex on 06.03.2026.
//

import XCTest
@testable import KiaMaps

private final class PorscheProviderTransportStub {
    struct StubResponse {
        let statusCode: Int
        let headers: [String: String]
        let body: Data

        init(statusCode: Int, headers: [String: String] = [:], json: Any? = nil) {
            self.statusCode = statusCode
            self.headers = headers
            if let json {
                self.body = try! JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            } else {
                self.body = Data()
            }
        }
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [StubResponse]

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func transport(_ request: URLRequest) async throws -> PorscheHTTPTransportResponse {
        requests.append(request)
        let response = responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: response.headers
        )!
        return PorscheHTTPTransportResponse(data: response.body, response: httpResponse)
    }
}

private final class PorscheRequestProviderStub: ApiRequestProvider, ApiCaller {
    let urlSession: URLSession
    private(set) var requests: [URLRequest] = []
    private var responses: [StubResponse]

    struct StubResponse {
        let statusCode: Int
        let headers: [String: String]
        let body: Data

        init(statusCode: Int, headers: [String: String] = [:], json: Any? = nil) {
            self.statusCode = statusCode
            self.headers = headers
            if let json {
                self.body = try! JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            } else {
                self.body = Data()
            }
        }
    }

    override var caller: ApiCaller {
        self
    }

    init(configuration: ApiConfiguration = PorscheApiConfiguration.europe, responses: [StubResponse]) {
        self.urlSession = .shared
        self.responses = responses
        super.init(configuration: configuration, callerType: Self.self, requestType: PorscheRequestProviderApiRequest.self)
    }

    required init(configuration: any ApiConfiguration, urlSession: URLSession, authorization: AuthorizationData?) {
        self.urlSession = urlSession
        responses = []
        super.init(configuration: configuration, callerType: Self.self, requestType: PorscheRequestProviderApiRequest.self)
        self.authorization = authorization
    }

    func dequeueResponse(for request: URLRequest) throws -> StubResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return responses.removeFirst()
    }
}

private struct PorscheRequestProviderApiRequest: ApiRequest {
    let caller: ApiCaller
    let method: ApiMethod
    let endpoint: any ApiEndpointProtocol
    let queryItems: [URLQueryItem]
    let headers: Headers
    let body: Data?
    let timeout: TimeInterval
    let authorization: Bool

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
        self.caller = caller
        self.method = method ?? .post
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = form
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
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
            var allHeaders = headers
            if let authorization = caller.authorization {
                for (key, value) in authorization.authorizatioHeaders(for: caller.configuration) {
                    allHeaders[key] = value
                }
            }
            request.allHTTPHeaderFields = allHeaders
            request.httpBody = body
            return request
        }
    }

    func response<Data: Decodable>(acceptStatusCode _: Int) async throws -> Data {
        throw URLError(.badServerResponse)
    }

    func responseValue<Data: Decodable>(acceptStatusCode _: Int) async throws -> Data {
        throw URLError(.badServerResponse)
    }

    func responseEmpty(acceptStatusCode _: Int) async throws -> ApiResponseEmpty {
        throw URLError(.badServerResponse)
    }

    func empty(acceptStatusCode: Int) async throws {
        _ = try await rawData(acceptStatusCodes: [acceptStatusCode])
    }

    func string(acceptStatusCodes: Set<Int>) async throws -> String {
        String(decoding: try await rawData(acceptStatusCodes: acceptStatusCodes), as: UTF8.self)
    }

    func httpResponse(acceptStatusCodes: Set<Int>) async throws -> HTTPURLResponse {
        let provider = try provider()
        let request = try urlRequest
        let response = try provider.dequeueResponse(for: request)
        if response.statusCode == 401 {
            throw ApiError.unauthorized
        }
        guard acceptStatusCodes.contains(response.statusCode) else {
            throw ApiError.unexpectedStatusCode(response.statusCode)
        }
        return HTTPURLResponse(url: request.url!, statusCode: response.statusCode, httpVersion: nil, headerFields: response.headers)!
    }

    func data<T: Decodable>(acceptStatusCodes _: Set<Int>) async throws -> T {
        throw URLError(.badServerResponse)
    }

    func rawData(acceptStatusCodes: Set<Int>) async throws -> Data {
        let provider = try provider()
        let request = try urlRequest
        let response = try provider.dequeueResponse(for: request)
        if response.statusCode == 401 {
            throw ApiError.unauthorized
        }
        guard acceptStatusCodes.contains(response.statusCode) else {
            throw ApiError.unexpectedStatusCode(response.statusCode)
        }
        return response.body
    }

    func referalUrl(acceptStatusCodes _: Set<Int>) async throws -> URL {
        throw URLError(.badServerResponse)
    }

    private func provider() throws -> PorscheRequestProviderStub {
        guard let provider = caller as? PorscheRequestProviderStub else {
            throw URLError(.badServerResponse)
        }
        return provider
    }
}

final class PorscheEndpointAndMapperTests: XCTestCase {
    func testApiBrandPorscheSelectsRegionSpecificConfiguration() {
        let euConfiguration = ApiBrand.porsche.configuration(for: .europe)
        let usConfiguration = ApiBrand.porsche.configuration(for: .usa)
        XCTAssertTrue(euConfiguration is PorscheApiConfiguration)
        XCTAssertTrue(usConfiguration is PorscheApiConfiguration)
    }

    func testPorscheEndpointURLCompositionEU() throws {
        let config = PorscheApiConfiguration.europe
        let vehicleURL = try config.url(for: PorscheApiEndpoint.vehicle("WP0ZZZ99ZTS392124"))
        XCTAssertEqual(vehicleURL.absoluteString, "https://api.ppa.porsche.com/app/connect/v1/vehicles/WP0ZZZ99ZTS392124")
    }

    func testPorscheEndpointURLCompositionUS() throws {
        let config = PorscheApiConfiguration.usa
        let commandsURL = try config.url(for: PorscheApiEndpoint.commands("VIN123"))
        XCTAssertEqual(commandsURL.absoluteString, "https://api.ppa.porsche.com/app/connect/v1/vehicles/VIN123/commands")
    }

    func testProviderFactoryChoosesPorscheProvider() {
        let api = Api(configuration: PorscheApiConfiguration.europe, rsaService: .init())
        let provider = VehicleApiProviderFactory.provider(for: api)
        XCTAssertTrue(provider is PorscheVehicleApiProvider)
    }

    func testMapperUsesMeasurementPayloadAndSafeDefaults() throws {
        let payload: [String: Any] = [
            "vin": "VIN",
            "modelName": "Taycan",
            "modelType": [
                "year": "2024",
                "engine": "BEV",
                "model": "4S",
            ],
            "customName": "My Porsche",
            "measurements": [
                [
                    "key": "BATTERY_LEVEL",
                    "status": ["isEnabled": true],
                    "value": ["percent": 62.5],
                ],
                [
                    "key": "GPS_LOCATION",
                    "status": ["isEnabled": true],
                    "value": [
                        "location": "50.1,14.4",
                        "direction": 90,
                        "lastModified": "2026-03-06T16:00:00Z",
                    ],
                ],
                [
                    "key": "LOCK_STATE_VEHICLE",
                    "status": ["isEnabled": true],
                    "value": ["isLocked": true],
                ],
                [
                    "key": "MILEAGE",
                    "status": ["isEnabled": true],
                    "value": ["kilometers": 15432],
                ],
                [
                    "key": "CLIMATIZER_STATE",
                    "status": ["isEnabled": true],
                    "value": ["isOn": true, "targetTemperature": 294.15],
                ],
                [
                    "key": "CHARGING_RATE",
                    "status": ["isEnabled": true],
                    "value": ["chargingPower": 11000],
                ],
            ],
        ]

        let summary = PorscheVehicleMapper.mapSummary(from: payload)
        let snapshot = PorscheVehicleMapper.map(summary: summary)
        let state = try PorscheVehicleMapper.mapVehicleState(from: payload)

        XCTAssertEqual(snapshot.batterySoc, 62.5)
        XCTAssertEqual(snapshot.latitude, 50.1)
        XCTAssertEqual(snapshot.longitude, 14.4)
        XCTAssertEqual(snapshot.odometerKm, 15_432)
        XCTAssertTrue(snapshot.locked)
        XCTAssertTrue(snapshot.climateActive)
        XCTAssertEqual(snapshot.chargingPowerKw, 11)
        XCTAssertEqual(state.status.green.batteryManagement.batteryRemain.ratio, 62.5)
        XCTAssertEqual(state.status.drivetrain.odometer, 15_432)
        XCTAssertEqual(state.status.location?.geoCoordinate.latitude, 50.1)
        XCTAssertEqual(state.status.location?.geoCoordinate.longitude, 14.4)
        XCTAssertEqual(state.status.cabin.hvac.row1.driver.blower.speedLevel, 1)
    }

    func testCommandBodyUsesRemoteClimatizerStartPayload() throws {
        let data = PorscheVehicleMapper.commandBody(for: .climateOn(vin: "VIN", temperatureC: 22))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["key"] as? String, "REMOTE_CLIMATIZER_START")
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        let targetTemperature = try XCTUnwrap(payload["targetTemperature"] as? Double)
        XCTAssertEqual(targetTemperature, 295.15, accuracy: 0.001)
    }

    func testProviderRefreshesTokenAfterUnauthorizedVehiclesCall() async throws {
        let vehiclePayload: [[String: Any]] = [[
            "vin": "WP0AA2Y1XNSA00001",
            "modelName": "Taycan",
            "modelType": [
                "year": "2025",
                "engine": "BEV",
                "model": "Turbo",
            ],
            "customName": "Turbo",
        ]]

        let authStub = PorscheProviderTransportStub(responses: [
            .init(statusCode: 200, json: [
                "access_token": "fresh-access",
                "refresh_token": "fresh-refresh",
                "token_type": "Bearer",
                "expires_in": 3600,
                "scope": "openid cars",
            ]),
        ])
        let requestProvider = PorscheRequestProviderStub(responses: [
            .init(statusCode: 401),
            .init(statusCode: 200, json: vehiclePayload),
        ])

        let api = Api(configuration: PorscheApiConfiguration.europe, rsaService: .init(), provider: requestProvider)
        api.authorization = AuthorizationData(
            stamp: "porsche",
            deviceId: UUID(),
            accessToken: "expired",
            expiresIn: 3600,
            refreshToken: "refresh-token",
            isCcuCCS2Supported: true,
            providerKind: "porsche",
            tokenIssuer: PorscheApiConfiguration.europe.loginHost,
            tokenAudience: PorscheApiConfiguration.europe.audience,
            tokenScope: PorscheApiConfiguration.europe.scope
        )
        let authClient = PorscheAuthClient(configuration: .europe, transport: authStub.transport, now: { Date(timeIntervalSince1970: 42) })
        let provider = PorscheVehicleApiProvider(api: api, authClient: authClient, commandPollIntervalNanoseconds: 0)

        let response = try await provider.vehicles()

        XCTAssertEqual(response.vehicles.count, 1)
        XCTAssertEqual(api.authorization?.accessToken, "fresh-access")
        XCTAssertEqual(authStub.requests[0].url?.path, "/oauth/token")
    }

    func testProviderStartClimateUsesCommandsEndpoint() async throws {
        let vehicleID = UUID.porscheVehicleID(for: "WP0AA2Y1XNSA00001")
        let requestProvider = PorscheRequestProviderStub(responses: [
            .init(statusCode: 200, json: [[
                "vin": "WP0AA2Y1XNSA00001",
                "modelName": "Taycan",
                "modelType": [
                    "year": "2025",
                    "engine": "BEV",
                    "model": "4S",
                ],
            ]]),
            .init(statusCode: 200, json: [
                "status": [
                    "id": "4FD78B24-3C94-4EC2-8BE4-7D53FA3B84B6",
                    "result": "ACCEPTED",
                ],
            ]),
            .init(statusCode: 200, json: [
                "status": [
                    "result": "PERFORMED",
                ],
            ]),
        ])

        let api = Api(configuration: PorscheApiConfiguration.europe, rsaService: .init(), provider: requestProvider)
        api.authorization = AuthorizationData(
            stamp: "porsche",
            deviceId: UUID(),
            accessToken: "access",
            expiresIn: 3600,
            refreshToken: "refresh",
            isCcuCCS2Supported: true,
            providerKind: "porsche"
        )
        let provider = PorscheVehicleApiProvider(api: api, commandPollIntervalNanoseconds: 0)

        let commandID = try await provider.startClimate(vehicleID, options: .init(temperature: 21), pin: "")

        XCTAssertEqual(commandID.uuidString, "4FD78B24-3C94-4EC2-8BE4-7D53FA3B84B6")
        XCTAssertEqual(requestProvider.requests[1].url?.path, "/app/connect/v1/vehicles/WP0AA2Y1XNSA00001/commands")
        let body = try XCTUnwrap(requestProvider.requests[1].httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["key"] as? String, "REMOTE_CLIMATIZER_START")
    }
}
