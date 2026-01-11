//
//  NotificationManager.swift
//  app
//
//  Manages local notifications with actionable buttons for medication reminders
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Manager
class NotificationManager: NSObject {
    static let shared = NotificationManager()

    // Notification category identifier
    static let medicationReminderCategory = "MEDICATION_REMINDER"

    // Action identifiers
    static let takenActionIdentifier = "TAKEN_ACTION"
    static let didntTakeActionIdentifier = "DIDNT_TAKE_ACTION"

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Register notification categories with actions
    func registerNotificationCategories() {
        // Define actions
        let takenAction = UNNotificationAction(
            identifier: NotificationManager.takenActionIdentifier,
            title: "Taken",
            options: [.foreground]
        )

        let didntTakeAction = UNNotificationAction(
            identifier: NotificationManager.didntTakeActionIdentifier,
            title: "Didn't Take",
            options: []
        )

        // Define the category with actions
        let medicationCategory = UNNotificationCategory(
            identifier: NotificationManager.medicationReminderCategory,
            actions: [takenAction, didntTakeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([medicationCategory])
        print("✅ Notification categories registered")
    }

    /// Request notification permissions including critical alerts
    func requestPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            // Request authorization with critical alerts
            let granted = try await center.requestAuthorization(options: [
                .alert,
                .sound,
                .badge,
                .criticalAlert
            ])

            if granted {
                print("✅ Notification permissions granted (including critical alerts)")
            } else {
                print("⚠️ Notification permissions denied")
            }

            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if notifications are authorized
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Check if critical alerts are enabled
    func checkCriticalAlertsEnabled() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.criticalAlertSetting == .enabled
    }

    // MARK: - Handle Notification Actions

    /// Handle when user taps on a notification action
    func handleNotificationAction(
        actionIdentifier: String,
        itemId: String,
        completion: @escaping () -> Void
    ) {
        switch actionIdentifier {
        case NotificationManager.takenActionIdentifier:
            // User tapped "Taken" - mark the item as taken
            Task {
                await markItemAsTaken(itemId: itemId)
                completion()
            }

        case NotificationManager.didntTakeActionIdentifier:
            // User tapped "Didn't Take" - do nothing, just dismiss
            print("📝 User tapped 'Didn't Take' for item: \(itemId)")
            completion()

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            print("📝 User tapped notification for item: \(itemId)")
            completion()

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            print("📝 User dismissed notification for item: \(itemId)")
            completion()

        default:
            completion()
        }
    }

    /// Mark an item as taken by calling the API
    private func markItemAsTaken(itemId: String) async {
        print("📝 Marking item as taken: \(itemId)")

        do {
            let response = try await LoggingService.shared.toggleTaken(itemId: itemId)

            // Update local state if needed
            await MainActor.run {
                if let index = LoggingViewModel.shared.items.firstIndex(where: { $0.id == itemId }) {
                    LoggingViewModel.shared.items[index] = response.item
                }
            }

            print("✅ Item marked as taken via notification action")

            // Haptic feedback
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            print("❌ Failed to mark item as taken: \(error.localizedDescription)")
        }
    }

    // MARK: - Schedule Notifications

    /// Schedule a medication reminder notification
    /// - Parameters:
    ///   - itemId: The unique ID of the medication/supplement item
    ///   - itemName: The display name of the item
    ///   - itemType: "supplement" or "medication"
    ///   - hour: Hour of the reminder (0-23)
    ///   - minute: Minute of the reminder (0-59)
    ///   - weekday: Day of the week (1=Sunday, 7=Saturday)
    ///   - timeIndex: Index of this time in the list of reminder times (for multiple times per day)
    ///   - startDate: Optional start date for the reminder schedule
    ///   - endDate: Optional end date for the reminder schedule
    func scheduleReminder(
        itemId: String,
        itemName: String,
        itemType: String,
        hour: Int,
        minute: Int,
        weekday: Int,
        timeIndex: Int = 0,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        // Determine the start date (use provided or today)
        let effectiveStartDate = startDate ?? calendar.startOfDay(for: Date())
        let today = calendar.startOfDay(for: Date())
        let actualStartDate = effectiveStartDate > today ? effectiveStartDate : today

        // Format time for display
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        var timeComponents = DateComponents()
        timeComponents.hour = hour
        timeComponents.minute = minute
        let timeString = calendar.date(from: timeComponents).map { timeFormatter.string(from: $0) } ?? "\(hour):\(minute)"

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to take \(itemName)"
        content.body = "Don't forget your \(itemType)! (\(timeString))"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.medicationReminderCategory

        // Store the item ID in userInfo so we can use it when handling actions
        content.userInfo = ["itemId": itemId]

        // If there's an end date, schedule individual notifications for each occurrence
        if let endDate = endDate {
            let endDateStartOfDay = calendar.startOfDay(for: endDate)

            // Calculate all occurrences between start and end dates
            var occurrences: [Date] = []
            var currentDate = actualStartDate

            while currentDate <= endDateStartOfDay {
                // Get the weekday component (1 = Sunday, 2 = Monday, etc.)
                let currentWeekday = calendar.component(.weekday, from: currentDate)

                // If this day matches the reminder weekday
                if currentWeekday == weekday {
                    // Create a date with the specified hour and minute
                    var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                    components.hour = hour
                    components.minute = minute
                    components.second = 0

                    if let notificationDate = calendar.date(from: components), notificationDate >= Date() {
                        occurrences.append(notificationDate)
                    }
                }

                // Move to next day
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }

            // Schedule individual notifications for each occurrence
            for (index, occurrenceDate) in occurrences.enumerated() {
                let timeInterval = occurrenceDate.timeIntervalSinceNow

                // Only schedule if the date is in the future
                guard timeInterval > 0 else { continue }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                // Include timeIndex in the request ID for multiple times per day
                let requestId = "\(itemId)_time\(timeIndex)_day\(weekday)_\(index)_\(Int(occurrenceDate.timeIntervalSince1970))"

                let request = UNNotificationRequest(
                    identifier: requestId,
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    print("✅ Scheduled notification for \(itemName) on \(occurrenceDate) at \(hour):\(minute) (time \(timeIndex + 1))")
                } catch {
                    print("❌ Failed to schedule notification: \(error.localizedDescription)")
                }
            }

            if !occurrences.isEmpty {
                print("✅ Scheduled \(occurrences.count) notifications for \(itemName) at time slot \(timeIndex + 1) until \(endDateStartOfDay)")
            }
        } else {
            // No end date - use repeating notifications as before
            // Create date components for the trigger
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday // 1 = Sunday, 2 = Monday, etc.

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            // Create the request with a unique identifier that includes timeIndex
            let requestId = "\(itemId)_time\(timeIndex)_day\(weekday)"
            let request = UNNotificationRequest(
                identifier: requestId,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                print("✅ Scheduled repeating notification for \(itemName) on weekday \(weekday) at \(hour):\(minute) (time \(timeIndex + 1))")
            } catch {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    /// Cancel all reminders for an item
    func cancelReminders(for itemId: String) async {
        let center = UNUserNotificationCenter.current()
        
        // Get all pending notifications
        let pendingRequests = await center.pendingNotificationRequests()
        
        // Filter notifications that belong to this item
        let itemNotificationIds = pendingRequests.compactMap { request -> String? in
            // Check if the notification ID starts with the item ID
            // IDs can be in format: "\(itemId)_day\(weekday)" or "\(itemId)_day\(weekday)_\(index)_\(timestamp)"
            if request.identifier.hasPrefix("\(itemId)_") {
                return request.identifier
            }
            return nil
        }
        
        if !itemNotificationIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: itemNotificationIds)
            print("🗑️ Cancelled \(itemNotificationIds.count) reminders for item: \(itemId)")
        } else {
            // Fallback: try the old format for backwards compatibility
            let identifiers = (1...7).map { "\(itemId)_day\($0)" }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            print("🗑️ Cancelled reminders for item: \(itemId) (fallback)")
        }
    }
    
    /// Cancel ALL medication reminders (used when subscription ends)
    func cancelAllMedicationReminders() async {
        let center = UNUserNotificationCenter.current()
        
        // Get all pending notifications
        let pendingRequests = await center.pendingNotificationRequests()
        
        // Filter notifications that are medication reminders
        // Medication reminder IDs contain item IDs, so we need to identify them differently
        // We'll check the category identifier in userInfo or check all notifications
        // Since we can't easily filter by category, we'll remove all notifications
        // that match the medication reminder pattern (contain item IDs from the database)
        
        // Get all item IDs from LoggingViewModel to identify which notifications to cancel
        let allItemIds = await MainActor.run {
            LoggingViewModel.shared.items.map { $0.id }
        }
        
        // Find all notification IDs that belong to any medication item
        var notificationIdsToRemove: [String] = []
        
        for request in pendingRequests {
            // Check if this notification belongs to any medication item
            for itemId in allItemIds {
                if request.identifier.hasPrefix("\(itemId)_") {
                    notificationIdsToRemove.append(request.identifier)
                    break
                }
            }
        }
        
        if !notificationIdsToRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: notificationIdsToRemove)
            print("🗑️ Cancelled all \(notificationIdsToRemove.count) medication reminders due to subscription cancellation")
        } else {
            // Fallback: remove all pending notifications if we can't identify them
            // This is a last resort - be careful with this
            print("⚠️ No medication reminders found to cancel, or unable to identify them")
        }
    }
}
