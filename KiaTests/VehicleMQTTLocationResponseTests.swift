//
//  VehicleMQTTLocationResponseTests.swift
//  KiaTests
//
//  Created by Codex on 03/03/26.
//

import XCTest
@testable import KiaMaps

final class VehicleMQTTLocationResponseTests: XCTestCase {

    func testDecode_ValidMergedTimestampWithNullLocation() throws {
        let data = Data(
            """
            {
              "latestUpdateTime": "20250901142733",
              "state": {
                "Vehicle": {
                  "Location": null
                }
              }
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(VehicleMQTTLocationResponse.self, from: data)
        XCTAssertNil(response.state.vehicle.location)

        guard let utcTimeZone = TimeZone(secondsFromGMT: 0) else {
            XCTFail("Failed to create UTC timezone")
            return
        }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = utcTimeZone
        let components = utc.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: response.lastUpdateTime
        )

        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 27)
        XCTAssertEqual(components.second, 33)
    }

    func testDecode_InvalidMergedTimestamp_Throws() {
        let data = Data(
            """
            {
              "latestUpdateTime": "2025-09-01T14:27:33Z",
              "state": {
                "Vehicle": {
                  "Location": null
                }
              }
            }
            """.utf8
        )

        XCTAssertThrowsError(try JSONDecoder().decode(VehicleMQTTLocationResponse.self, from: data)) { error in
            guard let parsingError = error as? DateValue<MergedDateFormatter>.ParsingError else {
                XCTFail("Unexpected error type: \(type(of: error))")
                return
            }

            switch parsingError {
            case .invalidString(let invalidValue, _):
                XCTAssertEqual(invalidValue, "2025-09-01T14:27:33Z")
            }
        }
    }

    func testMergedDateFormatter_RoundTrip() {
        let formatter = MergedDateFormatter()
        let source = "20241231235958"

        let date = try XCTUnwrap(formatter.date(from: source))
        XCTAssertEqual(formatter.string(from: date), source)
    }
}
