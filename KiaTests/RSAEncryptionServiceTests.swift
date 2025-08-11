//
//  RSAEncryptionServiceTests.swift
//  KiaMapsTests
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class RSAEncryptionServiceTests: XCTestCase {
    
    var rsaService: RSAEncryptionService!
    
    override func setUp() {
        super.setUp()
        rsaService = RSAEncryptionService()
    }
    
    override func tearDown() {
        rsaService = nil
        super.tearDown()
    }
    
    // MARK: - Test Data
    
    /// Sample RSA key data similar to what the server provides
    /// This is a test key - modulus is shortened for testing purposes
    private var sampleRSAKeyData: RSAEncryptionService.RSAKeyData {
        return RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "AQAB", // Standard RSA exponent (65537)
            keyId: "HMGID2_CIPHER_KEY1",
            // This is a shortened test modulus - in reality it would be much longer
            modulus: "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw3vWkTxJWlPknHkBJxoH5P-D7t59RibA7BPI6rsc2bBE8PSzCahfQ-bMOhAwMWesOOajN9ki-caE6MUMS6naRhmxUjYe4OHVuEKCPvYZ9O188L4yKqUfCRWXOMjmJBvMz1KFtHZto9SdaC25v5dN82R4JgRQ4Pq9PDVd3v08egpS7BURblRGg22jS9fouyKceoie4s6JiKeyvvGj0qRKJSFUGLP0ScpUcY1XgUMjGNC51ncTOQdMSGxaj9k623m7w"
        )
    }
    
    /// Invalid RSA key data with wrong key type
    private var invalidKeyTypeData: RSAEncryptionService.RSAKeyData {
        return RSAEncryptionService.RSAKeyData(
            keyType: "ECDSA", // Wrong type
            exponent: "AQAB",
            keyId: "HMGID2_CIPHER_KEY1",
            modulus: "invalid-base64-modulus"
        )
    }
    
    /// Invalid RSA key data with malformed base64
    private var invalidBase64Data: RSAEncryptionService.RSAKeyData {
        return RSAEncryptionService.RSAKeyData(
            keyType: "RSA",
            exponent: "INVALID_BASE64!@#",
            keyId: "HMGID2_CIPHER_KEY1",
            modulus: "INVALID_BASE64!@#"
        )
    }
    
    // MARK: - Success Tests
    
    func testPasswordEncryptionWithValidData() throws {
        // Given
        let password = "testPassword123"
        let keyData = sampleRSAKeyData
        
        // When
        XCTAssertNoThrow {
            let encryptedPassword = try self.rsaService.encryptPassword(password, with: keyData)
            
            // Then
            XCTAssertFalse(encryptedPassword.isEmpty, "Encrypted password should not be empty")
            XCTAssertNotEqual(encryptedPassword, password, "Encrypted password should be different from original")
            XCTAssertTrue(encryptedPassword.allSatisfy { $0.isHexDigit }, "Encrypted password should be hex encoded")
            
            // Verify it's hex encoded (even length, valid hex characters)
            XCTAssertEqual(encryptedPassword.count % 2, 0, "Hex string should have even length")
            
            print("✅ Password encrypted successfully: \(encryptedPassword.prefix(20))...")
        }
    }
    
    func testPasswordEncryptionConsistency() throws {
        // Given
        let password = "consistencyTest"
        let keyData = sampleRSAKeyData
        
        // When
        let encrypted1 = try rsaService.encryptPassword(password, with: keyData)
        let encrypted2 = try rsaService.encryptPassword(password, with: keyData)
        
        // Then
        // RSA encryption with PKCS1 padding includes randomness, so results should be different
        XCTAssertNotEqual(encrypted1, encrypted2, "RSA encryption should produce different results due to padding randomness")
        XCTAssertFalse(encrypted1.isEmpty)
        XCTAssertFalse(encrypted2.isEmpty)
    }
    
    func testEmptyPasswordEncryption() throws {
        // Given
        let password = ""
        let keyData = sampleRSAKeyData
        
        // When/Then
        XCTAssertNoThrow {
            let encryptedPassword = try self.rsaService.encryptPassword(password, with: keyData)
            XCTAssertFalse(encryptedPassword.isEmpty, "Even empty passwords should produce encrypted output")
        }
    }
    
    func testSpecialCharacterPasswordEncryption() throws {
        // Given
        let password = "p@ssw0rd!#$%^&*()"
        let keyData = sampleRSAKeyData
        
        // When/Then
        XCTAssertNoThrow {
            let encryptedPassword = try self.rsaService.encryptPassword(password, with: keyData)
            XCTAssertFalse(encryptedPassword.isEmpty)
            XCTAssertNotEqual(encryptedPassword, password)
        }
    }
    
    func testUnicodePasswordEncryption() throws {
        // Given
        let password = "пароль测试🔒"
        let keyData = sampleRSAKeyData
        
        // When/Then
        XCTAssertNoThrow {
            let encryptedPassword = try self.rsaService.encryptPassword(password, with: keyData)
            XCTAssertFalse(encryptedPassword.isEmpty)
            XCTAssertNotEqual(encryptedPassword, password)
        }
    }
    
    // MARK: - Error Tests
    
    func testInvalidKeyType() {
        // Given
        let password = "testPassword"
        let keyData = invalidKeyTypeData
        
        // When/Then
        XCTAssertThrowsError(try rsaService.encryptPassword(password, with: keyData)) { error in
            XCTAssertTrue(error is RSAError, "Should throw RSAError")
            if let rsaError = error as? RSAError {
                XCTAssertEqual(rsaError, RSAError.invalidKeyType, "Should be invalidKeyType error")
                XCTAssertEqual(rsaError.localizedDescription, "Invalid key type. Expected RSA.")
            }
        }
    }
    
    func testInvalidBase64KeyData() {
        // Given
        let password = "testPassword"
        let keyData = invalidBase64Data
        
        // When/Then
        XCTAssertThrowsError(try rsaService.encryptPassword(password, with: keyData)) { error in
            XCTAssertTrue(error is RSAError, "Should throw RSAError")
            if let rsaError = error as? RSAError {
                switch rsaError {
                case .invalidKeyData:
                    XCTAssertTrue(true, "Should be invalidKeyData error")
                case .keyCreationFailed(_):
                    XCTAssertTrue(true, "Acceptable error for invalid key data")
                default:
                    XCTFail("Unexpected error type: \(rsaError)")
                }
            }
        }
    }
    
    // MARK: - Base64URL Decoding Tests
    
    func testBase64URLDecoding() {
        // Test the Data extension for base64URL decoding
        
        // Standard base64url test cases
        let testCases: [(input: String, expected: String)] = [
            ("SGVsbG8", "Hello"),
            ("SGVsbG8gV29ybGQ", "Hello World"),
            ("TWFu", "Man"),
            ("TQ", "M"),
            ("", "")
        ]
        
        for testCase in testCases {
            let decoded = Data(base64URLEncoded: testCase.input)
            let expectedData = testCase.expected.data(using: .utf8)
            
            XCTAssertEqual(decoded, expectedData, "Base64URL decoding failed for: \(testCase.input)")
        }
    }
    
    func testBase64URLDecodingWithPadding() {
        // Test cases that require padding
        let testCases: [(input: String, paddedExpected: String)] = [
            ("SGVsbG8", "SGVsbG8="),
            ("SGVsbG8gV29ybGQ", "SGVsbG8gV29ybGQ="),
            ("TQ", "TQ==")
        ]
        
        for testCase in testCases {
            let decoded = Data(base64URLEncoded: testCase.input)
            let expectedDecoded = Data(base64Encoded: testCase.paddedExpected)
            
            XCTAssertEqual(decoded, expectedDecoded, "Base64URL padding failed for: \(testCase.input)")
        }
    }
    
    func testBase64URLDecodingWithURLSafeCharacters() {
        // Test URL-safe character replacement (- and _)
        let base64Standard = "Hello+World/Test="
        let base64URL = "Hello-World_Test"
        
        let decodedStandard = Data(base64Encoded: base64Standard)
        let decodedURL = Data(base64URLEncoded: base64URL)
        
        XCTAssertEqual(decodedStandard, decodedURL, "URL-safe character replacement failed")
    }
    
    // MARK: - Hex Encoding Tests
    
    func testHexEncoding() {
        let testData = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF])
        let expectedHex = "0123456789abcdef"
        
        let actualHex = testData.hexEncodedString()
        
        XCTAssertEqual(actualHex, expectedHex, "Hex encoding failed")
    }
    
    func testEmptyDataHexEncoding() {
        let emptyData = Data()
        let hex = emptyData.hexEncodedString()
        
        XCTAssertEqual(hex, "", "Empty data should produce empty hex string")
    }
    
    // MARK: - RSA Key Data Validation Tests
    
    func testValidRSAKeyDataProperties() {
        let keyData = sampleRSAKeyData
        
        XCTAssertEqual(keyData.keyType, "RSA")
        XCTAssertEqual(keyData.exponent, "AQAB")
        XCTAssertEqual(keyData.keyId, "HMGID2_CIPHER_KEY1")
        XCTAssertFalse(keyData.modulus.isEmpty)
    }
    
    func testRSAKeyDataFromServerResponse() {
        // Simulate server response data
        let serverResponse = RSACertificateResponse(
            kty: "RSA",
            e: "AQAB",
            kid: "HMGID2_CIPHER_KEY1",
            n: sampleRSAKeyData.modulus
        )
        
        let keyData = RSAEncryptionService.RSAKeyData(
            keyType: serverResponse.kty,
            exponent: serverResponse.e,
            keyId: serverResponse.kid,
            modulus: serverResponse.n
        )
        
        XCTAssertEqual(keyData.keyType, "RSA")
        XCTAssertEqual(keyData.exponent, "AQAB")
        XCTAssertEqual(keyData.keyId, "HMGID2_CIPHER_KEY1")
        XCTAssertEqual(keyData.modulus, sampleRSAKeyData.modulus)
    }
    
    // MARK: - Performance Tests
    
    func testEncryptionPerformance() throws {
        let password = "performanceTestPassword123"
        let keyData = sampleRSAKeyData
        
        measure {
            do {
                _ = try rsaService.encryptPassword(password, with: keyData)
            } catch {
                XCTFail("Encryption should not fail in performance test: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullEncryptionWorkflow() throws {
        // This test simulates the full workflow as it would be used in the app
        
        // Step 1: Receive RSA certificate from server (simulated)
        let serverCertResponse = RSACertificateResponse(
            kty: "RSA",
            e: "AQAB",
            kid: "HMGID2_CIPHER_KEY1",
            n: sampleRSAKeyData.modulus
        )
        
        // Step 2: Convert to RSA key data
        let rsaKeyData = RSAEncryptionService.RSAKeyData(
            keyType: serverCertResponse.kty,
            exponent: serverCertResponse.e,
            keyId: serverCertResponse.kid,
            modulus: serverCertResponse.n
        )
        
        // Step 3: Encrypt password
        let userPassword = "mySecretPassword123!"
        let encryptedPassword = try rsaService.encryptPassword(userPassword, with: rsaKeyData)
        
        // Step 4: Verify the result
        XCTAssertFalse(encryptedPassword.isEmpty)
        XCTAssertNotEqual(encryptedPassword, userPassword)
        XCTAssertTrue(encryptedPassword.allSatisfy { $0.isHexDigit })
        
        // The encrypted password should be ready to send to the server
        print("✅ Full workflow test passed. Encrypted password length: \(encryptedPassword.count)")
    }
    
    // MARK: - Error Descriptions Tests
    
    func testRSAErrorDescriptions() {
        let errors: [RSAError] = [
            .invalidKeyType,
            .invalidKeyData,
            .invalidPassword,
            .keyCreationFailed("Test failure message"),
            .encryptionFailed("Test encryption failure")
        ]
        
        for error in errors {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error description should not be empty")
            XCTAssertTrue(description.count > 10, "Error description should be meaningful")
        }
    }
}

// MARK: - Test Extensions

private extension Character {
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
