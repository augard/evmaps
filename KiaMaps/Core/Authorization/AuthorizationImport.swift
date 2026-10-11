//
//  AuthorizationImport.swift
//  KiaMaps
//
//  Imports tokens issued by an approved Kia integration or local broker.
//

import Foundation

struct AuthorizationImportPayload: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let deviceId: UUID?
    let isCcuCCS2Supported: Bool?

    func authorization(for configuration: ApiConfiguration) throws -> AuthorizationData {
        let normalizedAccessToken = accessToken
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .removingBearerPrefix()
        guard !normalizedAccessToken.isEmpty else {
            throw AuthorizationImportError.missingAccessToken
        }
        guard expiresIn > 0 else {
            throw AuthorizationImportError.invalidExpiry
        }

        return AuthorizationData(
            stamp: AuthorizationData.generateStamp(for: configuration),
            deviceId: deviceId ?? UUID(),
            accessToken: normalizedAccessToken,
            expiresIn: expiresIn,
            refreshToken: refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            isCcuCCS2Supported: isCcuCCS2Supported ?? true,
            source: .external
        )
    }

    static func decode(from json: String) throws -> Self {
        guard let data = json.data(using: .utf8) else {
            throw AuthorizationImportError.invalidJSON
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw AuthorizationImportError.invalidJSON
        }
    }
}

enum AuthorizationImportError: LocalizedError, Equatable {
    case invalidJSON
    case missingAccessToken
    case invalidExpiry

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "The token bundle is not valid JSON."
        case .missingAccessToken:
            "The token bundle does not contain an access token."
        case .invalidExpiry:
            "expiresIn must be greater than zero."
        }
    }
}

private extension String {
    func removingBearerPrefix() -> String {
        let prefix = "Bearer"
        guard count >= prefix.count,
              self.prefix(prefix.count).caseInsensitiveCompare(prefix) == .orderedSame
        else {
            return self
        }

        let remainder = dropFirst(prefix.count)
        guard remainder.isEmpty || remainder.first?.isWhitespace == true else {
            return self
        }
        return String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
