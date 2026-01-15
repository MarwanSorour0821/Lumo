//
//  NotificationManager.swift
//  app
//
//  Manages local notifications with actionable buttons for medication reminders
//

import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Level
enum NotificationLevel: String, CaseIterable, Identifiable {
    case standard = "standard"
    case timeSensitive = "time_sensitive"
    case critical = "critical"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .timeSensitive: return "Time Sensitive"
        case .critical: return "Critical Alerts"
        }
    }
    
    var description: String {
        switch self {
        case .standard:
            return "Notifications appear normally and respect your Focus modes. May be silenced when Do Not Disturb is on."
        case .timeSensitive:
            return "Breaks through Focus modes to ensure you see your reminders. Best for workplace environments where you need discrete but reliable alerts."
        case .critical:
            return "Always plays sound even when muted or in Focus mode. Use for essential medications that must never be missed."
        }
    }
    
    var icon: String {
        switch self {
        case .standard: return "bell"
        case .timeSensitive: return "bell.badge"
        case .critical: return "bell.badge.fill"
        }
    }
    
    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .standard: return .active
        case .timeSensitive: return .timeSensitive
        case .critical: return .critical
        }
    }
}

// MARK: - Notification Type
enum MedicationNotificationType: String {
    case onTime = "ontime"      // At the scheduled time
}

// MARK: - Notification Manager
class NotificationManager: NSObject {
    static let shared = NotificationManager()

    // Notification category identifier
    static let medicationReminderCategory = "MEDICATION_REMINDER"

    // Action identifiers
    static let takenActionIdentifier = "TAKEN_ACTION"
    static let didntTakeActionIdentifier = "DIDNT_TAKE_ACTION"
    static let snoozeActionIdentifier = "SNOOZE_ACTION"
    
    // UserDefaults keys
    private let notificationLevelKey = "notification_level"

    private override init() {
        super.init()
    }
    
    // MARK: - Notification Level Preference
    
