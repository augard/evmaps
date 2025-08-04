//
//  DataExtensionsTests.swift
//  KiaMapsTests
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import XCTest
@testable import KiaMaps

final class DataExtensionsTests: XCTestCase {
    
    // MARK: - Base64URL Decoding Tests
    
    func testBase64URLDecodingBasicCases() {
        // Test basic decoding without padding
        let testCases: [(input: String, expected: String)] = [
            ("SGVsbG8", "Hello"),
            ("SGVsbG8gV29ybGQ", "Hello World"),
            ("TWFu", "Man"),
            ("TQ", "M"),
            ("", "")
        ]
        
        for (input, expected) in testCases {
            let decoded = Data(base64URLEncoded: input)
            let expectedData = expected.data(using: .utf8)
            
            XCTAssertEqual(decoded, expectedData, "Failed to decode: '\(input)' -> '\(expected)'")
        }
    }
    
    func testBase64URLDecodingWithPaddingRequired() {
        // Test cases where padding is automatically added
        let testCases: [(input: String, output: String)] = [
            ("TQ", "M"),           // Needs "=="
            ("TWE", "Ma"),         // Needs "="
            ("TWFu", "Man"),       // No padding needed
            ("TWFuIQ", "Man!")     // Needs "=="
        ]
        
        for (input, expected) in testCases {
            let decoded = Data(base64URLEncoded: input)
            let expectedData = expected.data(using: .utf8)
            
            XCTAssertEqual(decoded, expectedData, "Padding failed for: '\(input)' -> '\(expected)'")
        }
    }
    
    func testBase64URLDecodingWithURLSafeCharacters() {
        // Test URL-safe character substitution (- instead of +, _ instead of /)
        struct TestCase {
            let base64URL: String
            let base64Standard: String
            let expected: String
        }
        
        let testCases = [
            TestCase(
                base64URL: "PDw_Pz4-", 
                base64Standard: "PDw/Pz4+", 
                expected: "<<??>"
            ),
            TestCase(
                base64URL: "VGVzdC1VUkxfU2FmZQ", 
                base64Standard: "VGVzdC1VUkxfU2FmZQ==", 
                expected: "Test-URL_Safe"
            )
        ]
        
        for testCase in testCases {
            let decodedURL = Data(base64URLEncoded: testCase.base64URL)
            let decodedStandard = Data(base64Encoded: testCase.base64Standard)
            let expectedData = testCase.expected.data(using: .utf8)
            
            XCTAssertEqual(decodedURL, expectedData, "URL-safe decoding failed")
            XCTAssertEqual(decodedURL, decodedStandard, "URL-safe should match standard base64")
        }
    }
    
    func testBase64URLDecodingInvalidInput() {
        // Test invalid base64 input
        let invalidInputs = [
            "Invalid!@#",
            "Contains spaces",
            "SGVsb G8",  // Space in middle
            "SGVsb$",    // Invalid character
        ]
        
        for invalidInput in invalidInputs {
            let decoded = Data(base64URLEncoded: invalidInput)
            XCTAssertNil(decoded, "Should return nil for invalid input: '\(invalidInput)'")
        }
    }
    
    func testBase64URLDecodingRealWorldExample() {
        // Test with actual RSA modulus-like data (shortened for testing)
        let rsaModulusBase64URL = "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw"
        
        let decoded = Data(base64URLEncoded: rsaModulusBase64URL)
        XCTAssertNotNil(decoded, "Should decode real-world RSA modulus data")
        XCTAssertTrue(decoded!.count > 0, "Decoded data should not be empty")
    }
    
    // MARK: - Hex Encoding Tests
    
    func testHexEncodingBasicCases() {
        let testCases: [(input: [UInt8], expected: String)] = [
            ([0x00], "00"),
            ([0xFF], "ff"),
            ([0x01, 0x23, 0x45, 0x67], "01234567"),
            ([0x89, 0xAB, 0xCD, 0xEF], "89abcdef"),
            ([], "")
        ]
        
        for (input, expected) in testCases {
            let data = Data(input)
            let hex = data.hexEncodedString()
            
            XCTAssertEqual(hex, expected, "Hex encoding failed for: \(input)")
        }
    }
    
