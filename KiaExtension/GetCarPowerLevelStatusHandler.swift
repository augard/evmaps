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
    private var manager = VehicleManager(id: UUID())
    private var vehicleParameters: VehicleParameters { manager.vehicleParamter }
    
    private var timer: Timer?
    #if targetEnvironment(simulator)
    private let mock: Bool = true
    #else
    private let mock: Bool = false
    #endif
    
    init(api: Api) {
        self.api = api
    }
    
    func canHandle(_ intent: INIntent) -> Bool {
        return intent is INGetCarPowerLevelStatusIntent
    }
    
    func responseFromCarStatus(carId: UUID, status: VehicleStatusResponse) -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: .now)
        let chargingInformation = status.state.vehicle.green.chargingInformation
        let batteryManagement = status.state.vehicle.green.batteryManagement
        let drivetrain = status.state.vehicle.drivetrain
        let batteryCapacity = Double(batteryManagement.batteryCapacity.value)
        let batteryRemain = Float(batteryManagement.batteryRemain.ratio)
        
        result = .init(code: .success, userActivity: nil)
        result.carIdentifier = carId.uuidString
        result.dateOfLastStateUpdate = dateComponents
        result.consumptionFormulaArguments = consumptionFormulaArguments()
        result.chargingFormulaArguments = chargingFormulaArguments(maximumBatteryCapacity: batteryCapacity, unit: .kilojoules)
        
        result.maximumDistance = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemaining = .init(value: Double(drivetrain.fuelSystem.dte.total), unit: drivetrain.fuelSystem.dte.unit.unitLenght)
        
        result.maximumDistanceElectric = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemainingElectric = .init(value: Double(drivetrain.fuelSystem.dte.total), unit: drivetrain.fuelSystem.dte.unit.unitLenght)
        
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
    
    func mockCarStatus(carId: UUID) -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse
        
        let maximumCapacity: Double = 100.0
        let currentCharge: Double = 39.0
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: .now)
        
        result = .init(code: .success, userActivity: nil)
        result.carIdentifier = carId.uuidString
        result.dateOfLastStateUpdate = dateComponents
        result.consumptionFormulaArguments = consumptionFormulaArguments()
        result.chargingFormulaArguments = chargingFormulaArguments(maximumBatteryCapacity: maximumCapacity, unit: .kilowattHours)
        
        result.maximumDistance = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemaining = .init(value: 189, unit: .kilometers)
        
        result.maximumDistanceElectric = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemainingElectric = .init(value: 189, unit: .kilometers)
        
        result.minimumBatteryCapacity = .init(value: 0, unit: .kilowattHours)
        result.currentBatteryCapacity = .init(value: currentCharge, unit: .kilowattHours)
        result.maximumBatteryCapacity = .init(value: maximumCapacity, unit: .kilowattHours)
        
        result.charging = true
        result.activeConnector = .ccs2
        
        result.chargePercentRemaining = Float(currentCharge / 100)
        result.minutesToFull = 24
        
        return result
    }
    
    func carStatus(carId: UUID) async -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse
        
        do {
            if Authorization.isAuthorized {
                api.authorization = Authorization.authorization
            } else {
                let authorization = try await api.login(username: AppConfiguration.username, password: AppConfiguration.password)
                Authorization.store(data: authorization)
            }
            
            let status = try await api.vehicleCachedStatus(carId)
            try manager.store(status: status)
            
            result = responseFromCarStatus(carId: carId, status: status)
        } catch {
            result = .init(code: .failure, userActivity: nil)
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
            completion(mockCarStatus(carId: carId))
            return
        } else if let cachedData = try? manager.vehicleStatus {
            completion(responseFromCarStatus(carId: carId, status: cachedData))
            return
        }
        
        // completion(.init(code: .inProgress, userActivity: nil))
        
        Task {
            let result = await carStatus(carId: carId)
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func startSendingUpdates(for intent: INGetCarPowerLevelStatusIntent, to observer: any INGetCarPowerLevelStatusIntentResponseObserver) {
        var lastBatteryCharge: Float?
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 4, repeats: true, block: { [weak self] _ in
            guard let identifier = intent.carName?.vocabularyIdentifier, let carId = UUID(uuidString: identifier) else {
                observer.didUpdate(getCarPowerLevelStatus: .init(code: .failureRequiringAppLaunch, userActivity: nil))
                return
            }
            
            guard let self = self else { return }
            self.manager = VehicleManager(id: carId)
            
            if self.mock {
                let response = mockCarStatus(carId: carId)
                lastBatteryCharge = updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge)
                return
            } else if let cachedData = try? manager.vehicleStatus {
                let response = responseFromCarStatus(carId: carId, status: cachedData)
                lastBatteryCharge = updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge)
                return
            }
            
            Task {
                let response = await self.carStatus(carId: carId)
                
                DispatchQueue.main.async {
                    lastBatteryCharge = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge)
                }
            }
        })
    }
    
    func stopSendingUpdates(for intent: INGetCarPowerLevelStatusIntent) {
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
    
    private func consumptionFormulaArguments() -> [String: Any] {
        [
            "vehicle_parameters": vehicleParameters.consumptionFormulaParameters,
            "model_id": vehicleParameters.consumptionModelId
        ]
    }
    
    private func chargingFormulaArguments(maximumBatteryCapacity: Double, unit: UnitEnergy) -> [String: Any] {
        [
            "vehicle_parameters": vehicleParameters.chargingFormulaParameters(maximumBatteryCapacity: maximumBatteryCapacity, unit: unit),
            "model_id": vehicleParameters.chargingModelId
        ]
    }
}
