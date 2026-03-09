//
//  KiaTests.swift
//  KiaTests
//
//  Created by Lukáš Foldýna on 21/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class KiaTests: XCTestCase {

    private struct TimestampPayload: Codable {
        @TimestampDateValue var timestamp: Date
    }

    private struct MillisecondPayload: Codable {
        @MillisecondDateValue var eventTime: Date
    }

    func testTimestampDateValueDecodesEpochMillisecondsString() throws {
        let decoder = JSONDecoder()
        let data = #"{"timestamp":"1716728779116"}"#.data(using: .utf8)!

        let payload = try decoder.decode(TimestampPayload.self, from: data)
        let expected = Date(timeIntervalSince1970: 1_716_728_779.116)

        XCTAssertEqual(payload.timestamp.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.0001)
    }

    func testTimestampDateValueDecodesNativeDateUsingDecoderStrategy() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let data = #"{"timestamp":1716728779.116}"#.data(using: .utf8)!

        let payload = try decoder.decode(TimestampPayload.self, from: data)
        XCTAssertEqual(payload.timestamp.timeIntervalSince1970, 1_716_728_779.116, accuracy: 0.0001)
    }

    func testTimestampDateValueThrowsForInvalidString() {
        let decoder = JSONDecoder()
        let data = #"{"timestamp":"invalid"}"#.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TimestampPayload.self, from: data))
    }

    func testMillisecondDateValueRoundTripEncodingAndDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let inputDate = Date(timeIntervalSince1970: 1_716_728_779.116)
        let payload = MillisecondPayload(eventTime: inputDate)

        let encoded = try encoder.encode(payload)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(encodedString.contains(#""eventTime":"2024-05-26 10:12:59.116""#))

        let decoded = try decoder.decode(MillisecondPayload.self, from: encoded)
        XCTAssertEqual(decoded.eventTime.timeIntervalSince1970, inputDate.timeIntervalSince1970, accuracy: 0.001)
    }

    func testMQTTSubscriptionNameUsesWildcardSeparator() {
        XCTAssertEqual(MQTTBaseProtocolIds.connection.subscriptionName, "service/phone/_/connection")
        XCTAssertEqual(MQTTSpeedEventProtocolIds.location.subscriptionName, "service/phone/_/location")
    }

    func testMQTTProtocolInitFromTopicNameParsesVehicleSuffixedTopic() {
        let topic = "service/phone/_/connection/12345"
        let parsed = MQTTBaseProtocolIds(topicName: topic)

        XCTAssertEqual(parsed, .connection)
    }

    func testMQTTProtocolInitFromTopicNameRejectsUnknownTopic() {
        let topic = "service/phone/_/does-not-exist/12345"
        let parsed = MQTTBaseProtocolIds(topicName: topic)

        XCTAssertNil(parsed)
    }

    func testProtocolSubscriptionRequestEncodesRawProtocolValues() throws {
        let request = ProtocolSubscriptionRequest(
            protocols: [MQTTBaseProtocolIds.connection, MQTTSpeedEventProtocolIds.location],
            protocolId: MQTTBaseProtocolIds.vehicleCcuUpdate,
            carId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            brand: "KIA"
        )

        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let protocols = try XCTUnwrap(json["protocols"] as? [String])
        let protocolId = try XCTUnwrap(json["protocolId"] as? String)
        let brand = try XCTUnwrap(json["brand"] as? String)

        XCTAssertEqual(protocols, ["service.phone.connection", "service.phone.location"])
        XCTAssertEqual(protocolId, "statesync.vehicle.ccu.update")
        XCTAssertEqual(brand, "KIA")
    }

    func testMQTTConnectionStatusDisplayText() {
        XCTAssertEqual(MQTTConnectionStatus.disconnected.displayText, "Disconnected")
        XCTAssertEqual(MQTTConnectionStatus.connecting.displayText, "Connecting to vehicle...")
        XCTAssertEqual(MQTTConnectionStatus.connected.displayText, "Connected - receiving live data")
        XCTAssertEqual(MQTTConnectionStatus.error.displayText, "Connection failed")
    }

    func testPerformanceExample() throws {
        measure {
            _ = MQTTBaseProtocolIds.connection.subscriptionName
        }
    }

}
