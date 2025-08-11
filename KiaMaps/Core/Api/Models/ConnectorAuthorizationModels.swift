//
//  ConnectorAuthorizationModels.swift
//  KiaMaps
//
//  Created by Lukáš Foldýna on 7/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation

/// State object for connector authorization request
struct ConnectorAuthorizationState: Codable {
    let scope: String?
    let state: String?
    let lang: String?
    let cert: String
    let action: String
    let clientId: String
    let redirectUri: URL
    let responseType: String
    let signupLink: String?
    let hmgid2ClientId: String
    let hmgid2RedirectUri: URL
    let hmgid2Scope: String?
    let hmgid2State: String
    let hmgid2UiLocales: String?

    enum CodingKeys: String, CodingKey {
        case scope
        case state
        case lang
        case cert
        case action
        case clientId = "client_id"
        case redirectUri = "redirect_uri"
        case responseType = "response_type"
        case signupLink = "signup_link"
        case hmgid2ClientId = "hmgid2_client_id"
        case hmgid2RedirectUri = "hmgid2_redirect_uri"
        case hmgid2Scope = "hmgid2_scope"
        case hmgid2State = "hmgid2_state"
        case hmgid2UiLocales = "hmgid2_ui_locales"
    }
}
