//
//  NotificationManager.swift
//  app
//
//  Manages local notifications with actionable buttons for medication reminders
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Type
enum MedicationNotificationType: String {
    case before = "before"      // 15 minutes before
    case onTime = "ontime"      // At the scheduled time
    case followUp = "followup"  // 30 minutes after (if not taken)
}

// MARK: - Notification Manager
class NotificationManager: NSObject {
    static let shared = NotificationManager()

    // Notification category identifier
    static let medicationReminderCategory = "MEDICATION_REMINDER"
    static let medicationFollowUpCategory = "MEDICATION_FOLLOWUP"

    // Action identifiers
    static let takenActionIdentifier = "TAKEN_ACTION"
    static let didntTakeActionIdentifier = "DIDNT_TAKE_ACTION"
    static let snoozeActionIdentifier = "SNOOZE_ACTION"

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Register notification categories with actions
    func registerNotificationCategories() {
        // Define actions for main reminders
        let takenAction = UNNotificationAction(
            identifier: NotificationManager.takenActionIdentifier,
            title: "Taken ✓",
            options: [.foreground]
        )

        let didntTakeAction = UNNotificationAction(
            identifier: NotificationManager.didntTakeActionIdentifier,
            title: "Skip",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: NotificationManager.snoozeActionIdentifier,
            title: "Remind in 10 min",
            options: []
        )

        // Define the main medication reminder category
        let medicationCategory = UNNotificationCategory(
            identifier: NotificationManager.medicationReminderCategory,
            actions: [takenAction, didntTakeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Define the follow-up category (30 min after)
        let followUpCategory = UNNotificationCategory(
            identifier: NotificationManager.medicationFollowUpCategory,
            actions: [takenAction, didntTakeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register both categories
        UNUserNotificationCenter.current().setNotificationCategories([medicationCategory, followUpCategory])
        print("✅ Notification categories registered (main + follow-up)")
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

    /// Check if notifications are enabled (authorized or provisional)
    func areNotificationsEnabled() async -> Bool {
        let status = await checkPermissionStatus()
        return status == .authorized || status == .provisional
    }

    /// Open the app's notification settings in iOS Settings
    func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }

    // MARK: - Handle Notification Actions

    /// Handle when user taps on a notification action
    func handleNotificationAction(
        actionIdentifier: String,
        itemId: String,
        notificationType: String? = nil,
        scheduledTime: String? = nil,
        completion: @escaping () -> Void
    ) {
        switch actionIdentifier {
        case NotificationManager.takenActionIdentifier:
            // User tapped "Taken" - mark the item as taken and cancel follow-up
            Task {
                await markItemAsTaken(itemId: itemId)
                // Cancel any pending follow-up notifications for this item
                await cancelFollowUpNotifications(for: itemId, scheduledTime: scheduledTime)
                completion()
            }

        case NotificationManager.didntTakeActionIdentifier:
            // User tapped "Skip" - cancel follow-up notifications
            print("📝 User skipped medication for item: \(itemId)")
            Task {
                await cancelFollowUpNotifications(for: itemId, scheduledTime: scheduledTime)
                completion()
            }

        case NotificationManager.snoozeActionIdentifier:
            // User wants to be reminded in 10 minutes
            print("📝 User requested snooze for item: \(itemId)")
            Task {
                await scheduleSnoozeReminder(itemId: itemId)
            completion()
            }

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

    /// Schedule a snooze reminder (10 minutes from now)
    private func scheduleSnoozeReminder(itemId: String) async {
        let center = UNUserNotificationCenter.current()

        // Get item name from LoggingViewModel
        let itemName = await MainActor.run {
            LoggingViewModel.shared.items.first(where: { $0.id == itemId })?.name ?? "your medication"
        }

        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(itemName)"
        content.body = "You asked to be reminded again. Time to take your medication!"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.medicationReminderCategory
        content.userInfo = ["itemId": itemId, "notificationType": MedicationNotificationType.onTime.rawValue]

        // Schedule for 10 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let requestId = "\(itemId)_snooze_\(Int(Date().timeIntervalSince1970))"

        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("✅ Scheduled snooze reminder for \(itemName) in 10 minutes")
        } catch {
            print("❌ Failed to schedule snooze reminder: \(error.localizedDescription)")
        }
    }

    /// Cancel follow-up notifications for a specific item
    func cancelFollowUpNotifications(for itemId: String, scheduledTime: String? = nil) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()

        // Find all follow-up notifications for this item
        let followUpIds = pendingRequests.compactMap { request -> String? in
            if request.identifier.contains(itemId) && request.identifier.contains("_followup") {
                // If we have a specific scheduled time, only cancel that one
                if let time = scheduledTime {
                    if request.identifier.contains(time) {
                        return request.identifier
                    }
                    return nil
                }
                return request.identifier
            }
            return nil
        }

        if !followUpIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: followUpIds)
            print("🗑️ Cancelled \(followUpIds.count) follow-up notification(s) for item: \(itemId)")
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

            // Cancel any pending follow-up notifications for this item
            await cancelFollowUpNotifications(for: itemId)

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

    /// Schedule medication reminder notifications (15 min before, on-time, and 30 min after)
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

        // Create a unique time identifier for cancellation purposes
        let scheduledTimeId = "\(hour)_\(minute)"

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

            // Schedule notifications for each occurrence (3 per occurrence)
            for (index, occurrenceDate) in occurrences.enumerated() {
                await scheduleThreeNotifications(
                    center: center,
                    itemId: itemId,
                    itemName: itemName,
                    itemType: itemType,
                    scheduledDate: occurrenceDate,
                    timeString: timeString,
                    scheduledTimeId: scheduledTimeId,
                    requestIdBase: "\(itemId)_time\(timeIndex)_day\(weekday)_\(index)_\(Int(occurrenceDate.timeIntervalSince1970))"
                )
            }

            if !occurrences.isEmpty {
                print("✅ Scheduled \(occurrences.count * 3) notifications (3 per time) for \(itemName) at time slot \(timeIndex + 1) until \(endDateStartOfDay)")
            }
        } else {
            // No end date - use repeating notifications
            await scheduleRepeatingThreeNotifications(
                center: center,
                itemId: itemId,
                itemName: itemName,
                itemType: itemType,
                hour: hour,
                minute: minute,
                weekday: weekday,
                timeString: timeString,
                scheduledTimeId: scheduledTimeId,
                requestIdBase: "\(itemId)_time\(timeIndex)_day\(weekday)"
            )
        }
    }

    /// Schedule 3 notifications for a specific date: 15 min before, on-time, 30 min after
    private func scheduleThreeNotifications(
        center: UNUserNotificationCenter,
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledDate: Date,
        timeString: String,
        scheduledTimeId: String,
        requestIdBase: String
    ) async {
        let calendar = Calendar.current

        // 1. Schedule 15 minutes BEFORE
        if let beforeDate = calendar.date(byAdding: .minute, value: -15, to: scheduledDate) {
            let timeInterval = beforeDate.timeIntervalSinceNow
            if timeInterval > 0 {
                let content = UNMutableNotificationContent()
                content.title = "Coming up: \(itemName)"
                content.body = "Heads up! Time to take your \(itemType) in 15 minutes (\(timeString))"
                content.sound = .default
                content.categoryIdentifier = NotificationManager.medicationReminderCategory
                content.userInfo = [
                    "itemId": itemId,
                    "notificationType": MedicationNotificationType.before.rawValue,
                    "scheduledTime": scheduledTimeId
                ]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(requestIdBase)_before",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    print("✅ Scheduled 15-min before notification for \(itemName)")
                } catch {
                    print("❌ Failed to schedule before notification: \(error.localizedDescription)")
                }
            }
        }

        // 2. Schedule ON-TIME notification
        let onTimeInterval = scheduledDate.timeIntervalSinceNow
        if onTimeInterval > 0 {
            let content = UNMutableNotificationContent()
            content.title = "Time to take \(itemName)"
            content.body = "It's time for your \(itemType)! Tap to mark as taken."
            content.sound = .default
            content.categoryIdentifier = NotificationManager.medicationReminderCategory
            content.userInfo = [
                "itemId": itemId,
                "notificationType": MedicationNotificationType.onTime.rawValue,
                "scheduledTime": scheduledTimeId
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: onTimeInterval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(requestIdBase)_ontime",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                print("✅ Scheduled on-time notification for \(itemName)")
            } catch {
                print("❌ Failed to schedule on-time notification: \(error.localizedDescription)")
            }
        }

        // 3. Schedule 30 minutes AFTER (follow-up if not taken)
        if let afterDate = calendar.date(byAdding: .minute, value: 30, to: scheduledDate) {
            let timeInterval = afterDate.timeIntervalSinceNow
            if timeInterval > 0 {
                let content = UNMutableNotificationContent()
                content.title = "Did you take \(itemName)?"
                content.body = "You haven't marked your \(itemType) as taken yet. Don't forget!"
                content.sound = .default
                content.categoryIdentifier = NotificationManager.medicationFollowUpCategory
                content.userInfo = [
                    "itemId": itemId,
                    "notificationType": MedicationNotificationType.followUp.rawValue,
                    "scheduledTime": scheduledTimeId
                ]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(requestIdBase)_followup",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    print("✅ Scheduled 30-min follow-up notification for \(itemName)")
                } catch {
                    print("❌ Failed to schedule follow-up notification: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Schedule 3 repeating notifications for a specific weekday/time
    private func scheduleRepeatingThreeNotifications(
        center: UNUserNotificationCenter,
        itemId: String,
        itemName: String,
        itemType: String,
        hour: Int,
        minute: Int,
        weekday: Int,
        timeString: String,
        scheduledTimeId: String,
        requestIdBase: String
    ) async {
        let calendar = Calendar.current

        // Calculate before time (15 minutes earlier)
        var beforeHour = hour
        var beforeMinute = minute - 15
        if beforeMinute < 0 {
            beforeMinute += 60
            beforeHour -= 1
            if beforeHour < 0 {
                beforeHour = 23
            }
        }

        // Calculate after time (30 minutes later)
        var afterHour = hour
        var afterMinute = minute + 30
        if afterMinute >= 60 {
            afterMinute -= 60
            afterHour += 1
            if afterHour >= 24 {
                afterHour = 0
            }
        }

        // 1. Schedule 15 minutes BEFORE (repeating)
        var beforeComponents = DateComponents()
        beforeComponents.hour = beforeHour
        beforeComponents.minute = beforeMinute
        beforeComponents.weekday = weekday

        let beforeContent = UNMutableNotificationContent()
        beforeContent.title = "Coming up: \(itemName)"
        beforeContent.body = "Heads up! Time to take your \(itemType) in 15 minutes (\(timeString))"
        beforeContent.sound = .default
        beforeContent.categoryIdentifier = NotificationManager.medicationReminderCategory
        beforeContent.userInfo = [
            "itemId": itemId,
            "notificationType": MedicationNotificationType.before.rawValue,
            "scheduledTime": scheduledTimeId
        ]

        let beforeTrigger = UNCalendarNotificationTrigger(dateMatching: beforeComponents, repeats: true)
        let beforeRequest = UNNotificationRequest(
            identifier: "\(requestIdBase)_before",
            content: beforeContent,
            trigger: beforeTrigger
        )

        do {
            try await center.add(beforeRequest)
            print("✅ Scheduled repeating 15-min before notification for \(itemName) on weekday \(weekday)")
        } catch {
            print("❌ Failed to schedule before notification: \(error.localizedDescription)")
        }

        // 2. Schedule ON-TIME notification (repeating)
        var onTimeComponents = DateComponents()
        onTimeComponents.hour = hour
        onTimeComponents.minute = minute
        onTimeComponents.weekday = weekday

        let onTimeContent = UNMutableNotificationContent()
        onTimeContent.title = "Time to take \(itemName)"
        onTimeContent.body = "It's time for your \(itemType)! Tap to mark as taken."
        onTimeContent.sound = .default
        onTimeContent.categoryIdentifier = NotificationManager.medicationReminderCategory
        onTimeContent.userInfo = [
            "itemId": itemId,
            "notificationType": MedicationNotificationType.onTime.rawValue,
            "scheduledTime": scheduledTimeId
        ]

        let onTimeTrigger = UNCalendarNotificationTrigger(dateMatching: onTimeComponents, repeats: true)
        let onTimeRequest = UNNotificationRequest(
            identifier: "\(requestIdBase)_ontime",
            content: onTimeContent,
            trigger: onTimeTrigger
        )

        do {
            try await center.add(onTimeRequest)
            print("✅ Scheduled repeating on-time notification for \(itemName) on weekday \(weekday) at \(hour):\(minute)")
        } catch {
            print("❌ Failed to schedule on-time notification: \(error.localizedDescription)")
        }

        // 3. Schedule 30 minutes AFTER (repeating follow-up)
        var afterComponents = DateComponents()
        afterComponents.hour = afterHour
        afterComponents.minute = afterMinute
        afterComponents.weekday = weekday

        let afterContent = UNMutableNotificationContent()
        afterContent.title = "Did you take \(itemName)?"
        afterContent.body = "You haven't marked your \(itemType) as taken yet. Don't forget!"
        afterContent.sound = .default
        afterContent.categoryIdentifier = NotificationManager.medicationFollowUpCategory
        afterContent.userInfo = [
            "itemId": itemId,
            "notificationType": MedicationNotificationType.followUp.rawValue,
            "scheduledTime": scheduledTimeId
        ]

        let afterTrigger = UNCalendarNotificationTrigger(dateMatching: afterComponents, repeats: true)
        let afterRequest = UNNotificationRequest(
            identifier: "\(requestIdBase)_followup",
            content: afterContent,
            trigger: afterTrigger
        )

        do {
            try await center.add(afterRequest)
            print("✅ Scheduled repeating 30-min follow-up notification for \(itemName) on weekday \(weekday)")
        } catch {
            print("❌ Failed to schedule follow-up notification: \(error.localizedDescription)")
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
