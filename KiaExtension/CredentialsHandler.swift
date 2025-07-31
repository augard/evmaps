//
//  CredentialsHandler.swift
//  KiaExtension
//
//  Created by Lukáš Foldýna on 31/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

class CredentialsHandler {
    private let api: Api
    private let credentialClient: LocalCredentialClient
    private var task: (Task<()?, Never>)? = nil

    init(api: Api, credentialClient: LocalCredentialClient) {
        self.api = api
        self.credentialClient = credentialClient

        DarwinNotificationHelper.observe(name: DarwinNotificationHelper.NotificationName.credentialsUpdated) { [weak self] in
            Task {
                await self?.updateCredentials()
            }
        }

        task = Task { [weak self] in
            await self?.updateCredentials()
            self?.task = nil
        }
    }

    func continueOrWaitForCredentials() async {
        guard let task = task else { return }
        _ = await task.result
    }

    private func updateCredentials() async {
        print("CredentialsHandler: Updating credentials")

        if let credentials = try? await credentialClient.fetchCredentials() {
            api.authorization = credentials.authorization
            if let authorization = credentials.authorization {
                Authorization.store(data: authorization)
            } else {
                Authorization.remove()
            }
            print("CredentialsHandler: Successfully updated authorization from local server")
        } else {
            print("CredentialsHandler: Failed to fetch credentials from local server")
            // Fallback to localy stored in keychain
            api.authorization = Authorization.authorization
        }
    }
}
