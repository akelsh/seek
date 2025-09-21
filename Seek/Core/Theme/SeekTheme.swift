import SwiftUI
import AppKit

struct SeekTheme {
    static let appBackground = Color(
        light: Color(red: 242/255, green: 242/255, blue: 247/255),
        dark: Color(red: 22/255, green: 22/255, blue: 24/255) 
    )
    
    static let appSurface = Color(
        light: Color(red: 255/255, green: 255/255, blue: 255/255),
        dark: Color(red: 31/255, green: 31/255, blue: 34/255) 
    )
    
    static let appElevated = Color(
        light: Color(red: 255/255, green: 255/255, blue: 255/255),
        dark: Color(red: 37/255, green: 37/255, blue: 41/255)
    )
    
    static let appCardHover = Color(
        light: Color(red: 248/255, green: 248/255, blue: 250/255),
        dark: Color(red: 41/255, green: 41/255, blue: 46/255)
    )
    
    static let appPrimary = Color(
        light: Color(red: 88/255, green: 88/255, blue: 92/255),
        dark: Color(red: 186/255, green: 186/255, blue: 192/255)  
    )
    
    static let appSecondary = Color(
        light: Color(red: 88/255, green: 86/255, blue: 214/255),
        dark: Color(red: 167/255, green: 139/255, blue: 250/255)
    )
    
    static let appTextPrimary = Color(
        light: Color(red: 17/255, green: 17/255, blue: 17/255),
        dark: Color(red: 245/255, green: 245/255, blue: 247/255) 
    )
    
    static let appTextSecondary = Color(
        light: Color(red: 102/255, green: 102/255, blue: 102/255),
        dark: Color(red: 168/255, green: 168/255, blue: 176/255) 
    )
    
    static let appTextTertiary = Color(
        light: Color(red: 153/255, green: 153/255, blue: 153/255),
        dark: Color(red: 110/255, green: 110/255, blue: 118/255) 
    )
    
    // Elegant separators with blue tint
    static let appSeparator = Color(
        light: Color(red: 200/255, green: 199/255, blue: 204/255).opacity(0.5),
        dark: Color(red: 84/255, green: 84/255, blue: 92/255).opacity(0.4)
    )
    
    // Fill colors with subtle color
    static let appFillPrimary = Color(
        light: Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.08),
        dark: Color(red: 120/255, green: 120/255, blue: 140/255).opacity(0.12)
    )
    
    static let appFillSecondary = Color(
        light: Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.05),
        dark: Color(red: 130/255, green: 130/255, blue: 150/255).opacity(0.08)
    )
    
    static let appFillTertiary = Color(
        light: Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.03),
        dark: Color(red: 140/255, green: 140/255, blue: 160/255).opacity(0.05)
    )
    
    // Interactive states - FIXED for light mode visibility
    static let appHover = Color(
        light: Color(red: 0/255, green: 0/255, blue: 0/255).opacity(0.04), 
        dark: Color(red: 186/255, green: 186/255, blue: 192/255).opacity(0.08)
    )
    
    static let appPressed = Color(
        light: Color(red: 0/255, green: 0/255, blue: 0/255).opacity(0.08), 
        dark: Color(red: 186/255, green: 186/255, blue: 192/255).opacity(0.15)
    )
    
    static let appSelection = Color(
        light: Color(red: 88/255, green: 88/255, blue: 92/255).opacity(0.08),
        dark: Color(red: 186/255, green: 186/255, blue: 192/255).opacity(0.18)
    )
    
    static let appHighlight = Color(
        light: Color(red: 88/255, green: 88/255, blue: 92/255).opacity(0.1),
        dark: Color(red: 186/255, green: 186/255, blue: 192/255).opacity(0.12)
    )
    
    static let appGlow = Color(
        light: Color(red: 88/255, green: 88/255, blue: 92/255).opacity(0.15),
        dark: Color(red: 186/255, green: 186/255, blue: 192/255).opacity(0.06)
    )
    
    static let appSuccess = Color(
        light: Color(red: 52/255, green: 199/255, blue: 89/255),
        dark: Color(red: 48/255, green: 176/255, blue: 88/255)
    )
    
    static let appWarning = Color(
        light: Color(red: 255/255, green: 149/255, blue: 0/255),
        dark: Color(red: 255/255, green: 159/255, blue: 10/255)
    )
    
    static let appError = Color(
        light: Color(red: 255/255, green: 59/255, blue: 48/255),
        dark: Color(red: 255/255, green: 99/255, blue: 88/255)
    )
    
    static let appInfo = Color(
        light: Color(red: 88/255, green: 88/255, blue: 92/255),
        dark: Color(red: 160/255, green: 160/255, blue: 168/255)
    )
    
    static let appWindowBackground = Color(
        light: Color(red: 246/255, green: 246/255, blue: 246/255),
        dark: Color(red: 29/255, green: 29/255, blue: 32/255)
    )
    
    static let appBadgeGray = Color(
        light: Color(red: 88/255, green: 88/255, blue: 92/255).opacity(0.1),
        dark: Color(red: 186/255, green: 186/255, blue: 192/255).opacity(0.15)
    )
    
    static let appBadgePurple = Color(
        light: Color(red: 175/255, green: 82/255, blue: 222/255).opacity(0.1),
        dark: Color(red: 167/255, green: 139/255, blue: 250/255).opacity(0.15)
    )
    
    static let appBadgeGreen = Color(
        light: Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.1),
        dark: Color(red: 48/255, green: 176/255, blue: 88/255).opacity(0.15)
    )
    
    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusMedium: CGFloat = 10
    static let cornerRadiusLarge: CGFloat = 14
    static let cornerRadiusXLarge: CGFloat = 20
    
    static let spacingXSmall: CGFloat = 4
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 16
    static let spacingXLarge: CGFloat = 20
    static let spacingXXLarge: CGFloat = 32
}

extension Color {
    init(light: Color, dark: Color) {
        self = Color(NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        })
    }
}