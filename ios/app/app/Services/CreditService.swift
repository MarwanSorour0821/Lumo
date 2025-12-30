import Foundation

/// Response model for credit balance
struct CreditBalanceResponse: Codable {
    let credits: Int
}

/// Response model for deducting credits
struct DeductCreditResponse: Codable {
    let success: Bool
    let message: String?
}

/// Response model for checkout session
struct CreditCheckoutResponse: Codable {
    let checkout_url: String
    let session_id: String
}

/// Credit bundle options
struct CreditBundle: Identifiable {
    let id: String
    let credits: Int
    let price: Double
    let priceDisplay: String
    let savings: String?
    
    static let bundles: [CreditBundle] = [
        CreditBundle(id: "1", credits: 1, price: 1.99, priceDisplay: "$1.99", savings: nil),
        CreditBundle(id: "3", credits: 3, price: 3.99, priceDisplay: "$3.99", savings: "Save 33%"),
        CreditBundle(id: "5", credits: 5, price: 5.99, priceDisplay: "$5.99", savings: "Best Value"),
    ]
}

/// Service for managing user credits
actor CreditService {
    static let shared = CreditService()
    
    private init() {}
    
    /// Get the current user's credit balance
    func getCredits() async throws -> Int {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/credits/") else {
            throw NSError(domain: "CreditService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "CreditService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get credits: \(errorText)"])
        }
        
        let decoded = try JSONDecoder().decode(CreditBalanceResponse.self, from: data)
        return decoded.credits
    }
    
    /// Deduct one credit from the user's balance
    /// Returns true if successful, false if insufficient credits
    func deductCredit() async throws -> Bool {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/credits/deduct/") else {
            throw NSError(domain: "CreditService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CreditService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // 402 Payment Required means insufficient credits
        if httpResponse.statusCode == 402 {
            return false
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "CreditService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to deduct credit: \(errorText)"])
        }
        
        let decoded = try JSONDecoder().decode(DeductCreditResponse.self, from: data)
        return decoded.success
    }
    
    /// Create a checkout session for purchasing credits
    func createCheckoutSession(bundle: String) async throws -> String {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/credits/checkout/") else {
            throw NSError(domain: "CreditService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "bundle": bundle,
            "success_url": "lumo://credits-success",
            "cancel_url": "lumo://credits-cancel"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "CreditService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create checkout: \(errorText)"])
        }
        
        let decoded = try JSONDecoder().decode(CreditCheckoutResponse.self, from: data)
        return decoded.checkout_url
    }
}
