//
//  LocalCredentialServer.swift
//  KiaMaps
//
//  Created by Claude on 26.01.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import Network
import os.log

/// Local server that provides credentials to extensions securely
final class LocalCredentialServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.kiamaps.localserver", qos: .userInitiated)
    private let port: UInt16
    private let serverPassword: String
    
    /// Shared instance of the credential server
    static let shared = LocalCredentialServer(password: ProcessInfo.processInfo.environment[Configuration.serverPasswordKey])
    
    /// Check if server is currently running
    var isRunning: Bool {
        return listener?.state == .ready
    }
    
    /// Current server state
    var serverState: NWListener.State? {
        return listener?.state
    }
    
    /// Server configuration
    private struct Configuration {
        static let defaultPort: UInt16 = 8765
        static let serverPasswordKey = "KIAMAPS_SERVER_PASSWORD"
        static let serverPasswordFallback = "KiaMapsSecurePassword2025"
    }
    
    /// Response structure for credential requests
    private struct CredentialResponse: Codable {
        let authorization: AuthorizationData?
        let selectedVIN: String?
        let username: String?
        let password: String?
        let timestamp: Date
    }
    
    /// Request structure from extensions
    private struct CredentialRequest: Codable {
        let password: String
        let extensionIdentifier: String
    }
    
    init(port: UInt16 = Configuration.defaultPort, password: String?) {
        self.port = port
        // Use compile-time password from environment variable or fallback
        self.serverPassword = password ?? Configuration.serverPasswordFallback
    }
    
    /// Starts the local server
    func start(completion: ((Bool) -> Void)? = nil) {
        guard listener == nil else {
            os_log(.default, log: Logger.server, "Server already running")
            completion?(true)
            return
        }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        // Allow background networking
        parameters.allowFastOpen = true
        parameters.serviceClass = .background
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
        } catch {
            os_log(.error, log: Logger.server, "Failed to create listener: %{public}@", error.localizedDescription)
            completion?(false)
            return
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                os_log(.info, log: Logger.server, "Server is ready on port %{public}d", self?.port ?? 0)
                completion?(true)
            case .failed(let error):
                os_log(.error, log: Logger.server, "Server failed with error: %{public}@", error.localizedDescription)
                self?.handleServerFailure(error: error)
                completion?(false)
            case .cancelled:
                os_log(.info, log: Logger.server, "Server cancelled")
                completion?(false)
            case .waiting(let error):
                os_log(.debug, log: Logger.server, "Server waiting: %{public}@", error.localizedDescription)
            default:
                os_log(.debug, log: Logger.server, "Server state: %{public}@", String(describing: state))
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: queue)
    }
    
    /// Handles server failures with retry logic
    private func handleServerFailure(error: NWError) {
        stop()
        
        // Retry after a short delay for certain errors
        if case .posix(let posixError) = error, posixError == .EADDRINUSE {
            os_log(.default, log: Logger.server, "Port in use, retrying in 5 seconds...")
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.start()
            }
        }
    }
    
    /// Stops the local server
    func stop() {
        listener?.cancel()
        listener = nil
        os_log(.info, log: Logger.server, "Server stopped")
    }
    
    /// Handles incoming connections
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                os_log(.debug, log: Logger.server, "Connection ready")
            case .failed(let error):
                os_log(.error, log: Logger.server, "Connection failed: %{public}@", error.localizedDescription)
            case .cancelled:
                os_log(.debug, log: Logger.server, "Connection cancelled")
            default:
                os_log(.debug, log: Logger.server, "Connection state: %{public}@", String(describing: state))
            }
        }
        
        connection.start(queue: queue)
        
        // Receive request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                os_log(.error, log: Logger.server, "Receive error: %{public}@", error.localizedDescription)
                connection.cancel()
                return
            }
            
            guard let data = data, !data.isEmpty else {
                os_log(.default, log: Logger.server, "No data received")
                connection.cancel()
                return
            }
            
            self.processRequest(data: data, connection: connection)
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    /// Processes incoming credential requests
    private func processRequest(data: Data, connection: NWConnection) {
        do {
            let request = try JSONDecoder().decode(CredentialRequest.self, from: data)
            
            // Verify password
            guard request.password == serverPassword else {
                os_log(.default, log: Logger.server, "Invalid password from extension: %{public}@", request.extensionIdentifier)
                sendErrorResponse(connection: connection, error: "Invalid password")
                return
            }
            
            os_log(.info, log: Logger.server, "Valid request from extension: %{public}@", request.extensionIdentifier)

            let credentials = LoginCredentialManager.retrieveCredentials()

            // Get current credentials and selected VIN
            let response = CredentialResponse(
                authorization: Authorization.authorization,
                selectedVIN: SharedVehicleManager.shared.selectedVehicleVIN,
                username: credentials?.username,
                password: credentials?.password,
                timestamp: Date()
            )
            
            let responseData = try JSONEncoder().encode(response)
            sendResponse(connection: connection, data: responseData)
            
        } catch {
            os_log(.error, log: Logger.server, "Failed to process request: %{public}@", error.localizedDescription)
            sendErrorResponse(connection: connection, error: "Invalid request format")
        }
    }
    
    /// Sends response data to the connection
    private func sendResponse(connection: NWConnection, data: Data) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                os_log(.error, log: Logger.server, "Send error: %{public}@", error.localizedDescription)
            } else {
                os_log(.debug, log: Logger.server, "Response sent successfully")
            }
            connection.cancel()
        })
    }
    
    /// Sends error response to the connection
    private func sendErrorResponse(connection: NWConnection, error: String) {
        let errorDict = ["error": error]
        guard let data = try? JSONSerialization.data(withJSONObject: errorDict, options: []) else {
            connection.cancel()
            return
        }
        sendResponse(connection: connection, data: data)
    }
}

/// Extension to expose the server password for extensions (compile-time)
extension LocalCredentialServer {
    /// Returns the compile-time server password for use in build settings
    static var compileTimePassword: String {
        ProcessInfo.processInfo.environment[Configuration.serverPasswordKey] ?? Configuration.serverPasswordFallback
    }
}
