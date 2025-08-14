//
//  Keychain.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 06.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Enumeration of Security Framework constants used for keychain operations
/// Provides type-safe access to keychain attribute keys and values
private enum KeychainSecurityKeys: String {
    /// Security class type
    case className
    /// Account attribute
    case attributeAccount
    /// Generic attribute for custom data
    case attributeGeneric
    /// Service attribute for grouping items
    case attributeService
    /// Match limit for search queries
    case matchLimit
    /// Single item match limit
    case matchLimitOne
    /// Return data flag for queries
    case returnData
    /// Value data for storage
    case valueData
    /// Generic password class type
    case genericPassword
    /// Accessibility level for stored items
    case accessible
    /// Accessible after first unlock level
    case firstUnlock
    /// Synchronization attribute
    case synchronizable
    /// Access group for shared keychain access
    case accessGroup

    /// Returns the Security Framework constant for each key
    public var rawValue: String {
        let key: CFString
        switch self {
        case .className:
            key = kSecClass
        case .attributeAccount:
            key = kSecAttrAccount
        case .attributeGeneric:
            key = kSecAttrGeneric
        case .attributeService:
            key = kSecAttrService
        case .matchLimit:
            key = kSecMatchLimit
        case .matchLimitOne:
            key = kSecMatchLimitOne
        case .returnData:
            key = kSecReturnData
        case .valueData:
            key = kSecValueData
        case .genericPassword:
            key = kSecClassGenericPassword
        case .accessible:
            key = kSecAttrAccessible
        case .firstUnlock:
            key = kSecAttrAccessibleAfterFirstUnlock
        case .synchronizable:
            key = kSecAttrSynchronizable
        case .accessGroup:
            key = kSecAttrAccessGroup
        }
        return key as String
    }
}

/// Generic keychain storage utility for securely storing and retrieving Codable data
/// Uses iOS Security Framework to store encrypted data with app group sharing support
struct Keychain<Key: RawRepresentable> {
    /// The app group identifier for shared keychain access between app and extensions
    private static var accessGroupId: String {
        AppConfiguration.accessGroupId
    }

    /// Stores a Codable value in the keychain or removes it if value is nil
    /// - Parameters:
    ///   - value: The value to store, or nil to remove existing value
    ///   - path: The keychain service identifier for this item
    static func store<Content: Codable>(value: Content?, path: Key) {
        if let value {
            do {
                let encoded = try JSONEncoders.default.encode(value)
                let nativeQuery: [KeychainSecurityKeys: Any] = [
                    .className: KeychainSecurityKeys.genericPassword.rawValue,
                    .attributeService: path.rawValue,
                    .attributeAccount: "local",
                    .valueData: encoded as NSData,
                    .accessible: KeychainSecurityKeys.firstUnlock.rawValue,
                    .synchronizable: kCFBooleanFalse as Any,
                    .accessGroup: accessGroupId,
                ]
                let keychainQuery = nativeQuery.securityQuery
                let deleteStatus = SecItemDelete(keychainQuery)
                let addStatus = SecItemAdd(keychainQuery, nil)

                checkForErrors("Store failed to delete value at path: \(path).", status: deleteStatus)
                checkForErrors("Store failed to add value at path: \(path).", status: addStatus)
            } catch {
                os_log(.error, log: Logger.keychain, "Failed to encode a value for storing into the keychain.")
            }
        } else {
            removeValue(at: path)
        }
    }

    /// Removes a value from the keychain at the specified path
    /// - Parameter path: The keychain service identifier for the item to remove
    static func removeValue(at path: Key) {
        let nativeQuery: [KeychainSecurityKeys: Any] = [
            .className: KeychainSecurityKeys.genericPassword.rawValue,
            .attributeService: path.rawValue,
            .attributeAccount: "local",
            .synchronizable: kCFBooleanFalse as Any,
            .accessGroup: accessGroupId,
        ]
        let deleteStatus = SecItemDelete(nativeQuery.securityQuery)

        checkForErrors("Store empty failed to delete value at path: \(path).", status: deleteStatus)
    }

    /// Retrieves and decodes a Codable value from the keychain
    /// - Parameter path: The keychain service identifier for the item to retrieve
    /// - Returns: The decoded value of type Content, or nil if not found or decoding fails
    static func value<Content: Codable>(for path: Key) -> Content? {
        let nativeQuery: [KeychainSecurityKeys: Any] = [
            .className: KeychainSecurityKeys.genericPassword.rawValue,
            .attributeService: path.rawValue,
            .attributeAccount: "local",
            .synchronizable: kCFBooleanFalse as Any,
            .matchLimit: KeychainSecurityKeys.matchLimitOne.rawValue,
            .returnData: kCFBooleanTrue as Any,
            .accessGroup: accessGroupId,
        ]
        var retrievedData: AnyObject?
        let status = SecItemCopyMatching(nativeQuery.securityQuery, &retrievedData)
        checkForErrors("Failed to get value at path: \(path).", status: status)

        guard status == errSecSuccess else {
            return nil
        }

        guard let retrievedData else {
            return nil
        }

        guard let data = retrievedData as? Data else {
            os_log(.error, log: Logger.keychain, "Failed to cast value at path: %{public}@ to type Data", String(describing: path))
            return nil
        }

        do {
            return try JSONDecoders.default.decode(Content.self, from: data)
        } catch {
            os_log(.error, log: Logger.keychain, "Failed to decode value at path: %{public}@ from type Data: %{public}@", String(describing: path), error.localizedDescription)
            return nil
        }
    }

    /// Logs keychain operation errors while ignoring expected status codes
    /// - Parameters:
    ///   - message: Error message to log
    ///   - status: OSStatus from keychain operation
    private static func checkForErrors(
        _ message: String,
        status: OSStatus
    ) {
        let ignoredStatuses: [OSStatus] = [
            errSecSuccess,
            errSecItemNotFound,
        ].compactMap { $0 }

        guard !ignoredStatuses.contains(status) else { return }
        os_log(.error, log: Logger.keychain, "%{public}@, error: %{public}d", message, status)
    }
}

/// Extension to convert KeychainSecurityKeys dictionary to NSDictionary for Security Framework
private extension Dictionary where Key == KeychainSecurityKeys, Value == Any {
    /// Converts the dictionary to NSDictionary format required by Security Framework functions
    var securityQuery: NSDictionary {
        NSDictionary(
            objects: Array(values),
            forKeys: keys.map { $0.rawValue } as [NSString]
        )
    }
}