    /// Get the current notification level preference
    var notificationLevel: NotificationLevel {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: notificationLevelKey),
               let level = NotificationLevel(rawValue: rawValue) {
                return level
            }
            return .timeSensitive // Default to time sensitive
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: notificationLevelKey)
        }
    }

    // MARK: - Setup

    /// Register notification categories with actions
    func registerNotificationCategories() {
        // Define actions for reminders
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

        // Define the medication reminder category
        let medicationCategory = UNNotificationCategory(
            identifier: NotificationManager.medicationReminderCategory,
            actions: [takenAction, didntTakeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register category
        UNUserNotificationCenter.current().setNotificationCategories([medicationCategory])
        print("✅ Notification categories registered")
    }

    /// Request notification permissions based on selected level
    func requestPermissions(for level: NotificationLevel? = nil) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let selectedLevel = level ?? notificationLevel

        do {
            var options: UNAuthorizationOptions = [.alert, .sound, .badge]
            
            // Add critical alert option if that's the selected level
            if selectedLevel == .critical {
                options.insert(.criticalAlert)
            }
            
            let granted = try await center.requestAuthorization(options: options)

            if granted {
                print("✅ Notification permissions granted for level: \(selectedLevel.displayName)")
                // Save the selected level
                notificationLevel = selectedLevel
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
            // User tapped "Taken" - mark the item as taken
            Task {
                await markItemAsTaken(itemId: itemId)
                completion()
            }

        case NotificationManager.didntTakeActionIdentifier:
            // User tapped "Skip"
            print("📝 User skipped medication for item: \(itemId)")
            completion()

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
        content.sound = notificationLevel == .critical ? .defaultCritical : .default
        content.categoryIdentifier = NotificationManager.medicationReminderCategory
        content.interruptionLevel = notificationLevel.interruptionLevel
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

    /// Schedule medication reminder notification (on-time only)
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
        print("🔔 NotificationManager.scheduleReminder called:")
        print("   itemName: \(itemName)")
        print("   hour: \(hour), minute: \(minute)")
        print("   weekday: \(weekday) (1=Sun, 7=Sat)")
        print("   startDate: \(String(describing: startDate))")
        print("   endDate: \(String(describing: endDate))")
        print("   notificationLevel: \(notificationLevel.displayName)")
        
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

        // Create a unique time identifier
        let scheduledTimeId = "\(hour)_\(minute)"

        // If there's an end date, schedule individual notifications for each occurrence
        if let endDate = endDate {
            print("   📅 Has end date - using time-interval based scheduling")
            let endDateStartOfDay = calendar.startOfDay(for: endDate)
            print("   actualStartDate: \(actualStartDate)")
            print("   endDateStartOfDay: \(endDateStartOfDay)")

            // Calculate all occurrences between start and end dates
            var occurrences: [Date] = []
            var currentDate = actualStartDate
            var daysChecked = 0

            while currentDate <= endDateStartOfDay {
                daysChecked += 1
                // Get the weekday component (1 = Sunday, 2 = Monday, etc.)
                let currentWeekday = calendar.component(.weekday, from: currentDate)

                // If this day matches the reminder weekday
                if currentWeekday == weekday {
                    // Create a date with the specified hour and minute
                    var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                    components.hour = hour
                    components.minute = minute
                    components.second = 0

                    if let notificationDate = calendar.date(from: components) {
                        if notificationDate >= Date() {
                            occurrences.append(notificationDate)
                            print("   ✅ Added occurrence: \(notificationDate)")
                        } else {
                            print("   ⏭️ Skipped past occurrence: \(notificationDate) (now is \(Date()))")
                        }
                    }
                }

                // Move to next day
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }
            
            print("   📊 Checked \(daysChecked) days, found \(occurrences.count) future occurrences for weekday \(weekday)")

            // Schedule notifications for each occurrence
            for (index, occurrenceDate) in occurrences.enumerated() {
                await scheduleOnTimeNotification(
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
                print("✅ Scheduled \(occurrences.count) on-time notifications for \(itemName) at time slot \(timeIndex + 1) until \(endDateStartOfDay)")
            } else {
                print("⚠️ No future occurrences found for \(itemName) on weekday \(weekday)")
            }
        } else {
            print("   🔁 No end date - using repeating calendar notifications")
            // No end date - use repeating notifications
            await scheduleRepeatingOnTimeNotification(
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

    /// Schedule on-time notification for a specific date
    private func scheduleOnTimeNotification(
        center: UNUserNotificationCenter,
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledDate: Date,
        timeString: String,
        scheduledTimeId: String,
        requestIdBase: String
    ) async {
        let onTimeInterval = scheduledDate.timeIntervalSinceNow
        guard onTimeInterval > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to take \(itemName)"
        content.body = "It's time for your \(itemType)! Tap to mark as taken."
        content.sound = notificationLevel == .critical ? .defaultCritical : .default
        content.categoryIdentifier = NotificationManager.medicationReminderCategory
        content.interruptionLevel = notificationLevel.interruptionLevel
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

    /// Schedule repeating on-time notification for a specific weekday/time
    private func scheduleRepeatingOnTimeNotification(
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
        var onTimeComponents = DateComponents()
        onTimeComponents.hour = hour
        onTimeComponents.minute = minute
        onTimeComponents.weekday = weekday

        let onTimeContent = UNMutableNotificationContent()
        onTimeContent.title = "Time to take \(itemName)"
        onTimeContent.body = "It's time for your \(itemType)! Tap to mark as taken."
        onTimeContent.sound = notificationLevel == .critical ? .defaultCritical : .default
        onTimeContent.categoryIdentifier = NotificationManager.medicationReminderCategory
        onTimeContent.interruptionLevel = notificationLevel.interruptionLevel
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
    }

    /// Cancel all reminders for an item
    func cancelReminders(for itemId: String) async {
        let center = UNUserNotificationCenter.current()
        
        // Get all pending notifications
        let pendingRequests = await center.pendingNotificationRequests()
        
        // Filter notifications that belong to this item
        let itemNotificationIds = pendingRequests.compactMap { request -> String? in
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
    
    /// Debug: List all pending notifications
    func debugListPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        print("📋 ===== PENDING NOTIFICATIONS (\(pendingRequests.count) total) =====")
        for request in pendingRequests {
            let trigger = request.trigger
            var triggerDescription = "Unknown"
            
            if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
                let components = calendarTrigger.dateComponents
                triggerDescription = "Calendar: weekday=\(components.weekday ?? -1), hour=\(components.hour ?? -1), min=\(components.minute ?? -1), repeats=\(calendarTrigger.repeats)"
            } else if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
                triggerDescription = "Interval: \(intervalTrigger.timeInterval)s, repeats=\(intervalTrigger.repeats)"
            }
            
            print("  📌 ID: \(request.identifier)")
            print("     Title: \(request.content.title)")
            print("     Trigger: \(triggerDescription)")
        }
        print("📋 ===== END PENDING NOTIFICATIONS =====")
    }
    
    /// Cancel ALL pending notifications (used when user logs out or switches accounts)
    func cancelAllNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        print("🗑️ Cancelled ALL pending notifications (user logout/switch)")
    }
    
    /// Cancel ALL medication reminders (used when subscription ends)
    func cancelAllMedicationReminders() async {
        let center = UNUserNotificationCenter.current()
        
        // Get all pending notifications
        let pendingRequests = await center.pendingNotificationRequests()
        
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
            print("⚠️ No medication reminders found to cancel, or unable to identify them")
        }
    }
}
