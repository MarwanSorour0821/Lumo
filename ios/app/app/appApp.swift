//
//  LumoApp.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Combine
import Supabase

@main
struct LumoApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onOpenURL { url in
                    // Log when the app receives a deep link
                    print("🔵 App received deep link: \(url.absoluteString)")
                    // OAuth callback URL is handled by ASWebAuthenticationSession
                    // This is just for debugging
                }
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    
    init() {
        checkAuthentication()
    }
    
    func checkAuthentication() {
        Task {
            isLoading = true
            do {
                // Check if there's an existing session
                guard let client = SupabaseManager.shared.getClient() else {
                    await MainActor.run {
                        self.isAuthenticated = false
                        self.isLoading = false
                    }
                    return
                }
                
                // Try to get the current session
                let session = try? await client.auth.session
                
                let hasSession = (session != nil)
                
                await MainActor.run {
                    self.isAuthenticated = hasSession
                    self.isLoading = false
                    print("🔵 Authentication check: \(self.isAuthenticated ? "Authenticated" : "Not authenticated")")
                }
                
                // Load user data if authenticated
                if hasSession {
                    await UserDataViewModel.shared.loadAllUserData()
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.isLoading = false
                    print("⚠️ Error checking authentication: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                guard let client = SupabaseManager.shared.getClient() else { return }
                try await client.auth.signOut()
                await MainActor.run {
                    // Clear all user data
                    UserDataViewModel.shared.clearAllData()
                    self.isAuthenticated = false
                }
            } catch {
                print("⚠️ Error signing out: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .environmentObject(ThemeManager.shared)
                    .transition(.opacity)
            } else {
                if appState.isLoading {
                    // Still checking authentication
                    AppColors.background(ThemeManager.shared.colorScheme)
                        .ignoresSafeArea()
                } else if appState.isAuthenticated {
                    // User is authenticated, show home
                    HomeView()
                        .environmentObject(appState)
                        .environmentObject(ThemeManager.shared)
                        .transition(.opacity)
                } else {
                    // User is not authenticated, show onboarding
                    OnboardingView()
                        .environmentObject(appState)
                        .environmentObject(ThemeManager.shared)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Show splash for 1.5 seconds, then check authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}
