//
//  WidgetDataManager.swift
//  app
//
//  Shared data manager for widget data communication.
//  This file should be added to BOTH the main app target AND the widget extension target.
//

import Foundation
import WidgetKit

/// App Group identifier - must match in both app and widget entitlements
let appGroupIdentifier = "group.com.lumoblood.app"

/// Keys for shared UserDefaults
enum WidgetDataKeys {
    static let supplements = "widget_supplements"
    static let lastUpdated = "widget_last_updated"
    static let isLoggedIn = "widget_is_logged_in"
    static let accessToken = "widget_access_token"
    static let apiURL = "widget_api_url"
}

// MARK: - Widget Supplement Model

/// Simplified supplement model for widget display
/// This model is shared between the main app and widget
struct WidgetSupplement: Codable, Identifiable {
    let id: String
    let name: String
    let type: String  // "supplement", "medication", "food"
    let reminderTimes: [String]
    let isTakenToday: Bool
    let doseStatuses: [WidgetDoseStatus]
    
    /// Icon name based on type
    var iconName: String {
        switch type {
        case "medication":
            return "cross.case.fill"
        case "food":
            return "leaf.fill"
        default:
            return "pills.fill"
        }
    }
    
    /// Check if all doses are taken
    var allDosesTaken: Bool {
        if doseStatuses.isEmpty {
            return isTakenToday
        }
        return doseStatuses.allSatisfy { $0.isTaken }
    }
    
    /// Get pending (untaken) doses
    var pendingDoses: [WidgetDoseStatus] {
        doseStatuses.filter { !$0.isTaken }
    }
    
    /// Next pending dose time
    var nextPendingDose: WidgetDoseStatus? {
        pendingDoses.first
    }
}

/// Represents a single dose time and its taken status
struct WidgetDoseStatus: Codable, Identifiable {
    var id: String { "\(supplementId)-\(timeIndex)" }
    let supplementId: String
    let timeIndex: Int
    let time: String  // e.g., "09:00:00"
    let isTaken: Bool
    
    /// Formatted time for display (e.g., "9:00 AM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        // Fallback: try HH:mm format
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return time
    }
}

// MARK: - Widget Data Manager

