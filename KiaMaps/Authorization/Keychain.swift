//
//  Keychain.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 06.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

private enum KeychainSecurityKeys: String {
    case className
    case attributeAccount
    case attributeGeneric
    case attributeService
    case matchLimit
    case matchLimitOne
    case returnData
    case valueData
    case genericPassword
    case accessible
    case firstUnlock
    case synchronizable
    case accessGroup

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

struct Keychain<Key: RawRepresentable> {
    private static var accessGroupId: String {
        AppConfiguration.accessGroupId
    }
    
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
                    //.accessGroup: accessGroupId,
                ]
                let keychainQuery = nativeQuery.securityQuery
                let deleteStatus = SecItemDelete(keychainQuery)
                let addStatus = SecItemAdd(keychainQuery, nil)

                checkForErrors("Store failed to delete value at path: \(path).", status: deleteStatus)
                checkForErrors("Store failed to add value at path: \(path).", status: addStatus)
            } catch {
                print("Failed to encode: \(value)")
            }
        } else {
            removeVakue(at: path)
        }
    }
    
    static func removeVakue(at path: Key) {
        let nativeQuery: [KeychainSecurityKeys: Any] = [
            .className: KeychainSecurityKeys.genericPassword.rawValue,
            .attributeService: path.rawValue,
            .attributeAccount: "local",
            .synchronizable: kCFBooleanFalse as Any,
            //.accessGroup: accessGroupId,
        ]
        let deleteStatus = SecItemDelete(nativeQuery.securityQuery)

        checkForErrors("Store empty failed to delete value at path: \(path).", status: deleteStatus)
    }

    static func value<Content: Codable>(for path: Key) -> Content? {
        let nativeQuery: [KeychainSecurityKeys: Any] = [
            .className: KeychainSecurityKeys.genericPassword.rawValue,
            .attributeService: path.rawValue,
            .attributeAccount: "local",
            .synchronizable: kCFBooleanFalse as Any,
            .matchLimit: KeychainSecurityKeys.matchLimitOne.rawValue,
            .returnData: kCFBooleanTrue as Any,
            //.accessGroup: accessGroupId,
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
            print("Failed to cast value at path: \(path) to type Data.")
            return nil
        }

        do {
            return try JSONDecoders.default.decode(Content.self, from: data)
        } catch {
            print("Failed to decode value at path: \(path) from type Data. \(error)")
            return nil
        }
    }

    private static func checkForErrors(
        _ message: String,
        status: OSStatus
    ) {
        let ignoredStatuses: [OSStatus] = [
            errSecSuccess,
            errSecItemNotFound,
        ].compactMap { $0 }

        guard !ignoredStatuses.contains(status) else { return }
        print(message + ", error: \(status)")
    }
}

private extension Dictionary where Key == KeychainSecurityKeys, Value == Any {
    var securityQuery: NSDictionary {
        NSDictionary(
            objects: Array(values),
            forKeys: keys.map { $0.rawValue } as [NSString]
        )
    }
}
