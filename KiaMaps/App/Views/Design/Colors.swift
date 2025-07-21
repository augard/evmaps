//
//  Colors.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Color definitions and asset catalog integration
//

import SwiftUI

/// Extended color definitions for cases where asset catalog colors are not available
/// Provides fallback system colors and semantic color utilities
extension KiaDesign.Colors {
    
    // MARK: - Semantic Color Helpers
    
    /// Dynamic color that adapts to light/dark mode
    static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
    
    // MARK: - Kia Brand Colors (Fallback)
    
    /// Kia signature lime green - primary brand color
    static let kiaLimeGreen = Color(red: 0.0, green: 0.82, blue: 0.33) // #00D154
    
    /// Kia dark green - for dark themes
    static let kiaDarkGreen = Color(red: 0.0, green: 0.6, blue: 0.25) // #009940
    
    /// Kia light green - for accents and highlights
    static let kiaLightGreen = Color(red: 0.67, green: 0.95, blue: 0.78) // #ABF2C7
    
    // MARK: - EV Status Colors
    
    /// Battery and charging states
    struct Battery {
        static let full = Color.green
        static let good = Color.mint
        static let medium = Color.yellow
        static let low = Color.orange
        static let critical = Color.red
        static let charging = Color.blue
    }
    
    /// Vehicle status indicators
    struct Status {
        static let ready = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let inactive = Color.gray
        static let locked = Color.blue
        static let unlocked = Color.orange
    }
    
    /// Climate control colors
    struct Climate {
        static let cool = Color.blue
        static let warm = Color.orange
        static let hot = Color.red
        static let cold = Color.cyan
        static let auto = Color.mint
    }
    
    // MARK: - Tesla-Inspired Gradients
    
    /// Battery level gradient (empty to full)
    static let batteryGradient = LinearGradient(
        colors: [Battery.critical, Battery.low, Battery.medium, Battery.good, Battery.full],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Charging progress gradient
    static let chargingGradient = LinearGradient(
        colors: [Battery.charging, kiaLimeGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Climate temperature gradient (cold to hot)
    static let temperatureGradient = LinearGradient(
        colors: [Climate.cold, Climate.cool, Climate.auto, Climate.warm, Climate.hot],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    /// Card background gradient for premium feel
    static let cardGradient = LinearGradient(
        colors: [
            dynamicColor(light: .white, dark: Color(red: 0.11, green: 0.11, blue: 0.12)),
            dynamicColor(light: Color(red: 0.98, green: 0.98, blue: 0.99), dark: Color(red: 0.09, green: 0.09, blue: 0.10))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Utility Extensions

extension Color {
    /// Create color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Get hex string representation of color
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
    
    /// Lighten color by percentage (0.0 to 1.0)
    func lighter(by percentage: CGFloat = 0.2) -> Color {
        return self.opacity(1.0 - percentage)
    }
    
    /// Darken color by percentage (0.0 to 1.0)
    func darker(by percentage: CGFloat = 0.2) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(max(brightness * (1.0 - percentage), 0.0)),
            opacity: Double(alpha)
        )
    }
}