//
//  AppleSignInButton.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let onPress: () -> Void
    var loading: Bool = false
    var disabled: Bool = false
    var text: String = "Continue with Apple"
    
    // Determine if we're in light mode
    private var isLightMode: Bool {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .light
    }
    
    // Background color: black in light mode, white in dark mode
    private var backgroundColor: Color {
        isLightMode ? Color.black : Color.white
    }
    
    // Text/icon color: white in light mode, black in dark mode
    private var foregroundColor: Color {
        isLightMode ? Color.white : Color.black
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onPress()
        }) {
            if loading {
                CustomSpinner(size: 20, lineWidth: 2.5)
                    .frame(height: 20)
            } else {
                HStack(spacing: 12) {
                    AppleIcon(color: foregroundColor)
                    Text(text)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(foregroundColor)
                }
            }
        }
        .disabled(disabled || loading)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(backgroundColor)
        .cornerRadius(28)
        .opacity((disabled || loading) ? 0.6 : 1.0)
    }
}

// MARK: - Apple Icon
struct AppleIcon: View {
    var color: Color = .black
    
    var body: some View {
        // Use SF Symbol for Apple logo - clean and reliable
        Image(systemName: "apple.logo")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(color)
    }
}

#Preview {
    VStack(spacing: 16) {
        AppleSignInButton(onPress: {})
            .padding(.horizontal)
        
        AppleSignInButton(onPress: {}, loading: true)
            .padding(.horizontal)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
    .environmentObject(ThemeManager.shared)
}
