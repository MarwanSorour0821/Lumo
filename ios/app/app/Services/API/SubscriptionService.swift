import Foundation

/// Response model for subscription status
struct SubscriptionStatusResponse: Codable {
    let hasActiveSubscription: Bool
    let subscription: SubscriptionDetails?
    
    enum CodingKeys: String, CodingKey {
        case hasActiveSubscription = "has_active_subscription"
        case subscription
    }
}

/// Subscription details
struct SubscriptionDetails: Codable {
    let id: String
    let plan: String
    let status: String
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, plan, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response model for checkout session
struct SubscriptionCheckoutResponse: Codable {
    let checkoutUrl: String
    let sessionId: String
    
    enum CodingKeys: String, CodingKey {
        case checkoutUrl = "checkout_url"
        case sessionId = "session_id"
    }
}

/// Subscription plan options
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case monthly = "monthly"
    case yearly = "yearly"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    var price: String {
        switch self {
        case .monthly: return "$4.99"
        case .yearly: return "$34.99"
        }
    }
    
    var pricePerMonth: String {
        switch self {
        case .monthly: return "$4.99"
        case .yearly: return "$2.92"
        }
    }
    
    var savings: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return "Save 42%"
        }
    }
    
    var tagline: String? {
        switch self {
        case .monthly: return "No commitment. Cancel anytime."
        case .yearly: return nil
        }
    }
    
    var badge: String? {
        switch self {
        case .monthly: return "Pay-as-you-go"
        case .yearly: return "Most popular"
        }
    }
    
    /// Stripe Price ID for this plan
    var stripePriceId: String {
        switch self {
        case .monthly: return "price_1SoU8jEACKuyUvsydbx0Wn9D"
        case .yearly: return "price_1SoUAeEACKuyUvsylzSPlvyT"
        }
    }
}

/// Service for managing user subscriptions
actor SubscriptionService {
    static let shared = SubscriptionService()
    
    private var cachedStatus: Bool?
    private var lastCheck: Date?
    private let cacheValidity: TimeInterval = 60 // 1 minute cache
    
    private init() {}
    
    /// Check if user has an active subscription
    func hasActiveSubscription(forceRefresh: Bool = false) async throws -> Bool {
        // Return cached result if valid
        if !forceRefresh, let cached = cachedStatus, let lastCheck = lastCheck,
           Date().timeIntervalSince(lastCheck) < cacheValidity {
            return cached
        }
        
        guard let supabaseURL = SupabaseManager.shared.getURL(),
              let supabaseKey = SupabaseManager.shared.getAnonKey() else {
            throw NSError(domain: "SubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
        }
        
        let userId = try await AuthService.shared.getCurrentUserId()
        let accessToken = try await AuthService.shared.getAccessToken()
        
        // Check for both 'active' and 'trialing' status (trial users should have access)
        guard let url = URL(string: "\(supabaseURL)/rest/v1/subscriptions?user_id=eq.\(userId)&status=in.(active,trialing)&select=id,plan,status,created_at,updated_at") else {
            throw NSError(domain: "SubscriptionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SubscriptionService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to check subscription"])
        }
        
        let subscriptions = try JSONDecoder().decode([SubscriptionDetails].self, from: data)
        let hasActive = !subscriptions.isEmpty
        
        // Cache the result
        cachedStatus = hasActive
        lastCheck = Date()
        
        return hasActive
    }
    
    /// Check subscription status with retries (useful after checkout completion)
    /// The webhook might not have been processed yet, so we retry a few times
    func hasActiveSubscriptionWithRetry(maxRetries: Int = 5, delaySeconds: Double = 1.5) async throws -> Bool {
        for attempt in 1...maxRetries {
            let hasActive = try await hasActiveSubscription(forceRefresh: true)
            if hasActive {
                print("✅ Subscription found on attempt \(attempt)")
                return true
            }
            
            if attempt < maxRetries {
                print("🔄 Subscription not found, retrying in \(delaySeconds)s (attempt \(attempt)/\(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
        
        print("⚠️ Subscription not found after \(maxRetries) attempts")
        return false
    }
    
    /// Get current subscription details
    func getSubscription() async throws -> SubscriptionDetails? {
        guard let supabaseURL = SupabaseManager.shared.getURL(),
              let supabaseKey = SupabaseManager.shared.getAnonKey() else {
            throw NSError(domain: "SubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
        }
        
        let userId = try await AuthService.shared.getCurrentUserId()
        let accessToken = try await AuthService.shared.getAccessToken()
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/subscriptions?user_id=eq.\(userId)&select=id,plan,status,created_at,updated_at&order=created_at.desc&limit=1") else {
            throw NSError(domain: "SubscriptionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SubscriptionService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get subscription"])
        }
        
        let subscriptions = try JSONDecoder().decode([SubscriptionDetails].self, from: data)
        return subscriptions.first
    }
    
    /// Create a checkout session for a subscription
    func createCheckoutSession(plan: SubscriptionPlan) async throws -> String {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/subscriptions/checkout/") else {
            throw NSError(domain: "SubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "plan": plan.rawValue,
            "price_id": plan.stripePriceId,
            "success_url": "lumo://subscription-success",
            "cancel_url": "lumo://subscription-cancel"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SubscriptionService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create checkout: \(errorText)"])
        }
        
        let decoded = try JSONDecoder().decode(SubscriptionCheckoutResponse.self, from: data)
        return decoded.checkoutUrl
    }
    
    /// Create a customer portal session for managing subscription
    func createPortalSession() async throws -> String {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/subscriptions/portal/") else {
            throw NSError(domain: "SubscriptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "return_url": "lumo://portal-return"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SubscriptionService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create portal: \(errorText)"])
        }
        
        struct PortalResponse: Codable {
            let url: String
        }
        
        let decoded = try JSONDecoder().decode(PortalResponse.self, from: data)
        return decoded.url
    }
    
    /// Clear cached status
    func clearCache() {
        cachedStatus = nil
        lastCheck = nil
    }
    
    /// Check subscription status and cancel notifications if subscription ended
    /// This should be called on app launch and when app becomes active
    func checkAndHandleSubscriptionStatus() async {
        do {
            let hasActive = try await hasActiveSubscription(forceRefresh: true)
            
            if !hasActive {
                // Subscription is not active - cancel all medication reminders
                await NotificationManager.shared.cancelAllMedicationReminders()
                print("🔔 Cancelled all medication reminders - subscription not active")
            }
        } catch {
            print("⚠️ Error checking subscription status: \(error.localizedDescription)")
        }
    }
}
