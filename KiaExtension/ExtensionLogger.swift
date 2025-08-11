//
//  ExtensionLogger.swift
//  KiaExtension
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Extension-specific logger that wraps both os_log and RemoteLogger
enum ExtensionLogger {
    
    // MARK: - Logging Methods
    
    /// Log a debug message
    static func debug(_ message: String, category: String = "Extension", _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        logMessage(.debug, log: Logger.extension, category: category, message, args, file: file, function: function, line: line)
    }
    
    /// Log an info message
    static func info(_ message: String, category: String = "Extension", _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        logMessage(.info, log: Logger.extension, category: category, message, args, file: file, function: function, line: line)
    }
    
    /// Log a default/warning message
    static func warning(_ message: String, category: String = "Extension", _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        logMessage(.default, log: Logger.extension, category: category, message, args, file: file, function: function, line: line)
    }
    
    /// Log an error message
    static func error(_ message: String, category: String = "Extension", _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        logMessage(.error, log: Logger.extension, category: category, message, args, file: file, function: function, line: line)
    }
    
    /// Log a fault message
    static func fault(_ message: String, category: String = "Extension", _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        logMessage(.fault, log: Logger.extension, category: category, message, args, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private static func logMessage(
        _ level: OSLogType,
        log: OSLog,
        category: String,
        _ message: String,
        _ args: [CVarArg],
        file: String,
        function: String,
        line: Int
    ) {
        // Log to os_log first
        if args.isEmpty {
            os_log(level, log: log, "%{public}@", message)
        } else {
            // Format message with arguments
            let formattedMessage = String(format: message, arguments: args)
            os_log(level, log: log, "%{public}@", formattedMessage)
        }
        
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
        
        // Format message with args for remote logging
        let formattedMessage = args.isEmpty ? message : String(format: message, arguments: args)
        
        // Determine source based on bundle identifier
        let source: LogEntry.LogSource
        if Bundle.main.bundleIdentifier?.contains("CarPlay") == true {
            source = .carPlayExtension
        } else {
            source = .siriExtension
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
    
    // MARK: - Configuration
    
    /// Enable or disable remote logging
    static func setRemoteLoggingEnabled(_ enabled: Bool) {
        RemoteLogger.shared.setEnabled(enabled)
        
        if enabled {
            info("Remote logging enabled for extension")
        } else {
            info("Remote logging disabled for extension")
        }
    }
    
    /// Check if remote logging is enabled from UserDefaults on startup
    static func configure() {
        let enabled = UserDefaults.standard.bool(forKey: "RemoteLoggingEnabled")
        RemoteLogger.shared.setEnabled(enabled)
        
        info("Extension logger configured - Remote logging: %@", enabled ? "enabled" : "disabled")
    }
}