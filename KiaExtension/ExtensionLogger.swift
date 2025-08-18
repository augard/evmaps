//
//  ExtensionLogger.swift
//  KiaExtension
//
//  Created by Claude on 14.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Extension-specific logger implementation that uses both os_log and remote logging
public final class ExtensionLogger: AbstractLoggerProtocol {
    
    // MARK: - Properties
    
    private let subsystem: String
    private var categoryLogs: [LogCategory: OSLog] = [:]
    private let remoteLogger: RemoteLogger
    private let logSource: LogEntry.LogSource
    
    // MARK: - Initialization
    
    public init(subsystem: String? = nil, remoteLogger: RemoteLogger = RemoteLogger.shared) {
        self.subsystem = subsystem ?? Bundle.main.bundleIdentifier ?? "com.porsche.kiamaps.extension"
        self.remoteLogger = remoteLogger
        
        // Determine source based on bundle identifier
        if Bundle.main.bundleIdentifier?.contains("CarPlay") == true {
            self.logSource = .carPlayExtension
        } else {
            self.logSource = .siriExtension
        }
        
        // Pre-create OSLog instances for all categories
        for category in LogCategory.allCases {
            categoryLogs[category] = category.osLog(subsystem: self.subsystem)
        }
    }
    
    // MARK: - AbstractLoggerProtocol Implementation
    
    public func log(_ level: AbstractLogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        // Log to os_log
        logToOSLog(level, category: category, message: message, file: file, function: function, line: line)
        
        // Log to remote logger
        logToRemoteLogger(level, category: category, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Configuration
    
    /// Enable or disable remote logging
    public func setRemoteLoggingEnabled(_ enabled: Bool) {
        remoteLogger.setEnabled(enabled)
        
        if enabled {
            info("Remote logging enabled for extension", category: .ext)
        } else {
            info("Remote logging disabled for extension", category: .ext)
        }
    }
    
    /// Check if remote logging is enabled
    public var isRemoteLoggingEnabled: Bool {
        return remoteLogger.isEnabled
    }
    
    // MARK: - Private Methods
    
    private func logToOSLog(_ level: AbstractLogLevel, category: LogCategory, message: String, file: String, function: String, line: Int) {
        guard let osLog = categoryLogs[category] else {
            // Fallback to general category if somehow missing
            let fallbackLog = LogCategory.general.osLog(subsystem: subsystem)
            performOSLog(level.osLogType, log: fallbackLog, message: message, file: file, function: function, line: line)
            return
        }
        
        performOSLog(level.osLogType, log: osLog, message: message, file: file, function: function, line: line)
    }
    
    private func performOSLog(_ osLogType: OSLogType, log: OSLog, message: String, file: String, function: String, line: Int) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        os_log(osLogType, log: log, "%{public}@", formattedMessage)
    }
    
    private func logToRemoteLogger(_ level: AbstractLogLevel, category: LogCategory, message: String, file: String, function: String, line: Int) {
        remoteLogger.log(
            level.remoteLogLevel,
            category: category.rawValue,
            message: message,
            source: logSource,
            file: file,
            function: function,
            line: line
        )
    }
}

// MARK: - Extension Logger Configuration

public extension ExtensionLogger {
    
    /// Configure the shared logger with an ExtensionLogger instance
    static func configureSharedLogger(subsystem: String? = nil, enableRemoteLogging: Bool = true) {
        let extensionLogger = ExtensionLogger(subsystem: subsystem)
        extensionLogger.setRemoteLoggingEnabled(enableRemoteLogging)
        SharedLogger.shared.configure(with: extensionLogger)
    }
}