//
//  AbstractLogger.swift
//  KiaMaps
//
//  Created by Claude on 14.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

// MARK: - Log Level Abstraction

/// Abstract log level that maps to both os_log and remote logging levels
public enum AbstractLogLevel: CaseIterable {
    case debug
    case info
    case warning
    case error
    case fault
    
    /// Convert to OSLogType for os_log compatibility
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
    
    /// Convert to RemoteLogger level
    var remoteLogLevel: LogEntry.LogLevel {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
}

// MARK: - Log Category Abstraction

/// Abstract log categories that can be used across app and extensions
public enum LogCategory: String, CaseIterable {
    case api = "API"
    case auth = "Auth"
    case server = "Server"
    case app = "App"
    case ui = "UI"
    case bluetooth = "Bluetooth"
    case mqtt = "MQTT"
    case keychain = "Keychain"
    case vehicle = "Vehicle"
    case ext = "Extension"
    case general = "General"
    
    /// Get corresponding OSLog for this category
    func osLog(subsystem: String) -> OSLog {
        return OSLog(subsystem: subsystem, category: self.rawValue)
    }
}

// MARK: - Abstract Logger Protocol

/// Protocol defining the abstract logging interface
public protocol AbstractLoggerProtocol {
    
    /// Log a debug message
    func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    
    /// Log an info message
    func info(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    
    /// Log a warning message
    func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    
    /// Log an error message
    func error(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    
    /// Log a fault message
    func fault(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    
    /// Log a message with specified level and category
    func log(_ level: AbstractLogLevel, message: String, category: LogCategory, file: String, function: String, line: Int)
}

// MARK: - Default Implementation

public extension AbstractLoggerProtocol {
    
    /// Default implementation using the general log method
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, category: category, file: file, function: function, line: line)
    }
    
    func fault(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.fault, message: message, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Shared Logger Instance

/// Global shared logger instance that can be configured differently for app vs extension
public final class SharedLogger {
    
    /// Shared singleton instance
    public static let shared = SharedLogger()
    
    /// The actual logger implementation (app or extension specific)
    private var implementation: AbstractLoggerProtocol
    
    private init() {
        // Default to a simple implementation - will be replaced during app startup
        self.implementation = AppLogger()
    }
    
    /// Configure the logger implementation (called during app/extension startup)
    public func configure(with logger: AbstractLoggerProtocol) {
        self.implementation = logger
    }
    
    /// Get the current logger implementation
    public var logger: AbstractLoggerProtocol {
        return implementation
    }
}

// MARK: - Convenience Global Functions

/// Global convenience functions for logging
public func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    SharedLogger.shared.logger.debug(message, category: category, file: file, function: function, line: line)
}

public func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    SharedLogger.shared.logger.info(message, category: category, file: file, function: function, line: line)
}

public func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    SharedLogger.shared.logger.warning(message, category: category, file: file, function: function, line: line)
}

public func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    SharedLogger.shared.logger.error(message, category: category, file: file, function: function, line: line)
}

public func logFault(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    SharedLogger.shared.logger.fault(message, category: category, file: file, function: function, line: line)
}