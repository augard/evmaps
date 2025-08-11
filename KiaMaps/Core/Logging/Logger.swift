//
//  Logger.swift
//  KiaMaps
//
//  Created by Claude on 11.08.2025.
//  Copyright © 2025 Lukas Foldyna. All rights reserved.
//

import Foundation
import os.log

/// Centralized logging utility for the KiaMaps application
enum Logger {
    
    // MARK: - Subsystems
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kiamaps"
    
    // MARK: - Log Categories
    
    /// API and network related logging
    static let api = OSLog(subsystem: subsystem, category: "API")
    
    /// Authentication and authorization logging
    static let auth = OSLog(subsystem: subsystem, category: "Auth")
    
    /// Local server and credential sharing
    static let server = OSLog(subsystem: subsystem, category: "Server")
    
    /// Application lifecycle and background tasks
    static let app = OSLog(subsystem: subsystem, category: "App")
    
    /// UI and view related logging
    static let ui = OSLog(subsystem: subsystem, category: "UI")
    
    /// Bluetooth connectivity
    static let bluetooth = OSLog(subsystem: subsystem, category: "Bluetooth")
    
    /// Keychain and secure storage
    static let keychain = OSLog(subsystem: subsystem, category: "Keychain")
    
    /// Vehicle data and status
    static let vehicle = OSLog(subsystem: subsystem, category: "Vehicle")
    
    /// Extension and Siri integration
    static let `extension` = OSLog(subsystem: subsystem, category: "Extension")
    
    /// General default logging
    static let general = OSLog(subsystem: subsystem, category: "General")
}