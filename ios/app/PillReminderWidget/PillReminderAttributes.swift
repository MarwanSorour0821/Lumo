//
//  PillReminderAttributes.swift
//  PillReminderWidget
//
//  Activity Attributes for Pill Reminder Live Activity (Dynamic Island)
//  This file is shared between the main app and the widget extension
//

import Foundation
import ActivityKit

/// Activity Attributes for the Pill Reminder Live Activity
struct PillReminderAttributes: ActivityAttributes {

    /// Dynamic content that can change during the activity
    public struct ContentState: Codable, Hashable {
        /// Current pill name
        var pillName: String

        /// Scheduled time for the pill
        var scheduledTime: Date

        /// Previous pill name (if any)
        var previousPillName: String?

        /// Whether the reminder is active (not yet taken or skipped)
        var isActive: Bool

        /// Time remaining until scheduled time (computed)
        var minutesRemaining: Int {
            let remaining = Int(scheduledTime.timeIntervalSinceNow / 60)
            return max(0, remaining)
        }

        /// Formatted scheduled time
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: scheduledTime)
        }
    }

    /// The item ID for the medication/supplement
    var itemId: String

    /// Item type (supplement or medication)
    var itemType: String

    /// Dose index (for multi-dose items)
    var doseIndex: Int
}