    func testHexEncodingAllBytes() {
        // Test all possible byte values
        let allBytes = Array(0...255).map { UInt8($0) }
        let data = Data(allBytes)
        let hex = data.hexEncodedString()
        
        // Should be exactly 512 characters (256 bytes * 2 chars each)
        XCTAssertEqual(hex.count, 512, "Hex encoding should produce 512 characters for 256 bytes")
        
        // Should start with "00" and end with "ff"
        XCTAssertTrue(hex.hasPrefix("00"), "Should start with 00")
        XCTAssertTrue(hex.hasSuffix("ff"), "Should end with ff")
        
        // Should contain only valid hex characters
        XCTAssertTrue(hex.allSatisfy { character in
            ("0"..."9").contains(character) || ("a"..."f").contains(character)
        }, "Should contain only lowercase hex characters")
    }
    
    func testHexEncodingLargeData() {
        // Test with larger data (simulating encrypted password)
        let largeData = Data(repeating: 0xA5, count: 256) // 256 bytes of 0xA5
        let hex = largeData.hexEncodedString()
        
        XCTAssertEqual(hex.count, 512, "Large data hex encoding length")
        XCTAssertEqual(hex, String(repeating: "a5", count: 256), "Should be all 'a5'")
    }
    
    func testHexEncodingEmptyData() {
        let emptyData = Data()
        let hex = emptyData.hexEncodedString()
        
        XCTAssertEqual(hex, "", "Empty data should produce empty hex string")
    }
    
    // MARK: - Round-trip Tests
    
    func testBase64URLRoundTrip() {
        // Test that we can round-trip data through base64URL encoding/decoding
        let originalStrings = [
            "Hello World",
            "Test123!@#",
            "пароль测试🔒",
            "",
            "A",
            "Special characters: +/="
        ]
        
        for original in originalStrings {
            guard let originalData = original.data(using: .utf8) else {
                XCTFail("Could not convert string to UTF-8 data")
                continue
            }
            
            // Encode to base64URL (we need to implement this for round-trip testing)
            let base64URL = originalData.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .trimmingCharacters(in: CharacterSet(charactersIn: "="))
            
            // Decode back
            let decodedData = Data(base64URLEncoded: base64URL)
            
            XCTAssertEqual(decodedData, originalData, "Round-trip failed for: '\(original)'")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBase64URLDecodingPerformance() {
        let testData = "o5OJwXceU_cJOYJyNP5pUxeTdMybhJ7rhx3f_VYzU8VgUlHbHhBqjlqoHM1_ie7OJNyOtKs0ijFebO7QKq-3bw3vWkTxJWlPknHkBJxoH5P-D7t59RibA7BPI6rsc2bBE8PSzCahfQ-bMOhAwMWesOOajN9ki-caE6MUMS6naRhmxUjYe4OHVuEKCPvYZ9O188L4yKqUfCRWXOMjmJBvMz1KFtHZto9SdaC25v5dN82R4JgRQ4Pq9PDVd3v08egpS7BURblRGg22jS9fouyKceoie4s6JiKeyvvGj0qRKJSFUGLP0ScpUcY1XgUMjGNC51ncTOQdMSGxaj9k623m7w"
        
        measure {
            for _ in 0..<100 {
                _ = Data(base64URLEncoded: testData)
            }
        }
    }
    
    func testHexEncodingPerformance() {
        let testData = Data(repeating: 0xAB, count: 1024) // 1KB of data
        
        measure {
            for _ in 0..<100 {
                _ = testData.hexEncodedString()
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testBase64URLDecodingEdgeCases() {
        // Test various edge cases
        struct EdgeCase {
            let input: String
            let shouldSucceed: Bool
            let description: String
        }
        
        let edgeCases = [
            EdgeCase(input: "A", shouldSucceed: false, description: "Single character (invalid padding)"),
            EdgeCase(input: "AA", shouldSucceed: true, description: "Two characters (valid with padding)"),
            EdgeCase(input: "AAA", shouldSucceed: true, description: "Three characters (valid with padding)"),
            EdgeCase(input: "AAAA", shouldSucceed: true, description: "Four characters (no padding needed)"),
            EdgeCase(input: "A===", shouldSucceed: false, description: "Too much padding"),
            EdgeCase(input: "AA==", shouldSucceed: true, description: "Standard base64 with padding"),
        ]
        
        for edgeCase in edgeCases {
            let result = Data(base64URLEncoded: edgeCase.input)
            
            if edgeCase.shouldSucceed {
                XCTAssertNotNil(result, "Should succeed: \(edgeCase.description)")
            } else {
                XCTAssertNil(result, "Should fail: \(edgeCase.description)")
            }
        }
    }
}