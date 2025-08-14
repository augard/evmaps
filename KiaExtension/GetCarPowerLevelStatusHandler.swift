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

/// Handler for INGetCarPowerLevelStatusIntent that provides battery status information to Apple Maps and Siri
/// Supports both cached data for quick responses and live data fetching with background updates
class GetCarPowerLevelStatusHandler: NSObject, INGetCarPowerLevelStatusIntentHandling, Handler {
    /// API client for fetching vehicle data
    private let api: Api
    /// Credentials handler for authentication management
    private let credentialsHandler: CredentialsHandler
    /// Vehicle manager for caching and vehicle-specific configuration
    private var manager = VehicleManager(id: UUID())
    /// Vehicle-specific parameters for Apple Maps integration
    private var vehicleParameters: VehicleParameters { manager.vehicleParamter }
    /// Flag to prevent infinite login retry loops
    private var loginRetry: Bool = false

    /// Timer for sending periodic updates to Apple Maps
    private var timer: Timer?
    /// Mock flag - true on simulator for testing, false on device
    #if targetEnvironment(simulator)
        private let mock: Bool = true
    #else
        private let mock: Bool = false
    #endif

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
    /// - Returns: True if this is an INGetCarPowerLevelStatusIntent
    func canHandle(_ intent: INIntent) -> Bool {
        intent is INGetCarPowerLevelStatusIntent
    }

    /// Fetches current vehicle status with proper error handling and fallback to cache
    /// - Parameter carId: UUID of the vehicle to fetch status for
    /// - Returns: INGetCarPowerLevelStatusIntentResponse with current battery status
    func fetchCarStatus(carId: UUID) async -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse

