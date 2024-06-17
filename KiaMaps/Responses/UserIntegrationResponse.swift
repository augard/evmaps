//
//  UserIntegrationResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

struct UserIntegrationResponse: Codable {
    let userId: UUID
    let serviceId: UUID
    let serviceName: String
}
