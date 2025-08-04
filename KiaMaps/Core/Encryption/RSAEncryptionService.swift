//
//  RSAEncryptionService.swift
//  KiaMaps
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import Security

/// Service for RSA encryption of passwords using server-provided public keys
final class RSAEncryptionService {
    
    /// RSA Key data from server's JWK format
    struct RSAKeyData {
        let keyType: String     // "RSA"
        let exponent: String    // "AQAB" (base64 encoded)
        let keyId: String       // "HMGID2_CIPHER_KEY1"
        let modulus: String     // Large base64url encoded modulus
    }
    
    /// Encrypt password using RSA public key
    func encryptPassword(_ password: String, with keyData: RSAKeyData) throws -> String {
        guard keyData.keyType == "RSA" else {
            throw RSAError.invalidKeyType
        }
        
        let publicKey = try createRSAPublicKey(from: keyData)
        guard let passwordData = password.data(using: .utf8) else {
            throw RSAError.invalidPassword
        }
        
        let encryptedData = try encrypt(data: passwordData, with: publicKey)
        return encryptedData.hexEncodedString()
    }
    
    /// Create RSA public key from JWK data
    private func createRSAPublicKey(from keyData: RSAKeyData) throws -> SecKey {
        // Decode base64url encoded modulus and exponent
        guard let modulusData = Data(base64URLEncoded: keyData.modulus),
              let exponentData = Data(base64URLEncoded: keyData.exponent) else {
            throw RSAError.invalidKeyData
        }
        
        // Create RSA public key in ASN.1 DER format
        let keyData = try createPublicKeyData(modulus: modulusData, exponent: exponentData)
        
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: modulusData.count * 8
        ]
        
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(keyData as CFData, keyAttributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw RSAError.keyCreationFailed(error.localizedDescription)
            }
            throw RSAError.keyCreationFailed("Unknown error")
        }
        
        return publicKey
    }
    
    /// Create ASN.1 DER encoded public key data
    private func createPublicKeyData(modulus: Data, exponent: Data) throws -> Data {
        // ASN.1 DER structure for RSA public key
        var keyData = Data()
        
        // SEQUENCE
        keyData.append(0x30)
        
        // Calculate and append total length
        let totalLength = modulusLengthBytes(modulus) + exponentLengthBytes(exponent)
        keyData.append(contentsOf: lengthBytes(of: totalLength))
        
        // Append modulus (INTEGER)
        keyData.append(0x02) // INTEGER tag
        keyData.append(contentsOf: lengthBytes(of: modulus.count + 1))
        keyData.append(0x00) // Leading zero for positive number
        keyData.append(modulus)
        
        // Append exponent (INTEGER)
        keyData.append(0x02) // INTEGER tag
        keyData.append(contentsOf: lengthBytes(of: exponent.count))
        keyData.append(exponent)
        
        return keyData
    }
    
    private func modulusLengthBytes(_ modulus: Data) -> Int {
        // Tag (1) + Length bytes + Content length + Leading zero (1)
        return 1 + lengthBytes(of: modulus.count + 1).count + modulus.count + 1
    }
    
    private func exponentLengthBytes(_ exponent: Data) -> Int {
        // Tag (1) + Length bytes + Content length
        return 1 + lengthBytes(of: exponent.count).count + exponent.count
    }
    
    private func lengthBytes(of length: Int) -> [UInt8] {
        if length < 128 {
            return [UInt8(length)]
        } else if length < 256 {
            return [0x81, UInt8(length)]
        } else {
            return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
        }
    }
    
    /// Encrypt data using RSA public key with PKCS1 padding
    private func encrypt(data: Data, with publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionPKCS1,
            data as CFData,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                throw RSAError.encryptionFailed(error.localizedDescription)
            }
            throw RSAError.encryptionFailed("Unknown error")
        }
        
        return encryptedData as Data
    }
}

// MARK: - RSA Errors

enum RSAError: LocalizedError {
    case invalidKeyType
    case invalidKeyData
    case invalidPassword
    case keyCreationFailed(String)
    case encryptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidKeyType:
            return "Invalid key type. Expected RSA."
        case .invalidKeyData:
            return "Invalid key data. Could not decode modulus or exponent."
        case .invalidPassword:
            return "Invalid password. Could not convert to UTF-8 data."
        case .keyCreationFailed(let message):
            return "Failed to create RSA public key: \(message)"
        case .encryptionFailed(let message):
            return "Failed to encrypt data: \(message)"
        }
    }
}

// MARK: - Data Extensions

extension Data {
    /// Initialize from base64url encoded string
    init?(base64URLEncoded: String) {
        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        self.init(base64Encoded: base64)
    }
    
    /// Convert data to hexadecimal string
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}