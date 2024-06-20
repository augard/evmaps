//
//  IntentHandler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
    let api: Api

    private lazy var intentHandlers: [Handler] = [
        CarListHandler(api: api),
        GetCarPowerLevelStatusHandler(api: api),
    ]

    override init() {
        api = Api(configuration: AppConfiguration.apiConfiguration)
        super.init()
    }

    override func handler(for intent: INIntent) -> Any? {
        intentHandlers.first { $0.canHandle(intent) }
    }
}
