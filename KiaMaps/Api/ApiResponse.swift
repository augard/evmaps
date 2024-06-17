//
//  ApiResponse.swift
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
    let resultd: UUID
    
    private enum CodingKeys: String, CodingKey {
        case returnCode = "retCode"
        case resultCode = "resCode"
        case result = "resMsg"
        case resultd = "msgId"
    }
}

extension URLResponse {
    var status: Int? {
        (self as? HTTPURLResponse)?.statusCode
    }
}
