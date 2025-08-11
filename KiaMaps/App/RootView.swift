//
//  RootView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 29.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import SwiftUI

enum NavigationDestination: Hashable {
    case welcome
    case login
    case main
}

struct RootView: View {
    let configuration: AppConfiguration.Type
    @Binding var navigationPath: [NavigationDestination]
    @State private var isAuthorized = Authorization.isAuthorized

    private var rootStep: NavigationDestination {
        let credentials = LoginCredentialManager.retrieveCredentials()
        if isAuthorized || (credentials?.username.isEmpty == false && credentials?.password.isEmpty == false) {
            return .main
        } else if credentials?.username.isEmpty == false || credentials?.password.isEmpty == false {
            return .login
        } else {
            return .welcome
        }
    }

    var body: some View {
        screenView(for: .welcome)
            .navigationDestination(for: NavigationDestination.self) { destination in
                screenView(for: destination)
            }
            .onAppear() {
                switch rootStep {
                case .welcome:
                    break
                case .login:
                    self.navigationPath.append(.login)
                case .main:
                    self.navigationPath.append(contentsOf: [.login, .main])
                }
            }
    }

    @ViewBuilder
    private func screenView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .welcome:
            WelcomeView {
                navigationPath.append(.login)
            }
            .navigationBarBackButtonHidden(true)
        case .login:
            // Show login view
            LoginView(configuration: configuration) { authorizationData in
                // Store authorization data
                Authorization.store(data: authorizationData)
                
                // Update local state
                isAuthorized = true
                
                // Navigate to main view
                navigationPath.append(NavigationDestination.main)
            }
        case .main:
            MainView(configuration: configuration)
                .navigationBarBackButtonHidden(true)
                .onReceive(NotificationCenter.default.publisher(for: .authorizationDidChange)) { _ in
                    // Check if we need to go back to login
                    if !Authorization.isAuthorized {
                        isAuthorized = false
                        navigationPath.removeLast()
                    }
                }
        }
    }
}
