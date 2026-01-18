//
//  PillReminderActivity.swift
//  app
//
//  Activity Attributes for Pill Reminder Live Activity (Dynamic Island)
//

import Foundation
import ActivityKit

/// Activity Attributes for the Pill Reminder Live Activity
struct PillReminderAttributes: ActivityAttributes {

    /// Static content that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Current pill name
        var pillName: String

        /// Scheduled time for the pill
        var scheduledTime: Date

        /// Previous pill name (if any)
        var previousPillName: String?

        /// Whether the reminder is active (not yet taken or skipped)
        var isActive: Bool

        /// Time remaining until scheduled time (computed on the widget side)
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

// MARK: - Live Activity Manager

@available(iOS 16.2, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<PillReminderAttributes>?

    private init() {}

    /// Start a new pill reminder Live Activity
    func startPillReminderActivity(
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledTime: Date,
        previousPillName: String? = nil,
        doseIndex: Int = 0
    ) async {
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities are not enabled")
            return
        }

        // End any existing activity for this item
        await endCurrentActivity()

        let attributes = PillReminderAttributes(
            itemId: itemId,
            itemType: itemType,
            doseIndex: doseIndex
        )

        let contentState = PillReminderAttributes.ContentState(
            pillName: itemName,
            scheduledTime: scheduledTime,
            previousPillName: previousPillName,
            isActive: true
        )

        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: scheduledTime)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            currentActivity = activity
            print("✅ Started Live Activity for \(itemName)")

            // Schedule automatic end after 1 hour if not interacted with
            Task {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000) // 1 hour
                await endActivity(activity: activity)
            }

        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Update the current activity state
    func updateActivity(
        pillName: String,
        scheduledTime: Date,
        previousPillName: String?,
        isActive: Bool
    ) async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }

        let updatedState = PillReminderAttributes.ContentState(
            pillName: pillName,
            scheduledTime: scheduledTime,
            previousPillName: previousPillName,
            isActive: isActive
        )

        let updatedContent = ActivityContent(
            state: updatedState,
            staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: scheduledTime)
        )

        await activity.update(updatedContent)
        print("✅ Updated Live Activity")
    }

    /// End the current activity
    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        await endActivity(activity: activity)
        currentActivity = nil
    }

    /// End a specific activity
    private func endActivity(activity: Activity<PillReminderAttributes>) async {
        let finalState = PillReminderAttributes.ContentState(
            pillName: activity.content.state.pillName,
            scheduledTime: activity.content.state.scheduledTime,
            previousPillName: activity.content.state.previousPillName,
            isActive: false
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        await activity.end(finalContent, dismissalPolicy: .immediate)
        print("✅ Ended Live Activity")
    }

    /// End activity when user takes the pill
    func markAsTaken() async {
        await endCurrentActivity()
    }

    /// End activity when user skips the pill
    func markAsSkipped() async {
        await endCurrentActivity()
    }

    /// Get the current activity's item ID
    var currentItemId: String? {
        return currentActivity?.attributes.itemId
    }

    /// Check if there's an active Live Activity
    var hasActiveActivity: Bool {
        return currentActivity != nil && currentActivity?.activityState == .active
    }
}
