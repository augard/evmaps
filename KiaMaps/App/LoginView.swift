//
//  LoginView.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 29.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import SwiftUI
import os.log

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var usernameError: String = ""
    @State private var showUsernameError: Bool = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username
        case password
    }
    
    let configuration: AppConfiguration.Type
    let onLoginSuccess: (AuthorizationData) -> Void
    
    private var api: Api {
        Api(configuration: configuration.apiConfiguration, rsaService: .init())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: KiaDesign.Spacing.large) {
                // Header
                VStack(spacing: KiaDesign.Spacing.xs) {
                    Image(systemName: "bolt.car")
                        .font(.system(size: 80))
                        .foregroundStyle(KiaDesign.Colors.primary)
                        .padding(.bottom, KiaDesign.Spacing.medium)

                    Text("Sign in to access your vehicle")
                        .font(KiaDesign.Typography.title1)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)

                    Text("Use your Kia.app login credentials")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, KiaDesign.Spacing.xxl)

                // Spacer to push content up when keyboard appears
                Spacer()

                // Login Form
                VStack(spacing: KiaDesign.Spacing.medium) {
                    // Username Field
                    VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                        Text("Username")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)

                        TextField("Enter your email address", text: $username)
                            .textFieldStyle(KiaTextFieldStyle(hasError: showUsernameError))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .username)
                            .onChange(of: username) { _, newValue in
                                validateUsername(newValue)
                            }
                            .onSubmit {
                                validateUsername(username)
                                if !showUsernameError {
                                    // Move focus to password field only if username is valid
                                    focusedField = .password
                                }
                            }

                        // Username validation error
                        if showUsernameError && !usernameError.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(KiaDesign.Colors.error)
                                    .font(.caption)

                                Text(usernameError)
                                    .font(KiaDesign.Typography.captionSmall)
                                    .foregroundStyle(KiaDesign.Colors.error)

                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                        Text("Password")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.textSecondary)

                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(KiaTextFieldStyle())
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                // Trigger login when user presses "Go"
                                if !username.isEmpty && !password.isEmpty && !isLoading {
                                    Task {
                                        await performLogin()
                                    }
                                }
                            }
                    }

                    // Error Message
                    if showError && !errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(KiaDesign.Colors.error)

                            Text(errorMessage)
                                .font(KiaDesign.Typography.caption)
                                .foregroundStyle(KiaDesign.Colors.error)

                            Spacer()
                        }
                        .padding(.horizontal, KiaDesign.Spacing.small)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, KiaDesign.Spacing.large)

                // Another spacer to provide adequate space
                Spacer()

                // Login Button
                VStack(spacing: KiaDesign.Spacing.medium) {
                    KiaButton(
                        "Sign In",
                        icon: "arrow.right",
                        style: .primary,
                        size: .large,
                        isEnabled: !isLoading && !username.isEmpty && !password.isEmpty && !showUsernameError,
                        isLoading: isLoading,
                        isFullWidth: true,
                        hapticFeedback: .medium,
                        action: {
                            Task {
                                await performLogin()
                            }
                        }
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, KiaDesign.Spacing.large)
                .padding(.bottom, KiaDesign.Spacing.large)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(KiaDesign.Colors.background)
        .navigationTitle("Login to Kia")
        .onAppear {
            loadSavedCredentials()
            // Auto-focus username field if no saved credentials
            if username.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .username
                }
            }
        }
    }
    
    private func performLogin() async {
        // Validate email before attempting login
        validateUsername(username)
        
        // Don't proceed if there are validation errors
        guard !showUsernameError else {
            return
        }
        
        // Hide previous errors
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = false
            errorMessage = ""

            // Set loading state
            isLoading = true
        }
        
        do {
            // Attempt login with API
            let authorizationData = try await api.login(username: username, password: password)
            
            // Store credentials and authorization data
            storeCredentials()
            
            // Call success callback with authorization data
            await MainActor.run {
                isLoading = false
                onLoginSuccess(authorizationData)
            }
        } catch let apiError as ApiError {
            await MainActor.run {
                isLoading = false
                errorMessage = apiError.localizedDescription
                withAnimation(.easeInOut(duration: 0.3)) {
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "An unexpected error occurred. Please try again."
                withAnimation(.easeInOut(duration: 0.3)) {
                    showError = true
                }
            }
        }
    }
    
    private func storeCredentials() {
        // Store credentials securely in keychain
        let credentials = LoginCredentials(username: username, password: password)
        LoginCredentialManager.store(credentials: credentials)
    }
    
    private func loadSavedCredentials() {
        if let savedCredentials = LoginCredentialManager.retrieveCredentials() {
            username = savedCredentials.username
            password = savedCredentials.password
        }
    }
    
    private func validateUsername(_ email: String) {
        // Clear previous errors first
        withAnimation(.easeInOut(duration: 0.2)) {
            showUsernameError = false
            usernameError = ""
        }
        
        // Don't validate empty field (let required field validation handle it)
        guard !email.isEmpty else { return }
        
        // Email validation regex
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !emailPredicate.evaluate(with: email) {
            withAnimation(.easeInOut(duration: 0.2)) {
                usernameError = "Please enter a valid email address"
                showUsernameError = true
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct KiaTextFieldStyle: TextFieldStyle {
    let hasError: Bool
    
    init(hasError: Bool = false) {
        self.hasError = hasError
    }
    
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(KiaDesign.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(KiaDesign.Colors.cardBackground)
                    .stroke(
                        hasError ? KiaDesign.Colors.error : KiaDesign.Colors.textTertiary.opacity(0.2), 
                        lineWidth: hasError ? 2 : 1
                    )
            )
            .font(KiaDesign.Typography.body)
    }
}

// MARK: - Preview

#Preview {
    LoginView(configuration: AppConfiguration.self) { authData in
        logInfo("Login successful for user", category: .auth)
    }
}
