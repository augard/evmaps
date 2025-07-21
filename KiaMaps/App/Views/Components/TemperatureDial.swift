//
//  TemperatureDial.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired temperature dial component for climate control
//

import SwiftUI
import Foundation
import CoreGraphics

/// Interactive temperature dial with Tesla-inspired design and visual feedback
struct TemperatureDial: View {
    @Binding var temperature: Double
    let range: ClosedRange<Double>
    let unit: TemperatureUnit
    let size: CGFloat
    
    @State private var isDragging = false
    @State private var dragAngle: Double = 0
    @State private var lastAngle: Double = 0
    
    private let startAngle: Double = 135 // Start angle in degrees
    private let endAngle: Double = 405   // End angle (270 degrees of rotation)
    private let totalAngle: Double = 270 // Total rotation range
    
    init(
        temperature: Binding<Double>,
        range: ClosedRange<Double> = 16...30,
        unit: TemperatureUnit = .celsius,
        size: CGFloat = 200
    ) {
        self._temperature = temperature
        self.range = range
        self.unit = unit
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(trackColor, lineWidth: trackWidth)
                .frame(width: size, height: size)
            
            // Temperature gradient arc
            Circle()
                .trim(from: 0, to: normalizedTemperature)
                .stroke(
                    temperatureGradient,
                    style: StrokeStyle(
                        lineWidth: trackWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(startAngle))
            
            // Thumb
            thumbView
                .offset(thumbOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged(handleDragChanged)
                        .onEnded(handleDragEnded)
                )
            
            // Center display
            centerDisplayView
        }
        .onAppear {
            updateDragAngle()
        }
        .onChange(of: temperature) { _, _ in
            if !isDragging {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    updateDragAngle()
                }
            }
        }
    }
    
    // MARK: - Thumb View
    
    private var thumbView: some View {
        ZStack {
            // Thumb background
            Circle()
                .fill(thumbColor)
                .frame(width: thumbSize, height: thumbSize)
                .shadow(
                    color: .black.opacity(isDragging ? 0.3 : 0.2),
                    radius: isDragging ? 8 : 4,
                    y: isDragging ? 4 : 2
                )
            
            // Temperature indicator icon
            Image(systemName: temperatureIcon)
                .font(.system(size: thumbSize * 0.35, weight: .medium))
                .foregroundStyle(.white)
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
    }
    
    // MARK: - Center Display
    
    private var centerDisplayView: some View {
        VStack(spacing: 4) {
            // Main temperature
            Text(formattedTemperature)
                .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                .foregroundStyle(temperatureColor)
                .monospacedDigit()
            
            // Unit and description
            VStack(spacing: 2) {
                Text(unit == .celsius ? "°C" : "°F")
                    .font(.system(size: size * 0.08, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
                
                Text(temperatureDescription)
                    .font(.system(size: size * 0.06, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var normalizedTemperature: Double {
        (temperature - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var trackWidth: CGFloat {
        size * 0.08
    }
    
    private var thumbSize: CGFloat {
        trackWidth * 1.8
    }
    
    private var trackColor: Color {
        KiaDesign.Colors.textTertiary.opacity(0.2)
    }
    
    private var temperatureGradient: AngularGradient {
        AngularGradient(
            colors: [
                KiaDesign.Colors.Climate.cold,    // Blue for cold
                KiaDesign.Colors.Climate.cool,    // Light blue for cool
                KiaDesign.Colors.Climate.auto,    // Green for comfortable
                KiaDesign.Colors.Climate.warm,    // Orange for warm
                KiaDesign.Colors.Climate.hot      // Red for hot
            ],
            center: .center,
            angle: .degrees(startAngle)
        )
    }
    
    private var thumbColor: Color {
        temperatureColor
    }
    
    private var temperatureColor: Color {
        let temp = unit == .celsius ? temperature : (temperature - 32) * 5/9
        
        switch temp {
        case ...15:
            return KiaDesign.Colors.Climate.cold
        case 16...19:
            return KiaDesign.Colors.Climate.cool
        case 20...24:
            return KiaDesign.Colors.Climate.auto
        case 25...28:
            return KiaDesign.Colors.Climate.warm
        case 29...:
            return KiaDesign.Colors.Climate.hot
        default:
            return KiaDesign.Colors.Climate.auto
        }
    }
    
    private var temperatureIcon: String {
        let temp = unit == .celsius ? temperature : (temperature - 32) * 5/9
        
        switch temp {
        case ...15:
            return "snowflake"
        case 16...19:
            return "wind"
        case 20...24:
            return "leaf.fill"
        case 25...28:
            return "sun.min.fill"
        case 29...:
            return "sun.max.fill"
        default:
            return "thermometer"
        }
    }
    
    private var temperatureDescription: String {
        let temp = unit == .celsius ? temperature : (temperature - 32) * 5/9
        
        switch temp {
        case ...15:
            return "Very Cold"
        case 16...18:
            return "Cold"
        case 19...21:
            return "Cool"
        case 22...24:
            return "Comfortable"
        case 25...26:
            return "Warm"
        case 27...28:
            return "Hot"
        case 29...:
            return "Very Hot"
        default:
            return "Moderate"
        }
    }
    
    private var formattedTemperature: String {
        String(format: "%.0f", temperature)
    }
    
    private var thumbOffset: CGSize {
        let radius = (size - thumbSize) / 2
        let angleInRadians = (dragAngle + startAngle) * .pi / 180
        
        return CGSize(
            width: Foundation.cos(angleInRadians) * radius,
            height: Foundation.sin(angleInRadians) * radius
        )
    }
    
    // MARK: - Drag Handling
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if !isDragging {
            isDragging = true
            lastAngle = dragAngle
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        let center = CGPoint(x: size / 2, y: size / 2)
        let location = CGPoint(
            x: value.location.x - center.x,
            y: value.location.y - center.y
        )
        
        let angle = atan2(location.y, location.x) * 180 / .pi
        let normalizedAngle = ((angle - startAngle + 360).truncatingRemainder(dividingBy: 360))
        let clampedAngle = max(0, min(totalAngle, normalizedAngle))
        
        dragAngle = clampedAngle
        
        // Update temperature
        let newTemperature = range.lowerBound + (clampedAngle / totalAngle) * (range.upperBound - range.lowerBound)
        let roundedTemperature = round(newTemperature * 2) / 2 // Round to nearest 0.5
        
        if abs(roundedTemperature - temperature) >= 0.5 {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        
        temperature = roundedTemperature
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Snap to final position
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            updateDragAngle()
        }
    }
    
    private func updateDragAngle() {
        let normalizedTemp = (temperature - range.lowerBound) / (range.upperBound - range.lowerBound)
        dragAngle = normalizedTemp * totalAngle
    }
}

// MARK: - Climate Control Container

/// Complete climate control interface with temperature dial and additional controls
struct ClimateControlView: View {
    @State private var targetTemperature: Double = 22
    @State private var isClimateOn: Bool = false
    @State private var fanSpeed: Double = 3
    @State private var isAutoMode: Bool = true
    
    let unit: TemperatureUnit
    
    init(unit: TemperatureUnit = .celsius) {
        self.unit = unit
    }
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Climate Control")
                        .font(KiaDesign.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(KiaDesign.Colors.textPrimary)
                    
                    Text(isClimateOn ? "System Active" : "System Off")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(isClimateOn ? KiaDesign.Colors.success : KiaDesign.Colors.textSecondary)
                }
                
                Spacer()
                
                // Power toggle
                KiaButton(
                    isClimateOn ? "Turn Off" : "Turn On",
                    icon: "power",
                    style: isClimateOn ? .destructive : .success,
                    size: .medium,
                    hapticFeedback: .medium
                ) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isClimateOn.toggle()
                    }
                }
            }
            
            if isClimateOn {
                // Temperature Dial
                TemperatureDial(
                    temperature: $targetTemperature,
                    range: unit == .celsius ? 16...30 : 60...86,
                    unit: unit,
                    size: 220
                )
                .padding(KiaDesign.Spacing.medium)
                
                // Climate Controls
                VStack(spacing: KiaDesign.Spacing.medium) {
                    // Auto mode toggle
                    HStack {
                        Text("Auto Mode")
                            .font(KiaDesign.Typography.body)
                            .fontWeight(.medium)
                            .foregroundStyle(KiaDesign.Colors.textPrimary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isAutoMode)
                            .toggleStyle(SwitchToggleStyle(tint: KiaDesign.Colors.primary))
                    }
                    
                    // Fan Speed (when not in auto mode)
                    if !isAutoMode {
                        VStack(alignment: .leading, spacing: KiaDesign.Spacing.small) {
                            Text("Fan Speed")
                                .font(KiaDesign.Typography.body)
                                .fontWeight(.medium)
                                .foregroundStyle(KiaDesign.Colors.textPrimary)
                            
                            KiaSlider(
                                value: $fanSpeed,
                                in: 1...10,
                                step: 1,
                                style: .fanSpeed,
                                showValue: true,
                                formatter: { "Speed \(Int($0))" }
                            )
                        }
                    }
                }
                .padding()
                .background(KiaDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            } else {
                // Off state placeholder
                VStack(spacing: KiaDesign.Spacing.medium) {
                    Image(systemName: "power")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(KiaDesign.Colors.textTertiary.opacity(0.5))
                    
                    Text("Climate system is off")
                        .font(KiaDesign.Typography.body)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                }
                .frame(height: 300)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isClimateOn)
    }
}

// MARK: - Preview

#Preview("Temperature Dial") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Individual dial
            Text("Temperature Dial")
                .font(KiaDesign.Typography.title2)
            
            TemperatureDial(
                temperature: .constant(22),
                unit: .celsius,
                size: 200
            )
            
            Divider()
            
            // Complete climate control
            Text("Climate Control Interface")
                .font(KiaDesign.Typography.title2)
            
            ClimateControlView(unit: .celsius)
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}

#Preview("Temperature Dial - Fahrenheit") {
    ClimateControlView(unit: .fahrenheit)
        .padding()
        .background(KiaDesign.Colors.background)
}
