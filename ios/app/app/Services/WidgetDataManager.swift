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
