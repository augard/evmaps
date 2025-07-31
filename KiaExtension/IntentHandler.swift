//
//  IntentHandler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
    static let api: Api = Api(configuration: AppConfiguration.apiConfiguration)
    static let credentialsHandler: CredentialsHandler = {
        CredentialsHandler(
            api: api,
            credentialClient: LocalCredentialClient(extensionIdentifier: "KiaExtension")
        )
    }()

    private lazy var intentHandlers: [Handler] = [
        CarListHandler(api: Self.api, credentialsHandler: Self.credentialsHandler),
        GetCarPowerLevelStatusHandler(api: Self.api, credentialsHandler: Self.credentialsHandler),
    ]

    override func handler(for intent: INIntent) -> Any? {
        intentHandlers.first { $0.canHandle(intent) }
    }
}
