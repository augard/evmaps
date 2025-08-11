//
//  LoadingViewDemo.swift
//  KiaMaps
//
//  Created by Claude Code on 22.07.2025.
//  Demo view to showcase the new loading components
//

import SwiftUI

struct LoadingViewDemo: View {
    @State private var progress: Double = 0.0
    @State private var showFullScreen = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: KiaDesign.Spacing.xl) {
                    // Standard loading
                    demoSection(title: "Standard Loading") {
                        KiaLoadingView()
                            .frame(height: 150)
                    }
                    
                    // Custom messages
                    demoSection(title: "Custom Messages") {
                        VStack(spacing: KiaDesign.Spacing.large) {
                            KiaLoadingView(
                                message: "Authenticating",
                                submessage: "Verifying your credentials"
                            )
                            .frame(height: 150)
                            
                            KiaLoadingView(
                                message: "Refreshing",
                                submessage: "Getting latest vehicle status"
                            )
                            .frame(height: 150)
                        }
                    }
                    
                    // Inline loading
                    demoSection(title: "Inline Loading") {
                        HStack(spacing: KiaDesign.Spacing.xl) {
                            VStack {
                                KiaInlineLoadingView(size: .small)
                                Text("Small")
                                    .font(KiaDesign.Typography.caption)
                            }
                            
                            VStack {
                                KiaInlineLoadingView(size: .medium)
                                Text("Medium")
                                    .font(KiaDesign.Typography.caption)
                            }
                            
                            VStack {
                                KiaInlineLoadingView(size: .large)
                                Text("Large")
                                    .font(KiaDesign.Typography.caption)
                            }
                        }
                    }
                    
                    // Progress loading
                    demoSection(title: "Progress Loading") {
                        VStack(spacing: KiaDesign.Spacing.medium) {
                            KiaProgressLoadingView(
                                message: "Downloading update...",
                                progress: progress
                            )
                            
                            KiaSlider(
                                value: $progress,
                                in: 0...1,
                                style: .standard
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Full screen demo button
                    KiaButton(
                        "Show Full Screen Loading",
                        icon: "arrow.up.left.and.arrow.down.right",
                        style: .primary
                    ) {
                        showFullScreen = true
                    }
                }
                .padding()
            }
            .navigationTitle("Loading Components")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            ZStack {
                // Mock background
                LinearGradient(
                    colors: [
                        KiaDesign.Colors.primary.opacity(0.1),
                        KiaDesign.Colors.accent.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    KiaFullScreenLoadingView(
                        message: "Processing",
                        submessage: "This may take a few moments"
                    )
                    
                    KiaButton(
                        "Dismiss",
                        style: .secondary
                    ) {
                        showFullScreen = false
                    }
                    .padding(.top, KiaDesign.Spacing.xl)
                }
            }
        }
    }
    
    private func demoSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: KiaDesign.Spacing.medium) {
            Text(title)
                .font(KiaDesign.Typography.title3)
                .fontWeight(.semibold)
                .foregroundStyle(KiaDesign.Colors.textPrimary)
            
            KiaCard {
                content()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
}

#Preview {
    LoadingViewDemo()
}