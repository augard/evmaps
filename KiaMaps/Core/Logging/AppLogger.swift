//
//  AppLogger.swift
//  KiaMaps
//
//  Created by Claude on 14.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// App-specific logger implementation that uses only os_log
public final class AppLogger: AbstractLoggerProtocol {
    
    // MARK: - Properties
    
    private let subsystem: String
    private var categoryLogs: [LogCategory: OSLog] = [:]
    
    // MARK: - Initialization
    
    public init(subsystem: String? = nil) {
        self.subsystem = subsystem ?? Bundle.main.bundleIdentifier ?? "com.porsche.kiamaps"
        
        // Pre-create OSLog instances for all categories
        for category in LogCategory.allCases {
            categoryLogs[category] = category.osLog(subsystem: self.subsystem)
        }
    }
    
    // MARK: - AbstractLoggerProtocol Implementation
    
    public func log(_ level: AbstractLogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        guard let osLog = categoryLogs[category] else {
            // Fallback to general category if somehow missing
            let fallbackLog = LogCategory.general.osLog(subsystem: subsystem)
            logToOSLog(level.osLogType, log: fallbackLog, message: message, file: file, function: function, line: line)
            return
        }
        
        logToOSLog(level.osLogType, log: osLog, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func logToOSLog(_ level: OSLogType, log: OSLog, message: String, file: String, function: String, line: Int) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        os_log(level, log: log, "%{public}@", formattedMessage)
    }
}

// MARK: - App Logger Configuration

public extension AppLogger {
    
    /// Configure the shared logger with an AppLogger instance
    static func configureSharedLogger(subsystem: String? = nil) {
        let appLogger = AppLogger(subsystem: subsystem)
        SharedLogger.shared.configure(with: appLogger)
    }
}