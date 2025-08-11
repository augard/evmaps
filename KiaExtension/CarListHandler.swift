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

class CarListHandler: NSObject, INListCarsIntentHandling, Handler {
    private let api: Api
    private let credentialsHandler: CredentialsHandler
    private var loginRetry: Bool = false

    init(api: Api, credentialsHandler: CredentialsHandler) {
        self.api = api
        self.credentialsHandler = credentialsHandler
        super.init()
    }

    func canHandle(_ intent: INIntent) -> Bool {
        return intent is INListCarsIntent
    }

    func handle(completion: @escaping (INListCarsIntentResponse) -> Void) {
        Task {
            await credentialsHandler.continueOrWaitForCredentials()
            let result: INListCarsIntentResponse?

            do {
                loginRetry = false
                let cars = try await api.vehicles().vehicles

                result = .init(code: .success, userActivity: nil)
                result?.cars = cars.map { $0.car(with: api.configuration) }
            } catch let error  {
                if let error = error as? ApiError {
                    switch (error, loginRetry) {
                    case (.unauthorized, false):
                        loginRetry = true
                        do {
                            try await credentialsHandler.reauthorize()
                            result = nil
                            handle(completion: completion)
                        } catch {
                            result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                        }
                    case (.unauthorized, true):
                        result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                    case (.unexpectedStatusCode(400), false):
                        result = .init(code: .success, userActivity: nil)
                    default:
                        result = .init(code: .failure, userActivity: nil)
                    }
                } else {
                    result = .init(code: .failure, userActivity: nil)
                }
            }

            guard let result = result else { return }
            await MainActor.run {
                completion(result)
            }
        }
    }

    @objc
    func handle(intent _: INListCarsIntent, completion: @escaping (INListCarsIntentResponse) -> Void) {
        handle(completion: completion)
    }

    func confirm(intent _: INListCarsIntent, completion: @escaping (INListCarsIntentResponse) -> Void) {
        handle(completion: completion)
    }
}

extension Vehicle {
    func car(with configuration: ApiConfiguration) -> INCar {
        let manager = VehicleManager(id: vehicleId)
        manager.store(type: configuration.name + "-" + detailInfo.saleCarmdlEnName)

        let supportedChargingConnectors = manager.vehicleParamter.supportedChargingConnectors
        
        // Get Bluetooth and iAP2 identifiers for this vehicle
        let headUnitIds = headUnitIdentifiers()
        ExtensionLogger.debug("CarListHandler: Vehicle '%@' - Bluetooth: %@, iAP2: %@", category: "CarList", nickname, headUnitIds.bluetooth ?? "none", headUnitIds.iap2 ?? "none")
        
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

        for connector in supportedChargingConnectors {
            guard let power = manager.vehicleParamter.maximumPower(for: connector) else {
                continue
            }
            car.setMaximumPower(.init(value: power, unit: .kilowatts), for: connector)
        }
        return car
    }
}
