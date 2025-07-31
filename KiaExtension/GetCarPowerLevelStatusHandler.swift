//
//  GetCarPowerLevelStatusHandler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Intents
import UIKit

class GetCarPowerLevelStatusHandler: NSObject, INGetCarPowerLevelStatusIntentHandling, Handler {
    private let api: Api
    private let credentialsHandler: CredentialsHandler
    private var manager = VehicleManager(id: UUID())
    private var vehicleParameters: VehicleParameters { manager.vehicleParamter }

    private var timer: Timer?
    #if targetEnvironment(simulator)
        private let mock: Bool = true
    #else
        private let mock: Bool = false
    #endif

    init(api: Api, credentialsHandler: CredentialsHandler) {
        self.api = api
        self.credentialsHandler = credentialsHandler
        super.init()
    }
    
    func canHandle(_ intent: INIntent) -> Bool {
        return intent is INGetCarPowerLevelStatusIntent
    }

    func fetchCarStatus(carId: UUID) async -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse

        do {
            let status = try await api.vehicleCachedStatus(carId)
            // Fetched status is older than 5 minutes, try ask for refresh in next 5 mins
            if status.lastUpdateTime + 5 * 60 < Date.now {
                _ = try await api.refreshVehicle(carId)
            } else {
                try manager.store(status: status)
            }
            result = status.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
        } catch {
            manager.restoreOutdatedData()
            if let cachedData = try? manager.vehicleStatus {
                return cachedData.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
            } else {
                result = .init(code: .failure, userActivity: nil)
            }
        }
        return result
    }

    @objc
    func handle(intent: INGetCarPowerLevelStatusIntent, completion: @escaping (INGetCarPowerLevelStatusIntentResponse) -> Void) {
        guard let identifier = intent.carName?.vocabularyIdentifier, let carId = UUID(uuidString: identifier) else {
            completion(.init(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        manager = VehicleManager(id: carId)

        if mock {
            // Use mock for testing
            completion(VehicleStatusResponse.lowBatteryPreview.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters))
        } else if let cachedData = try? manager.vehicleStatus {
            // Use data from cache
            if cachedData.lastUpdateTime + 5 * 60 < Date.now {
                Task {
                    await credentialsHandler.continueOrWaitForCredentials()
                    _ = try await api.refreshVehicle(carId)
                }
                manager.removeLastUpdateDate()
            }
            completion(cachedData.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters))
        } else {
            // Get data from server
            Task {
                await credentialsHandler.continueOrWaitForCredentials()
                let result = await fetchCarStatus(carId: carId)

                await MainActor.run {
                    completion(result)
                }
            }
        }
    }

    func startSendingUpdates(for intent: INGetCarPowerLevelStatusIntent, to observer: any INGetCarPowerLevelStatusIntentResponseObserver) {
        let lastBatteryCharge = BatteryChargeBox()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 4, repeats: true, block: { [weak self] _ in
            guard let identifier = intent.carName?.vocabularyIdentifier, let carId = UUID(uuidString: identifier) else {
                observer.didUpdate(getCarPowerLevelStatus: .init(code: .failureRequiringAppLaunch, userActivity: nil))
                return
            }

            guard let self = self else { return }
            self.manager = VehicleManager(id: carId)

            if self.mock {
                let response = VehicleStatusResponse.lowBatteryPreview.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
                lastBatteryCharge.value = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge.value)
            } else if let cachedData = try? self.manager.vehicleStatus {
                let response = cachedData.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
                lastBatteryCharge.value = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge.value)
            }

            Task {
                await self.credentialsHandler.continueOrWaitForCredentials()
                let response = await self.fetchCarStatus(carId: carId)

                await MainActor.run {
                    lastBatteryCharge.value = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge.value)
                }
            }
        })
    }

    func stopSendingUpdates(for _: INGetCarPowerLevelStatusIntent) {
        timer?.invalidate()
        timer = nil
    }

    private func updateCharge(
        observer: any INGetCarPowerLevelStatusIntentResponseObserver,
        response: INGetCarPowerLevelStatusIntentResponse,
        lastBatteryCharge: Float?
    ) -> Float? {
        if let lastBatteryCharge = lastBatteryCharge, lastBatteryCharge == response.chargePercentRemaining {
            return lastBatteryCharge
        }
        observer.didUpdate(getCarPowerLevelStatus: response)
        return response.chargePercentRemaining
    }
}

class BatteryChargeBox {
    var value: Float?
    init(_ value: Float? = nil) { self.value = value }
}

extension VehicleStatusResponse.State {
    func toIntentResponse(carId: UUID, vehicleParameters: VehicleParameters) -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: .now)
        let chargingInformation = vehicle.green.chargingInformation
        let batteryManagement = vehicle.green.batteryManagement
        let drivetrain = vehicle.drivetrain
        let batteryCapacity = Double(batteryManagement.batteryCapacity.value)
        let batteryRemain = Float(batteryManagement.batteryRemain.ratio)

        result = .init(code: .success, userActivity: nil)
        result.carIdentifier = carId.uuidString
        result.dateOfLastStateUpdate = dateComponents
        result.consumptionFormulaArguments = vehicleParameters.consumptionFormulaArguments()
        result.chargingFormulaArguments = vehicleParameters.chargingFormulaArguments(maximumBatteryCapacity: batteryCapacity, unit: .kilojoules)

        result.maximumDistance = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemaining = .init(value: Double(drivetrain.fuelSystem.dte.total), unit: drivetrain.fuelSystem.dte.unit.measuremntUnit)

        result.maximumDistanceElectric = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemainingElectric = .init(value: Double(drivetrain.fuelSystem.dte.total), unit: drivetrain.fuelSystem.dte.unit.measuremntUnit)

        result.minimumBatteryCapacity = .init(value: 0, unit: .kilowattHours)
        result.currentBatteryCapacity = .init(value: batteryCapacity * 0.01 * Double(batteryRemain), unit: .kilojoules)
        result.maximumBatteryCapacity = .init(value: batteryCapacity, unit: .kilojoules)

        result.charging = chargingInformation.electricCurrentLevel.state == 1
        if result.charging == true {
            let charging = chargingInformation.charging
            let measurement = Measurement<UnitDuration>(value: charging.remainTime, unit: charging.remainTimeUnit.unitDuration)
            result.minutesToFull = Int(measurement.converted(to: .minutes).value)
            result.activeConnector = .ccs2
        } else {
            result.minutesToFull = chargingInformation.estimatedTime.quick
            result.activeConnector = nil
        }

        result.chargePercentRemaining = batteryRemain / 100

        return result
    }
}
