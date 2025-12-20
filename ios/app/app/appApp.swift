//
//  LumoApp.swift
//  app
//
//  Created on iOS
//

import SwiftUI

@main
struct LumoApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .onOpenURL { url in
                    // Log when the app receives a deep link
                    print("🔵 App received deep link: \(url.absoluteString)")
                    // OAuth callback URL is handled by ASWebAuthenticationSession
                    // This is just for debugging
                }
        }
    }
}
