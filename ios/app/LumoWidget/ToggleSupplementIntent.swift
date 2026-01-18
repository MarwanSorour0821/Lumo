//
//  ToggleSupplementIntent.swift
//  LumoWidget
//
//  AppIntent for toggling supplement taken status from the widget
//

import AppIntents
import WidgetKit

/// App Group identifier - must match main app
private let appGroupIdentifier = "group.com.lumoblood.app"

/// Keys for shared UserDefaults
private enum WidgetDataKeys {
    static let supplements = "widget_supplements"
    static let accessToken = "widget_access_token"
    static let apiURL = "widget_api_url"
    static let lastWidgetToggle = "widget_last_toggle_time"
}

// MARK: - Toggle Supplement Intent

/// Intent to toggle a supplement's taken status
struct ToggleSupplementIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Supplement as Taken"
    static var description = IntentDescription("Toggle whether a supplement has been taken today")
    
    @Parameter(title: "Supplement ID")
    var supplementId: String
    
    @Parameter(title: "Supplement Name")
    var supplementName: String
    
    @Parameter(title: "Time Index", default: -1)
    var timeIndex: Int
    
    init() {
        self.supplementId = ""
        self.supplementName = ""
        self.timeIndex = -1
    }
    
    init(supplementId: String, supplementName: String, timeIndex: Int = -1) {
        self.supplementId = supplementId
        self.supplementName = supplementName
        self.timeIndex = timeIndex
    }
    
    func perform() async throws -> some IntentResult {
        print("🔘 Widget Intent: ========== TOGGLE START ==========")
        print("🔘 Widget Intent: Supplement: \(supplementName)")
        print("🔘 Widget Intent: ID: \(supplementId)")
        print("🔘 Widget Intent: TimeIndex: \(timeIndex)")
        
        // Check shared defaults access
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Widget Intent: Cannot access App Group '\(appGroupIdentifier)'")
            return .result()
        }
        print("✅ Widget Intent: App Group accessible")
        
        // Check for token
        guard let token = sharedDefaults.string(forKey: WidgetDataKeys.accessToken) else {
            print("❌ Widget Intent: No access token found in shared storage")
            print("   Keys in defaults: \(sharedDefaults.dictionaryRepresentation().keys)")
            return .result()
        }
        print("✅ Widget Intent: Token found (length: \(token.count), starts with: \(String(token.prefix(20)))...)")
        
        // Check for API URL
        guard let apiURL = sharedDefaults.string(forKey: WidgetDataKeys.apiURL) else {
            print("❌ Widget Intent: No API URL found in shared storage")
            return .result()
        }
        print("✅ Widget Intent: API URL: \(apiURL)")
        
        // Determine the endpoint
        let endpoint: String
        if timeIndex >= 0 {
            endpoint = "\(apiURL)/api/logging/items/\(supplementId)/toggle-dose/\(timeIndex)/"
        } else {
            endpoint = "\(apiURL)/api/logging/items/\(supplementId)/toggle-taken/"
        }
        print("🌐 Widget Intent: Endpoint: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("❌ Widget Intent: Invalid URL from endpoint")
            return .result()
        }
        
        // Make the API request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🌐 Widget Intent: Making API request...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Widget Intent: Response is not HTTP response")
                return .result()
            }
            
            print("🌐 Widget Intent: HTTP Status: \(httpResponse.statusCode)")
            
            if let responseBody = String(data: data, encoding: .utf8) {
                print("🌐 Widget Intent: Response body: \(responseBody.prefix(500))")
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Widget Intent: Request failed with status \(httpResponse.statusCode)")
                return .result()
            }
            
            print("✅ Widget Intent: API call SUCCESS!")
            
            // Save timestamp so app knows widget just made a change
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: WidgetDataKeys.lastWidgetToggle)
            sharedDefaults.synchronize()
            print("⏱️ Widget Intent: Saved toggle timestamp")
            
            // Update local data optimistically
            updateSupplementLocally(supplementId: supplementId, timeIndex: timeIndex >= 0 ? timeIndex : nil)
            
            // Trigger widget refresh
            WidgetCenter.shared.reloadTimelines(ofKind: "SupplementWidget")
            print("🔘 Widget Intent: ========== TOGGLE END ==========")
            
        } catch {
            print("❌ Widget Intent: Network error: \(error)")
            print("❌ Widget Intent: Error details: \(error.localizedDescription)")
        }
        
        return .result()
    }
    
    /// Update supplement data locally after toggle
    private func updateSupplementLocally(supplementId: String, timeIndex: Int?) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = sharedDefaults.data(forKey: WidgetDataKeys.supplements) else {
            return
        }
        
        do {
            var supplements = try JSONDecoder().decode([WidgetSupplementData].self, from: data)
            
            guard let index = supplements.firstIndex(where: { $0.id == supplementId }) else {
                return
            }
            
            var supplement = supplements[index]
            
            // Update dose statuses
            var updatedDoseStatuses = supplement.doseStatuses
            if let timeIndex = timeIndex {
                // Multi-dose: toggle specific dose
                if let doseIndex = updatedDoseStatuses.firstIndex(where: { $0.timeIndex == timeIndex }) {
                    let dose = updatedDoseStatuses[doseIndex]
                    updatedDoseStatuses[doseIndex] = WidgetDoseStatusData(
                        supplementId: supplementId,
                        timeIndex: dose.timeIndex,
                        time: dose.time,
                        isTaken: !dose.isTaken
                    )
                }
            } else {
                // Single-dose: toggle all doses
                updatedDoseStatuses = updatedDoseStatuses.map { dose in
                    WidgetDoseStatusData(
                        supplementId: supplementId,
                        timeIndex: dose.timeIndex,
                        time: dose.time,
                        isTaken: !dose.isTaken
                    )
                }
            }
            
            // Check if all doses are taken
            let allTaken = updatedDoseStatuses.allSatisfy { $0.isTaken }
            
            // Create updated supplement
            let updatedSupplement = WidgetSupplementData(
                id: supplement.id,
                name: supplement.name,
                type: supplement.type,
                reminderTimes: supplement.reminderTimes,
                isTakenToday: allTaken,
                doseStatuses: updatedDoseStatuses
            )
            
            supplements[index] = updatedSupplement
            
            // Save back to shared storage
            let encodedData = try JSONEncoder().encode(supplements)
            sharedDefaults.set(encodedData, forKey: WidgetDataKeys.supplements)
            sharedDefaults.synchronize()
            
            print("✅ Widget: Updated local supplement data")
        } catch {
            print("❌ Widget: Failed to update local data - \(error)")
        }
    }
}

// MARK: - Data Models for Intent (must match main app models)

struct WidgetSupplementData: Codable {
    let id: String
    let name: String
    let type: String
    let reminderTimes: [String]
    let isTakenToday: Bool
    let doseStatuses: [WidgetDoseStatusData]
}

struct WidgetDoseStatusData: Codable {
    let supplementId: String
    let timeIndex: Int
    let time: String
    let isTaken: Bool
}

