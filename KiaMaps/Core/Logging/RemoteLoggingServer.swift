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
    
    static let shared = RemoteLoggingServer()
    
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var isRunning = false
    @Published private(set) var connectionCount = 0
    
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8081
    private let maxLogCount = 1000
    private var connections: Set<LogConnection> = []
    
    // Filtering
    @Published var filterText = ""
    @Published var selectedLevel: LogEntry.LogLevel?
    @Published var selectedSource: LogEntry.LogSource?
    @Published var selectedCategory: String?
    
    var availableCategories: [String] {
        Array(Set(logs.map { $0.category })).sorted()
    }
    
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
            os_log(.info, log: Logger.server, "Remote logging server started on port %d", port.rawValue)
        } catch {
            os_log(.error, log: Logger.server, "Failed to start remote logging server: %{public}@", error.localizedDescription)
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        connectionCount = 0
        isRunning = false
        os_log(.info, log: Logger.server, "Remote logging server stopped")
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func exportLogs() -> String {
        logs.map { $0.formattedLogLine }.joined(separator: "\n")
    }
    
    // MARK: - Private Methods
    
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
    
    private func handleConnectionStateChange(connection: LogConnection, state: NWConnection.State) {
        switch state {
        case .cancelled, .failed:
            connections.remove(connection)
            connectionCount = connections.count
        default:
            break
        }
    }
    
    private func handleLogBatch(_ batch: LogBatch) {
        // Add new logs
        logs.append(contentsOf: batch.entries)
        
        // Trim if exceeding max count
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
        
        // Log device info if available
        if let deviceInfo = batch.deviceInfo {
            os_log(.debug, log: Logger.server, "Received logs from %{public}@ running iOS %{public}@", 
                   deviceInfo.deviceModel, deviceInfo.osVersion)
        }
    }
}

// MARK: - Connection Handler

private class LogConnection: Hashable {
    let id = UUID()
    private let connection: NWConnection
    private let onReceive: (LogBatch) -> Void
    var onStateChange: ((NWConnection.State) -> Void)?
    
    init(connection: NWConnection, onReceive: @escaping (LogBatch) -> Void) {
        self.connection = connection
        self.onReceive = onReceive
        
        connection.stateUpdateHandler = { [weak self] state in
            self?.onStateChange?(state)
        }
    }
    
    func start() {
        connection.start(queue: .main)
        receiveMessage()
    }
    
    func cancel() {
        connection.cancel()
    }
    
    private func receiveMessage() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                do {
                    let batch = try JSONDecoder().decode(LogBatch.self, from: data)
                    self.onReceive(batch)
                } catch {
                    os_log(.error, log: Logger.server, "Failed to decode log batch: %{public}@", error.localizedDescription)
                }
            }
            
            if !isComplete && error == nil {
                self.receiveMessage()
            }
        }
    }
    
    static func == (lhs: LogConnection, rhs: LogConnection) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}