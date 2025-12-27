//
//  HomeView.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Supabase
import UIKit

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showAnalyseModal = false
    
    var body: some View {
        ZStack {
            TabView {
                HomeTabView()
                    .tabItem {
                        Label("Home", systemImage: "apple.homekit")
                    }
                
                HistoryTabView()
                    .tabItem {
                        Label("History", systemImage: "gauge.chart.lefthalf.righthalf")
                    }
                
                ChatTabView()
                    .tabItem {
                        Label("Chat", systemImage: "quote.bubble")
                    }
                
                SettingsTabView()
                    .tabItem {
                        Label("Me", systemImage: "brain.filled.head.profile")
                    }
            }
            .accentColor(AppColors.primary)
            .onAppear {
                // Customize tab bar appearance for even spacing
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                let bgColor = AppColors.background(themeManager.colorScheme)
                appearance.backgroundColor = UIColor(bgColor)
                
                // Configure normal state
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor.gray,
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                
                // Configure selected state
                let primaryColor = UIColor(red: 199/255.0, green: 0/255.0, blue: 43/255.0, alpha: 1.0) // #C7002B
                appearance.stackedLayoutAppearance.selected.iconColor = primaryColor
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: primaryColor,
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                
                // Apply to all tab bars
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
            
            // Floating Analyse Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showAnalyseModal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#C7002B"))
                                    .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 70) // Position above tab bar
                }
            }
        }
        .sheet(isPresented: $showAnalyseModal) {
            AnalyseModalView(isPresented: $showAnalyseModal)
        }
    }
}

