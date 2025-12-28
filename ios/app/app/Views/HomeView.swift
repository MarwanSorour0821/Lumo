//
//  HomeView.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Supabase
import UIKit
import UniformTypeIdentifiers
import WebKit

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showAnalyseModal = false
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeTabView()
                    .tag(0)
                    .tabItem {
                        Label("Home", systemImage: "apple.homekit")
                    }
                
                HistoryTabView()
                    .tag(1)
                    .tabItem {
                        Label("History", systemImage: "gauge.chart.lefthalf.righthalf")
                    }
                
                ChatTabView()
                    .tag(2)
                    .tabItem {
                        Label("Chat", systemImage: "quote.bubble")
                    }
                
                SettingsTabView()
                    .tag(3)
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
            
            // Floating Analyse Button (hidden on Chat tab)
            if selectedTab != 2 {
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
                            
                            // Progress fill (adaptive color, partial - cut off at bottom) - animated
                            Circle()
                                .trim(from: 0.125, to: 0.125 + (animatedProgress * 0.75)) // Fill based on animated progress
                                .stroke(themeManager.colorScheme == .light ? Color.black : Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
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
                                    .foregroundColor(themeManager.colorScheme == .light ? .white : .black)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(themeManager.colorScheme == .light ? Color.black : Color.white)
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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var analyses: [Analysis] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var selectedAnalysis: Analysis? = nil
    @State private var showDetail: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.yellow)
                        Text("Failed to load analyses")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Text(error)
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else if analyses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        Text("No analyses yet")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Text("Upload a lab report to see your history")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(analyses, id: \ .id) { analysis in
                                Button(action: {
                                    selectedAnalysis = analysis
                                    showDetail = true
                                }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(listTitle(for: analysis))
                                                .font(.custom("ProductSans-Bold", size: 16))
                                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                                            Text(listSubtitle(for: analysis))
                                                .font(.custom("ProductSans-Regular", size: 14))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 6) {
                                            Text(formattedDate(analysis.created_at))
                                                .font(.custom("ProductSans-Regular", size: 12))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        }
                                    }
                                    .padding(12)
                                    .background(AppColors.surface(themeManager.colorScheme))
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.03 : 0.0), radius: 1, x: 0, y: 1)
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await loadAnalyses()
                    }
                }
            }
            .navigationBarTitle("History", displayMode: .inline)
            .onAppear {
                Task { await loadAnalyses() }
            }
            .sheet(isPresented: $showDetail) {
                if let analysis = selectedAnalysis {
                    AnalysisDetailView(analysis: analysis)
                        .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Helpers
    private func loadAnalyses() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let uid = try await AuthService.shared.getCurrentUserId()
            let fetched = try await HealthScoreService.shared.fetchAnalyses(userId: uid)
            await MainActor.run {
                self.analyses = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: date)
        }
        return iso
    }

    private func listTitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData(), let name = parsed.patientInfo?.name, !name.isEmpty {
            return name
        }
        // fallback to ID short
        return "Analysis \(analysis.id.prefix(8))"
    }

    private func listSubtitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData() {
            let count = parsed.testResults.count
            return "\(count) markers · Report"
        }
        return "Lab report"
    }
}

// MARK: - Analysis Detail View
struct AnalysisDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let analysis: Analysis

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Report")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Spacer()
                        Text(formattedDate(analysis.created_at))
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }

                    if let parsed = analysis.getParsedData() {
                        if let patient = parsed.patientInfo {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Patient")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                if let name = patient.name { Text(name).foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                                if let age = patient.age { Text("Age: \(age)").foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                                if let sex = patient.sex { Text("Sex: \(sex)").foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                            }
                            .padding()
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            ForEach(parsed.testResults, id: \ .marker) { result in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.marker)
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        Text(result.referenceRange)
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text(result.value + " " + result.unit)
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(AppColors.primary)
                                        Text(result.status)
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }
                                }
                                .padding(12)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(10)
                            }
                        }
                    } else {
                        Text("Unable to parse report details")
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { }
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .background(AppColors.background(themeManager.colorScheme).ignoresSafeArea())
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: date)
        }
        return iso
    }
}

