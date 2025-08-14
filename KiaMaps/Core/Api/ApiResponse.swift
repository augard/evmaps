//
//  ApiResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

/// Generic API response wrapper containing result data and metadata
/// Used for responses with string-based status codes
struct ApiResponse<Result: Decodable>: Decodable {
    /// Return code indicating request status
    let returnCode: String
    /// Result code indicating operation status
    let resultCode: String
    /// The actual response data
    let result: Result
    /// Unique identifier for this response
    let resultId: UUID

    private enum CodingKeys: String, CodingKey {
        case returnCode = "retCode"
        case resultCode = "resCode"
        case result = "resMsg"
        case resultId = "msgId"
    }
}

/// API response wrapper for responses with numeric status codes and detailed error information
/// Provides more structured error handling than basic ApiResponse
struct ApiResponseValue<Result: Decodable>: Decodable {
    /// Numeric return code indicating request status
    let returnCode: Int
    /// The actual response data
    let returnValue: Result
    /// Optional numeric result code for additional status information
    let resultCode: Int?
    /// Optional result message for status details
    let resultMessage: String?
    /// Optional sub-message for additional error context
    let resultSubMessage: String?
    /// Unique identifier for this response
    let resultId: UUID

    private enum CodingKeys: String, CodingKey {
        case returnCode = "retCode"
        case returnValue = "retValue"
        case resultCode = "resCode"
        case resultMessage = "resMsg"
        case resultSubMessage = "resSubMsg"
        case resultId = "retId"
    }
}

/// API response for operations that return no data, only status information
/// Used for confirmation responses and operations without return values
struct ApiResponseEmpty: Decodable {
    /// Return code indicating request status
    let returnCode: String
    /// Result code indicating operation status
    let resultCode: String
    /// Unique identifier for this response
    let resultId: UUID

    private enum CodingKeys: String, CodingKey {
        case returnCode = "retCode"
        case resultCode = "resCode"
        case resultId = "msgId"
    }
}

extension URLResponse {
    /// Extracts HTTP status code from URLResponse if it's an HTTPURLResponse
    var status: Int? {
        (self as? HTTPURLResponse)?.statusCode
    }
}
