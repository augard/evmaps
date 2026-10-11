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
import Combine

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

    /// Timer for sending periodic updates to Apple Maps
    private var timer: Timer?
    /// MQTT Manager for real-time vehicle status updates
    private var mqttManager: MQTTManager?
    /// Combine cancellable for MQTT subscription
    private var mqttCancellable: AnyCancellable?
    /// Combine cancellable for MQTT status subscription
    private var mqttStatusCancellable: AnyCancellable?
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
            let status = try await api.vehicleCachedStatusWithAutoRefresh(carId)
            // Fetched status is older than 5 minutes, try ask for refresh in next 5 mins
            if status.lastUpdateTime + 5 * 60 < Date.now {
                _ = try await api.refreshVehicleWithAutoRefresh(carId)
            } else {
                try manager.store(status: status)
            }
            result = status.status.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters, lastUpdateDate: status.lastUpdateTime)
            logDebug("Loaded car status '\(status.status.green.batteryManagement.batteryRemain.ratio)'", category: .vehicle)
        } catch {
            if let error = error as? ApiError {
                switch error {
                case .unauthorized:
                    logError("Unauthorized after retry (Status code 401)", category: .auth)
                    result = .init(code: .failureRequiringAppLaunch, userActivity: nil)
                case .unexpectedStatusCode(400):
                    logError("We probably reached call limit (Status code 400)", category: .api)
                    result = .init(code: .success, userActivity: nil)
                default:
                    logError("Unknown Api Error '\(error.localizedDescription)'", category: .api)
                    result = .init(code: .failure, userActivity: nil)
                }
            } else {
                logError("Unknown error '\(error.localizedDescription)'", category: .general)
                result = .init(code: .failure, userActivity: nil)
            }

            logDebug("Returning cached data for failure", category: .vehicle)
            manager.restoreOutdatedData()
            if let cachedData = try? manager.vehicleState {
                return cachedData.status.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters, lastUpdateDate: cachedData.lastUpdateTime)
            } else {
                logDebug("No cached data, returning failure", category: .vehicle)
                manager.removeLastUpdateDate()
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
            logDebug("Handler: Returning mocking data", category: .vehicle)
            return KiaVehicleStatusMapper.map(response: VehicleStateResponse.lowBatteryPreview).status.toIntentResponse(
                carId: carId,
                vehicleParameters: vehicleParameters,
                lastUpdateDate: .now - 1 * 60
            )
        } else if let cachedData = try? manager.vehicleState {
            // Use data from cache
            if cachedData.lastUpdateTime + 5 * 60 < Date.now {
                logDebug("Handler: Old cache, updating cached data", category: .vehicle)
                await credentialsHandler.continueOrWaitForCredentials()
                do {
                    _ = try await api.refreshVehicleWithAutoRefresh(carId)
                } catch {
                    logError("Failed to refresh vehicle: \(error.localizedDescription)", category: .vehicle)
                }
                manager.removeLastUpdateDate()
            }

            logDebug("Handler: Use cached data", category: .vehicle)
            return cachedData.status.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters, lastUpdateDate: cachedData.lastUpdateTime)
        } else {
            // Get data from server
            await credentialsHandler.continueOrWaitForCredentials()
            return await fetchCarStatus(carId: carId)
        }
    }

    /// Starts sending periodic updates to Apple Maps for live battery status monitoring
    /// Uses cached data for initial update, then relies on MQTT for real-time updates
    /// - Parameters:
    ///   - intent: The intent to provide updates for
    ///   - observer: Observer that receives the updates
    func startSendingUpdates(for intent: INGetCarPowerLevelStatusIntent, to observer: any INGetCarPowerLevelStatusIntentResponseObserver) {
        logDebug("Updater: Starting updating car status with MQTT", category: .vehicle)
        
        guard let identifier = intent.carName?.vocabularyIdentifier, let carId = UUID(uuidString: identifier) else {
            logError("Updater: Failed to find car name '\(intent.carName?.spokenPhrase ?? "Unknown")'", category: .vehicle)
            observer.didUpdate(getCarPowerLevelStatus: .init(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }
        
        manager = VehicleManager(id: carId)
        
        // Send initial update from cached data immediately
        if let cachedData = try? manager.vehicleState {
            logDebug("Updater: Sending initial update from cached data", category: .vehicle)
            let response = cachedData.status.toIntentResponse(carId: carId, vehicleParameters: vehicleParameters, lastUpdateDate: .now - 1 * 60)
            observer.didUpdate(getCarPowerLevelStatus: response)
        }
        
        // Start MQTT connection and subscription in a Task to handle MainActor isolation
        Task { @MainActor in
            // Initialize MQTT Manager if not already created (MainActor-isolated)
            if mqttManager == nil {
                mqttManager = MQTTManager(api: api)
            }
            
            // Subscribe to MQTT updates
            mqttCancellable = mqttManager?.$vehicleState
                .compactMap { $0 } // Filter out nil values
                .sink { [weak self] mqttStatus in
                    guard let self = self else { return }

                    logDebug("Updater: Received MQTT update", category: .mqtt)

                    let mappedStatus = KiaVehicleStatusMapper.map(state: mqttStatus.state.vehicle)
                    let response = mappedStatus.toIntentResponse(
                        carId: carId,
                        vehicleParameters: self.vehicleParameters,
                        lastUpdateDate: mqttStatus.lastUpdateTime
                    )

                    // Update stored status
                    do {
                        let status = VehicleStatusSnapshot(
                            lastUpdateTime: mqttStatus.lastUpdateTime,
                            status: mappedStatus
                        )
                        try manager.store(status: status)
                    } catch {
                        logError("Updater: Failed to store mqtt status: \(error.localizedDescription)", category: .vehicle)
                    }

                    // Only update if battery charge has changed
                    observer.didUpdate(getCarPowerLevelStatus: response)
                }

            // Subscribe to MQTT status updates
            mqttStatusCancellable = mqttManager?.$connectionStatus
                .dropFirst()
                .sink { [weak self] status in
                    switch status {
                    case .connected:
                        self?.stopUpdateCarStatusFromApi()
                    case .disconnected, .error:
                        self?.startUpdateCarStatusFromApi(with: carId, observer: observer)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                            Task { [weak self] in
                                await self?.activateMQTTCommunication(with: carId)
                            }
                        }
                    case .connecting:
                        break
                    }
                }

            await activateMQTTCommunication(with: carId)

            if mqttManager?.connectionStatus != .connected {
                // Keep a fallback timer for non-MQTT updates (every 10 minutes instead of 4)
                // This is only used when MQTT is not connected
                startUpdateCarStatusFromApi(with: carId, observer: observer)
            }
        }
    }

    /// Stops sending periodic updates, disconnects MQTT, and invalidates the timer
    /// - Parameter intent: The intent to stop updates for
    func stopSendingUpdates(for _: INGetCarPowerLevelStatusIntent) {
        logDebug("Updater: Stopping updating car status and MQTT", category: .vehicle)
        
        // Stop timer
        timer?.invalidate()
        timer = nil
        
        // Cancel MQTT subscription
        mqttCancellable?.cancel()
        mqttCancellable = nil

        mqttStatusCancellable?.cancel()
        mqttStatusCancellable = nil

        // Disconnect MQTT (needs to be done on MainActor)
        Task { @MainActor in
            mqttManager?.disconnect()
            mqttManager = nil
        }
    }

    // MARK: - Api fallback for car update

    private func activateMQTTCommunication(with carId: UUID) async {
        do {
            try await mqttManager?.activateMQTTCommunication(for: carId)
        } catch {
            logError("Updater: Failed to start MQTT: \(error.localizedDescription)", category: .mqtt)
        }
    }

    private func startUpdateCarStatusFromApi(with carId: UUID, observer: any INGetCarPowerLevelStatusIntentResponseObserver) {
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateCarStatusFromApi(with: carId, observer: observer)
            }
        }
    }

    private func stopUpdateCarStatusFromApi() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func updateCarStatusFromApi(with carId: UUID, observer: any INGetCarPowerLevelStatusIntentResponseObserver) {
        // Only fetch from API if MQTT is not connected
        guard mqttManager?.connectionStatus != .connected else {
            stopUpdateCarStatusFromApi()
            return
        }
        logDebug("Updater: MQTT not connected, fetching from API", category: .vehicle)

        // Fetch in background task
        Task { [weak self] in
            guard let self = self else { return }
            await self.credentialsHandler.continueOrWaitForCredentials()
            let response = await self.fetchCarStatus(carId: carId)

            await MainActor.run {
                observer.didUpdate(getCarPowerLevelStatus: response)
            }
        }
    }
}

