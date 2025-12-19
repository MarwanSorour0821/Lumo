//
//  SupabaseClient.swift
//  app
//
//  Created on iOS
//

import Foundation
import AuthenticationServices
import Supabase

// MARK: - Supabase Client Manager
class SupabaseManager {
    static let shared = SupabaseManager()
    
    private var supabaseClient: SupabaseClient?
    
    private init() {
        // Load from Info.plist
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let url = URL(string: urlString) else {
            print("⚠️ Supabase configuration missing in Info.plist")
            return
        }
        
        supabaseClient = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
    
    var isConfigured: Bool {
        return supabaseClient != nil
    }
    
    func getClient() -> SupabaseClient? {
        return supabaseClient
    }
    
    func getAPIURL() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    }
    
    func getURL() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
    }
    
    func getAnonKey() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
    }
}

// MARK: - Authentication Service
class AuthService {
    static let shared = AuthService()
    
    // Retain active OAuth sessions to prevent deallocation
    private var activeOAuthSession: ASWebAuthenticationSession?
    
    struct SignInResponse {
        let user: User?
        let error: AuthError?
    }
    
    struct User {
        let id: String
        let email: String?
        let firstName: String?
        let lastName: String?
    }
    
    struct AuthError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    
    struct SignUpResponse {
        let user: User?
        let error: AuthError?
    }
    
    struct ProfileResponse {
        let error: AuthError?
    }
    