// MARK: - Chat Tab View
struct ChatTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var messages: [ChatMessageDTO] = []
    @State private var messageText: String = ""
    @State private var userId: String? = nil
    @State private var userName: String? = nil
    @State private var isInitialLoading: Bool = true
    @State private var isTyping: Bool = false
    @State private var isUploading: Bool = false
    @State private var selectedImage: UIImage? = nil
    @State private var selectedDocumentURL: URL? = nil
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showAttachmentActionSheet: Bool = false
    @State private var scrollProxyId = UUID()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    HStack {
                        Spacer()
                    }
                    Text("Chat")
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(AppColors.background(themeManager.colorScheme))

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if isInitialLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                    .padding(.top, 40)
                            } else if messages.isEmpty {
                                VStack(spacing: 8) {
                                    Text("Hello \(userName ?? "")")
                                        .font(.custom("ProductSans-Bold", size: 28))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    Text("How may I assist you?")
                                        .font(.custom("ProductSans-Regular", size: 16))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .padding(.top, 40)
                            } else {
                                ForEach(messages) { msg in
                                    MessageRow(message: msg)
                                        .id(msg.id)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                if isTyping {
                                    TypingIndicatorView()
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8, blendDuration: 0), value: messages.count)
                        .onChange(of: messages.count) { _ in
                            // Scroll to bottom when new messages arrive
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                                if let last = messages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            })
                        }
                    }
                }

                // Selected file preview
                if let image = selectedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)

                        Text("Image ready to send")
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                        Button(action: {
                            selectedImage = nil
                        }) {
                            Text("×")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface(themeManager.colorScheme))
                } else if let doc = selectedDocumentURL {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 40, height: 40)

                        Text(doc.lastPathComponent)
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineLimit(1)

                        Spacer()

                        Button(action: {
                            selectedDocumentURL = nil
                        }) {
                            Text("×")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface(themeManager.colorScheme))
                }

                // Input bar
                HStack(spacing: 12) {
                    // Attachment button: circular and same height as input
                    Button(action: {
                        showAttachmentActionSheet = true
                    }) {
                        Image(systemName: "paperclip.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .actionSheet(isPresented: $showAttachmentActionSheet) {
                        ActionSheet(title: Text("Add attachment"), buttons: [
                            .default(Text("Photo")) { showImagePicker = true },
                            .default(Text("File (PDF)")) { showDocumentPicker = true },
                            .cancel()
                        ])
                    }

                    // Rounded input (pill shaped)
                    TextField("Ask anything", text: $messageText, onCommit: sendMessage)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .clipShape(Capsule())
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .overlay(
                            // optional placeholder color alignment
                            EmptyView()
                        )
                        .frame(maxWidth: .infinity)

                    // Send button: same height as input
                    Button(action: sendMessage) {
                        if isUploading || isTyping {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                .frame(width: 24, height: 24)
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                        }
                    }
                    .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil && selectedDocumentURL == nil) || isUploading || isTyping)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.background(themeManager.colorScheme))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let img = image {
                        self.selectedImage = img
                    }
                    showImagePicker = false
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    if let u = url {
                        self.selectedDocumentURL = u
                    }
                    showDocumentPicker = false
                }
            }
            .onAppear {
                Task {
                    await initializeChat()
                }
            }
        }
    }

    // MARK: - Actions
    private func initializeChat() async {
        isInitialLoading = true
        do {
            let uid = try await AuthService.shared.getCurrentUserId()
            userId = uid

            // Load user name
            if let client = SupabaseManager.shared.getClient() {
                do {
                    let session = try await client.auth.session
                    userName = session.user.email?.components(separatedBy: "@").first?.capitalized
                } catch {
                    userName = "User"
                }
            }

            // Load history
            let history = try await ChatService.shared.getChatHistory(userId: uid)
            await MainActor.run {
                self.messages = history
                self.isInitialLoading = false
            }
        } catch {
            print("Error initializing chat: \(error)")
            await MainActor.run { self.isInitialLoading = false }
        }
    }

    private func sendMessage() {
        Task {
            guard let uid = userId else { return }
            let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Prepare optimistic local user message
            let tempId = Int(Date().timeIntervalSince1970 * 1000)
            var tempContent = userMessage
            var messageType = "text"
            var fileName: String? = nil

            if let img = selectedImage {
                messageType = "image"
                fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                tempContent = "[Shared an image: \(fileName!)] \(userMessage)"
            } else if let doc = selectedDocumentURL {
                messageType = "pdf"
                fileName = doc.lastPathComponent
                tempContent = "[Shared a PDF: \(fileName!)] \(userMessage)"
            }

            let tempMsg = ChatMessageDTO(id: tempId, role: "user", content: tempContent, message_type: messageType, file_name: fileName, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))

            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    self.messages.append(tempMsg)
                }
                self.messageText = ""
                self.isUploading = (self.selectedImage != nil || self.selectedDocumentURL != nil)
                self.isTyping = true
            }

            do {
                if let img = selectedImage {
                    // write image to temp file
                    let data = img.jpegData(compressionQuality: 0.8) ?? Data()
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName ?? "upload.jpg")
                    try data.write(to: tmpURL)

                    let result = try await ChatService.shared.sendChatFile(userId: uid, fileUrl: tmpURL, fileName: fileName ?? "image.jpg", mimeType: "image/jpeg", message: userMessage.isEmpty ? nil : userMessage)

                    if let assistant = result.response {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: assistant, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                self.messages.append(assistantMsg)
                            }
                        }
                    }
                } else if let doc = selectedDocumentURL {
                    let mime = "application/pdf"
                    let result = try await ChatService.shared.sendChatFile(userId: uid, fileUrl: doc, fileName: doc.lastPathComponent, mimeType: mime, message: userMessage.isEmpty ? nil : userMessage)
                    if let assistant = result.response {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: assistant, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                self.messages.append(assistantMsg)
                            }
                        }
                    }
                } else {
                    // text message
                    let response = try await ChatService.shared.sendChatMessage(userId: uid, message: userMessage)
                    if !response.isEmpty {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: response, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                self.messages.append(assistantMsg)
                            }
                        }
                    }
                }
            } catch {
                print("Error sending message: \(error)")
                // Optionally show error UI
            }

            await MainActor.run {
                self.selectedImage = nil
                self.selectedDocumentURL = nil
                self.isUploading = false
                self.isTyping = false
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func MessageRow(message: ChatMessageDTO) -> some View {
        HStack {
            if message.role == "assistant" {
                // assistant flush left
                VStack(alignment: .leading, spacing: 6) {
                    if message.message_type != "text", let name = message.file_name {
                        HStack(spacing: 8) {
                            Image(systemName: message.message_type == "image" ? "photo" : "doc.richtext")
                                .foregroundColor(AppColors.primary)
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        .padding(10)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(12)
                        .transition(.scale)
                    }

                    if !message.content.isEmpty {
                        if isLaTeX(message.content) {
                            LaTeXView(latex: message.content)
                                .frame(minHeight: 40)
                                .padding(8)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(12)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        } else {
                            Text(message.content)
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(12)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 80)

                Spacer(minLength: 8)
            } else {
                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if message.message_type != "text", let name = message.file_name {
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(Color.white)
                            Image(systemName: message.message_type == "image" ? "photo" : "doc.richtext")
                                .foregroundColor(Color.white.opacity(0.9))
                        }
                        .padding(10)
                        .background(AppColors.primary.opacity(0.95))
                        .cornerRadius(12)
                        .transition(.scale)
                    }

                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(Color.white)
                            .padding(12)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.leading, 80)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: UUID())
    }

    private func TypingIndicatorView() -> some View {
        HStack {
            if true { Spacer() }
            HStack(spacing: 6) {
                Circle().frame(width: 8, height: 8).foregroundColor(AppColors.textSecondary(themeManager.colorScheme)).opacity(0.6)
                Circle().frame(width: 8, height: 8).foregroundColor(AppColors.textSecondary(themeManager.colorScheme)).opacity(0.4)
                Circle().frame(width: 8, height: 8).foregroundColor(AppColors.textSecondary(themeManager.colorScheme)).opacity(0.6)
            }
            .padding(10)
            .background(AppColors.surface(themeManager.colorScheme))
            .cornerRadius(16)
            if true { Spacer() }
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType { case camera, photoLibrary }
    var sourceType: SourceType = .photoLibrary
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = (sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera)) ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.completion(image)
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker Wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.completion(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.completion(nil)
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
                            SettingsItem(icon: "sun.max.fill", text: "Appearance") {
                                showAppearancePicker = true
                            }

                            SettingsItem(icon: "bell.fill", text: "Notifications") {
                                showNotificationSettings = true
                            }

                            SettingsItem(icon: "person.fill", text: "Edit information") {
                                showEditInformation = true
                            }

                            if !hasActiveSubscription {
                                SettingsItem(icon: "star.fill", text: "Upgrade to Pro") {
                                    // Placeholder action - integrate purchase flow
                                }
                            } else {
                                SettingsItem(icon: "creditcard.fill", text: "Manage Subscription") {
                                    // Placeholder for subscription management
                                }
                            }

                            SettingsItem(icon: "arrow.right.square.fill", text: "Sign Out") {
                                showSignOutAlert = true
                            }

                            SettingsItem(icon: "trash.fill", text: "Delete Account") {
                                showDeleteAccountAlert = true
                            }
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
            Task { await refreshSettings() }
        }
        .confirmationDialog("Choose Appearance", isPresented: $showAppearancePicker, titleVisibility: .visible) {
            Button("Light Mode") { themeManager.setColorScheme(.light) }
            Button("Dark Mode") { themeManager.setColorScheme(.dark) }
            Button("System") { themeManager.setColorScheme(nil) }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func refreshSettings() async {
        isRefreshing = true
        // TODO: Refresh subscription status
        hasActiveSubscription = false
        isRefreshing = false
    }

    private func handleSignOut() {
        Task {
            do {
                guard let client = SupabaseManager.shared.getClient() else { return }
                try await client.auth.signOut()
                await MainActor.run { appState.isAuthenticated = false }
            } catch {
                await MainActor.run { print("Error signing out: \(error.localizedDescription)") }
            }
        }
    }

    private func handleDeleteAccount() {
        Task {
            do {
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

                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "Settings", code: 3, userInfo: [NSLocalizedDescriptionKey: "Supabase client not configured"])
                }

                try await client.auth.signOut()

                await MainActor.run {
                    appState.isAuthenticated = false
                    print("Account deleted successfully")
                }
            } catch {
                await MainActor.run { print("Error deleting account: \(error.localizedDescription)") }
            }
        }
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

                Spacer()

                if selectedFile == nil {
                    VStack(spacing: 12) {
                        Text("Upload a file to analyse")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
                            uploadOption(icon: "photo", title: "Photo")
                            uploadOption(icon: "doc.fill", title: "PDF")
                        }
                    }
                } else {
                    Text("Selected: \(selectedFile ?? "")")
                        .foregroundColor(.white)
                }

                Spacer()

                Button {
                    // Handle continue action
                    isPresented = false
                } label: {
                    Text("Continue")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(selectedFile == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "#1A1A1A"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Close")
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
                        .font(.system(size: 24))
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("What is the health score")
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    infoRow(marker: "Cholesterol", range: "0 - 200 mg/dL", weight: "High")
                    infoRow(marker: "Blood Sugar", range: "70 - 99 mg/dL", weight: "Medium")
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) { Text("Close") }
                }
            }
        }
    }

    private func infoRow(marker: String, range: String, weight: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(marker).font(.custom("ProductSans-Bold", size: 16))
                Text(range).font(.custom("ProductSans-Regular", size: 14)).foregroundColor(.gray)
            }
            Spacer()
            Text(weight).font(.custom("ProductSans-Regular", size: 14))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Biomarker Card
