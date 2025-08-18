//
//  RemoteLoggingServer.swift
//  KiaMaps
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import Network
import os.log
import Combine

/// Server that receives logs from extensions via network
@MainActor
final class RemoteLoggingServer: ObservableObject {
    
    // MARK: - Properties
    
    /// Singleton instance of the remote logging server
    static let shared = RemoteLoggingServer()
    
    /// Array of all received log entries, published for UI updates
    /// - Note: Automatically trimmed to maxLogCount (1000) entries
    @Published private(set) var logs: [LogEntry] = []
    
    /// Indicates whether the server is currently running and accepting connections
    @Published private(set) var isRunning = false
    
    /// Current number of active client connections
    @Published private(set) var connectionCount = 0
    
    /// Network listener that accepts incoming TCP connections
    private var listener: NWListener?
    
    /// TCP port number for the logging server
    private let port: NWEndpoint.Port = 8081
    
    /// Maximum number of log entries to retain in memory
    /// - Note: Older entries are automatically removed when this limit is exceeded
    private let maxLogCount = 1000
    
    /// Set of active client connections
    private var connections: Set<LogConnection> = []
    
    // MARK: - Filtering Properties
    
    /// Text filter for searching through log messages, categories, and locations
    @Published var filterText = ""
    
    /// Optional filter for log level (debug, info, warning, error)
    @Published var selectedLevel: LogEntry.LogLevel?
    
    /// Optional filter for log source (main app or extension)
    @Published var selectedSource: LogEntry.LogSource?
    
    /// Optional filter for log category
    @Published var selectedCategory: String?
    
    /// Computed property that returns all unique categories from current logs, sorted alphabetically
    var availableCategories: [String] {
        Array(Set(logs.map { $0.category })).sorted()
    }
    
    /// Computed property that returns filtered log entries based on current filter settings
    /// - Note: Filters are applied cumulatively - all active filters must match for an entry to be included
    var filteredLogs: [LogEntry] {
        logs.filter { entry in
            // Filter by search text
            if !filterText.isEmpty {
                let searchText = filterText.lowercased()
                let matchesText = entry.message.lowercased().contains(searchText) ||
                                 entry.category.lowercased().contains(searchText) ||
                                 (entry.formattedLocation?.lowercased().contains(searchText) ?? false)
                if !matchesText { return false }
            }
            
            // Filter by level
            if let level = selectedLevel, entry.level != level {
                return false
            }
            
            // Filter by source
            if let source = selectedSource, entry.source != source {
                return false
            }
            
            // Filter by category
            if let category = selectedCategory, entry.category != category {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Starts the remote logging server on port 8081
    /// - Note: This method is idempotent - calling it multiple times while running has no effect
    /// - Throws: Does not throw but logs errors internally if the server fails to start
    func start() {
        guard !isRunning else { return }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: parameters, on: port)
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }
            
            listener?.start(queue: .main)
            isRunning = true
            logInfo("Remote logging server started on port \(port.rawValue)", category: .server)
        } catch {
            logError("Failed to start remote logging server: \(error.localizedDescription)", category: .server)
        }
    }
    
    /// Stops the remote logging server and closes all active connections
    /// - Note: Cancels all active connections and resets the connection count
    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        connectionCount = 0
        isRunning = false
        logInfo("Remote logging server stopped", category: .server)
    }
    
    /// Removes all stored log entries from memory
    /// - Note: This action cannot be undone
    func clearLogs() {
        logs.removeAll()
    }
    
    /// Exports all log entries as a formatted string
    /// - Returns: A string containing all log entries, one per line, formatted for readability
    func exportLogs() -> String {
        logs.map { $0.formattedLogLine }.joined(separator: "\n")
    }
    
    // MARK: - Test Helper Methods
    
    #if DEBUG
    /// Adds multiple test log entries for debugging purposes
    /// - Parameter entries: An array of LogEntry objects to add to the log collection
    /// - Note: Only available in DEBUG builds. Automatically trims logs if they exceed maxLogCount (1000)
    func addTestLogs(_ entries: [LogEntry]) {
        logs.append(contentsOf: entries)
        // Trim if needed
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
    }
    
    /// Adds a single test log entry for debugging purposes
    /// - Parameter entry: A LogEntry object to add to the log collection
    /// - Note: Only available in DEBUG builds. Automatically trims logs if they exceed maxLogCount (1000)
    func addTestLog(_ entry: LogEntry) {
        logs.append(entry)
        // Trim if needed
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
    }
    #endif
    
    // MARK: - Private Methods
    
    /// Handles a new incoming network connection from a client
    /// - Parameter connection: The NWConnection object representing the new connection
    /// - Note: Creates a LogConnection wrapper, sets up callbacks, and starts receiving data
    private func handleNewConnection(_ connection: NWConnection) {
        let logConnection = LogConnection(connection: connection) { [weak self] batch in
            Task { @MainActor in
                self?.handleLogBatch(batch)
            }
        }
        
        logConnection.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionStateChange(connection: logConnection, state: state)
            }
        }
        
        connections.insert(logConnection)
        connectionCount = connections.count
        logConnection.start()
    }
    
    /// Handles state changes for active connections
    /// - Parameters:
    ///   - connection: The LogConnection whose state has changed
    ///   - state: The new NWConnection.State
    /// - Note: Removes connections from the active set when they are cancelled or failed
    private func handleConnectionStateChange(connection: LogConnection, state: NWConnection.State) {
        switch state {
        case .cancelled, .failed:
            connections.remove(connection)
            connectionCount = connections.count
        default:
            break
        }
    }
    
    /// Processes a batch of log entries received from a client
    /// - Parameter batch: The LogBatch containing log entries and optional device information
    /// - Note: Adds entries to the log collection, trims excess logs, and logs device info if available
    private func handleLogBatch(_ batch: LogBatch) {
        // Add new logs
        logs.append(contentsOf: batch.entries)
        
        // Trim if exceeding max count
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
        
        // Log device info if available
        if let deviceInfo = batch.deviceInfo {
            logDebug("Received logs from \(deviceInfo.deviceModel) running iOS \(deviceInfo.osVersion)", category: .server)
        }
    }
}

