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
        
        // Observe credential updates from the main app
        setupCredentialObservers()
        
        // Update API authorization if available
        updateApiAuthorization()
    }
    
    private func setupCredentialObservers() {
        // Listen for credential updates
        DarwinNotificationHelper.observe(name: DarwinNotificationHelper.NotificationName.credentialsUpdated) {
            [weak self] in
            DispatchQueue.main.async {
                self?.updateApiAuthorization()
            }
        }
        
        // Listen for credential clearing
        DarwinNotificationHelper.observe(name: DarwinNotificationHelper.NotificationName.credentialsCleared) {
            [weak self] in
            DispatchQueue.main.async {
                self?.api.authorization = nil
            }
        }
    }
    
    private func updateApiAuthorization() {
        if Authorization.isAuthorized {
            api.authorization = Authorization.authorization
        }
    }

    override func handler(for intent: INIntent) -> Any? {
        intentHandlers.first { $0.canHandle(intent) }
    }
}
