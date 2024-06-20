//
//  Handler.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import Intents

protocol Handler: AnyObject {
    func canHandle(_ intent: INIntent) -> Bool
}