/// Manages shared data between the main app and widget extension
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let sharedDefaults: UserDefaults?
    
    private init() {
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        if sharedDefaults == nil {
            print("❌ WidgetDataManager: Failed to access App Group '\(appGroupIdentifier)'. Make sure it's configured in both targets.")
        } else {
            print("✅ WidgetDataManager: Successfully connected to App Group '\(appGroupIdentifier)'")
        }
    }
    
    // MARK: - Save Methods (Called from main app)
    
    /// Save supplements data for the widget
    /// Call this whenever supplements are loaded or updated
    func saveSupplements(_ supplements: [WidgetSupplement]) {
        guard let defaults = sharedDefaults else {
            print("⚠️ WidgetDataManager: Cannot save - App Group not configured")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(supplements)
            defaults.set(data, forKey: WidgetDataKeys.supplements)
            defaults.set(Date(), forKey: WidgetDataKeys.lastUpdated)
            defaults.synchronize()
            
            print("✅ WidgetDataManager: Saved \(supplements.count) supplements for widget")
            
            // Trigger widget refresh
            WidgetCenter.shared.reloadTimelines(ofKind: "SupplementWidget")
        } catch {
            print("❌ WidgetDataManager: Failed to encode supplements - \(error)")
        }
    }
    
    /// Set logged in status
    func setLoggedIn(_ isLoggedIn: Bool) {
        print("🔔 WidgetDataManager.setLoggedIn(\(isLoggedIn)) called")
        
        guard let defaults = sharedDefaults else {
            print("❌ WidgetDataManager: sharedDefaults is nil - App Group not configured!")
            return
        }
        
        defaults.set(isLoggedIn, forKey: WidgetDataKeys.isLoggedIn)
        defaults.synchronize()
        
        // Verify the value was saved
        let savedValue = defaults.bool(forKey: WidgetDataKeys.isLoggedIn)
        print("✅ WidgetDataManager: Saved isLoggedIn=\(isLoggedIn), verified=\(savedValue)")
        
        if !isLoggedIn {
            // Clear supplements when logged out
            clearSupplements()
        }
        
        // Trigger widget refresh
        print("🔄 WidgetDataManager: Triggering widget refresh for 'SupplementWidget'")
        WidgetCenter.shared.reloadTimelines(ofKind: "SupplementWidget")
    }
    
    /// Clear all supplement data
    func clearSupplements() {
        sharedDefaults?.removeObject(forKey: WidgetDataKeys.supplements)
        sharedDefaults?.removeObject(forKey: WidgetDataKeys.lastUpdated)
        sharedDefaults?.synchronize()
        
        print("🗑️ WidgetDataManager: Cleared supplement data")
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "SupplementWidget")
    }
    
    // MARK: - Load Methods (Called from widget)
    
    /// Load supplements from shared storage
    func loadSupplements() -> [WidgetSupplement] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: WidgetDataKeys.supplements) else {
            print("ℹ️ WidgetDataManager: No supplement data found")
            return []
        }
        
        do {
            let supplements = try JSONDecoder().decode([WidgetSupplement].self, from: data)
            print("✅ WidgetDataManager: Loaded \(supplements.count) supplements")
            return supplements
        } catch {
            print("❌ WidgetDataManager: Failed to decode supplements - \(error)")
            return []
        }
    }
    
    /// Check if user is logged in
    func isLoggedIn() -> Bool {
        return sharedDefaults?.bool(forKey: WidgetDataKeys.isLoggedIn) ?? false
    }
    
    /// Get last update time
    func lastUpdated() -> Date? {
        return sharedDefaults?.object(forKey: WidgetDataKeys.lastUpdated) as? Date
    }
    
    // MARK: - Auth Token (for widget API calls)
    
    /// Save access token for widget to use
    func saveAccessToken(_ token: String) {
        guard let defaults = sharedDefaults else {
            print("❌ WidgetDataManager: Cannot save token - sharedDefaults is nil")
            return
        }
        defaults.set(token, forKey: WidgetDataKeys.accessToken)
        defaults.synchronize()
        
        // Verify the save
        if let saved = defaults.string(forKey: WidgetDataKeys.accessToken) {
            print("✅ WidgetDataManager: Saved access token (length: \(saved.count), verified: true)")
        } else {
            print("❌ WidgetDataManager: Token save FAILED - could not read back")
        }
    }
    
    /// Get access token
    func getAccessToken() -> String? {
        return sharedDefaults?.string(forKey: WidgetDataKeys.accessToken)
    }
    
    /// Save API URL for widget to use
    func saveAPIURL(_ url: String) {
        guard let defaults = sharedDefaults else {
            print("❌ WidgetDataManager: Cannot save API URL - sharedDefaults is nil")
            return
        }
        defaults.set(url, forKey: WidgetDataKeys.apiURL)
        defaults.synchronize()
        
        // Verify the save
        if let saved = defaults.string(forKey: WidgetDataKeys.apiURL) {
            print("✅ WidgetDataManager: Saved API URL: \(saved)")
        } else {
            print("❌ WidgetDataManager: API URL save FAILED")
        }
    }
    
    /// Get API URL
    func getAPIURL() -> String? {
        return sharedDefaults?.string(forKey: WidgetDataKeys.apiURL)
    }
    
    /// Clear auth data on logout
    func clearAuthData() {
        sharedDefaults?.removeObject(forKey: WidgetDataKeys.accessToken)
        sharedDefaults?.removeObject(forKey: WidgetDataKeys.apiURL)
        sharedDefaults?.synchronize()
        print("🗑️ WidgetDataManager: Cleared auth data")
    }
    
    // MARK: - Toggle Supplement (called from widget)
    
    /// Toggle a supplement's taken status and update local data
    /// Returns true if successful
    func toggleSupplementTaken(supplementId: String, timeIndex: Int? = nil) async -> Bool {
        guard let token = getAccessToken(),
              let apiURL = getAPIURL() else {
            print("❌ Widget: No auth token or API URL available")
            return false
        }
        
        // Determine the endpoint based on whether it's a multi-dose or single-dose
        let endpoint: String
        if let timeIndex = timeIndex {
            endpoint = "\(apiURL)/api/logging/items/\(supplementId)/toggle-dose/\(timeIndex)/"
        } else {
            endpoint = "\(apiURL)/api/logging/items/\(supplementId)/toggle-taken/"
        }
        
        guard let url = URL(string: endpoint) else {
            print("❌ Widget: Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Widget: Toggle request failed")
                return false
            }
            
            print("✅ Widget: Successfully toggled supplement \(supplementId)")
            
            // Update local data optimistically
            updateSupplementLocally(supplementId: supplementId, timeIndex: timeIndex)
            
            // Trigger widget refresh
            WidgetCenter.shared.reloadTimelines(ofKind: "SupplementWidget")
            
            return true
        } catch {
            print("❌ Widget: Network error - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Update supplement data locally after toggle
    private func updateSupplementLocally(supplementId: String, timeIndex: Int?) {
        var supplements = loadSupplements()
        
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
                updatedDoseStatuses[doseIndex] = WidgetDoseStatus(
                    supplementId: supplementId,
                    timeIndex: dose.timeIndex,
                    time: dose.time,
                    isTaken: !dose.isTaken
                )
            }
        } else {
            // Single-dose: toggle all doses
            updatedDoseStatuses = updatedDoseStatuses.map { dose in
                WidgetDoseStatus(
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
        let updatedSupplement = WidgetSupplement(
            id: supplement.id,
            name: supplement.name,
            type: supplement.type,
            reminderTimes: supplement.reminderTimes,
            isTakenToday: allTaken,
            doseStatuses: updatedDoseStatuses
        )
        
        supplements[index] = updatedSupplement
        saveSupplements(supplements)
    }
}

// MARK: - FoodSupplementItem Extension (Main App Only)

#if !WIDGET_EXTENSION
import SwiftUI

extension FoodSupplementItem {
    /// Convert to widget-compatible supplement model
    func toWidgetSupplement() -> WidgetSupplement {
        // Convert dose statuses
        let widgetDoseStatuses: [WidgetDoseStatus]
        
        if let doseStatuses = doseStatusesToday, !doseStatuses.isEmpty {
            widgetDoseStatuses = doseStatuses.map { dose in
                WidgetDoseStatus(
                    supplementId: self.id,
                    timeIndex: dose.timeIndex,
                    time: dose.time ?? reminderTimes[safe: dose.timeIndex] ?? "",
                    isTaken: dose.isTaken
                )
            }
        } else if !reminderTimes.isEmpty {
            // Single dose item - create one dose status
            widgetDoseStatuses = [
                WidgetDoseStatus(
                    supplementId: self.id,
                    timeIndex: 0,
                    time: reminderTimes.first ?? "",
                    isTaken: isTakenToday
                )
            ]
        } else {
            widgetDoseStatuses = []
        }
        
        return WidgetSupplement(
            id: self.id,
            name: self.name,
            type: self.type.rawValue,
            reminderTimes: self.reminderTimes,
            isTakenToday: self.isTakenToday,
            doseStatuses: widgetDoseStatuses
        )
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
#endif
