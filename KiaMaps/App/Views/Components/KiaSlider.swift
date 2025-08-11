//
//  KiaSlider.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired slider components for temperature, fan speed, and other controls
//

import SwiftUI

/// Custom slider component with Tesla-inspired design and smooth interactions
struct KiaSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let style: Style
    let hapticFeedback: Bool
    let showValue: Bool
    let formatter: ((Double) -> String)?
    
    @State private var isDragging = false
    @State private var hapticTimer: Timer?
    
    enum Style {
        case standard       // Basic slider
        case temperature    // Temperature gradient
        case fanSpeed      // Fan speed with icons
        case custom(gradient: LinearGradient, thumbColor: Color)
        
        var gradient: LinearGradient {
            switch self {
            case .standard:
                return LinearGradient(
                    colors: [KiaDesign.Colors.textTertiary, KiaDesign.Colors.primary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .temperature:
                return KiaDesign.Colors.temperatureGradient
            case .fanSpeed:
                return LinearGradient(
                    colors: [KiaDesign.Colors.textTertiary, KiaDesign.Colors.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .custom(let gradient, _):
                return gradient
            }
        }
        
        var thumbColor: Color {
            switch self {
            case .standard:
                return KiaDesign.Colors.primary
            case .temperature:
                return .white
            case .fanSpeed:
                return KiaDesign.Colors.accent
            case .custom(_, let thumbColor):
                return thumbColor
            }
        }
        
        var trackHeight: CGFloat {
            switch self {
            case .temperature, .fanSpeed:
                return 8
            default:
                return 6
            }
        }
    }
    
    // MARK: - Initializers
    
    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double? = nil,
        style: Style = .standard,
        hapticFeedback: Bool = true,
        showValue: Bool = false,
        formatter: ((Double) -> String)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.style = style
        self.hapticFeedback = hapticFeedback
        self.showValue = showValue
        self.formatter = formatter
    }
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.small) {
            if showValue {
                HStack {
                    Spacer()
                    Text(formattedValue)
                        .font(KiaDesign.Typography.caption)
                        .foregroundStyle(KiaDesign.Colors.textSecondary)
                        .monospacedDigit()
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: style.trackHeight / 2)
                        .fill(KiaDesign.Colors.textTertiary.opacity(0.2))
                        .frame(height: style.trackHeight)
                    
                    // Active track
                    RoundedRectangle(cornerRadius: style.trackHeight / 2)
                        .fill(style.gradient)
                        .frame(
                            width: max(0, geometry.size.width * normalizedValue),
                            height: style.trackHeight
                        )
                    
                    // Thumb
                    Circle()
                        .fill(style.thumbColor)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(
                            color: .black.opacity(isDragging ? 0.2 : 0.1),
                            radius: isDragging ? 6 : 3,
                            y: isDragging ? 3 : 1
                        )
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(KiaDesign.Animation.quick, value: isDragging)
                        .offset(x: thumbOffset(in: geometry))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if !isDragging {
                                        isDragging = true
                                        if hapticFeedback {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                    
                                    let newValue = valueFromOffset(
                                        gesture.location.x,
                                        in: geometry
                                    )
                                    updateValue(newValue)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    hapticTimer?.invalidate()
                                    if hapticFeedback {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                }
                        )
                }
            }
            .frame(height: max(style.trackHeight, thumbSize))
        }
    }
    
    // MARK: - Private Properties
    
    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var thumbSize: CGFloat {
        style.trackHeight * 3
    }
    
    private var formattedValue: String {
        if let formatter = formatter {
            return formatter(value)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    // MARK: - Private Methods
    
    private func thumbOffset(in geometry: GeometryProxy) -> CGFloat {
        let trackWidth = geometry.size.width - thumbSize
        return trackWidth * normalizedValue
    }
    
    private func valueFromOffset(_ offset: CGFloat, in geometry: GeometryProxy) -> Double {
        let trackWidth = geometry.size.width - thumbSize
        let normalizedOffset = max(0, min(1, offset / trackWidth))
        let newValue = range.lowerBound + normalizedOffset * (range.upperBound - range.lowerBound)
        
        if let step = step {
            return round(newValue / step) * step
        }
        return newValue
    }
    
    private func updateValue(_ newValue: Double) {
        let clampedValue = max(range.lowerBound, min(range.upperBound, newValue))
        
        if abs(clampedValue - value) > 0.1 && hapticFeedback {
            // Provide haptic feedback for significant changes
            hapticTimer?.invalidate()
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }
        
        value = clampedValue
    }
}

// MARK: - Temperature Slider

/// Specialized slider for climate control with temperature formatting
struct KiaTemperatureSlider: View {
    @Binding var temperature: Double
    let range: ClosedRange<Double>
    let unit: TemperatureUnit
    
    init(
        temperature: Binding<Double>,
        range: ClosedRange<Double> = 16...30,
        unit: TemperatureUnit = .celsius
    ) {
        self._temperature = temperature
        self.range = range
        self.unit = unit
    }
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            HStack {
                Image(systemName: temperatureIcon)
                    .font(.title2)
                    .foregroundStyle(temperatureColor)
                
                Spacer()
                
                Text(formattedTemperature)
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(temperatureColor)
                    .monospacedDigit()
            }
            
            KiaSlider(
                value: $temperature,
                in: range,
                step: 0.5,
                style: .temperature,
                hapticFeedback: true
            )
        }
        .padding()
        .background(temperatureColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
    }
    
    private var temperatureIcon: String {
        if temperature < 18 {
            return "thermometer.snowflake"
        } else if temperature > 26 {
            return "thermometer.high"
        } else {
            return "thermometer.medium"
        }
    }
    
    private var temperatureColor: Color {
        if temperature < 18 {
            return KiaDesign.Colors.Climate.cool
        } else if temperature > 26 {
            return KiaDesign.Colors.Climate.warm
        } else {
            return KiaDesign.Colors.Climate.auto
        }
    }
    
    private var formattedTemperature: String {
        let temp = unit == .celsius ? temperature : temperature * 9/5 + 32
        return String(format: "%.0f°%@", temp, unit == .celsius ? "C" : "F")
    }
}

// MARK: - Fan Speed Slider

/// Specialized slider for HVAC fan speed control
struct KiaFanSpeedSlider: View {
    @Binding var fanSpeed: Double
    let maxSpeed: Double
    
    init(fanSpeed: Binding<Double>, maxSpeed: Double = 10) {
        self._fanSpeed = fanSpeed
        self.maxSpeed = maxSpeed
    }
    
    var body: some View {
        VStack(spacing: KiaDesign.Spacing.medium) {
            HStack {
                Image(systemName: fanIcon)
                    .font(.title2)
                    .foregroundStyle(fanColor)
                    .rotationEffect(.degrees(fanSpeed > 0 ? 360 : 0))
                    .animation(
                        fanSpeed > 0 
                            ? .linear(duration: 2.0 / fanSpeed).repeatForever(autoreverses: false)
                            : .default,
                        value: fanSpeed
                    )
                
                Spacer()
                
                Text(fanSpeedText)
                    .font(KiaDesign.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(fanColor)
            }
            
            KiaSlider(
                value: $fanSpeed,
                in: 0...maxSpeed,
                step: 1,
                style: .fanSpeed,
                hapticFeedback: true
            )
        }
        .padding()
        .background(fanColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
    }
    
    private var fanIcon: String {
        if fanSpeed == 0 {
            return "fan.fill"
        } else if fanSpeed <= 3 {
            return "fan.fill"
        } else if fanSpeed <= 7 {
            return "fan.fill"
        } else {
            return "fan.fill"
        }
    }
    
    private var fanColor: Color {
        if fanSpeed == 0 {
            return KiaDesign.Colors.textTertiary
        } else if fanSpeed <= 3 {
            return KiaDesign.Colors.success
        } else if fanSpeed <= 7 {
            return KiaDesign.Colors.accent
        } else {
            return KiaDesign.Colors.warning
        }
    }
    
    private var fanSpeedText: String {
        if fanSpeed == 0 {
            return "Off"
        } else {
            return "Speed \(Int(fanSpeed))"
        }
    }
}

// MARK: - Circular Slider

/// Circular slider for rotary controls like temperature dials
struct KiaCircularSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let diameter: CGFloat
    let lineWidth: CGFloat
    let style: KiaSlider.Style
    
    @State private var isDragging = false
    @State private var lastAngle: Double = 0
    
    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        diameter: CGFloat = 150,
        lineWidth: CGFloat = 20,
        style: KiaSlider.Style = .temperature
    ) {
        self._value = value
        self.range = range
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.style = style
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    KiaDesign.Colors.textTertiary.opacity(0.2),
                    lineWidth: lineWidth
                )
            
            // Progress arc
            Circle()
                .trim(from: 0.125, to: 0.125 + 0.75 * normalizedValue) // 270 degree range
                .stroke(
                    style.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-135)) // Start from bottom-left
            
            // Thumb
            Circle()
                .fill(style.thumbColor)
                .frame(width: lineWidth + 8, height: lineWidth + 8)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .offset(y: -(diameter / 2))
                .rotationEffect(.degrees(thumbAngle))
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(KiaDesign.Animation.quick, value: isDragging)
            
            // Center value display
            VStack {
                Text("\(Int(value))")
                    .font(.system(size: diameter * 0.2, weight: .bold, design: .monospaced))
                    .foregroundStyle(KiaDesign.Colors.textPrimary)
                
                Text("°C")
                    .font(.system(size: diameter * 0.08, weight: .medium))
                    .foregroundStyle(KiaDesign.Colors.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    handleDragChange(gesture)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
    
    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var thumbAngle: Double {
        -135 + (270 * normalizedValue) // Map to 270 degree range
    }
    
    private func handleDragChange(_ gesture: DragGesture.Value) {
        if !isDragging {
            isDragging = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let location = gesture.location
        
        let angle = atan2(location.y - center.y, location.x - center.x)
        let degrees = angle * 180 / .pi
        
        // Normalize angle to 0-270 range starting from -135 degrees
        let normalizedAngle = (degrees + 135 + 360).truncatingRemainder(dividingBy: 360)
        let clampedAngle = max(0, min(270, normalizedAngle))
        
        let newValue = range.lowerBound + (clampedAngle / 270) * (range.upperBound - range.lowerBound)
        
        if abs(newValue - value) > 0.5 {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        
        value = newValue
    }
}

// MARK: - Preview

#Preview("Slider Components") {
    ScrollView {
        VStack(spacing: KiaDesign.Spacing.xl) {
            // Standard sliders
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Standard Sliders")
                    .font(KiaDesign.Typography.title2)
                
                KiaSlider(
                    value: .constant(0.6),
                    in: 0...1,
                    showValue: true,
                    formatter: { "\(Int($0 * 100))%" }
                )
                
                KiaSlider(
                    value: .constant(75),
                    in: 0...100,
                    step: 5,
                    style: .fanSpeed,
                    showValue: true
                )
            }
            
            Divider()
            
            // Temperature slider
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Temperature Control")
                    .font(KiaDesign.Typography.title2)
                
                KiaTemperatureSlider(temperature: .constant(22))
            }
            
            Divider()
            
            // Fan speed slider
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Fan Speed Control")
                    .font(KiaDesign.Typography.title2)
                
                KiaFanSpeedSlider(fanSpeed: .constant(5))
            }
            
            Divider()
            
            // Circular slider
            VStack(spacing: KiaDesign.Spacing.large) {
                Text("Circular Temperature Dial")
                    .font(KiaDesign.Typography.title2)
                
                KiaCircularSlider(
                    value: .constant(24),
                    range: 16...30
                )
            }
        }
        .padding()
    }
    .background(KiaDesign.Colors.background)
}