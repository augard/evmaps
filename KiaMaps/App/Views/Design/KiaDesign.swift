//
//  KiaDesign.swift
//  KiaMaps
//
//  Created by Claude Code on 21.07.2025.
//  Tesla-inspired design system for Kia electric vehicle app
//

import SwiftUI

/// Centralized design system providing colors, typography, spacing, and visual styles
/// following Tesla-inspired modern EV app aesthetics
struct KiaDesign {
    
    // MARK: - Colors
    
    enum Colors {
        // Primary Kia brand colors
        static let primary = Color("KiaPrimary") // Kia signature green
        static let primaryLight = Color("KiaPrimaryLight")
        static let primaryDark = Color("KiaPrimaryDark")
        
        // Semantic colors
        static let background = Color("Background") // Adaptive background
        static let backgroundSecondary = Color("BackgroundSecondary")
        static let cardBackground = Color("CardBackground") // Elevated surfaces
        static let accent = Color("Accent") // Interactive elements
        
        // Status colors
        static let success = Color("Success") // Charging, locked, ready
        static let warning = Color("Warning") // Low battery, maintenance
        static let error = Color("Error") // Faults, errors
        static let charging = Color("Charging") // Active charging state
        
        // Text colors
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        
        // Fallback system colors for compatibility
        static let systemPrimary = Color.accentColor
        static let systemBackground = Color(UIColor.systemBackground)
        static let systemSecondaryBackground = Color(UIColor.secondarySystemBackground)
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Display styles for hero sections
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .default)
        
        // Title styles for section headers
        static let title1 = Font.system(size: 24, weight: .bold, design: .default)
        static let title2 = Font.system(size: 20, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 18, weight: .semibold, design: .default)
        
        // Body text for content
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 16, weight: .semibold, design: .default)
        static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
        
        // Caption and labels
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .medium, design: .default)
        
        // Monospace for technical data (VIN, values)
        static let monospace = Font.system(size: 16, weight: .medium, design: .monospaced)
        static let monospaceSmall = Font.system(size: 14, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        // Base spacing units following 8pt grid
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // Specific use cases
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let componentSpacing: CGFloat = 16
        static let minTouchTarget: CGFloat = 44
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let circle: CGFloat = 1000 // Large enough to be circular
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let card = custom(
            color: .black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
        
        static let elevated = custom(
            color: .black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 4
        )
        
        static let floating = custom(
            color: .black.opacity(0.16),
            radius: 24,
            x: 0,
            y: 8
        )
        
        struct custom {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
    
    // MARK: - Layout Constants
    
    enum Layout {
        static let cardMaxWidth: CGFloat = 400
        static let heroImageSize: CGFloat = 200
        static let iconSize: CGFloat = 24
        static let largeIconSize: CGFloat = 32
        static let progressBarHeight: CGFloat = 8
        static let sliderHeight: CGFloat = 44
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling with shadow and background
    func kiaCard(padding: CGFloat = KiaDesign.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(KiaDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            .shadow(
                color: KiaDesign.Shadow.card.color,
                radius: KiaDesign.Shadow.card.radius,
                x: KiaDesign.Shadow.card.x,
                y: KiaDesign.Shadow.card.y
            )
    }
    
    /// Apply elevated card styling for important sections
    func kiaCardElevated(padding: CGFloat = KiaDesign.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(KiaDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: KiaDesign.CornerRadius.large))
            .shadow(
                color: KiaDesign.Shadow.elevated.color,
                radius: KiaDesign.Shadow.elevated.radius,
                x: KiaDesign.Shadow.elevated.x,
                y: KiaDesign.Shadow.elevated.y
            )
    }
    
    /// Apply standard section spacing
    func kiaSectionSpacing() -> some View {
        self.padding(.bottom, KiaDesign.Spacing.sectionSpacing)
    }
}