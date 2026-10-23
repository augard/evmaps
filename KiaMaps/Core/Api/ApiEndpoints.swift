//
//  ApiEndpoints.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

/// Specifies which base URL an endpoint is relative to.
enum ApiEndpointBase {
    enum RelativeTo {
        case base   // Main API base host
        case login  // Authentication host
        case spa    // Single Page Application API host
        case user   // User profile host
        case mqtt   // MQTT host
    }
}

/// Shared protocol for brand-specific endpoint enums.
protocol ApiEndpointProtocol: CustomStringConvertible {
    var path: (String, ApiEndpointBase.RelativeTo) { get }
}
