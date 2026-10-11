//
//  AuthorizationImportView.swift
//  KiaMaps
//

import SwiftUI

struct AuthorizationImportView: View {
    @State private var bundleJSON = ""
    @State private var errorMessage = ""

    let configuration: AppConfiguration.Type
    let onLoginSuccess: (AuthorizationData) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KiaDesign.Spacing.large) {
                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(KiaDesign.Colors.primary)

                    Text("Connect an authorized session")
                        .font(KiaDesign.Typography.title1)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)

                    Text("Paste a token bundle issued by your approved Kia integration or local broker. Tokens stay in the iOS Keychain.")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                    Text("Authorization bundle")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)

                    TextEditor(text: $bundleJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 190)
                        .padding(KiaDesign.Spacing.small)
                        .background(KiaDesign.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KiaDesign.Colors.textSecondary.opacity(0.25))
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .accessibilityLabel("Authorization bundle JSON")

                    if !errorMessage.isEmpty {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(KiaDesign.Typography.caption)
                            .foregroundStyle(KiaDesign.Colors.error)
                    }
                }

                VStack(alignment: .leading, spacing: KiaDesign.Spacing.xs) {
                    Text("Required JSON")
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    Text(#"{"accessToken":"…","expiresIn":3600}"#)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                    Text("Optional: refreshToken, deviceId, isCcuCCS2Supported")
                        .font(KiaDesign.Typography.captionSmall)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }

                KiaButton(
                    "Import authorization",
                    icon: "lock.open",
                    style: .primary,
                    size: .large,
                    isEnabled: !bundleJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    isFullWidth: true,
                    hapticFeedback: .medium,
                    action: importAuthorization
                )
            }
            .padding(KiaDesign.Spacing.large)
        }
        .background(KiaDesign.Colors.background)
    }

    private func importAuthorization() {
        do {
            let payload = try AuthorizationImportPayload.decode(from: bundleJSON)
            let authorization = try payload.authorization(for: configuration.apiConfiguration)
            LoginCredentialManager.clearCredentials()
            errorMessage = ""
            onLoginSuccess(authorization)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to import authorization."
        }
    }
}

#Preview {
    AuthorizationImportView(configuration: AppConfiguration.self) { _ in }
}
