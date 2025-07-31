//
//  AppConfiguration.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

enum AppConfiguration {
    /// Supported brands
    static let apiConfiguration: ApiConfiguration = ApiBrand.kia.configuration(for: .europe)
    /// If nil it will choose first vehicle in list
    static let vehicleVin: String? = nil

    static let accessGroupId = "N448G4S8S9.com.porsche.one.shared"
}