    // Sign in with email and password using Supabase client
    func signInWithEmail(email: String, password: String) async -> SignInResponse {
        guard let client = SupabaseManager.shared.getClient() else {
            return SignInResponse(
                user: nil,
                error: AuthError(message: "Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist.")
            )
        }
        
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            let user = response.user
            
            return SignInResponse(
                user: User(id: user.id.uuidString, email: user.email, firstName: nil, lastName: nil),
                error: nil
            )
        } catch {
            return SignInResponse(
                user: nil,
                error: AuthError(message: error.localizedDescription)
            )
        }
    }
    
    // Sign up with email and password using Supabase client
    func signUpWithEmail(email: String, password: String) async -> SignUpResponse {
        guard let client = SupabaseManager.shared.getClient() else {
            print("❌ Supabase client not configured")
            return SignUpResponse(
                user: nil,
                error: AuthError(message: "Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist.")
            )
        }
        
        do {
            print("🔵 Attempting to sign up user with email: \(email)")
            let response = try await client.auth.signUp(email: email, password: password)
            
            // Wait a bit for the user to be created
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let user = response.user
            print("✅ User created successfully. User ID: \(user.id.uuidString), Email: \(user.email ?? "N/A")")
            return SignUpResponse(
                user: User(id: user.id.uuidString, email: user.email, firstName: nil, lastName: nil),
                error: nil
            )
        } catch {
            print("❌ Sign up error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)")
            }
            return SignUpResponse(
                user: nil,
                error: AuthError(message: error.localizedDescription)
            )
        }
    }
    
    // Create user profile in the public.users table
    func createUserProfile(
        userId: String,
        biologicalSex: String,
        dateOfBirth: Date,
        heightCm: Double,
        weightKg: Double,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil
    ) async -> ProfileResponse {
        guard let client = SupabaseManager.shared.getClient() else {
            return ProfileResponse(
                error: AuthError(message: "Supabase is not configured. Please set SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist.")
            )
        }
        
        do {
            // Wait a bit before creating profile
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Define the profile structure
            struct UserProfile: Codable {
                let id: String
                let biological_sex: String
                let date_of_birth: String
                let height_cm: Double
                let weight_kg: Double
                let created_at: String
                let updated_at: String
                let first_name: String?
                let last_name: String?
                let email: String?
            }
            
            let profile = UserProfile(
                id: userId,
                biological_sex: biologicalSex,
                date_of_birth: isoFormatter.string(from: dateOfBirth),
                height_cm: heightCm,
                weight_kg: weightKg,
                created_at: isoFormatter.string(from: Date()),
                updated_at: isoFormatter.string(from: Date()),
                first_name: firstName?.trimmingCharacters(in: .whitespaces).isEmpty == false ? firstName?.trimmingCharacters(in: .whitespaces) : nil,
                last_name: lastName?.trimmingCharacters(in: .whitespaces).isEmpty == false ? lastName?.trimmingCharacters(in: .whitespaces) : nil,
                email: email?.trimmingCharacters(in: .whitespaces).isEmpty == false ? email?.trimmingCharacters(in: .whitespaces) : nil
            )
            
            // Use upsert to insert or update the profile
            print("🔵 Creating user profile with data: userId=\(userId), sex=\(biologicalSex), height=\(heightCm)cm, weight=\(weightKg)kg")
            try await client.database
                .from("users")
                .upsert(profile, onConflict: "id")
                .execute()
            
            print("✅ User profile created successfully")
            return ProfileResponse(error: nil)
        } catch {
            print("❌ Profile creation error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain), code: \(nsError.code), userInfo: \(nsError.userInfo)")
            }
            return ProfileResponse(
                error: AuthError(message: error.localizedDescription)
            )
        }
    }
    
    // Sign in with Google (OAuth) - using backend API
    func signInWithGoogle() async -> SignInResponse {
        // Get API URL from configuration
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let apiURL = URL(string: "\(apiURLString)/api/auth/google/") else {
            return SignInResponse(
                user: nil,
                error: AuthError(message: "API URL is not configured. Please set API_URL in Info.plist.")
            )
        }
        
        // Generate redirect URL for OAuth callback
        let bundleId = Bundle.main.bundleIdentifier ?? "com.lumoblood.app"
        let redirectURL = "\(bundleId)://auth/callback"
        
        // Step 1: Call backend to get OAuth URL
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "redirect_url": redirectURL
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return SignInResponse(
                user: nil,
                error: AuthError(message: "Failed to create request: \(error.localizedDescription)")
            )
        }
        
        // Make request to backend
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return SignInResponse(
                    user: nil,
                    error: AuthError(message: "Invalid response from server")
                )
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                return SignInResponse(
                    user: nil,
                    error: AuthError(message: "Server error: \(errorMessage)")
                )
            }
            
            // Parse response to get OAuth URL
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("🔵 Backend response: \(responseString)")
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauthURLString = json["url"] as? String,
                  let oauthURL = URL(string: oauthURLString) else {
                print("❌ Failed to parse response. Response: \(responseString)")
                return SignInResponse(
                    user: nil,
                    error: AuthError(message: "Invalid response format from server. Response: \(responseString)")
                )
            }
            
            print("🔵 OAuth URL: \(oauthURLString)")
            
            // Step 2: Open OAuth session manually
            return await withCheckedContinuation { continuation in
                var hasResumed = false
                var timeoutTask: Task<Void, Never>?
                
                // Set a timeout to detect if callback never comes
                timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    if !hasResumed {
                        print("⏰ OAuth timeout - callback never received")
                        await MainActor.run {
                            AuthService.shared.activeOAuthSession?.cancel()
                            AuthService.shared.activeOAuthSession = nil
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: SignInResponse(
                                    user: nil,
                                    error: AuthError(message: "OAuth timeout - the browser may not have opened. Please check your device settings.")
                                ))
                            }
                        }
                    }
                }
                
                let authSession = ASWebAuthenticationSession(
                    url: oauthURL,
                    callbackURLScheme: bundleId
                ) { callbackURL, error in
                    timeoutTask?.cancel()
                    AuthService.shared.activeOAuthSession = nil  // Release when done
                    hasResumed = true
                    print("🔵 OAuth callback received")
                    
                    if let error = error {
                        print("❌ OAuth error: \(error.localizedDescription)")
                        let nsError = error as NSError
                        if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: SignInResponse(
                                    user: nil,
                                    error: AuthError(message: "Sign in cancelled")
                                ))
                            }
                        } else {
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: SignInResponse(
                                    user: nil,
                                    error: AuthError(message: "OAuth error: \(error.localizedDescription)")
                                ))
                            }
                        }
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        print("❌ No callback URL received")
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: SignInResponse(
                                user: nil,
                                error: AuthError(message: "No callback URL received")
                            ))
                        }
                        return
                    }
                    
                    print("🔵 Callback URL: \(callbackURL.absoluteString)")
                    
                    // Step 3: Send callback URL to backend to complete authentication
                    Task {
                        await AuthService.shared.completeGoogleSignIn(callbackURL: callbackURL, continuation: continuation)
                    }
                }
                
                let provider = OAuthPresentationContextProvider.shared
                authSession.presentationContextProvider = provider
                authSession.prefersEphemeralWebBrowserSession = false
                
                // CRITICAL: Retain the session in a class property BEFORE starting it
                AuthService.shared.activeOAuthSession = authSession
                
                print("🔵 Starting OAuth session with callback scheme: \(bundleId)")
                print("🔵 Redirect URL: \(redirectURL)")
                print("🔵 OAuth URL: \(oauthURL.absoluteString)")
                
                // Start on main thread - ASWebAuthenticationSession must start on main thread
                // Use async dispatch to ensure it happens on the next run loop cycle
                DispatchQueue.main.async {
                    // Double-check session is still retained
                    guard AuthService.shared.activeOAuthSession === authSession else {
                        print("❌ Session was deallocated before starting")
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: SignInResponse(
                                user: nil,
                                error: AuthError(message: "Session was deallocated. Please try again.")
                            ))
                        }
                        return
                    }
                    
                    // Verify window is available
                    let provider = OAuthPresentationContextProvider.shared
                    let anchor = provider.presentationAnchor(for: authSession)
                    print("🔵 Presentation anchor: \(anchor)")
                    print("🔵 Window is key: \(anchor.isKeyWindow)")
                    print("🔵 Window is hidden: \(anchor.isHidden)")
                    print("🔵 Window alpha: \(anchor.alpha)")
                    
                    // Check if running on simulator (sometimes OAuth doesn't work well on simulator)
                    #if targetEnvironment(simulator)
                    print("⚠️ Running on iOS Simulator - OAuth may not work properly")
                    #endif
                    
                    let startResult = authSession.start()
                    print("🔵 authSession.start() returned: \(startResult)")
                    
                    if !startResult {
                        print("❌ Failed to start OAuth session")
                        AuthService.shared.activeOAuthSession = nil
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: SignInResponse(
                                user: nil,
                                error: AuthError(message: "Failed to start OAuth session. Please check your URL scheme configuration.")
                            ))
                        }
                    } else {
                        print("✅ OAuth session started successfully - browser should open now")
                        // Verify the session is still retained
                        if AuthService.shared.activeOAuthSession === nil {
                            print("⚠️ WARNING: Session was deallocated immediately after start()")
                        } else {
                            print("✅ Session is still retained after start()")
                        }
                    }
                }
            }
        } catch {
            return SignInResponse(
                user: nil,
                error: AuthError(message: "Network error: \(error.localizedDescription)")
            )
        }
    }
    
    // Complete Google sign-in by sending callback URL to backend
    private func completeGoogleSignIn(callbackURL: URL, continuation: CheckedContinuation<SignInResponse, Never>) async {
        print("🔵 Completing Google sign-in with callback URL")
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let apiURL = URL(string: "\(apiURLString)/api/auth/google/callback/") else {
            print("❌ API URL not configured")
            continuation.resume(returning: SignInResponse(
                user: nil,
                error: AuthError(message: "API URL is not configured")
            ))
            return
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "callback_url": callbackURL.absoluteString
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            continuation.resume(returning: SignInResponse(
                user: nil,
                error: AuthError(message: "Failed to create request: \(error.localizedDescription)")
            ))
            return
        }
        
        do {
            print("🔵 Sending callback URL to backend: \(apiURL.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                continuation.resume(returning: SignInResponse(
                    user: nil,
                    error: AuthError(message: "Invalid response from server")
                ))
                return
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("🔵 Backend callback response (\(httpResponse.statusCode)): \(responseString)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Server error: \(responseString)")
                continuation.resume(returning: SignInResponse(
                    user: nil,
                    error: AuthError(message: "Server error: \(responseString)")
                ))
                return
            }
            
            // Parse response to get user data
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON. Response: \(responseString)")
                continuation.resume(returning: SignInResponse(
                    user: nil,
                    error: AuthError(message: "Invalid JSON response: \(responseString)")
                ))
                return
            }
            
            print("🔵 Parsed JSON: \(json)")
            
            guard let userData = json["user"] as? [String: Any],
                  let userId = userData["id"] as? String else {
                print("❌ Missing user data in response. JSON: \(json)")
                continuation.resume(returning: SignInResponse(
                    user: nil,
                    error: AuthError(message: "Invalid response format from server. Missing user data.")
                ))
                return
            }
            
            let email = userData["email"] as? String
            let firstName = userData["first_name"] as? String ?? userData["firstName"] as? String
            let lastName = userData["last_name"] as? String ?? userData["lastName"] as? String
            
            print("✅ Sign-in successful. User ID: \(userId), Email: \(email ?? "N/A")")
            
            continuation.resume(returning: SignInResponse(
                user: User(
                    id: userId,
                    email: email,
                    firstName: firstName,
                    lastName: lastName
                ),
                error: nil
            ))
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            continuation.resume(returning: SignInResponse(
                user: nil,
                error: AuthError(message: "Network error: \(error.localizedDescription)")
            ))
        }
    }
}

// MARK: - OAuth Presentation Context
class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthPresentationContextProvider()
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        print("🔵 Getting presentation anchor for OAuth session")
        
        // Try to get the active window scene first
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("❌ No window scene found")
            // Last resort fallback
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return UIWindow(windowScene: scene)
            }
            return UIWindow()
        }
        
        // Try to get key window first
        if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            print("✅ Found key window: \(keyWindow)")
            return keyWindow
        }
        
        // Fallback to first window
        if let firstWindow = windowScene.windows.first {
            print("✅ Found first window: \(firstWindow)")
            return firstWindow
        }
        
        // Create a new window as last resort
        print("⚠️ Creating new window for window scene")
        let newWindow = UIWindow(windowScene: windowScene)
        newWindow.makeKeyAndVisible()
        return newWindow
    }
}
