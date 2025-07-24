//
//  MainLoadingView.swift
//  KiaMaps
//
//  Created by Claude Code on 23.07.2025.
//  Loading state view for MainView
//

import SwiftUI

/// Loading view displayed while connecting to vehicle
struct MainLoadingView: View {
    var body: some View {
        KiaLoadingView(
            message: "Loading",
            submessage: "Connecting to your vehicle"
        )
    }
}

// MARK: - Preview

#Preview("Main Loading View") {
    MainLoadingView()
        .background(KiaDesign.Colors.background)
}