// MARK: - Home Tab View
struct HomeTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var healthScore: Double = 0.0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var showInfoModal: Bool = false
    @State private var animatedProgress: Double = 0.0
    @State private var userName: String? = nil
    @State private var topBiomarkers: [HealthScoreService.BiomarkerAttention] = []
    @State private var hasAnalyses: Bool = false
    
    // Calculate progress from score (0-10 scale)
    private var progress: Double {
        min(max(healthScore / 10.0, 0.0), 1.0)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        AppColors.gradientStart(themeManager.colorScheme),
                        AppColors.gradientEnd(themeManager.colorScheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 40) {
                    
                    // Health Score Section
                    VStack(spacing: 12) {
                        // Circular progress indicator
                        ZStack {
                            // Background circle (light gray, partial - cut off at bottom)
                            Circle()
                                .trim(from: 0.125, to: 0.875) // C-shape: gap at bottom
                                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(90)) // Rotate so gap is at bottom
                            
                            // Progress fill (white, partial - cut off at bottom) - animated
                            Circle()
                                .trim(from: 0.125, to: 0.125 + (animatedProgress * 0.75)) // Fill based on animated progress
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(90)) // Rotate so gap is at bottom
                                .animation(.easeInOut(duration: 1.5), value: animatedProgress)
                            
                            // Center score display
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.text(themeManager.colorScheme)))
                            } else if let error = errorMessage {
                                VStack(spacing: 4) {
                                    Text("Error")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    Text(error)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                            } else {
                                VStack(spacing: 4) {
                                    Text(String(format: "%.1f", healthScore))
                                        .font(.system(size: 72, weight: .bold))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    // "your health score" with info button
                                    HStack(spacing: 6) {
                                        Text("your health score")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        
                                        Button(action: {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                            showInfoModal = true
                                        }) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: 300, height: 300)
                        
                        // Your Trends Button with Icon
                        HStack(spacing: 12) {
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                // TODO: Navigate to trends view
                            }) {
                                Text("Your trends")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(themeManager.colorScheme == .light ? .black : .white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .cornerRadius(25) // Pill shape
                            }
                            
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .padding(.top, -8) // Bring it closer to the health score
                    }
                    .padding(.top, 20)
                    
                    // Top Biomarkers Section
                    if hasAnalyses {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What Needs Attention")
                                .font(.custom("ProductSans-Bold", size: 24))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(.horizontal, 24)
                            
                            if !topBiomarkers.isEmpty {
                                ForEach(topBiomarkers) { biomarker in
                                    BiomarkerCard(biomarker: biomarker)
                                }
                            } else {
                                // All biomarkers are optimal
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.green)
                                    
                                    Text("All biomarkers are within optimal ranges")
                                        .font(.custom("ProductSans-Bold", size: 18))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("Great job! Your blood test results look healthy.")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Do nothing
                    }) {
                        if let name = userName {
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        } else {
                            Text("User")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                    }
                }
            }
        }
        .onAppear {
            loadUserProfile()
            loadHealthScore()
        }
        .onChange(of: healthScore) { newValue in
            // Animate progress when score changes
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedProgress = progress
            }
        }
        .sheet(isPresented: $showInfoModal) {
            HealthScoreInfoModal(isPresented: $showInfoModal)
        }
    }
    
    // MARK: - Load User Profile
    private func loadUserProfile() {
        Task {
            do {
                let userId = try await AuthService.shared.getCurrentUserId()
                print("🔵 Loading user profile for userId: \(userId)")
                
                // Get Supabase URL and auth token
                guard let supabaseURL = SupabaseManager.shared.getURL(),
                      let supabaseKey = SupabaseManager.shared.getAnonKey(),
                      let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(userId)&select=first_name,last_name") else {
                    print("❌ Supabase configuration missing")
                    return
                }
                
                print("🔵 Request URL: \(url.absoluteString)")
                
                // Get auth token from AuthService
                let accessToken = try await AuthService.shared.getAccessToken()
                
                // Make request to Supabase REST API
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/vnd.pgjson.object+json", forHTTPHeaderField: "Prefer")
                
                struct UserProfile: Codable {
                    let first_name: String?
                    let last_name: String?
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    return
                }
                
                print("🔵 Response status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ HTTP error: \(errorString)")
                    return
                }
                
                // Log raw response
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔵 Raw response: \(responseString)")
                }
                
                let decoder = JSONDecoder()
                
                // Try to decode as single object first, then as array
                var userProfile: UserProfile?
                
                if let singleProfile = try? decoder.decode(UserProfile.self, from: data) {
                    userProfile = singleProfile
                    print("✅ Decoded user profile as single object - first_name: \(singleProfile.first_name ?? "nil"), last_name: \(singleProfile.last_name ?? "nil")")
                } else if let array = try? decoder.decode([UserProfile].self, from: data) {
                    print("🔵 Decoded as array with \(array.count) items")
                    if let firstProfile = array.first {
                        userProfile = firstProfile
                        print("✅ Using first element - first_name: \(firstProfile.first_name ?? "nil"), last_name: \(firstProfile.last_name ?? "nil")")
                    } else {
                        print("⚠️ Array is empty")
                    }
                } else {
                    let dataString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    print("❌ Failed to decode user profile. Response: \(String(dataString.prefix(200)))")
                }
                
                await MainActor.run {
                    if let profile = userProfile {
                        if let firstName = profile.first_name, !firstName.isEmpty {
                            self.userName = firstName
                            print("✅ Set userName to: \(firstName)")
                        } else if let lastName = profile.last_name, !lastName.isEmpty {
                            self.userName = lastName
                            print("✅ Set userName to: \(lastName)")
                        } else {
                            print("⚠️ User profile has no first_name or last_name - both are nil or empty")
                        }
                    } else {
                        print("⚠️ User profile is nil after decoding attempt")
                    }
                }
            } catch {
                print("❌ Error loading user profile: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    print("❌ Decoding error: \(decodingError)")
                }
            }
        }
    }
    
    // MARK: - Load Health Score
    private func loadHealthScore() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // Get current user ID
                let userId = try await AuthService.shared.getCurrentUserId()
                print("🔵 Fetching analyses for user: \(userId)")
                
                // Fetch analyses
                let analyses = try await HealthScoreService.shared.fetchAnalyses(userId: userId)
                print("🔵 Fetched \(analyses.count) analyses")
                
                // Calculate score
                let score = HealthScoreService.shared.calculateHealthScore(analyses: analyses)
                print("🔵 Calculated health score: \(score)")
                
                // Get top biomarkers
                let biomarkers = HealthScoreService.shared.getTopBiomarkers(analyses: analyses, limit: 4)
                print("🔵 Found \(biomarkers.count) biomarkers needing attention")
                
                await MainActor.run {
                    self.healthScore = score
                    self.topBiomarkers = biomarkers
                    self.hasAnalyses = !analyses.isEmpty
                    self.isLoading = false
                    // Animate progress bar
                    withAnimation(.easeInOut(duration: 1.5)) {
                        self.animatedProgress = min(max(score / 10.0, 0.0), 1.0)
                    }
                    print("✅ Health score set to: \(score)")
                }
            } catch {
                print("❌ Error loading health score: \(error.localizedDescription)")
                await MainActor.run {
                    // Show user-friendly error or default to 0
                    if error.localizedDescription.contains("format") || error.localizedDescription.contains("decode") {
                        self.errorMessage = "Unable to parse health data"
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                    self.isLoading = false
                    // Default to 0 if no data
                    self.healthScore = 0.0
                }
            }
        }
    }
}

