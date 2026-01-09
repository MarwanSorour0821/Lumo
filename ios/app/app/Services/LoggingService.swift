//
//  LoggingService.swift
//  app
//
//  Service for food and supplement logging API calls
//

import Foundation

// MARK: - Logging Service
class LoggingService {
    static let shared = LoggingService()
    
    private init() {}
    
    // MARK: - Items
    
    /// Get all food/supplement items for the current user
    func getItems(type: LogItemType? = nil, includeArchived: Bool = false) async throws -> [FoodSupplementItem] {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              var urlComponents = URLComponents(string: "\(apiURLString)/api/logging/items/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        var queryItems: [URLQueryItem] = []
        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        if includeArchived {
            queryItems.append(URLQueryItem(name: "include_archived", value: "true"))
        }
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch items"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([FoodSupplementItem].self, from: data)
    }
    
    /// Create a new food/supplement item
    func createItem(name: String, type: LogItemType, description: String? = nil, frequency: LogFrequency = .daily, timesPerWeek: Int = 7, startDate: Date? = nil, endDate: Date? = nil) async throws -> FoodSupplementItem {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var body: [String: Any] = [
            "name": name,
            "type": type.rawValue,
            "frequency": frequency.rawValue,
            "times_per_week": timesPerWeek
        ]
        if let description = description {
            body["description"] = description
        }
        if let startDate = startDate {
            body["start_date"] = dateFormatter.string(from: startDate)
        }
        if let endDate = endDate {
            body["end_date"] = dateFormatter.string(from: endDate)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create item"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FoodSupplementItem.self, from: data)
    }
    
    /// Update an existing item
    func updateItem(itemId: String, name: String? = nil, type: LogItemType? = nil, description: String? = nil, frequency: LogFrequency? = nil, timesPerWeek: Int? = nil, startDate: Date? = nil, endDate: Date? = nil, clearStartDate: Bool = false, clearEndDate: Bool = false) async throws -> FoodSupplementItem {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let type = type { body["type"] = type.rawValue }
        if let description = description { body["description"] = description }
        if let frequency = frequency { body["frequency"] = frequency.rawValue }
        if let timesPerWeek = timesPerWeek { body["times_per_week"] = timesPerWeek }
        if let startDate = startDate {
            body["start_date"] = dateFormatter.string(from: startDate)
        } else if clearStartDate {
            body["start_date"] = NSNull()
        }
        if let endDate = endDate {
            body["end_date"] = dateFormatter.string(from: endDate)
        } else if clearEndDate {
            body["end_date"] = NSNull()
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to update item"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FoodSupplementItem.self, from: data)
    }
    
    /// Delete an item
    func deleteItem(itemId: String) async throws {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to delete item"])
        }
    }
    
    /// Archive/unarchive an item
    func archiveItem(itemId: String, isArchived: Bool) async throws -> FoodSupplementItem {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/archive/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["is_archived": isArchived]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to archive item"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FoodSupplementItem.self, from: data)
    }
    
    // MARK: - Logs
    
    /// Log an intake for a specific item
    func logItem(itemId: String, quantity: String? = nil, notes: String? = nil) async throws -> LogEntry {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/log/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let quantity = quantity { body["quantity"] = quantity }
        if let notes = notes { body["notes"] = notes }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to log item"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(LogEntry.self, from: data)
    }
    
    /// Get all logs
    func getLogs(itemId: String? = nil, limit: Int = 50) async throws -> [LogEntry] {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              var urlComponents = URLComponents(string: "\(apiURLString)/api/logging/logs/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let itemId = itemId {
            queryItems.append(URLQueryItem(name: "item_id", value: itemId))
        }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch logs"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([LogEntry].self, from: data)
    }
    
    /// Delete a log entry
    func deleteLog(logId: String) async throws {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/logs/\(logId)/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to delete log"])
        }
    }

    /// Get logs for a specific date range
    func getLogsByDate(startDate: Date, endDate: Date) async throws -> [LogEntry] {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              var urlComponents = URLComponents(string: "\(apiURLString)/api/logging/logs/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        urlComponents.queryItems = [
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: endDate)),
            URLQueryItem(name: "limit", value: "100")
        ]

        guard let url = urlComponents.url else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch logs"])
        }

        let decoder = JSONDecoder()
        return try decoder.decode([LogEntry].self, from: data)
    }
    
    // MARK: - Quick Log (Voice/Text)
    
    /// Quick log via voice transcription or text
    func quickLog(inputText: String) async throws -> QuickLogResponse {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/quick-log/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["input_text": inputText]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to process quick log"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(QuickLogResponse.self, from: data)
    }
    
    // MARK: - Biomarker Impacts
    
    /// Get biomarker impacts for an item
    func getBiomarkerImpacts(itemId: String) async throws -> [BiomarkerImpact] {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/impacts/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch impacts"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([BiomarkerImpact].self, from: data)
    }
    
    /// Generate biomarker impacts for an item using AI
    func generateBiomarkerImpacts(itemId: String) async throws -> BiomarkerImpactsResponse {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/impacts/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate impacts"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(BiomarkerImpactsResponse.self, from: data)
    }
    
    // MARK: - Taken Status

    /// Toggle the taken status of an item
    func toggleTaken(itemId: String) async throws -> ToggleTakenResponse {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/toggle-taken/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }

        let accessToken = try await AuthService.shared.getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to toggle taken status"])
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ToggleTakenResponse.self, from: data)
    }

    // MARK: - Reminders

    /// Update reminder settings for an item
    func updateReminder(itemId: String, enabled: Bool, time: String? = nil, days: [Int]? = nil) async throws -> FoodSupplementItem {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let url = URL(string: "\(apiURLString)/api/logging/items/\(itemId)/reminder/") else {
            throw NSError(domain: "LoggingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["reminder_enabled": enabled]
        if let time = time { body["reminder_time"] = time }
        if let days = days { body["reminder_days"] = days }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LoggingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to update reminder"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FoodSupplementItem.self, from: data)
    }
}
