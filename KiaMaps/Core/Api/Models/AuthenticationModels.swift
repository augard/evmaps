//
//  NewAuthenticationModels.swift
//  KiaMaps
//
//  Created by Claude on 31.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation

// MARK: - Client Configuration

struct ClientConfiguration: Codable {
    let clientId: String
    let companyCode: String
    let clientName: String
    let scope: String
    let clientAddition: ClientAddition
    let clientRedirectUris: [ClientRedirectUri]
    let clientConnectors: [ClientConnector]
    let connectorAddition: ConnectorAddition
}

struct ClientAddition: Codable {
    let clientId: String?
    let serviceId: String
    let ssoEnabled: Bool
    let accountConnectorEnabled: Bool
    let accountManagedItems: String
    let accountOptionItems: String
    let secondAuthManagedItems: String
    let loginMethodItems: String
    let socialAuthManagedItems: String
    let externalAuthManagedItem: String?
    let headerLogo: String?
    let formSkin: String
    let accessLimitBirthYear: Int
    let rememberMeEnabled: Bool
    let serviceRegion: String
    let emailAuthLaterEnabled: Bool
}

struct ClientRedirectUri: Codable {
    let redirectUri: String
    let userAgent: String
    let usage: String
}

struct ClientConnector: Codable {
    let connectorClientId: String
}

struct ConnectorAddition: Codable {
    let idpCd: String
}

// MARK: - Password Encryption Settings

struct PasswordEncryptionSettings: Codable {
    let groupCode: String
    let detailCode: String
    let detailDescription: String
    let useEnabled: Bool
    let value1: String
    let value2: String
    let value3: String
    let value4: String
    let value5: String
}

// MARK: - RSA Certificate

struct RSACertificateResponse: Codable {
    let kty: String  // Key type (RSA)
    let e: String    // Exponent (AQAB)
    let kid: String  // Key ID (HMGID2_CIPHER_KEY1)
    let n: String    // Modulus (base64url encoded)
}

// MARK: - OAuth2 Flow

struct OAuth2InitializationResult {
    let csrfToken: String
    let sessionKey: String
    let cookies: [HTTPCookie]
}

struct AuthorizationCodeResult {
    let code: String
    let state: String
    let loginSuccess: Bool
}

// MARK: - Token Response

struct TokenResponse: Codable {
    let scope: String?
    let connector: [String: ConnectorTokenInfo]?
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case scope, connector
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct ConnectorTokenInfo: Codable {
    let scope: String?
    let idpCd: String
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case scope
        case idpCd = "idp_cd"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

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

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case connectorAuthorizationFailed
    case clientConfigurationFailed
    case encryptionSettingsFailed
    case certificateRetrievalFailed
    case oauth2InitializationFailed
    case signInFailed
    case authorizationCodeNotFound
    case tokenExchangeFailed
    case csrfTokenNotFound
    case sessionKeyNotFound
    
    var errorDescription: String? {
        switch self {
        case .connectorAuthorizationFailed:
            "Client connector authorization failed"
        case .clientConfigurationFailed:
            "Failed to retrieve client configuration"
        case .encryptionSettingsFailed:
            "Failed to retrieve encryption settings or encryption is disabled"
        case .certificateRetrievalFailed:
            "Failed to retrieve RSA certificate"
        case .oauth2InitializationFailed:
            "Failed to initialize OAuth2 flow"
        case .signInFailed:
            "Sign in failed"
        case .authorizationCodeNotFound:
            "Authorization code not found in response"
        case .tokenExchangeFailed:
            "Failed to exchange authorization code for tokens"
        case .csrfTokenNotFound:
            "CSRF token not found in response"
        case .sessionKeyNotFound:
            "Session key not found in response"
        }
    }
}
