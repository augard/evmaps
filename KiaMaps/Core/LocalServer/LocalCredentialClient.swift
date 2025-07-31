//
//  LocalCredentialClient.swift
//  KiaMaps
//
//  Created by Claude on 26.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import Network

/// Universal client for retrieving credentials from the main app's local server
/// Used by both the main app and extensions
final class LocalCredentialClient {
    private let queue = DispatchQueue(label: "com.kiamaps.localclient", qos: .userInitiated)
    private let serverHost = "127.0.0.1"
    private let serverPort: UInt16 = 8765
    private let extensionIdentifier: String
    private let serverPassword: String
    private let maxRetryAttempts: Int
    
    /// Response structure from the server
    struct CredentialResponse: Codable {
        let authorization: AuthorizationData?
        let selectedVIN: String?
        let timestamp: Date
    }
    
    /// Request structure to send to server
    private struct CredentialRequest: Codable {
        let password: String
        let extensionIdentifier: String
    }
    
    /// Initialize with explicit parameters
    init(extensionIdentifier: String, serverPassword: String? = nil, maxRetryAttempts: Int = 3) {
        self.extensionIdentifier = extensionIdentifier
        // Use provided password or get from environment/fallback
        self.serverPassword = serverPassword ?? ProcessInfo.processInfo.environment["KIAMAPS_SERVER_PASSWORD"] ?? "KiaMapsSecurePassword2025"
        self.maxRetryAttempts = maxRetryAttempts
    }
    
    /// Convenience initializer for extensions
    convenience init(extensionIdentifier: String) {
        self.init(extensionIdentifier: extensionIdentifier, serverPassword: nil, maxRetryAttempts: 3)
    }
    
    /// Fetches credentials from the local server
    func fetchCredentials(completion: @escaping (Result<CredentialResponse, Error>) -> Void) {
        let connection = NWConnection(
            host: NWEndpoint.Host(serverHost),
            port: NWEndpoint.Port(integerLiteral: serverPort),
            using: .tcp
        )
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("LocalCredentialClient: Connected to server")
            case .failed(let error), .waiting(let error):
                print("LocalCredentialClient: Connection failed: \(error)")
                completion(.failure(error))
            case .cancelled:
                print("LocalCredentialClient: Connection cancelled")
            default:
                print("LocalCredentialClient: Connection state \(state)")
            }
        }
        
        connection.start(queue: queue)

        // Send request
        let request = CredentialRequest(password: serverPassword, extensionIdentifier: extensionIdentifier)
        
        do {
            let requestData = try JSONEncoder().encode(request)
            
            connection.send(content: requestData, completion: .contentProcessed { error in
                if let error = error {
                    print("LocalCredentialClient: Send error: \(error)")
                    completion(.failure(error))
                    connection.cancel()
                    return
                }
                
                // Receive response
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                    defer { connection.cancel() }
                    
                    if let error = error {
                        print("LocalCredentialClient: Receive error: \(error)")
                        completion(.failure(error))
                        connection.cancel()
                        return
                    }
                    
                    guard let data = data, !data.isEmpty else {
                        completion(.failure(NSError(domain: "LocalCredentialClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        connection.cancel()
                        return
                    }
                    
                    // Try to decode as error response first
                    if let errorDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                       let errorMessage = errorDict["error"] {
                        completion(.failure(NSError(domain: "LocalCredentialClient", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                        connection.cancel()
                        return
                    }
                    
                    // Decode as credential response
                    do {
                        let response = try JSONDecoder().decode(CredentialResponse.self, from: data)
                        completion(.success(response))
                        connection.cancel()
                    } catch {
                        print("LocalCredentialClient: Decode error: \(error)")
                        completion(.failure(error))
                        connection.cancel()
                    }
                }
            })
        } catch {
            print("LocalCredentialClient: Encode error: \(error)")
            completion(.failure(error))
            connection.cancel()
        }
    }
    
    /// Async/await version for fetching credentials
    func fetchCredentials() async throws -> CredentialResponse {
        try await withCheckedThrowingContinuation { continuation in
            fetchCredentials { result in
                continuation.resume(with: result)
            }
        }
    }
}
