//
//  RemoteLogger.swift
//  KiaMaps
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Remote logger that sends logs to the main app via network
final class RemoteLogger {
    
    // MARK: - Properties
    
    static let shared = RemoteLogger()
    
    private let serverURL: URL
    private let session: URLSession
    private var logBuffer: [LogEntry] = []
    private let bufferQueue = DispatchQueue(label: "com.kiamaps.remotelogger", qos: .utility)
    private var flushTimer: Timer?
    private let maxBufferSize = 50
    private let flushInterval: TimeInterval = 2.0
    
    private var isEnabled: Bool = false
    private let enabledKey = "RemoteLoggingEnabled"
    
    // MARK: - Initialization
    
    private init() {
        // Default to localhost for development
        // In production, this could be configurable
        self.serverURL = URL(string: "http://localhost:8081/logs")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        self.session = URLSession(configuration: config)
        
        // Check if remote logging is enabled
        self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        
        if isEnabled {
            startFlushTimer()
        }
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable remote logging
    func setEnabled(_ enabled: Bool) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            self.isEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: self.enabledKey)
            
            if enabled {
                self.startFlushTimer()
            } else {
                self.stopFlushTimer()
                self.logBuffer.removeAll()
            }
        }
    }
    
    /// Log a message to the remote server
    func log(
        _ level: LogEntry.LogLevel,
        category: String,
        message: String,
        source: LogEntry.LogSource,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let entry = LogEntry(
            category: category,
            level: level,
            message: message,
            source: source,
            file: file,
            function: function,
            line: line
        )
        
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            self.logBuffer.append(entry)
            
            // Flush immediately if buffer is full
            if self.logBuffer.count >= self.maxBufferSize {
                self.flushLogs()
            }
        }
    }
    
    /// Force flush all buffered logs
    func flush() {
        bufferQueue.async { [weak self] in
            self?.flushLogs()
        }
    }
    
    // MARK: - Private Methods
    
    private func startFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flushTimer?.invalidate()
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.flushInterval, repeats: true) { _ in
                self.bufferQueue.async {
                    self.flushLogs()
                }
            }
        }
    }
    
    private func stopFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer?.invalidate()
            self?.flushTimer = nil
        }
    }
    
    private func flushLogs() {
        guard !logBuffer.isEmpty else { return }
        
        let batch = LogBatch(
            entries: logBuffer,
            deviceInfo: LogBatch.DeviceInfo.current
        )
        
        // Clear buffer immediately
        logBuffer.removeAll()
        
        // Send logs asynchronously
        Task {
            await sendBatch(batch)
        }
    }
    
    private func sendBatch(_ batch: LogBatch) async {
        do {
            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(batch)
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                os_log(.error, log: Logger.extension, "Failed to send logs to server: HTTP %d", httpResponse.statusCode)
            }
        } catch {
            // Don't log network errors to avoid infinite loop
            // Just silently fail
        }
    }
}

// MARK: - Extension Logger Integration

extension RemoteLogger {
    
    /// Log wrapper that also sends to os_log
    static func log(
        _ level: OSLogType,
        log: OSLog,
        category: String,
        source: LogEntry.LogSource,
        _ message: String,
        _ args: CVarArg...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Log to os_log first
        // Note: We can't directly pass variadic args to os_log, so we format the message
        let formattedMessage = String(format: message, arguments: args)
        os_log(level, log: log, "%{public}@", formattedMessage)
        
        // Convert to remote log level
        let remoteLevel: LogEntry.LogLevel
        switch level {
        case .debug:
            remoteLevel = .debug
        case .info:
            remoteLevel = .info
        case .default:
            remoteLevel = .default
        case .error:
            remoteLevel = .error
        case .fault:
            remoteLevel = .fault
        default:
            remoteLevel = .default
        }
        
        // Send to remote logger
        RemoteLogger.shared.log(
            remoteLevel,
            category: category,
            message: formattedMessage,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }
}