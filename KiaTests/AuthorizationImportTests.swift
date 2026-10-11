import XCTest
@testable import KiaMaps

final class AuthorizationImportTests: XCTestCase {
    private let configuration = ApiBrand.kia.configuration(for: .europe)

    func testMinimalBundleCreatesExternalAuthorization() throws {
        let payload = try AuthorizationImportPayload.decode(
            from: #"{"accessToken":"authorized-token","expiresIn":3600}"#
        )

        let authorization = try payload.authorization(for: configuration)

        XCTAssertEqual(authorization.accessToken, "authorized-token")
        XCTAssertEqual(authorization.expiresIn, 3600)
        XCTAssertEqual(authorization.refreshToken, "")
        XCTAssertTrue(authorization.isCcuCCS2Supported)
        XCTAssertEqual(authorization.effectiveSource, .external)
    }

    func testBearerPrefixIsRemovedToAvoidDoubleAuthorizationPrefix() throws {
        let payload = AuthorizationImportPayload(
            accessToken: "  Bearer token-value  ",
            refreshToken: " refresh-value ",
            expiresIn: 7200,
            deviceId: UUID(uuidString: "11111111-2222-3333-4444-555555555555"),
            isCcuCCS2Supported: false
        )

        let authorization = try payload.authorization(for: configuration)
        let headers = authorization.authorizatioHeaders(for: configuration)

        XCTAssertEqual(authorization.accessToken, "token-value")
        XCTAssertEqual(authorization.refreshToken, "refresh-value")
        XCTAssertEqual(headers["Authorization"], "Bearer token-value")
        XCTAssertEqual(headers["ccsp-device-id"], "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(headers["ccuCCS2ProtocolSupport"], "0")
    }

    func testInvalidJSONIsRejected() {
        XCTAssertThrowsError(try AuthorizationImportPayload.decode(from: "not json")) { error in
            XCTAssertEqual(error as? AuthorizationImportError, .invalidJSON)
        }
    }

    func testEmptyAccessTokenIsRejected() {
        let payload = AuthorizationImportPayload(
            accessToken: " Bearer  ",
            refreshToken: nil,
            expiresIn: 3600,
            deviceId: nil,
            isCcuCCS2Supported: nil
        )
        XCTAssertThrowsError(try payload.authorization(for: configuration)) { error in
            XCTAssertEqual(error as? AuthorizationImportError, .missingAccessToken)
        }
    }

    func testNonPositiveExpiryIsRejected() {
        let payload = AuthorizationImportPayload(
            accessToken: "token",
            refreshToken: nil,
            expiresIn: 0,
            deviceId: nil,
            isCcuCCS2Supported: nil
        )
        XCTAssertThrowsError(try payload.authorization(for: configuration)) { error in
            XCTAssertEqual(error as? AuthorizationImportError, .invalidExpiry)
        }
    }

    func testOldAuthorizationRecordDefaultsToLegacySource() throws {
        let data = Data(#"{"stamp":"stamp","deviceId":"11111111-2222-3333-4444-555555555555","accessToken":"token","expiresIn":3600,"refreshToken":"refresh","isCcuCCS2Supported":true}"#.utf8)
        let authorization = try JSONDecoder().decode(AuthorizationData.self, from: data)
        XCTAssertEqual(authorization.effectiveSource, .legacy)
    }
}
