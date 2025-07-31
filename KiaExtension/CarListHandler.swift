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

class CarListHandler: NSObject, INListCarsIntentHandling, Handler {
    private let api: Api
    private let credentialsHandler: CredentialsHandler

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
            let result: INListCarsIntentResponse

            do {
                let cars = try await api.vehicles().vehicles

                result = .init(code: .success, userActivity: nil)
                result.cars = cars.map { $0.car(with: api.configuration) }
            } catch {
                result = .init(code: .failure, userActivity: nil)
            }
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
        let car: INCar = .init(
            carIdentifier: vehicleId.uuidString,
            displayName: configuration.name + " - " + nickname,
            year: year,
            make: configuration.name,
            model: vehicleName,
            color: UIColor.systemGreen.cgColor,
            headUnit: .init(bluetoothIdentifier: nil, iAP2Identifier: nil),
            supportedChargingConnectors: supportedChargingConnectors
        )

        for connector in supportedChargingConnectors {
            if let power = manager.vehicleParamter.maximumPower(for: connector) {
                car.setMaximumPower(.init(value: power, unit: .kilowatts), for: connector)
            }
        }

        return car
    }
}