// MARK: - History Tab View
struct HistoryTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("History")
                    .font(.custom("ProductSans-Bold", size: 32))
                    .foregroundColor(.white)
                
                Text("Your test history")
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(Color(hex: "#808080"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Chat Tab View
struct ChatTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Chat")
                    .font(.custom("ProductSans-Bold", size: 32))
                    .foregroundColor(.white)
                
                Text("Get medical advice")
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(Color(hex: "#808080"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showEditInformation = false
    @State private var showNotificationSettings = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountFinalAlert = false
    @State private var isRefreshing = false
    @State private var hasActiveSubscription = false
    @State private var showAppearancePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Title with Gear Icon
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            Text("Settings")
                                .font(.custom("ProductSans-Bold", size: 32))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        
                        // Settings Items
                        VStack(spacing: 0) {
                            // Appearance
                            SettingsItem(
                                icon: "sun.max.fill",
                                text: "Appearance",
                                rightContent: {
                                    Text(themeManager.displayName)
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                },
                                onPress: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    showAppearancePicker = true
                                }
                            )
                            
                            // Notifications
                            SettingsItem(
                                icon: "bell.fill",
                                text: "Notifications",
                                onPress: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    showNotificationSettings = true
                                }
                            )
                            
                            // Edit Information
                            SettingsItem(
                                icon: "person.fill",
                                text: "Edit information",
                                onPress: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    showEditInformation = true
                                }
                            )
                            
                            // Upgrade to Pro / Manage Subscription
                            if !hasActiveSubscription {
                                SettingsItem(
                                    icon: "bolt.fill",
                                    text: "Upgrade to Pro",
                                    rightContent: {
                                        HStack(spacing: 8) {
                                            Text("PRO")
                                                .font(.custom("ProductSans-Bold", size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "#C7002B"))
                                                .cornerRadius(4)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        }
                                    },
                                    onPress: {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                        // TODO: Navigate to Paywall
                                    }
                                )
                            } else {
                                SettingsItem(
                                    icon: "bolt.fill",
                                    text: "Manage Subscription",
                                    rightContent: {
                                        HStack(spacing: 8) {
                                            Text("PRO")
                                                .font(.custom("ProductSans-Bold", size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "#C7002B"))
                                                .cornerRadius(4)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        }
                                    },
                                    onPress: {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                        // TODO: Open subscription management
                                    }
                                )
                            }
                            
                            // Sign Out
                            SettingsItem(
                                icon: "rectangle.portrait.and.arrow.forward",
                                text: "Sign out",
                                onPress: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    showSignOutAlert = true
                                }
                            )
                            
                            // Delete Account
                            SettingsItem(
                                icon: "trash.fill",
                                text: "Delete account",
                                onPress: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    showDeleteAccountAlert = true
                                }
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
                .refreshable {
                    await refreshSettings()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEditInformation) {
            EditInformationView(isPresented: $showEditInformation)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView(isPresented: $showNotificationSettings)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                handleSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteAccountFinalAlert = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data including analyses and chat history will be permanently deleted.")
        }
        .alert("Final Confirmation", isPresented: $showDeleteAccountFinalAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Delete My Account", role: .destructive) {
                handleDeleteAccount()
            }
        } message: {
            Text("This is your last chance. Your account and all data will be permanently deleted. Are you absolutely sure?")
        }
        .onAppear {
            Task {
                await refreshSettings()
            }
        }
        .confirmationDialog("Choose Appearance", isPresented: $showAppearancePicker, titleVisibility: .visible) {
            Button("Light Mode") {
                themeManager.setColorScheme(.light)
            }
            Button("Dark Mode") {
                themeManager.setColorScheme(.dark)
            }
            Button("System") {
                themeManager.setColorScheme(nil)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func refreshSettings() async {
        isRefreshing = true
        // TODO: Refresh subscription status
        // For now, just set to false
        hasActiveSubscription = false
        isRefreshing = false
    }
    
    private func handleSignOut() {
        Task {
            do {
                guard let client = SupabaseManager.shared.getClient() else {
                    await MainActor.run {
                        // Show error
                    }
                    return
                }
                
                try await client.auth.signOut()
                
                await MainActor.run {
                    // Update app state to reflect sign out
                    appState.isAuthenticated = false
                    print("✅ Signed out successfully")
                }
            } catch {
                await MainActor.run {
                    // Show error
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleDeleteAccount() {
        Task {
            do {
                // Step 1: Delete all user data from backend
                let userId = try await AuthService.shared.getCurrentUserId()
                guard let apiURLString = SupabaseManager.shared.getAPIURL(),
                      let apiURL = URL(string: "\(apiURLString)/api/analyses/delete-account/") else {
                    throw NSError(domain: "Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
                }
                
                let accessToken = try await AuthService.shared.getAccessToken()
                
                var request = URLRequest(url: apiURL)
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to delete account data"])
                }
                
                // Step 2: Sign out
                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "Settings", code: 3, userInfo: [NSLocalizedDescriptionKey: "Supabase client not configured"])
                }
                
                try await client.auth.signOut()
                
                await MainActor.run {
                    // Update app state to reflect account deletion
                    appState.isAuthenticated = false
                    print("Account deleted successfully")
                }
            } catch {
                await MainActor.run {
                    print("Error deleting account: \(error.localizedDescription)")
                    // Show error alert
                }
            }
        }
    }
}

// MARK: - Settings Item
struct SettingsItem<RightContent: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let text: String
    let rightContent: RightContent?
    let onPress: (() -> Void)?
    
    init(icon: String, text: String, @ViewBuilder rightContent: () -> RightContent = { EmptyView() }, onPress: (() -> Void)? = nil) {
        self.icon = icon
        self.text = text
        self.rightContent = rightContent()
        self.onPress = onPress
    }
    
    var body: some View {
        Button(action: {
            onPress?()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .frame(width: 24)
                
                Text(text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                
                Spacer()
                
                if rightContent is EmptyView {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                } else {
                    rightContent
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Analyse Modal View
struct AnalyseModalView: View {
    @Binding var isPresented: Bool
    @State private var selectedFile: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#333333"))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)
                
                Spacer()
                
                if selectedFile == nil {
                    // Upload Options
                    VStack(spacing: 16) {
                        Text("Add Post")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(.white)
                        
                        Text("Export post to upload here")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(Color(hex: "#808080"))
                        
                        HStack(spacing: 16) {
                            uploadOption(icon: "camera.fill", title: "Camera")
                            uploadOption(icon: "photo.fill", title: "Photo")
                            uploadOption(icon: "doc.fill", title: "File")
                        }
                        .padding(.top, 16)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#333333"), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Continue Button
                Button {
                    // Handle continue action
                } label: {
                    HStack {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(selectedFile == nil ? Color(hex: "#808080") : .white)
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(selectedFile == nil ? Color(hex: "#808080") : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedFile == nil ? Color(hex: "#333333") : Color(hex: "#C7002B"))
                    .cornerRadius(24)
                }
                .disabled(selectedFile == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "#1A1A1A"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func uploadOption(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "#1A1A1A"))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                )
            
            Text(title)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Health Score Info Modal
struct HealthScoreInfoModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How Your Health Score is Calculated")
                            .font(.custom("ProductSans-Bold", size: 28))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text("Your score reflects cardiovascular, metabolic, and inflammatory risk — weighted by long-term impact and recent trends.")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .padding(.top, 20)
                    
                    // Component 1: Core Risk Biomarkers
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("1. Core Risk Biomarkers")
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            Spacer()
                            Text("45%")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Text("Evaluates 12 key blood markers that predict long-term disease risk:")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            infoRow(marker: "Hemoglobin (Hb)", range: "13.0-17.0", weight: "15%")
                            infoRow(marker: "Total RBC count", range: "4.5-5.5", weight: "10%")
                            infoRow(marker: "Packed Cell Volume (PCV)", range: "40-50", weight: "10%")
                            infoRow(marker: "Total WBC count", range: "4000-11000", weight: "10%")
                            infoRow(marker: "Platelet Count", range: "150000-410000", weight: "10%")
                            infoRow(marker: "ESR", range: "0-15", weight: "5%")
                            infoRow(marker: "Neutrophils", range: "50-62%", weight: "8%")
                            infoRow(marker: "Lymphocytes", range: "20-40%", weight: "8%")
                            infoRow(marker: "MCH", range: "27-32", weight: "7%")
                            infoRow(marker: "MCHC", range: "32.5-34.5", weight: "7%")
                            infoRow(marker: "MCV", range: "83-101", weight: "5%")
                            infoRow(marker: "RDW", range: "11.6-14.0", weight: "5%")
                        }
                        .padding(.leading, 16)
                        
                        Text("• Normal values = 1.0 point\n• Abnormal values = 0.5-1.0 based on distance from optimal")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(16)
                    
                    // Component 2: Optimal vs Normal
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("2. Optimal vs Normal Ranges")
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(.white)
                            Spacer()
                            Text("17.5%")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(Color(hex: "#C7002B"))
                        }
                        
                        Text("Rewards markers in optimal ranges, not just \"normal\":")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("•")
                                    .foregroundColor(.green)
                                Text("Normal status = 1.0 point")
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text("•")
                                    .foregroundColor(.orange)
                                Text("Low/High status = 0.5 points")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.leading, 16)
                    }
                    .padding()
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(16)
                    
                    // Component 3: Data Completeness
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("3. Data Completeness")
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(.white)
                            Spacer()
                            Text("5%")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(Color(hex: "#C7002B"))
                        }
                        
                        Text("Measures how complete your blood test is:")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Score = (Markers Found / 15 Expected) × 100%")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(.gray)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(16)
                    
                    // Final Calculation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Final Score Calculation")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Final = (Core Risk × 0.45) + (Optimal Range × 0.175) + (Completeness × 0.05)")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Display Score = Final × 10 (clamped to 0-10)")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 16)
                    }
                    .padding()
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(16)
                    
                    // Multiple Analyses Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Multiple Blood Tests")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(.white)
                        
                        Text("If you have multiple blood tests, we calculate a score for each and then average them to get your overall health score.")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(16)
                    
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func infoRow(marker: String, range: String, weight: String) -> some View {
        HStack {
            Text("• \(marker)")
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
            Spacer()
            Text(range)
                .font(.custom("ProductSans-Regular", size: 12))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            Text(weight)
                .font(.custom("ProductSans-Bold", size: 12))
                .foregroundColor(AppColors.primary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Biomarker Card
struct BiomarkerCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let biomarker: HealthScoreService.BiomarkerAttention
    
    var body: some View {
        HStack(alignment: .top) {
            // Left side: Name and reason
            VStack(alignment: .leading, spacing: 4) {
                Text(biomarker.name)
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .frame(height: 22) // Match the height of the right side elements
                
                Text(biomarker.reason)
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right side: Arrow icon and status tag (vertically aligned with name)
            HStack(alignment: .center, spacing: 8) {
                // Trend icon (on the left of the tag) - colored to match tag
                if biomarker.trend != "→" {
                    Image(systemName: trendIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(statusColor)
                        .frame(width: 20, height: 20)
                }
                
                // Status badge with color (right-aligned)
                Text(biomarker.status)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(8)
            }
            .frame(height: 22) // Match the height of the name text
        }
        .padding(16)
        .background(AppColors.surface(themeManager.colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    private var trendIcon: String {
        switch biomarker.trend {
        case "↑":
            return "arrow.up.forward.circle.dotted"
        case "↓":
            return "arrow.down.right.circle.dotted"
        default:
            return ""
        }
    }
    
    private var statusColor: Color {
        switch biomarker.status {
        case "Optimal":
            return .green
        case "Borderline":
            return .orange
        case "Elevated":
            return .red
        default:
            return .gray
        }
    }
    
    private var trendColor: Color {
        switch biomarker.trend {
        case "↑":
            return .red
        case "↓":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Edit Information View
struct EditInformationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = true
    @State private var isSavingProfile: Bool = false
    @State private var isSavingPassword: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Title
                        Text("Edit Information")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        
                        // Profile Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Profile")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            VStack(spacing: 16) {
                                CustomTextField(
                                    label: "First name",
                                    text: $firstName,
                                    placeholder: "First name"
                                )
                                
                                CustomTextField(
                                    label: "Last name",
                                    text: $lastName,
                                    placeholder: "Last name"
                                )
                                
                                CustomTextField(
                                    label: "Email",
                                    text: $email,
                                    placeholder: "you@example.com",
                                    keyboardType: .emailAddress
                                )
                            }
                            
                            Button(action: handleSaveProfile) {
                                Text(isSavingProfile ? "Saving..." : "Save profile")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColors.primary)
                                    .cornerRadius(12)
                            }
                            .disabled(isSavingProfile || isLoading)
                        }
                        .padding(24)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        
                        // Password Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Password")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            VStack(spacing: 16) {
                                CustomTextField(
                                    label: "New password",
                                    text: $newPassword,
                                    placeholder: "Enter new password",
                                    isSecure: true
                                )
                                
                                CustomTextField(
                                    label: "Confirm new password",
                                    text: $confirmPassword,
                                    placeholder: "Confirm new password",
                                    isSecure: true
                                )
                            }
                            
                            Button(action: handleChangePassword) {
                                Text(isSavingPassword ? "Updating..." : "Change password")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppColors.primary)
                                    .cornerRadius(12)
                            }
                            .disabled(isSavingPassword)
                        }
                        .padding(24)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Edit Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        Task {
            isLoading = true
            do {
                let userId = try await AuthService.shared.getCurrentUserId()
                print("🔵 Loading profile for user: \(userId)")
                
                // Fetch user profile from Supabase REST API (same pattern as React)
                guard let supabaseURL = SupabaseManager.shared.getURL(),
                      let supabaseKey = SupabaseManager.shared.getAnonKey(),
                      let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(userId)&select=first_name,last_name,email") else {
                    print("❌ Failed to create URL")
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                print("🔵 Request URL: \(url.absoluteString)")
                
                let accessToken = try await AuthService.shared.getAccessToken()
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/vnd.pgjson.object+json", forHTTPHeaderField: "Prefer")
                
                struct UserProfile: Codable {
                    let first_name: String?
                    let last_name: String?
                    let email: String?
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                print("🔵 Response status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ HTTP error: \(errorString)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                // Try to decode as single object first, then as array
                let decoder = JSONDecoder()
                var profile: UserProfile?
                
                // Try single object
                if let singleProfile = try? decoder.decode(UserProfile.self, from: data) {
                    profile = singleProfile
                    print("✅ Decoded as single object")
                } else if let array = try? decoder.decode([UserProfile].self, from: data),
                          let firstProfile = array.first {
                    profile = firstProfile
                    print("✅ Decoded as array, using first element")
                } else {
                    let dataString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    print("❌ Failed to decode profile. Response: \(dataString)")
                    // Try to get email from session as fallback
                    if let client = SupabaseManager.shared.getClient() {
                        let session = try await client.auth.session
                        await MainActor.run {
                            self.email = session.user.email ?? ""
                            self.isLoading = false
                        }
                        return
                    }
                }
                
                guard let userProfile = profile else {
                    print("❌ Profile is nil")
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                print("✅ Profile loaded - firstName: \(userProfile.first_name ?? "nil"), lastName: \(userProfile.last_name ?? "nil"), email: \(userProfile.email ?? "nil")")
                
                await MainActor.run {
                    self.firstName = userProfile.first_name ?? ""
                    self.lastName = userProfile.last_name ?? ""
                    // If email is not in profile, try to get it from session
                    if let email = userProfile.email, !email.isEmpty {
                        self.email = email
                    } else {
                        // Get email from auth session as fallback
                        Task {
                            do {
                                if let client = SupabaseManager.shared.getClient() {
                                    let session = try await client.auth.session
                                    await MainActor.run {
                                        self.email = session.user.email ?? ""
                                    }
                                }
                            } catch {
                                print("⚠️ Could not get email from session: \(error.localizedDescription)")
                            }
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("❌ Error loading profile: \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        print("❌ Decoding error details: \(decodingError)")
                    }
                }
            }
        }
    }
    
    private func handleSaveProfile() {
        Task {
            isSavingProfile = true
            do {
                let userId = try await AuthService.shared.getCurrentUserId()
                
                // Update user profile in Supabase (same pattern as React)
                guard let supabaseURL = SupabaseManager.shared.getURL(),
                      let supabaseKey = SupabaseManager.shared.getAnonKey(),
                      let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(userId)") else {
                    await MainActor.run {
                        isSavingProfile = false
                    }
                    return
                }
                
                let accessToken = try await AuthService.shared.getAccessToken()
                
                // Step 1: Update profile in users table
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/vnd.pgjson.object+json", forHTTPHeaderField: "Prefer")
                
                let updateData: [String: Any] = [
                    "first_name": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "last_name": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "EditInformation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to update profile"])
                }
                
                // Step 2: Update email in auth if email changed (same as React)
                if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    guard let authURL = URL(string: "\(supabaseURL)/auth/v1/user") else {
                        throw NSError(domain: "EditInformation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid auth URL"])
                    }
                    
                    var authRequest = URLRequest(url: authURL)
                    authRequest.httpMethod = "PUT"
                    authRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    authRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let authUpdateData: [String: Any] = [
                        "email": email.trimmingCharacters(in: .whitespacesAndNewlines)
                    ]
                    
                    authRequest.httpBody = try JSONSerialization.data(withJSONObject: authUpdateData)
                    
                    let (_, authResponse) = try await URLSession.shared.data(for: authRequest)
                    
                    if let authHttpResponse = authResponse as? HTTPURLResponse,
                       !(200...299).contains(authHttpResponse.statusCode) {
                        // Email update failed, but profile update succeeded
                        print("Warning: Profile updated but email update failed")
                    }
                }
                
                await MainActor.run {
                    isSavingProfile = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSavingPassword = false
                    print("Error saving profile: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleChangePassword() {
        guard newPassword == confirmPassword else {
            // Show error - passwords don't match
            return
        }
        
        guard newPassword.count >= 6 else {
            // Show error - password too short
            return
        }
        
        Task {
            isSavingPassword = true
            do {
                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "EditInformation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not configured"])
                }
                
                // Update password using Supabase auth API (same pattern as React)
                guard let supabaseURL = SupabaseManager.shared.getURL(),
                      let url = URL(string: "\(supabaseURL)/auth/v1/user") else {
                    throw NSError(domain: "EditInformation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                
                let accessToken = try await AuthService.shared.getAccessToken()
                
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let updateData: [String: Any] = [
                    "password": newPassword
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let errorData = try? JSONSerialization.jsonObject(with: Data(), options: []) as? [String: Any]
                    let errorMessage = errorData?["error"] as? String ?? "Failed to update password"
                    throw NSError(domain: "EditInformation", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                
                await MainActor.run {
                    isSavingPassword = false
                    newPassword = ""
                    confirmPassword = ""
                    // Show success
                }
            } catch {
                await MainActor.run {
                    isSavingPassword = false
                    print("Error changing password: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var notificationsEnabled: Bool = false
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text("Notifications")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        
                        Text("Manage your notification preferences")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                        
                        // Settings Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Notifications")
                                        .font(.custom("ProductSans-Bold", size: 16))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("Receive push notifications for important updates")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $notificationsEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                                    .disabled(isLoading)
                            }
                        }
                        .padding(24)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .onChange(of: notificationsEnabled) { newValue in
                handleToggleNotifications(enabled: newValue)
            }
        }
    }
    
    private func handleToggleNotifications(enabled: Bool) {
        // TODO: Implement notification permission request and storage
        isLoading = true
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
            
            Rectangle()
                .fill(AppColors.border(themeManager.colorScheme))
                .frame(height: 1)
        }
    }
}

#Preview {
    HomeView()
}
