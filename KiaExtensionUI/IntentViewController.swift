//
//  IntentViewController.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 14.06.2024.
//  Copyright © 2024 Apple. All rights reserved.
//

import IntentsUI

class IntentViewController: UIViewController, INUIHostedViewControlling {
    func configure(with _: INInteraction, context _: INUIHostedViewContext, completion: @escaping (CGSize) -> Void) {
        completion(desiredSize)
    }

    var desiredSize: CGSize {
        CGSize(width: 350.0, height: 150.0)
    }
}
