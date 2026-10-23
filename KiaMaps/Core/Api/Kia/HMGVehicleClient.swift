//
//  HMGVehicleClient.swift
//  KiaMaps
//
//  Created by Codex on 09.03.2026.
//

import Foundation

struct HMGVehicleClient {
    let provider: ApiRequestProvider

    private var authorization: AuthorizationData? {
        provider.authorization
    }

    func vehicles() async throws -> VehicleResponse {
        guard authorization != nil else {
            throw ApiError.unauthorized
        }
        return try await provider.request(endpoint: KiaApiEndpoint.vehicles).response()
    }

    func refreshVehicle(_ vehicleId: UUID) async throws -> UUID {
        guard let authorization else {
            throw ApiError.unauthorized
        }
        let endpoint: KiaApiEndpoint = authorization.isCcuCCS2Supported == true ? .refreshCCS2Vehicle(vehicleId) : .refreshVehicle(vehicleId)
        return try await provider.request(endpoint: endpoint).responseEmpty().resultId
    }

    func vehicleCachedStatus(_ vehicleId: UUID) async throws -> VehicleStatusSnapshot {
        guard let authorization else {
            throw ApiError.unauthorized
        }
        let endpoint: KiaApiEndpoint = authorization.isCcuCCS2Supported == true ? .vehicleCachedCCS2Status(vehicleId) : .vehicleCachedStatus(vehicleId)
        let response: VehicleStateResponse = try await provider.request(endpoint: endpoint).response()
        return KiaVehicleStatusMapper.map(response: response)
    }

    func profile() async throws -> String {
        guard authorization != nil else {
            throw ApiError.unauthorized
        }
        return try await provider.request(endpoint: KiaApiEndpoint.userProfile).string()
    }

    func startClimate(_ vehicleId: UUID, options: ClimateControlOptions, pin: String) async throws -> UUID {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }
        guard !pin.isEmpty else {
            throw ClimateControlError.missingPin
        }
        guard options.isValid else {
            if !options.isTemperatureValid {
                throw ClimateControlError.invalidTemperature(options.temperature)
            }
            if !options.areSeatLevelsValid {
                let invalidLevel = [options.driverSeatLevel, options.passengerSeatLevel, options.rearLeftSeatLevel, options.rearRightSeatLevel]
                    .first { $0 < 0 || $0 > 3 } ?? -1
                throw ClimateControlError.invalidSeatLevel(invalidLevel)
            }
            if !options.isDurationValid {
                throw ClimateControlError.invalidDuration(options.duration)
            }
            throw ClimateControlError.vehicleNotReady
        }

        return try await provider.request(
            with: .post,
            endpoint: KiaApiEndpoint.startClimate(vehicleId),
            encodable: options.toClimateControlRequest(pin: pin)
        ).responseEmpty().resultId
    }

    func stopClimate(_ vehicleId: UUID) async throws -> UUID {
        guard authorization?.accessToken != nil else {
            throw ApiError.unauthorized
        }
        return try await provider.request(
            with: .post,
            endpoint: KiaApiEndpoint.stopClimate(vehicleId)
        ).responseEmpty().resultId
    }
}
