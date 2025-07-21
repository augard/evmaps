//
//  KiaProgressBar.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired progress bar components with smooth animations
//

import SwiftUI

/// Animated progress bar component for battery level, charging progress, and other metrics
struct KiaProgressBar: View {
    let value: Double // 0.0 to 1.0
    let style: Style
    let height: CGFloat
    let animationDuration: Double
    let showPercentage: Bool
    let cornerRadius: CGFloat
    
    @State private var animatedValue: Double = 0
    @State private var isAnimating: Bool = false
    
    enum Style {
        case battery        // Green gradient for battery
        case charging       // Blue gradient for active charging
        case temperature    // Temperature gradient from cold to hot
        case custom(gradient: LinearGradient, background: Color)
        
        var gradient: LinearGradient {
            switch self {
            case .battery:
                return KiaDesign.Colors.batteryGradient
            case .charging:
                return KiaDesign.Colors.chargingGradient
            case .temperature:
                return KiaDesign.Colors.temperatureGradient
            case .custom(let gradient, _):
                return gradient
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .battery, .charging, .temperature:
                return KiaDesign.Colors.textTertiary.opacity(0.15)
            case .custom(_, let background):
                return background
            }
        }
    }
    
    init(
        value: Double,
        style: Style = .battery,
        height: CGFloat = KiaDesign.Layout.progressBarHeight,
        animationDuration: Double = 0.8,
        showPercentage: Bool = false,
        cornerRadius: CGFloat? = nil
    ) {
        self.value = max(0, min(1, value)) // Clamp between 0 and 1
        self.style = style
        self.height = height
        self.animationDuration = animationDuration
        self.showPercentage = showPercentage
        self.cornerRadius = cornerRadius ?? (height / 2)
    }
    
    var body: some View {
        HStack(spacing: KiaDesign.Spacing.small) {
            progressBarView
            
            if showPercentage {
                Text("\(Int(value * 100))%")
                    .font(KiaDesign.Typography.caption)
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                    .monospacedDigit()
                    .animation(.none, value: value) // Don't animate text changes
            }
        }
        .onAppear {
            animateToValue()
        }
        .onChange(of: value) { oldValue, newValue in
            animateToValue()
        }
    }
    
    private var progressBarView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(style.backgroundColor)
                    .frame(height: height)
                
                // Progress fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(style.gradient)
                    .frame(
                        width: max(0, geometry.size.width * animatedValue),
                        height: height
                    )
                    .animation(
                        .easeInOut(duration: animationDuration),
                        value: animatedValue
                    )
                
                // Shimmer effect for charging state
                if case .charging = style, isAnimating {
                    shimmerEffect(in: geometry)
                }
            }
        }
        .frame(height: height)
    }
    
    private func shimmerEffect(in geometry: GeometryProxy) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: geometry.size.width * 0.3,
                height: height
            )
            .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.3)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(
                        width: max(0, geometry.size.width * animatedValue),
                        height: height
                    )
            )
    }
    
    private func animateToValue() {
        // Delay animation slightly for better visual effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animatedValue = value
            
            if case .charging = style {
                isAnimating = value > 0 && value < 1
            }
        }
    }
}

// MARK: - Circular Progress Bar

/// Circular progress indicator for prominent displays like battery status
struct KiaCircularProgressBar: View {
    let value: Double // 0.0 to 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let style: KiaProgressBar.Style
    let showValue: Bool
    let animationDuration: Double
    
    @State private var animatedValue: Double = 0
    
    init(
        value: Double,
        size: CGFloat = 120,
        lineWidth: CGFloat = 12,
        style: KiaProgressBar.Style = .battery,
        showValue: Bool = true,
        animationDuration: Double = 1.0
    ) {
        self.value = max(0, min(1, value))
        self.size = size
        self.lineWidth = lineWidth
        self.style = style
        self.showValue = showValue
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    style.backgroundColor,
                    lineWidth: lineWidth
                )
                .frame(width: size, height: size)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(
                    style.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90)) // Start from top
                .animation(
                    .easeInOut(duration: animationDuration),
                    value: animatedValue
                )
            
            // Center content
            if showValue {
                VStack(spacing: 4) {
                    Text("\(Int(value * 100))")
                        .font(KiaDesign.Typography.displayMedium)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text("%")
                        .font(KiaDesign.Typography.title3)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                .animation(.none, value: value) // Don't animate text
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animatedValue = value
            }
        }
        .onChange(of: value) { oldValue, newValue in
            animatedValue = newValue
        }
    }
}

// MARK: - Segmented Progress Bar

/// Multi-segment progress bar for showing different states or ranges
struct KiaSegmentedProgressBar: View {
    let segments: [Segment]
    let height: CGFloat
    let spacing: CGFloat
    
    struct Segment {
        let value: Double // 0.0 to 1.0 for this segment
        let color: Color
        let label: String?
        
        init(value: Double, color: Color, label: String? = nil) {
            self.value = max(0, min(1, value))
            self.color = color
            self.label = label
        }
    }
    
    init(
        segments: [Segment],
        height: CGFloat = KiaDesign.Layout.progressBarHeight,
        spacing: CGFloat = 2
    ) {
        self.segments = segments
        self.height = height
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                KiaProgressBar(
                    value: segment.value,
                    style: .custom(
                        gradient: LinearGradient(
                            colors: [segment.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        background: KiaDesign.Colors.textTertiary.opacity(0.15)
                    ),
                    height: height,
                    animationDuration: 0.6 + Double(index) * 0.1 // Stagger animations
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Progress Bar Variants") {
    let standardBattery = MockVehicleData.batteryLevel(from: MockVehicleData.standard)
    let chargingBattery = MockVehicleData.batteryLevel(from: MockVehicleData.charging)
    let lowBattery = MockVehicleData.batteryLevel(from: MockVehicleData.lowBattery)
    
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Battery progress bars
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Battery Progress Bars")
                    .font(KiaDesign.Typography.title2)
                
                KiaProgressBar(value: standardBattery, style: .battery, showPercentage: true)
                
                KiaProgressBar(value: chargingBattery, style: .charging, showPercentage: true)
                
                KiaProgressBar(value: 0.72, style: .temperature, showPercentage: true)
            }
            
            Divider()
            
            // Circular progress
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Circular Progress")
                    .font(KiaDesign.Typography.title2)
                
                HStack(spacing: KiaDesign.Spacing.xl) {
                    KiaCircularProgressBar(
                        value: standardBattery,
                        size: 100,
                        style: .battery
                    )
                    
                    KiaCircularProgressBar(
                        value: chargingBattery,
                        size: 100,
                        style: .charging
                    )
                }
            }
            
            Divider()
            
            // Segmented progress - Real battery scenarios
            VStack(spacing: KiaDesign.Spacing.medium) {
                Text("Battery Level Scenarios")
                    .font(KiaDesign.Typography.title2)
                
                KiaSegmentedProgressBar(
                    segments: [
                        .init(value: standardBattery, color: KiaDesign.Colors.success, label: "Standard"),
                        .init(value: chargingBattery, color: KiaDesign.Colors.primary, label: "Charging"),
                        .init(value: lowBattery, color: KiaDesign.Colors.warning, label: "Low")
                    ]
                )
            }
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}