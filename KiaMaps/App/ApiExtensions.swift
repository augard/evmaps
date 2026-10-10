//
//  ApiExtensions.swift
//  KiaMaps
//
//  Created by Claude on 28.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation

/// Extension to Api class that handles automatic token refresh and retry logic
extension Api {
    
    /// Executes a network request with automatic token refresh on expiration
    /// - parameter operation: The async operation to perform that might need authentication
    /// - returns: The result of the operation
    /// - throws: The original error if retry fails, or authentication errors
    func executeWithAutoRefresh<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            // First attempt - try the operation directly
            return try await operation()
        } catch {
            // Check if this is an unauthorized error (401) indicating expired token
            if let apiError = error as? ApiError, case .unauthorized = apiError {
                logInfo("Detected expired token, attempting automatic login retry", category: .auth)
                
                // Try to refresh the token using stored credentials
                if await refreshTokenIfPossible() {
                    logInfo("Token refreshed successfully, retrying operation", category: .auth)
                    // Retry the operation with fresh token
                    return try await operation()
                } else {
                    logError("Token refresh failed, throwing original error", category: .auth)
                    // If refresh failed, throw the original unauthorized error
                    throw error
                }
            } else {
                // For non-authentication errors, just throw the original error
                throw error
            }
        }
    }
    
    /// Attempts to refresh the token using stored refresh token or fallback to credentials
    /// - returns: True if token was successfully refreshed, false otherwise
    private func refreshTokenIfPossible() async -> Bool {
        // Check if current token is actually expired before attempting refresh
        if let currentAuth = authorization, !isTokenExpired(currentAuth) {
            logDebug("Current token is not expired, no refresh needed", category: .auth)
            return true
        }
        
        // First, try to refresh using the refresh token if available
        if let currentAuth = authorization {
            logInfo("Attempting to refresh token using refresh token", category: .auth)
            
            do {
                let tokenResponse = try await refreshToken(currentAuth.refreshToken)
                
                // Create new authorization data with refreshed tokens
                let newAuthData = AuthorizationData(
                    stamp: currentAuth.stamp, // Keep existing stamp
                    deviceId: currentAuth.deviceId, // Keep existing device ID
                    accessToken: tokenResponse.accessToken,
                    expiresIn: tokenResponse.expiresIn,
                    refreshToken: tokenResponse.refreshToken ?? currentAuth.refreshToken,
                    isCcuCCS2Supported: currentAuth.isCcuCCS2Supported
                )
                
                // Store the new authorization data
                Authorization.store(data: newAuthData)
                self.authorization = newAuthData
                
                logInfo("Successfully refreshed token using refresh token", category: .auth)
                return true
            } catch {
                logWarning("Refresh token failed: \(error.localizedDescription). Falling back to credential login", category: .auth)
                // Continue to fallback method below
            }
        }
        
        // Fallback: Try to refresh using stored login credentials
        guard let storedCredentials = LoginCredentialManager.retrieveCredentials() else {
            logInfo("No stored credentials available for fallback token refresh", category: .auth)
            return false
        }
        
        do {
            logInfo("Attempting fallback login with stored credentials", category: .auth)
            let newAuthData = try await login(
                username: storedCredentials.username,
                password: storedCredentials.password
            )
            
            // Store the new authorization data
            Authorization.store(data: newAuthData)
            self.authorization = newAuthData
            
            logInfo("Successfully refreshed token using credential fallback", category: .auth)
            return true
            
        } catch {
            logError("Failed to refresh token with fallback login: \(error.localizedDescription)", category: .auth)
            
            // If login fails, clear the stored credentials as they might be invalid
            if error is ApiError {
                logInfo("Clearing invalid stored credentials", category: .auth)
                LoginCredentialManager.clearCredentials()
            }
            
            return false
        }
    }
    
    /// Checks if the current authorization token is expired or close to expiring
    /// - parameter authData: The authorization data to check
    /// - returns: True if token is expired or expires within the next 5 minutes
    private func isTokenExpired(_ authData: AuthorizationData) -> Bool {
        // Decode JWT token to get expiration time
        guard let expirationDate = decodeJWTExpiration(from: authData.accessToken) else {
            logWarning("Unable to decode JWT expiration, assuming expired", category: .auth)
            return true // If we can't decode, assume expired for safety
        }
        
        // Check if token expires within the next 5 minutes (300 seconds buffer)
        let expirationBuffer: TimeInterval = 5 * 60 // 5 minutes
        let isExpired = Date().addingTimeInterval(expirationBuffer) >= expirationDate
        
        if isExpired {
            logInfo("JWT token is expired or expires within 5 minutes", category: .auth)
        } else {
            let timeUntilExpiration = expirationDate.timeIntervalSinceNow
            logDebug("JWT token is valid for \(Int(timeUntilExpiration)) more seconds", category: .auth)
        }
        
        return isExpired
    }
    
    /// Decodes JWT token to extract expiration date
    /// - parameter token: JWT token string
    /// - returns: Expiration date if successfully decoded, nil otherwise
    private func decodeJWTExpiration(from token: String) -> Date? {
        // JWT tokens have format: header.payload.signature
        let components = token.components(separatedBy: ".")
        guard components.count >= 2 else {
            logError("Invalid JWT token format", category: .auth)
            return nil
        }
        
        // Decode the payload (second component)
        let payload = components[1]
        
        // Add padding if needed (JWT base64 encoding may not include padding)
        var paddedPayload = payload
        let paddingLength = 4 - (payload.count % 4)
        if paddingLength != 4 {
            paddedPayload += String(repeating: "=", count: paddingLength)
        }
        
        // Decode base64
        guard let data = Data(base64Encoded: paddedPayload) else {
            logError("Failed to decode JWT payload from base64", category: .auth)
            return nil
        }
        
        // Parse JSON
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logError("JWT payload is not valid JSON", category: .auth)
                return nil
            }
            
            // Extract 'exp' claim (expiration time as Unix timestamp)
            guard let exp = json["exp"] as? TimeInterval else {
                logError("JWT payload does not contain 'exp' claim", category: .auth)
                return nil
            }
            
            // Convert Unix timestamp to Date
            return Date(timeIntervalSince1970: exp)
            
        } catch {
            logError("Failed to parse JWT payload JSON: \(error.localizedDescription)", category: .auth)
            return nil
        }
    }
}

