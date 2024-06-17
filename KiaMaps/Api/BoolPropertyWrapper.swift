//
//  BoolPropertyWrapper.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 06.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

@propertyWrapper
struct BoolValue: Codable, Sendable {
    var wrappedValue = false
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Bool.self) {
            wrappedValue = value
        } else if let number = try? container.decode(Int.self), [0, 1].contains(number) {
            wrappedValue = number == 1 ? true : false
        } else {
            wrappedValue = try container.decode(Bool.self)
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}
