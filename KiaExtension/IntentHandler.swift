//
//  IntentHandler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
    private let api: Api
    private let credentialsHandler: CredentialsHandler

    private lazy var intentHandlers: [Handler] = [
        CarListHandler(api: api, credentialsHandler: credentialsHandler),
        GetCarPowerLevelStatusHandler(api: api, credentialsHandler: credentialsHandler),
    ]

    override init() {
        api = Api(configuration: AppConfiguration.apiConfiguration)
        credentialsHandler = CredentialsHandler(
            api: api,
            credentialClient: LocalCredentialClient(extensionIdentifier: "KiaExtension")
        )
        super.init()
    }

    override func handler(for intent: INIntent) -> Any? {
        intentHandlers.first { $0.canHandle(intent) }
    }
}
