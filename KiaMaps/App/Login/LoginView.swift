//
//  LoginView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 29.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import SwiftUI

// MARK: - Login View Variants

struct LoginView: View {
    enum LoginMode {
        case authorizationImport
        case credentials
        case webView
    }
    
    let mode: LoginMode
    let configuration: AppConfiguration.Type
    let onLoginSuccess: (AuthorizationData) -> Void
    
    init(mode: LoginMode = .webView, configuration: AppConfiguration.Type, onLoginSuccess: @escaping (AuthorizationData) -> Void) {
        self.mode = mode
        self.configuration = configuration
        self.onLoginSuccess = onLoginSuccess
    }
    
    var body: some View {
        Group {
            switch mode {
            case .authorizationImport:
                AuthorizationImportView(configuration: configuration, onLoginSuccess: onLoginSuccess)
            case .credentials:
                CredentialsLoginView(configuration: configuration, onLoginSuccess: onLoginSuccess)
            case .webView:
                WebLoginView(configuration: configuration, onLoginSuccess: onLoginSuccess)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(KiaDesign.Colors.background)
        .navigationTitle("Login to \(configuration.apiConfiguration.brandName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu("Sign-in options", systemImage: "ellipsis.circle") {
                NavigationLink("Web Login") {
                    LoginView(mode: .webView, configuration: configuration, onLoginSuccess: onLoginSuccess)
                }
                NavigationLink("Email and password") {
                    LoginView(mode: .credentials, configuration: configuration, onLoginSuccess: onLoginSuccess)
                }
                NavigationLink("Import authorization") {
                    LoginView(mode: .authorizationImport, configuration: configuration, onLoginSuccess: onLoginSuccess)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Credentials Login") {
    LoginView(mode: .credentials, configuration: AppConfiguration.self) { authData in
        logInfo("Login successful for user", category: .auth)
    }
}

#Preview("Authorization Import") {
    LoginView(mode: .authorizationImport, configuration: AppConfiguration.self) { authData in
        logInfo("Authorization imported", category: .auth)
    }
}

#Preview("Web Login") {
    LoginView(mode: .webView, configuration: AppConfiguration.self) { authData in
        logInfo("Login successful for user", category: .auth)
    }
}
