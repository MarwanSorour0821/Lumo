//
//  UserDataViewModel.swift
//  app
//
//  Centralized user data management
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
class UserDataViewModel: ObservableObject {
    @Published var userName: String? = nil
    @Published var healthScore: Double = 0.0
    @Published var animatedProgress: Double = 0.0
    @Published var topBiomarkers: [HealthScoreService.BiomarkerAttention] = []
    @Published var hasAnalyses: Bool = false
    @Published var analyses: [Analysis] = []
    @Published var chatMessages: [ChatMessageDTO] = []
    @Published var isLoadingProfile: Bool = false
    @Published var isLoadingHealthScore: Bool = false
    @Published var isLoadingAnalyses: Bool = false
    @Published var isLoadingChat: Bool = false
    @Published var healthScoreError: String? = nil
    @Published var analysesError: String? = nil
    
    private var currentUserId: String? = nil
    private var hasLoadedProfile: Bool = false
    private var hasLoadedHealthScore: Bool = false
    private var hasLoadedAnalyses: Bool = false
    private var hasLoadedChat: Bool = false
    
    // Task tracking to prevent concurrent refreshes
    private var refreshHealthScoreTask: Task<Void, Never>? = nil
    private var refreshAnalysesTask: Task<Void, Never>? = nil
    private var refreshProfileTask: Task<Void, Never>? = nil
    private var refreshChatTask: Task<Void, Never>? = nil
    
    // Singleton instance
    static let shared = UserDataViewModel()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load all user data (call this once when user logs in or app launches)
    func loadAllUserData() async {
        do {
            let userId = try await AuthService.shared.getCurrentUserId()
            
            // If user hasn't changed, don't reload everything
            if currentUserId == userId && hasLoadedProfile && hasLoadedHealthScore {
                print("✅ User data already loaded for user: \(userId)")
                return
            }
            
            currentUserId = userId
            
            // Load data in parallel, but only if not already loaded
            let shouldLoadProfile = !hasLoadedProfile
            let shouldLoadHealthScore = !hasLoadedHealthScore
            let shouldLoadAnalyses = !hasLoadedAnalyses
            let shouldLoadChat = !hasLoadedChat
            
            async let profileTask: Void = {
                if shouldLoadProfile {
                    await loadUserProfile(userId: userId)
                }
            }()
            
            async let healthScoreTask: Void = {
                if shouldLoadHealthScore {
                    await loadHealthScore(userId: userId)
                }
            }()
            
            async let analysesTask: Void = {
                if shouldLoadAnalyses {
                    await loadAnalyses(userId: userId)
                }
            }()
            
            async let chatTask: Void = {
                if shouldLoadChat {
                    await loadChatHistory(userId: userId)
                }
            }()
            
            // Wait for all tasks to complete
            _ = await [profileTask, healthScoreTask, analysesTask, chatTask]
            
            print("✅ All user data loaded successfully")
        } catch {
            print("❌ Error loading user data: \(error.localizedDescription)")
        }
    }
    
    /// Force refresh user profile
    func refreshUserProfile() async {
        // Cancel any existing refresh task
        refreshProfileTask?.cancel()
        
        // Create new task and store reference
        refreshProfileTask = Task {
            guard !Task.isCancelled else { 
                print("⚠️ Profile refresh cancelled")
                return 
            }
            
            guard let userId = currentUserId else {
                await loadAllUserData()
                return
            }
            await loadUserProfile(userId: userId)
        }
        
        await refreshProfileTask?.value
    }
    
    /// Force refresh health score
    func refreshHealthScore() async {
        // Cancel any existing refresh task
        refreshHealthScoreTask?.cancel()
        
        // Create new task and store reference
        refreshHealthScoreTask = Task {
            guard !Task.isCancelled else { 
                print("⚠️ Health score refresh cancelled by new request")
                return 
            }
            
            guard let userId = currentUserId else {
                print("⚠️ No current user ID, loading all data")
                await loadAllUserData()
                return
            }
            
            print("🔄 Refreshing health score...")
            
            // Check for cancellation before each step
            guard !Task.isCancelled else { 
                print("⚠️ Health score refresh cancelled before loadHealthScore")
                return 
            }
            await loadHealthScore(userId: userId)
            
            guard !Task.isCancelled else { 
                print("⚠️ Health score refresh cancelled before loadAnalyses")
                return 
            }
            await loadAnalyses(userId: userId)
        }
        
        await refreshHealthScoreTask?.value
    }
    
    /// Force refresh analyses
    func refreshAnalyses() async {
        // Cancel any existing refresh task
        refreshAnalysesTask?.cancel()
        
        // Create new task and store reference
        refreshAnalysesTask = Task {
            guard !Task.isCancelled else { 
                print("⚠️ Analyses refresh cancelled")
                return 
            }
            
            guard let userId = currentUserId else {
                await loadAllUserData()
                return
            }
            await loadAnalyses(userId: userId)
        }
        
        await refreshAnalysesTask?.value
    }
    
    /// Force refresh chat
    func refreshChat() async {
        // Cancel any existing refresh task
        refreshChatTask?.cancel()
        
        // Create new task and store reference
        refreshChatTask = Task {
            guard !Task.isCancelled else { 
                print("⚠️ Chat refresh cancelled")
                return 
            }
            
            guard let userId = currentUserId else {
                await loadAllUserData()
                return
            }
            await loadChatHistory(userId: userId)
        }
        
        await refreshChatTask?.value
    }
    
    /// Add a new chat message locally (optimistic update)
    func addChatMessage(_ message: ChatMessageDTO) {
        chatMessages.append(message)
    }
    