// MARK: - Connection Handler

/// Wrapper class for managing individual network connections from logging clients
private class LogConnection: Hashable {
    /// Unique identifier for this connection, used for Hashable conformance
    let id = UUID()
    
    /// The underlying Network framework connection to the client
    private let connection: NWConnection
    
    /// Callback invoked when a LogBatch is successfully received and decoded
    private let onReceive: (LogBatch) -> Void
    
    /// Optional callback invoked when the connection state changes
    /// - Note: Used by RemoteLoggingServer to track connection lifecycle
    var onStateChange: ((NWConnection.State) -> Void)?
    
    /// Initializes a new log connection wrapper
    /// - Parameters:
    ///   - connection: The underlying NWConnection to manage
    ///   - onReceive: Callback invoked when a LogBatch is successfully received and decoded
    init(connection: NWConnection, onReceive: @escaping (LogBatch) -> Void) {
        self.connection = connection
        self.onReceive = onReceive
        
        connection.stateUpdateHandler = { [weak self] state in
            self?.onStateChange?(state)
        }
    }
    
    /// Starts the connection and begins receiving messages
    /// - Note: Initiates the connection on the main queue and starts the receive loop
    func start() {
        connection.start(queue: .main)
        receiveMessage()
    }
    
    /// Cancels the connection and stops receiving messages
    func cancel() {
        connection.cancel()
    }
    
    /// Recursively receives messages from the connection
    /// - Note: Handles both raw JSON and HTTP POST requests. For HTTP requests,
    ///         parses headers and extracts the JSON body for processing
    private func receiveMessage() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                // Check if this is an HTTP request by looking for HTTP headers
                if let httpString = String(data: data, encoding: .utf8),
                   httpString.hasPrefix("POST") {
                    self.handleHTTPRequest(data: data)
                } else {
                    // Handle raw JSON data (legacy format)
                    self.handleRawJSON(data: data)
                }
            }
            
            if !isComplete && error == nil {
                self.receiveMessage()
            }
        }
    }
    
    /// Handles HTTP POST requests containing JSON log data
    /// - Parameter data: Raw HTTP request data containing headers and JSON body
    private func handleHTTPRequest(data: Data) {
        guard let httpString = String(data: data, encoding: .utf8) else {
            logError("Failed to decode HTTP request as UTF-8", category: .server)
            return
        }
        
        // Split headers and body
        let components = httpString.components(separatedBy: "\r\n\r\n")
        guard components.count >= 2 else {
            logError("Invalid HTTP request format", category: .server)
            return
        }
        
        let headers = components[0]
        let bodyString = components[1]
        
        // Verify this is a POST to /logs
        guard headers.contains("POST /logs") || headers.contains("POST /") else {
            // Send simple HTTP response for unsupported endpoints
            sendHTTPResponse(status: "404 Not Found", body: "Not Found")
            return
        }
        
        // Parse JSON body
        guard let bodyData = bodyString.data(using: .utf8) else {
            sendHTTPResponse(status: "400 Bad Request", body: "Invalid request body")
            return
        }
        
        do {
            let batch = try JSONDecoder().decode(LogBatch.self, from: bodyData)
            self.onReceive(batch)
            // Send HTTP 200 response
            sendHTTPResponse(status: "200 OK", body: "OK")
        } catch {
            logError("Failed to decode log batch from HTTP request: \(error.localizedDescription)", category: .server)
            sendHTTPResponse(status: "400 Bad Request", body: "Invalid JSON")
        }
    }
    
    /// Handles raw JSON data (legacy format for backward compatibility)
    /// - Parameter data: Raw JSON data representing a LogBatch
    private func handleRawJSON(data: Data) {
        do {
            let batch = try JSONDecoder().decode(LogBatch.self, from: data)
            self.onReceive(batch)
        } catch {
            logError("Failed to decode log batch: \(error.localizedDescription)", category: .server)
        }
    }
    
    /// Sends a simple HTTP response back to the client
    /// - Parameters:
    ///   - status: HTTP status line (e.g., "200 OK", "404 Not Found")
    ///   - body: Response body text
    private func sendHTTPResponse(status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)
        Content-Type: text/plain
        Content-Length: \(body.utf8.count)
        Connection: close
        
        \(body)
        """
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { _ in
                // Close connection after sending response
                self.connection.cancel()
            })
        }
    }
    
    /// Equatable implementation based on unique identifier
    static func == (lhs: LogConnection, rhs: LogConnection) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashable implementation using unique identifier
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}