        do {
            loginRetry = false
            let status = try await api.vehicleCachedStatus(carId)
            // Fetched status is older than 5 minutes, try ask for refresh in next 5 mins
            if status.lastUpdateTime + 5 * 60 < Date.now {
                _ = try await api.refreshVehicle(carId)
            } else {
                try manager.store(status: status)
            }
            result = status.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
            ExtensionLogger.debug("Loaded car status '%2f'", category: "GetCarPowerLevelStatus", status.state.vehicle.green.batteryManagement.batteryRemain.ratio)
        } catch {
            var useCachedData = true
            if let error = error as? ApiError {
                switch (error, loginRetry) {
                case (.unauthorized, false):
                    do {
                        ExtensionLogger.warning("Unauthorized trying retry (Status code 401)", category: "GetCarPowerLevelStatus")
                        try await credentialsHandler.reauthorize()
                        result = await fetchCarStatus(carId: carId)

                        useCachedData = false
                        ExtensionLogger.debug("Succesfully reauthorized", category: "GetCarPowerLevelStatus")
                    } catch {
                        result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                    }
                case (.unauthorized, true):
                    ExtensionLogger.error("Unauthorized after retry (Status code 401)", category: "GetCarPowerLevelStatus")
                    result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                case (.unexpectedStatusCode(400), false):
                    ExtensionLogger.error("We probably reached call limit (Status code 400)", category: "GetCarPowerLevelStatus")
                    result = .init(code: .success, userActivity: nil)
                default:
                    ExtensionLogger.error("Unknown Api Error '%@", category: "GetCarPowerLevelStatus", error.localizedDescription)
                    result = .init(code: .failure, userActivity: nil)
                }
            } else {
                ExtensionLogger.error("Unknown error '%@'", category: "GetCarPowerLevelStatus", error.localizedDescription)
                result = .init(code: .failure, userActivity: nil)
            }

            if useCachedData {
                ExtensionLogger.debug("Returning cached data for failure", category: "GetCarPowerLevelStatus")
                manager.restoreOutdatedData()
                if let cachedData = try? manager.vehicleStatus {
                    return cachedData.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
                } else {
                    ExtensionLogger.debug("No cached data, returning failure", category: "GetCarPowerLevelStatus")
                    manager.removeLastUpdateDate()
                }
            }
        }
        return result
    }

    /// Main handler for INGetCarPowerLevelStatusIntent - provides immediate response using cache or fresh data
    /// - Parameters:
    ///   - intent: The intent containing car information
    ///   - completion: Completion handler for the response
    func handle(intent: INGetCarPowerLevelStatusIntent) async -> INGetCarPowerLevelStatusIntentResponse {
        guard let identifier = intent.carName?.vocabularyIdentifier, let carId = UUID(uuidString: identifier) else {
            return .init(code: .failureRequiringAppLaunch, userActivity: nil)
        }
        manager = VehicleManager(id: carId)

        if mock {
            do {
                try await Task.sleep(for: .seconds(4))
            } catch {

            }
            ExtensionLogger.debug("Handler: Returning mocking data", category: "GetCarPowerLevelStatus")
            return VehicleStatusResponse.lowBatteryPreview.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
        } else if let cachedData = try? manager.vehicleStatus {
            // Use data from cache
            if cachedData.lastUpdateTime + 5 * 60 < Date.now {
                ExtensionLogger.debug("Handler: Old cache, updating cached data", category: "GetCarPowerLevelStatus")
                await credentialsHandler.continueOrWaitForCredentials()
                do {
                    _ = try await api.refreshVehicle(carId)
                } catch {
                    ExtensionLogger.error("Failed to refresh vehicle: %@", category: "GetCarPowerLevelStatus", error.localizedDescription)
                }
                manager.removeLastUpdateDate()
            }

            ExtensionLogger.debug("Handler: Use cached data", category: "GetCarPowerLevelStatus")
            return cachedData.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
        } else {
            // Get data from server
            await credentialsHandler.continueOrWaitForCredentials()
            return await fetchCarStatus(carId: carId)
        }
    }

    /// Starts sending periodic updates to Apple Maps for live battery status monitoring
    /// - Parameters:
    ///   - intent: The intent to provide updates for
    ///   - observer: Observer that receives the updates
    func startSendingUpdates(for intent: INGetCarPowerLevelStatusIntent, to observer: any INGetCarPowerLevelStatusIntentResponseObserver) {
        ExtensionLogger.debug("Updater: Starting updating car status", category: "GetCarPowerLevelStatus")
        let lastBatteryCharge = BatteryChargeBox()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 4, repeats: true, block: { [weak self] _ in
            guard let identifier = intent.carName?.vocabularyIdentifier, let carId = UUID(uuidString: identifier) else {
                ExtensionLogger.error("Updater: Failed to find car name '%@", category: "GetCarPowerLevelStatus", intent.carName ?? "Unknown")
                observer.didUpdate(getCarPowerLevelStatus: .init(code: .failureRequiringAppLaunch, userActivity: nil))
                return
            }

            guard let self = self else { return }
            self.manager = VehicleManager(id: carId)

            if self.mock {
                Thread.sleep(until: .now + 4) // Just to simulate server request/response time
                ExtensionLogger.debug("Updater: Returning mocking data", category: "GetCarPowerLevelStatus")
                let response = VehicleStatusResponse.lowBatteryPreview.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
                lastBatteryCharge.value = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge.value)
            } else if let cachedData = try? self.manager.vehicleStatus {
                ExtensionLogger.debug("Updater: Using cached data", category: "GetCarPowerLevelStatus")
                let response = cachedData.state.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters)
                lastBatteryCharge.value = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge.value)
            }

            Task {
                ExtensionLogger.debug("Updater: Update vehicle data", category: "GetCarPowerLevelStatus")
                await self.credentialsHandler.continueOrWaitForCredentials()
                let response = await self.fetchCarStatus(carId: carId)

                await MainActor.run {
                    lastBatteryCharge.value = self.updateCharge(observer: observer, response: response, lastBatteryCharge: lastBatteryCharge.value)
                }
            }
        })
    }

    /// Stops sending periodic updates and invalidates the timer
    /// - Parameter intent: The intent to stop updates for
    func stopSendingUpdates(for _: INGetCarPowerLevelStatusIntent) {
        ExtensionLogger.debug("Updater: Stoping updating car status", category: "GetCarPowerLevelStatus")
        timer?.invalidate()
        timer = nil
    }

    /// Updates observer with new battery status only if the charge level has changed
    /// - Parameters:
    ///   - observer: The observer to notify of changes
    ///   - response: New battery status response
    ///   - lastBatteryCharge: Previous battery charge level
    /// - Returns: The current battery charge level for future comparisons
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

/// Simple container class for holding mutable Float values in closures
class BatteryChargeBox {
    /// The stored battery charge value
    var value: Float?
    
    /// Initializes with optional initial value
    /// - Parameter value: Initial battery charge value
    init(_ value: Float? = nil) { self.value = value }
}

extension VehicleStatusResponse.State {
    /// Converts vehicle status to Apple Maps compatible INGetCarPowerLevelStatusIntentResponse
    /// - Parameters:
    ///   - carId: Unique identifier for the vehicle
    ///   - vehicleParameters: Vehicle-specific parameters for Maps integration
    /// - Returns: Formatted response with battery status, charging info, and vehicle parameters
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
