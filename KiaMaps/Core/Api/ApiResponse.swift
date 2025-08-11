//
//  ApiResponseValue.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

struct ApiResponse<Result: Decodable>: Decodable {
    let returnCode: String
    let resultCode: String
    let result: Result
    let resultId: UUID

    private enum CodingKeys: String, CodingKey {
        case returnCode = "retCode"
        case resultCode = "resCode"
        case result = "resMsg"
        case resultId = "msgId"
    }
}

struct ApiResponseValue<Result: Decodable>: Decodable {
    let returnCode: Int
    let returnValue: Result
    let resultCode: Int?
    let resultMessage: String?
    let resultSubMessage: String?
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

struct ApiResponseEmpty: Decodable {
    let returnCode: String
    let resultCode: String
    let resultId: UUID

    private enum CodingKeys: String, CodingKey {
        case returnCode = "retCode"
        case resultCode = "resCode"
        case resultId = "msgId"
    }
}

extension URLResponse {
    var status: Int? {
        (self as? HTTPURLResponse)?.statusCode
    }
}
