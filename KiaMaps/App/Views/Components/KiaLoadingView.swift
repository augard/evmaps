//
//  KiaLoadingView.swift
//  KiaMaps
//
//  Created by Claude Code on 22.07.2025.
//  Tesla-inspired loading view with smooth animations
//

import SwiftUI

/// Modern loading view with animated spinner and customizable message
struct KiaLoadingView: View {
    let message: String
    let submessage: String?
    
    @State private var isRotating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var dotOpacity: [Double] = [1.0, 0.5, 0.3]
    
    init(
        message: String = "Loading...",
        submessage: String? = nil
    ) {
        self.message = message
        self.submessage = submessage
    }
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Main loading indicator
            loadingIndicator
            
            // Loading text
            loadingText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KiaDesign.Colors.background)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(KiaDesign.Colors.cardBackground, lineWidth: 4)
                .frame(width: 60, height: 60)
            
            // Animated progress arc
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        colors: [
                            KiaDesign.Colors.primary,
                            KiaDesign.Colors.primary.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: isRotating
                )
            
            // Center pulse effect
            Circle()
                .fill(KiaDesign.Colors.primary.opacity(0.2))
                .frame(width: 30, height: 30)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulseScale
                )
        }
    }
    
    // MARK: - Loading Text
    
    private var loadingText: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            // Main message with animated dots
            HStack(spacing: 2) {
                Text(message)
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                // Animated dots
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Text(".")
                            .font(KiaDesign.Typography.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                            .opacity(dotOpacity[index])
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: dotOpacity[index]
                            )
                    }
                }
            }
            
            // Optional submessage
            if let submessage = submessage {
                Text(submessage)
                    .font(KiaDesign.Typography.body)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Start rotation
        isRotating = true
        
        // Start pulse
        pulseScale = 1.2
        
        // Start dots animation
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                dotOpacity[index] = 0.3
            }
        }
    }
}

// MARK: - Full Screen Loading View

/// Full screen loading overlay with background blur
struct KiaFullScreenLoadingView: View {
    let message: String
    let submessage: String?
    let showBackground: Bool
    
    init(
        message: String = "Loading...",
        submessage: String? = nil,
        showBackground: Bool = true
    ) {
        self.message = message
        self.submessage = submessage
        self.showBackground = showBackground
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                // Background blur
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .blur(radius: 3)
            }
            
            // Loading card
            KiaCard(elevation: .high) {
                KiaLoadingView(
                    message: message,
                    submessage: submessage
                )
                .frame(width: 250, height: 200)
            }
            .frame(width: 250)
        }
    }
}

// MARK: - Inline Loading View

/// Compact loading view for inline use
struct KiaInlineLoadingView: View {
    let size: Size
    let color: Color
    
    @State private var isRotating = false
    
    enum Size {
        case small  // 16pt
        case medium // 24pt
        case large  // 32pt
        
        var dimension: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            }
        }
        
        var lineWidth: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }
    }
    
    init(
        size: Size = .medium,
        color: Color = KiaDesign.Colors.primary
    ) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: size.lineWidth)
                .frame(width: size.dimension, height: size.dimension)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(color, style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round))
                .frame(width: size.dimension, height: size.dimension)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isRotating
                )
        }
        .onAppear {
            isRotating = true
        }
    }
}

// MARK: - Progress Loading View

/// Loading view with progress indicator
struct KiaProgressLoadingView: View {
    let message: String
    let progress: Double // 0.0 to 1.0
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.large) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(KiaDesign.Colors.cardBackground, lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        KiaDesign.Colors.primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                
                // Percentage text
                Text("\(Int(progress * 100))%")
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                    .monospacedDigit()
            }
            
            // Message
            Text(message)
                .font(KiaDesign.Typography.body)
                .foregroundStyle(KiaDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(KiaDesign.Spacing.xl)
    }
}

// MARK: - Preview

#Preview("Loading Views") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Standard loading view
            VStack {
                Text("Standard Loading View")
                    .font(KiaDesign.Typography.title2)
                
                KiaLoadingView()
                    .frame(height: 200)
                    .background(KiaDesign.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            }
            
            // With custom message
            VStack {
                Text("Custom Message")
                    .font(KiaDesign.Typography.title2)
                
                KiaLoadingView(
                    message: "Connecting",
                    submessage: "Establishing secure connection to your vehicle"
                )
                .frame(height: 200)
                .background(KiaDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            }
            
            // Inline loading views
            VStack {
                Text("Inline Loading")
                    .font(KiaDesign.Typography.title2)
                
                HStack(spacing: KiaDesign.Spacing.large) {
                    KiaInlineLoadingView(size: .small)
                    KiaInlineLoadingView(size: .medium)
                    KiaInlineLoadingView(size: .large)
                    KiaInlineLoadingView(size: .large, color: KiaDesign.Colors.success)
                }
            }
            
            // Progress loading
            VStack {
                Text("Progress Loading")
                    .font(KiaDesign.Typography.title2)
                
                KiaProgressLoadingView(
                    message: "Downloading vehicle data...",
                    progress: 0.65
                )
                .background(KiaDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            }
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}

#Preview("Full Screen Loading") {
    ZStack {
        // Mock background content
        Color.blue.opacity(0.1)
            .ignoresSafeArea()
        
        KiaFullScreenLoadingView(
            message: "Authenticating",
            submessage: "Please wait while we connect to your account"
        )
    }
}