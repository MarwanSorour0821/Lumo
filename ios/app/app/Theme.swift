//
//  Theme.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Combine

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var colorScheme: ColorScheme? = nil // nil = system, .dark = dark, .light = light
    
    private let colorSchemeKey = "app_color_scheme"
    
    private init() {
        loadColorScheme()
    }
    
    private func loadColorScheme() {
        if let saved = UserDefaults.standard.string(forKey: colorSchemeKey) {
            switch saved {
            case "dark":
                colorScheme = .dark
            case "light":
                colorScheme = .light
            default:
                colorScheme = nil // system
            }
        } else {
            colorScheme = nil // default to system
        }
    }
    
    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        if let scheme = scheme {
            UserDefaults.standard.set(scheme == .dark ? "dark" : "light", forKey: colorSchemeKey)
        } else {
            UserDefaults.standard.set("system", forKey: colorSchemeKey)
        }
    }
    
    var displayName: String {
        switch colorScheme {
        case .dark:
            return "Dark mode"
        case .light:
            return "Light mode"
        case .none:
            return "System"
        }
    }
}

// MARK: - Adaptive Colors
struct AppColors {
    // Primary brand color (same in both modes)
    static let primary = Color(hex: "#C7002B")
    static let primaryDark = Color(hex: "#8E0F20")
    static let primaryLight = Color(hex: "#D4283D")
    
    // Adaptive colors based on color scheme
    static func background(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.black : Color.white
    }
    
    static func surface(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#F5F5F5")
    }
    
    static func text(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.white : Color.black
    }
    
    static func textSecondary(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.gray : Color(hex: "#666666")
    }
    
    static func border(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
    }
    
    static func inputBackground(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    // For gradients
    static func gradientStart(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.black : Color(hex: "#F8F8F8")
    }
    
    static func gradientEnd(_ colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#E8E8E8")
    }
}

// MARK: - Environment Key for Theme
struct ThemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var appColorScheme: ColorScheme? {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Color Extension
extension Color {
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
