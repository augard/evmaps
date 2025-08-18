//
//  CarListHandler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Intents
import UIKit
import os.log

/// Handler for INListCarsIntent that provides vehicle information to Apple Maps and Siri
/// Fetches the user's vehicles from the API and converts them to INCar objects with charging capabilities
class CarListHandler: NSObject, INListCarsIntentHandling, Handler {
    /// API client for fetching vehicle data
    private let api: Api
    /// Credentials handler for authentication management
    private let credentialsHandler: CredentialsHandler
    /// Flag to prevent infinite login retry loops
    private var loginRetry: Bool = false

    /// Initializes the handler with required dependencies
    /// - Parameters:
    ///   - api: API client for vehicle requests
    ///   - credentialsHandler: Authentication manager
    init(api: Api, credentialsHandler: CredentialsHandler) {
        self.api = api
        self.credentialsHandler = credentialsHandler
        super.init()
    }

    /// Determines if this handler can process the given intent
    /// - Parameter intent: The intent to check
    /// - Returns: True if this is an INListCarsIntent
    func canHandle(_ intent: INIntent) -> Bool {
        intent is INListCarsIntent
    }

    /// Internal handler that fetches vehicles with proper error handling and authentication
    /// - Parameters:
    ///   - intent: The intent requesting vehicle list
    func handle(intent: INListCarsIntent) async -> INListCarsIntentResponse {
        await credentialsHandler.continueOrWaitForCredentials()
        let result: INListCarsIntentResponse

        do {
            loginRetry = false
            let cars = try await api.vehicles().vehicles

            result = .init(code: .success, userActivity: nil)
            result.cars = cars.map { $0.car(with: api.configuration) }
            logDebug("Loaded \(cars.count) cars", category: .vehicle)
        } catch let error  {
            if let error = error as? ApiError {
                switch (error, loginRetry) {
                case (.unauthorized, false):
                    loginRetry = true
                    do {
                        logWarning("Unauthorized trying retry (Status code 401)", category: .auth)
                        try await credentialsHandler.reauthorize()
                        result = await handle(intent: intent)
                        logDebug("Successfully reauthorized", category: .auth)
                    } catch {
                        logError("Failed to reauthorize, unknown error '\(error.localizedDescription)'", category: .auth)
                        result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                    }
                case (.unauthorized, true):
                    logError("Unauthorized after retry (Status code 401)", category: .auth)
                    result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                default:
                    logError("Unknown Api Error '\(error.localizedDescription)'", category: .api)
                    result = .init(code: .failure, userActivity: nil)
                }
            } else {
                logError("Unknown error '\(error.localizedDescription)'", category: .general)
                result = .init(code: .failure, userActivity: nil)
            }
        }
        return result
    }
}

extension Vehicle {
    /// Converts a Vehicle model object to an INCar object for Apple Maps integration
    /// - Parameter configuration: API configuration containing brand information
    /// - Returns: INCar object with charging capabilities and head unit identifiers
    func car(with configuration: ApiConfiguration) -> INCar {
        let manager = VehicleManager(id: vehicleId)
        manager.store(type: configuration.name + "-" + detailInfo.saleCarmdlEnName)

        let supportedChargingConnectors = manager.vehicleParamter.supportedChargingConnectors
        
        // Get Bluetooth and iAP2 identifiers for this vehicle
        let headUnitIds = headUnitIdentifiers()
        logDebug("Vehicle '\(nickname)' - Bluetooth: \(headUnitIds.bluetooth ?? "none"), iAP2: \(headUnitIds.iap2 ?? "none")", category: .vehicle)
        
        let car: INCar = .init(
            carIdentifier: vehicleId.uuidString,
            displayName: configuration.name + " - " + nickname,
            year: year,
            make: configuration.name,
            model: vehicleName,
            color: UIColor.systemGreen.cgColor,
            headUnit: .init(bluetoothIdentifier: headUnitIds.bluetooth, iAP2Identifier: headUnitIds.iap2),
            supportedChargingConnectors: supportedChargingConnectors
        )

        // Set maximum charging power for each supported connector type
        for connector in supportedChargingConnectors {
            guard let power = manager.vehicleParamter.maximumPower(for: connector) else {
                continue
            }
            car.setMaximumPower(.init(value: power, unit: .kilowatts), for: connector)
        }
        return car
    }
}
