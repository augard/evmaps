//
//  AuthorizationResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 30.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

struct AuthorizationResponse: Decodable {
    let accessToken: String
    let tokenType: TokenType
    let refreshToken: String
    let expiresIn: Int
    
    enum TokenType: String, Codable {
        case bearer = "Bearer"
    }
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
