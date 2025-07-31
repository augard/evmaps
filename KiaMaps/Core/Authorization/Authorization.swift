//
//  Authorization.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 07.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

struct AuthorizationData: Codable {
    var stamp: String
    var deviceId: UUID
    var accessToken: String
    let expiresIn: Int
    var refreshToken: String
    var isCcuCCS2Supported: Bool

    func authorizatioHeaders(for configuration: ApiConfiguration) -> ApiRequest.Headers {
        [
            "Authorization": "Bearer \(accessToken)",
            "Stamp": Self.generateStamp(for: configuration),
            "ccsp-application-id": configuration.appId,
            "ccsp-service-id": configuration.serviceId,
            "ccsp-device-id": deviceId.uuidString.lowercased(),
            "ccuCCS2ProtocolSupport": isCcuCCS2Supported ? "1" : "0",
        ]
    }

    static func generateStamp(for configuration: ApiConfiguration) -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let rawString = "\(configuration.appId):\(timestamp)"

        guard let cfb = Data(base64Encoded: configuration.cfb),
              cfb.count == rawString.count,
              let rawData = rawString.data(using: .utf8)
        else {
            print("cfb and raw length not equal")
            return ""
        }

        var encodedBytes = [UInt8](repeating: 0, count: cfb.count)
        for i in 0 ..< cfb.count {
            encodedBytes[i] = cfb[i] ^ rawData[i]
        }
        return Data(encodedBytes).base64EncodedString()
    }
}

enum Authorization {
    private enum Key: String {
        case authorization
    }

    static var authorization: AuthorizationData? {
        Keychain<Key>.value(for: .authorization)
    }

    static var isAuthorized: Bool {
        authorization != nil
    }

    static func store(data: AuthorizationData) {
        Keychain<Key>.store(value: data, path: .authorization)
        // Notify extensions that credentials have been updated
        //DarwinNotificationHelper.post(name: DarwinNotificationHelper.NotificationName.credentialsUpdated)
        // Post local notification for UI updates
        NotificationCenter.default.post(name: .authorizationDidChange, object: nil)
    }

    static func setCcuCCS2Protocol(isSupported: Bool) {
        guard var data = authorization else { return }
        data.isCcuCCS2Supported = isSupported
        store(data: data)
        // Note: store() already posts the update notification
    }

    static func remove() {
        Keychain<Key>.removeVakue(at: .authorization)
        // Notify extensions that credentials have been cleared
        //DarwinNotificationHelper.post(name: DarwinNotificationHelper.NotificationName.credentialsCleared)
        // Post local notification for UI updates
        NotificationCenter.default.post(name: .authorizationDidChange, object: nil)
    }
}

extension Notification.Name {
    static let authorizationDidChange = Notification.Name("authorizationDidChange")
}
