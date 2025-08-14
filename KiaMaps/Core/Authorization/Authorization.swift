//
//  Authorization.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 07.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Contains authentication data required for API requests
/// Stores tokens, device information, and protocol support flags
struct AuthorizationData: Codable {
    /// Authorization stamp for request validation
    var stamp: String
    
    /// Unique device identifier for this installation
    var deviceId: UUID
    
    /// OAuth2 access token for API authentication
    var accessToken: String
    
    /// Token expiration time in seconds
    let expiresIn: Int
    
    /// OAuth2 refresh token for renewing access
    var refreshToken: String
    
    /// Flag indicating if vehicle supports CCS2 protocol
    var isCcuCCS2Supported: Bool

    /// Generates authorization headers for API requests
    /// - Parameter configuration: API configuration for header generation
    /// - Returns: Dictionary of authorization headers
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

    /// Generates a cryptographic stamp for API request authentication
    /// Uses XOR encryption with the configuration's CFB token
    /// - Parameter configuration: API configuration containing CFB token
    /// - Returns: Base64 encoded stamp string
    static func generateStamp(for configuration: ApiConfiguration) -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let rawString = "\(configuration.appId):\(timestamp)"

        guard let cfb = Data(base64Encoded: configuration.cfb),
              cfb.count == rawString.count,
              let rawData = rawString.data(using: .utf8)
        else {
            os_log(.error, log: Logger.auth, "CFB and raw length not equal")
            return ""
        }

        var encodedBytes = [UInt8](repeating: 0, count: cfb.count)
        for i in 0 ..< cfb.count {
            encodedBytes[i] = cfb[i] ^ rawData[i]
        }
        return Data(encodedBytes).base64EncodedString()
    }
}

/// Manages authorization data storage and retrieval using the keychain
/// Provides centralized access to authentication state across the app
enum Authorization {
    /// Keychain storage keys
    private enum Key: String {
        case authorization
    }

    /// Current authorization data from keychain storage
    static var authorization: AuthorizationData? {
        Keychain<Key>.value(for: .authorization)
    }

    /// Indicates whether the user is currently authorized
    static var isAuthorized: Bool {
        authorization != nil
    }

    /// Stores authorization data securely in the keychain
    /// Posts notification for UI updates and notifies extensions
    /// - Parameter data: Authorization data to store
    static func store(data: AuthorizationData) {
        Keychain<Key>.store(value: data, path: .authorization)
        // Notify extensions that credentials have been updated
        //DarwinNotificationHelper.post(name: DarwinNotificationHelper.NotificationName.credentialsUpdated)
        // Post local notification for UI updates
        NotificationCenter.default.post(name: .authorizationDidChange, object: nil)
    }

    /// Updates the CCS2 protocol support flag for the current authorization
    /// - Parameter isSupported: Whether CCS2 protocol is supported
    static func setCcuCCS2Protocol(isSupported: Bool) {
        guard var data = authorization else { return }
        data.isCcuCCS2Supported = isSupported
        store(data: data)
        // Note: store() already posts the update notification
    }

    /// Removes authorization data from keychain and posts notifications
    static func remove() {
        Keychain<Key>.removeValue(at: .authorization)
        // Notify extensions that credentials have been cleared
        //DarwinNotificationHelper.post(name: DarwinNotificationHelper.NotificationName.credentialsCleared)
        // Post local notification for UI updates
        NotificationCenter.default.post(name: .authorizationDidChange, object: nil)
    }
}

extension Notification.Name {
    static let authorizationDidChange = Notification.Name("authorizationDidChange")
}
