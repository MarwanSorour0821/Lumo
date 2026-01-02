//
//  LumoApp.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Combine
import Supabase
import BackgroundTasks
import UserNotifications

// MARK: - App Delegate for Background Tasks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lumo.analyzeBloodTest", using: nil) { task in
            self.handleBackgroundAnalysis(task: task as! BGProcessingTask)
        }
        return true
    }
    
    func scheduleBackgroundAnalysisIfNeeded() {
        // Check if there are any pending processing items
        let hasPendingItems = AnalysisProcessingManager.shared.processingItems.contains { 
            !$0.isComplete && !$0.isCancelled && $0.error == nil 
        }
        
        if hasPendingItems {
            let request = BGProcessingTaskRequest(identifier: "com.lumo.analyzeBloodTest")
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("🔵 Background task scheduled")
            } catch {
                print("⚠️ Failed to schedule background task: \(error)")
            }
        }
    }
    
    private func handleBackgroundAnalysis(task: BGProcessingTask) {
        // Schedule a new background task in case we need more time
        scheduleBackgroundAnalysisIfNeeded()
        
        task.expirationHandler = {
            // Handle expiration - processing manager handles persistence
            print("⚠️ Background task expired")
        }
        
        // The processing manager automatically resumes pending items when initialized
        // Just mark the task as complete after a delay to allow processing to continue
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            task.setTaskCompleted(success: true)
        }
    }
}

@main
struct LumoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
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
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // App is going to background - schedule background task if needed
                appDelegate.scheduleBackgroundAnalysisIfNeeded()
            case .active:
                // App became active - processing manager will resume automatically
                print("🔵 App became active")
            case .inactive:
                break
            @unknown default:
                break
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