extension VehicleStatus {
    /// Converts vehicle status to Apple Maps compatible INGetCarPowerLevelStatusIntentResponse
    /// - Parameters:
    ///   - carId: Unique identifier for the vehicle
    ///   - vehicleParameters: Vehicle-specific parameters for Maps integration
    /// - Returns: Formatted response with battery status, charging info, and vehicle parameters
    func toIntentResponse(carId: UUID, vehicleParameters: VehicleParameters, lastUpdateDate: Date) -> INGetCarPowerLevelStatusIntentResponse {
        let result: INGetCarPowerLevelStatusIntentResponse

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: lastUpdateDate)
        let chargingInformation = green.chargingInformation
        let batteryManagement = green.batteryManagement
        let driveTrain = drivetrain
        let batteryCapacity = batteryManagement.batteryCapacity ?? estimatedBatteryCapacity(from: batteryManagement)
        let batteryRemain = Float(batteryManagement.batteryRemain.ratio)

        result = .init(code: .success, userActivity: nil)
        result.carIdentifier = carId.uuidString
        result.dateOfLastStateUpdate = dateComponents
        result.consumptionFormulaArguments = vehicleParameters.consumptionFormulaArguments()
        result.chargingFormulaArguments = vehicleParameters.chargingFormulaArguments(maximumBatteryCapacity: batteryCapacity, unit: .kilojoules)

