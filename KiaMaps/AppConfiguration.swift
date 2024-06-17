//
//  AppConfiguration.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 13.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

enum AppConfiguration {
    /// Your username to Kia/Hyunday/Genesis connect
    static let username = ""
    /// Your password to Kia/Hyunday/Genesis connect
    static let password = ""
    /// Supported brands
    static let apiConfiguration: ApiConfiguration = ApiBrand.kia.configuration(for: .europe)
    /// If nil it will choose first vehicle in list
    static let vehicleVin: String? = nil
    
    static let accessGroupId = "com.porsche.one"
}
