//
//  LoginCredentialsManager.swift
//  KiaMaps
//
//  Created by Lukáš Foldýna on 31/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

struct LoginCredentials: Codable {
    let username: String
    let password: String
}

enum LoginCredentialManager {
    private enum Key: String {
        case loginCredentials
    }

    static func store(credentials: LoginCredentials) {
        Keychain<Key>.store(value: credentials, path: .loginCredentials)
    }

    static func retrieveCredentials() -> LoginCredentials? {
        Keychain<Key>.value(for: .loginCredentials)
    }

    static func clearCredentials() {
        Keychain<Key>.removeVakue(at: .loginCredentials)
    }
}