        result.maximumDistance = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemaining = .init(value: Double(driveTrain.fuelSystem.dte.total), unit: driveTrain.fuelSystem.dte.unit.measuremntUnit)

        result.maximumDistanceElectric = .init(value: vehicleParameters.maximumDistance, unit: .kilometers)
        result.distanceRemainingElectric = .init(value: Double(driveTrain.fuelSystem.dte.total), unit: driveTrain.fuelSystem.dte.unit.measuremntUnit)

        result.minimumBatteryCapacity = .init(value: 0, unit: .kilowattHours)
        result.currentBatteryCapacity = .init(value: batteryCapacity * 0.01 * Double(batteryRemain), unit: .kilojoules)
        result.maximumBatteryCapacity = .init(value: batteryCapacity, unit: .kilojoules)

        result.charging = isActivelyCharging
        if result.charging == true {
            let charging = chargingInformation.charging
            let measurement = Measurement<UnitDuration>(value: charging.remainTime, unit: charging.remainTimeUnit.unitDuration)
            result.minutesToFull = Int(measurement.converted(to: .minutes).value)
            result.activeConnector = .ccs2
        } else {
            result.minutesToFull = nil
            result.activeConnector = nil
        }

        result.chargePercentRemaining = batteryRemain / 100

        return result
    }

    private func estimatedBatteryCapacity(from batteryManagement: VehicleStatus.Green.BatteryManagement) -> Double {
        let ratio = batteryManagement.batteryRemain.ratio
        guard ratio > 0 else { return batteryManagement.batteryRemain.value }
        return batteryManagement.batteryRemain.value * 100 / ratio
    }
}
