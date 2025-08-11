//
//  CredentialsHandler.swift
//  KiaExtension
//
//  Created by Lukáš Foldýna on 31/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation
import os.log

class CredentialsHandler {
    private let api: Api
    private let credentialClient: LocalCredentialClient
    private var task: (Task<()?, Never>)? = nil

    init(api: Api, credentialClient: LocalCredentialClient) {
        self.api = api
        self.credentialClient = credentialClient

        // Not working correctly, it's looping in code
        /*DarwinNotificationHelper.observe(name: DarwinNotificationHelper.NotificationName.credentialsUpdated) { [weak self] in
            self?.task = Task {
                await self?.updateCredentials()
            }
        }*/

        task = Task { [weak self] in
            await self?.updateCredentials()
            self?.task = nil
        }
    }

    func reauthorize() async throws {
        // First try to get credentials from local server
        guard let credentials = LoginCredentialManager.retrieveCredentials() else {
            return
        }
        
        do {
            ExtensionLogger.info("CredentialsHandler: Using credentials from local server for reauthorization", category: "Credentials")
            let authorization = try await api.login(
                username: credentials.username,
                password: credentials.password
            )
            Authorization.store(data: authorization)
        } catch {
            Authorization.remove()
            throw error
        }
    }

    func continueOrWaitForCredentials() async {
        guard let task = task else { return }
        _ = await task.result
    }

    private func updateCredentials() async {
        ExtensionLogger.info("CredentialsHandler: Updating credentials", category: "Credentials")

        if let credentials = try? await credentialClient.fetchCredentials() {
            api.authorization = credentials.authorization
            if let authorization = credentials.authorization {
                Authorization.store(data: authorization)
            } else {
                Authorization.remove()
            }
            
            // Store username and password if available for future use
            if let username = credentials.username, let password = credentials.password {
                ExtensionLogger.info("CredentialsHandler: Successfully received username and password from local server", category: "Credentials")
                LoginCredentialManager.store(
                    credentials: LoginCredentials(
                        username: username,
                        password: password
                    )
                )
            }
            ExtensionLogger.info("CredentialsHandler: Successfully updated authorization from local server", category: "Credentials")
        } else {
            ExtensionLogger.warning("CredentialsHandler: Failed to fetch credentials from local server", category: "Credentials")
            // Fallback to locally stored in keychain
            api.authorization = Authorization.authorization
        }
    }
}
