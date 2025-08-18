//
//  LogEntry.swift
//  KiaMaps
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import UIKit

/// Represents a single log entry that can be sent over the network
public struct LogEntry: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let level: LogLevel
    public let message: String
    public let source: LogSource
    public let file: String?
    public let function: String?
    public let line: Int?
    
    public enum LogLevel: String, Codable, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case `default` = "DEFAULT"
        case error = "ERROR"
        case fault = "FAULT"
        
        var symbolName: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .default: return "⚠️"
            case .error: return "❌"
            case .fault: return "💥"
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .default: return 2
            case .error: return 3
            case .fault: return 4
            }
        }
    }
    
    public enum LogSource: String, Codable, CaseIterable {
        case mainApp = "MainApp"
        case carPlayExtension = "CarPlayExtension"
        case siriExtension = "SiriExtension"
    }
    
    public init(
        category: String,
        level: LogLevel,
        message: String,
        source: LogSource,
        file: String? = #file,
        function: String? = #function,
        line: Int? = #line
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.category = category
        self.level = level
        self.message = message
        self.source = source
        self.file = file?.components(separatedBy: "/").last
        self.function = function
        self.line = line
    }
    
    /// Formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    /// Formatted location for display
    var formattedLocation: String? {
        guard let file = file else { return nil }
        if let line = line {
            return "\(file):\(line)"
        }
        return file
    }
    
    /// Full formatted log line for display
    var formattedLogLine: String {
        var components = [String]()
        components.append(formattedTimestamp)
        components.append("[\(source.rawValue)]")
        components.append("[\(category)]")
        components.append(level.symbolName)
        components.append(message)
        
        if let location = formattedLocation {
            components.append("(\(location))")
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Network Payload

/// Container for sending multiple log entries
struct LogBatch: Codable {
    let entries: [LogEntry]
    let deviceInfo: DeviceInfo?
    
    struct DeviceInfo: Codable {
        let deviceModel: String
        let osVersion: String
        let appVersion: String
        
        static var current: DeviceInfo {
            DeviceInfo(
                deviceModel: UIDevice.current.model,
                osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            )
        }
    }
}