struct BiomarkerCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let biomarker: HealthScoreService.BiomarkerAttention

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(biomarker.name)
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                // Show concise reason and status instead of non-existent `detail` property
                Text(biomarker.reason)
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .lineLimit(2)

                Text(biomarker.status)
                    .font(.custom("ProductSans-Bold", size: 12))
                    .foregroundColor(AppColors.primary)
            }
            Spacer()
        }
        .padding()
        .background(AppColors.surface(themeManager.colorScheme))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
}

// New: SettingsItem used by the Settings tab
struct SettingsItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 28)

                Text(text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .padding(12)
            .background(AppColors.surface(themeManager.colorScheme))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 6)
    }
}

// MARK: - Edit Information View
struct EditInformationView: View {
    @Binding var isPresented: Bool
    @State private var firstName: String = ""
    @State private var lastName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }

                Section {
                    Button("Save") {
                        // Save action - hook into profile API
                        isPresented = false
                    }
                }
            }
            .navigationBarTitle("Edit Information", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
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
            
            if (isSecure) {
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

// MARK: - LaTeX Renderer
struct LaTeXView: UIViewRepresentable {
    let latex: String
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Sanitize content minimally for HTML embedding
        let safeContent = latex
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "</", with: "&lt;/")

        // Use a unique placeholder token to avoid Swift string interpolation issues
        let placeholder = "@@LATEX@@"

        // Build a simple MathJax page and embed the sanitized LaTeX by replacing the placeholder
        let wrapped = """
        <!doctype html>
        <html>
        <head>
          <meta name='viewport' content='width=device-width, initial-scale=1'>
          <style>body{font-family:-apple-system; background:transparent; color:#000; margin:0; padding:6px 8px;}</style>
          <script>window.MathJax = { tex: {inlineMath: [['$$','$$'], ['\\(','\\)']]}, svg: { fontCache: 'global' } };</script>
          <script src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js'></script>
        </head>
        <body>
          <div>$$@@LATEX@@$$</div>
        </body>
        </html>
        """.replacingOccurrences(of: placeholder, with: safeContent)

        webView.loadHTMLString(wrapped, baseURL: nil)
    }
}

// Helper to detect LaTeX-like content
private func isLaTeX(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains("$$") { return true }
    if trimmed.contains("\\begin{") { return true }
    if trimmed.contains("\\(") || trimmed.contains("\\[") { return true }
    // simple heuristic: many backslashes indicate LaTeX
    let backslashCount = trimmed.filter { $0 == "\\" }.count
    if backslashCount >= 3 { return true }
    return false
}

#Preview {
    HomeView()
}