    /// Clear all data (call when user logs out)
    func clearAllData() {
        // Cancel all pending tasks
        refreshHealthScoreTask?.cancel()
        refreshAnalysesTask?.cancel()
        refreshProfileTask?.cancel()
        refreshChatTask?.cancel()
        
        userName = nil
        healthScore = 0.0
        animatedProgress = 0.0
        topBiomarkers = []
        hasAnalyses = false
        analyses = []
        chatMessages = []
        currentUserId = nil
        hasLoadedProfile = false
        hasLoadedHealthScore = false
        hasLoadedAnalyses = false
        hasLoadedChat = false
        healthScoreError = nil
        analysesError = nil
        print("✅ All user data cleared")
    }
    
    // MARK: - Private Methods
    
    private func loadUserProfile(userId: String) async {
        // Allow reloading for explicit refresh calls
        
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        
        do {
            print("🔵 Loading user profile for userId: \(userId)")
            
            guard let supabaseURL = SupabaseManager.shared.getURL(),
                  let supabaseKey = SupabaseManager.shared.getAnonKey(),
                  let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(userId)&select=first_name,last_name") else {
                print("❌ Supabase configuration missing")
                return
            }
            
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
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ HTTP error: \(errorString)")
                return
            }
            
            let decoder = JSONDecoder()
            var userProfile: UserProfile?
            
            if let singleProfile = try? decoder.decode(UserProfile.self, from: data) {
                userProfile = singleProfile
            } else if let array = try? decoder.decode([UserProfile].self, from: data),
                      let firstProfile = array.first {
                userProfile = firstProfile
            }
            
            if let profile = userProfile {
                if let firstName = profile.first_name, !firstName.isEmpty {
                    userName = firstName
                    print("✅ Set userName to: \(firstName)")
                } else if let lastName = profile.last_name, !lastName.isEmpty {
                    userName = lastName
                    print("✅ Set userName to: \(lastName)")
                }
            }
            
            // Fallback to email if no name found
            if userName == nil {
                if let client = SupabaseManager.shared.getClient() {
                    do {
                        let session = try await client.auth.session
                        if let email = session.user.email {
                            userName = email.components(separatedBy: "@").first?.capitalized
                        } else {
                            userName = "User"
                        }
                    } catch {
                        userName = "User"
                    }
                }
            }
            
            hasLoadedProfile = true
        } catch {
            print("❌ Error loading user profile: \(error.localizedDescription)")
        }
    }
    
    private func loadHealthScore(userId: String) async {
        // Allow reloading even if already loaded (for refresh)
        
        isLoadingHealthScore = true
        healthScoreError = nil
        defer { isLoadingHealthScore = false }
        
        do {
            print("🔵 Fetching analyses for user: \(userId)")
            
            let fetchedAnalyses = try await HealthScoreService.shared.fetchAnalyses(userId: userId)
            print("🔵 Fetched \(fetchedAnalyses.count) analyses")
            
            // Fetch user profile for personalized scoring
            let userProfile = await UserHealthProfile.fetchFromSupabase()
            print("🔵 User profile loaded for personalization: age=\(userProfile.age ?? -1), conditions=\(userProfile.healthConditions.count)")
            
            // Use enhanced health score calculation with personalization
            let detailedResult = HealthScoreService.shared.calculateDetailedHealthScore(
                analyses: fetchedAnalyses,
                userProfile: userProfile
            )
            
            let score = detailedResult.score
            print("🔵 Calculated health score: \(score) (\(detailedResult.scoreCategory))")
            print("   Confidence: \(String(format: "%.0f", detailedResult.confidence * 100))%")
            print("   Summary: \(detailedResult.summaryExplanation)")
            
            let biomarkers = HealthScoreService.shared.getTopBiomarkers(analyses: fetchedAnalyses, limit: 4)
            print("🔵 Found \(biomarkers.count) biomarkers needing attention")
            
            healthScore = score
            topBiomarkers = biomarkers
            hasAnalyses = !fetchedAnalyses.isEmpty
            
            // Animate progress
            withAnimation(.easeInOut(duration: 1.5)) {
                animatedProgress = min(max(score / 10.0, 0.0), 1.0)
            }
            
            hasLoadedHealthScore = true
            print("✅ Health score loaded: \(score)")
        } catch {
            print("❌ Error loading health score: \(error.localizedDescription)")
            healthScoreError = error.localizedDescription
            healthScore = 0.0
        }
    }
    
    private func loadAnalyses(userId: String) async {
        // Allow reloading even if already loaded (for refresh)
        
        isLoadingAnalyses = true
        analysesError = nil
        defer { isLoadingAnalyses = false }
        
        do {
            let fetchedAnalyses = try await HealthScoreService.shared.fetchAnalyses(userId: userId)
            analyses = fetchedAnalyses
            hasLoadedAnalyses = true
            print("✅ Analyses loaded: \(fetchedAnalyses.count) items")
        } catch {
            print("❌ Error loading analyses: \(error.localizedDescription)")
            analysesError = error.localizedDescription
            analyses = []
        }
    }
    
    private func loadChatHistory(userId: String) async {
        // Allow reloading for explicit refresh calls
        
        isLoadingChat = true
        defer { isLoadingChat = false }
        
        do {
            let history = try await ChatService.shared.getChatHistory(userId: userId)
            chatMessages = history
            hasLoadedChat = true
            print("✅ Chat history loaded: \(history.count) messages")
        } catch {
            print("❌ Error loading chat history: \(error.localizedDescription)")
            chatMessages = []
        }
    }
}
