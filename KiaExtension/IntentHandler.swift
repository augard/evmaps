//
//  IntentHandler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Intents

/// Main intent handler for the KiaExtension that routes Siri/Maps requests to appropriate handlers
/// Provides entry point for all supported Intents including vehicle information and charging status
class IntentHandler: INExtension {
    /// Shared API client instance for making vehicle API requests
    static let api: Api = Api(configuration: AppConfiguration.apiConfiguration, rsaService: .init())
    
    /// Shared credentials handler for managing authentication across extension requests
    static let credentialsHandler: CredentialsHandler = {
        CredentialsHandler(
            api: api,
            credentialClient: LocalCredentialClient(extensionIdentifier: "KiaExtension")
        )
    }()
    
    /// Initializes the intent handler and configures extension logging
    override init() {
        super.init()
        // Configure shared logger for extension
        #if DEBUG
        ExtensionLogger.configureSharedLogger(enableRemoteLogging: true)
        #else
        ExtensionLogger.configureSharedLogger(enableRemoteLogging: false)
        #endif
        logInfo("IntentHandler initialized", category: .ext)
    }

    /// Array of specialized intent handlers for different types of requests
    /// Each handler implements the Handler protocol and can handle specific intent types
    private lazy var intentHandlers: [Handler] = [
        CarListHandler(api: Self.api, credentialsHandler: Self.credentialsHandler),
        GetCarPowerLevelStatusHandler(api: Self.api, credentialsHandler: Self.credentialsHandler),
    ]

    /// Routes incoming intents to the appropriate specialized handler
    /// - Parameter intent: The INIntent to be handled
    /// - Returns: The first handler that can process this intent type, or nil if none can handle it
    override func handler(for intent: INIntent) -> Any? {
        intentHandlers.first { $0.canHandle(intent) }
    }
}