/// Convenient wrapper functions for common API operations with auto-refresh
extension Api {
    
    /// Fetch vehicles list with automatic token refresh
    func vehiclesWithAutoRefresh() async throws -> VehicleResponse {
        return try await executeWithAutoRefresh {
            return try await self.vehicles()
        }
    }
    
    /// Fetch cached vehicle status with automatic token refresh
    func vehicleCachedStatusWithAutoRefresh(_ vehicleId: UUID) async throws -> VehicleStateResponse {
        return try await executeWithAutoRefresh {
            return try await self.vehicleCachedStatus(vehicleId)
        }
    }
    
    /// Refresh vehicle with automatic token refresh
    func refreshVehicleWithAutoRefresh(_ vehicleId: UUID) async throws -> UUID {
        return try await executeWithAutoRefresh { () -> UUID in
            return try await self.refreshVehicle(vehicleId)
        }
    }
    
    /// Logout with automatic token refresh (in case logout needs valid token)
    func logoutWithAutoRefresh() async throws {
        try await executeWithAutoRefresh {
            try await self.logout()
        }
    }

    /// MQTT device host with automatic token refresh (in case logout needs valid token)
    func fetchMQTTDeviceHostAutoRefresh() async throws -> MQTTHostInfo {
        try await executeWithAutoRefresh {
            try await self.fetchMQTTDeviceHost()
        }
    }
}
