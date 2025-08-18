//
//  ApiExtensions.swift
//  KiaMaps
//
//  Created by Claude on 28.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

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
    
    /// Attempts to refresh the token using stored credentials
    /// - returns: True if token was successfully refreshed, false otherwise
    private func refreshTokenIfPossible() async -> Bool {
        // Check if we have stored login credentials
        guard let storedCredentials = LoginCredentialManager.retrieveCredentials() else {
            logInfo("No stored credentials available for token refresh", category: .auth)
            return false
        }
        
        // Check if current token is actually expired before attempting refresh
        if let currentAuth = authorization, !isTokenExpired(currentAuth) {
            logDebug("Current token is not expired, no refresh needed", category: .auth)
            return true
        }
        
        do {
            logInfo("Attempting to login with stored credentials", category: .auth)
            let newAuthData = try await login(
                username: storedCredentials.username,
                password: storedCredentials.password
            )
            
            // Store the new authorization data
            Authorization.store(data: newAuthData)
            self.authorization = newAuthData
            
            logInfo("Successfully refreshed token", category: .auth)
            return true
            
        } catch {
            logError("Failed to refresh token with error: \(error.localizedDescription)", category: .auth)
            
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
        // Note: This implementation assumes the token was issued when stored
        // A more robust implementation would store the issue timestamp
        
        // For now, we'll consider a token expired if we get a 401 error
        // This method serves as a placeholder for potential future timestamp-based checking
        
        // You could enhance this by:
        // 1. Storing the token issue timestamp
        // 2. Calculating actual expiration time
        // 3. Adding a buffer (e.g., refresh 5 minutes before expiration)
        
        return false // Let the 401 error be the primary indicator
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
    func vehicleCachedStatusWithAutoRefresh(_ vehicleId: UUID) async throws -> VehicleStatusResponse {
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
}