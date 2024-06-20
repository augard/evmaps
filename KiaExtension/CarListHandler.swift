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

    init(api: Api) {
        self.api = api
    }

    func canHandle(_ intent: INIntent) -> Bool {
        return intent is INListCarsIntent
    }

    func cars() async throws -> [Vehicle] {
        if Authorization.isAuthorized {
            api.authorization = Authorization.authorization
        } else {
            let authorization = try await api.login(
                username: AppConfiguration.username,
                password: AppConfiguration.password
            )
            Authorization.store(data: authorization)
        }
        return try await api.vehicles().vehicles
    }

    func handle(completion: @escaping (INListCarsIntentResponse) -> Void) {
        // completion(.init(code: .inProgress, userActivity:  nil))

        Task {
            let result: INListCarsIntentResponse

            do {
                let cars = try await cars()

                result = .init(code: .success, userActivity: nil)
                result.cars = cars.map { $0.car(with: api.configuration) }
            } catch {
                result = .init(code: .failure, userActivity: nil)
            }
            DispatchQueue.main.async {
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
