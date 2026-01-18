//
//  NotificationManager.swift
//  app
//
//  Manages local notifications with actionable buttons for medication reminders
//  and Live Activities for Dynamic Island pill reminders
//

import Foundation
import UserNotifications
import UIKit
import ActivityKit

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
    case startLiveActivity = "startLiveActivity"  // 10 minutes before scheduled time
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
        
        // Define category for Live Activity trigger (silent, no actions)
        let liveActivityTriggerCategory = UNNotificationCategory(
            identifier: "LIVE_ACTIVITY_TRIGGER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([medicationCategory, liveActivityTriggerCategory])
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

        // Always use repeating notifications for efficiency (even with end dates)
        // We'll cancel them when the end date passes via background check
        print("   🔁 Using repeating calendar notifications (will auto-cancel after end date)")
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
            requestIdBase: "\(itemId)_time\(timeIndex)_day\(weekday)",
            endDate: endDate
        )
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
        // Include Live Activity trigger info in on-time notification
        content.userInfo = [
            "itemId": itemId,
            "itemName": itemName,
            "itemType": itemType,
            "scheduledTime": ISO8601DateFormatter().string(from: scheduledDate),
            "notificationType": MedicationNotificationType.onTime.rawValue,
            "scheduledTimeId": scheduledTimeId,
            "shouldStartLiveActivity": true // Start Live Activity when notification fires
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
    
    /// Schedule a notification to trigger Live Activity 10 minutes before scheduled time
    private func scheduleLiveActivityTrigger(
        center: UNUserNotificationCenter,
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledDate: Date,
        requestIdBase: String
    ) async {
        let tenMinutesBefore = scheduledDate.addingTimeInterval(-10 * 60)
        let triggerInterval = tenMinutesBefore.timeIntervalSinceNow
        
        guard triggerInterval > 0 else { return }
        
        let content = UNMutableNotificationContent()
        // Minimal content to ensure notification is delivered (iOS may not deliver empty notifications)
        content.title = "Reminder"
        content.body = "\(itemName) in 10 minutes"
        content.sound = nil // Silent
        // Add content-available to wake app in background (though it may not work for local notifications)
        content.userInfo = [
            "itemId": itemId,
            "itemName": itemName,
            "itemType": itemType,
            "scheduledTime": ISO8601DateFormatter().string(from: scheduledDate),
            "notificationType": MedicationNotificationType.startLiveActivity.rawValue
        ]
        // Try to make it trigger even in background by setting category
        content.categoryIdentifier = "LIVE_ACTIVITY_TRIGGER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(requestIdBase)_startLiveActivity",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ Scheduled Live Activity trigger for \(itemName) 10 minutes before scheduled time")
        } catch {
            print("❌ Failed to schedule Live Activity trigger: \(error.localizedDescription)")
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
        requestIdBase: String,
        endDate: Date? = nil
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
        
        // Find next occurrence for Live Activity scheduling
        let calendar = Calendar.current
        var scheduledTimeComponents = DateComponents()
        scheduledTimeComponents.weekday = weekday
        scheduledTimeComponents.hour = hour
        scheduledTimeComponents.minute = minute
        
        var scheduledTimeString = ""
        if let nextOccurrence = calendar.nextDate(after: Date(), matching: scheduledTimeComponents, matchingPolicy: .nextTime) {
            scheduledTimeString = ISO8601DateFormatter().string(from: nextOccurrence)
        }
        
        // Include end date in userInfo so we can cancel when it passes
        var userInfo: [String: Any] = [
            "itemId": itemId,
            "itemName": itemName,
            "itemType": itemType,
            "scheduledTime": scheduledTimeString,
            "notificationType": MedicationNotificationType.onTime.rawValue,
            "scheduledTimeId": scheduledTimeId,
            "shouldStartLiveActivity": true // Start Live Activity when notification fires
        ]
        
        if let endDate = endDate {
            userInfo["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        
        onTimeContent.userInfo = userInfo

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
    
    /// Schedule repeating Live Activity trigger (10 minutes before each occurrence)
    private func scheduleLiveActivityTriggerForRepeating(
        center: UNUserNotificationCenter,
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledTime: Date,
        liveActivityComponents: DateComponents,
        requestIdBase: String
    ) async {
        // For repeating, we'll schedule the first one, then reschedule when it fires
        let tenMinutesBefore = scheduledTime.addingTimeInterval(-10 * 60)
        let triggerInterval = tenMinutesBefore.timeIntervalSinceNow
        
        print("🕐 Repeating Live Activity: scheduledTime=\(scheduledTime), tenMinutesBefore=\(tenMinutesBefore), triggerInterval=\(triggerInterval)s")
        
        // If less than 10 minutes away, start Live Activity immediately
        if triggerInterval <= 0 {
            print("🚀 Starting Live Activity immediately for repeating reminder (less than 10 minutes away)")
            if #available(iOS 16.2, *) {
                await startPillReminderLiveActivity(
                    itemId: itemId,
                    itemName: itemName,
                    itemType: itemType,
                    scheduledTime: scheduledTime
                )
            } else {
                print("⚠️ iOS 16.2+ required for Live Activities")
            }
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "" // Silent notification
        content.body = ""
        content.sound = nil
        content.userInfo = [
            "itemId": itemId,
            "itemName": itemName,
            "itemType": itemType,
            "scheduledTime": ISO8601DateFormatter().string(from: scheduledTime),
            "notificationType": MedicationNotificationType.startLiveActivity.rawValue,
            "isRepeating": true,
            "requestIdBase": requestIdBase
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(requestIdBase)_startLiveActivity",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ Scheduled repeating Live Activity trigger for \(itemName) 10 minutes before scheduled time")
        } catch {
            print("❌ Failed to schedule Live Activity trigger: \(error.localizedDescription)")
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

    // MARK: - Live Activity Support

    /// Start a Live Activity for pill reminder (Dynamic Island)
    @available(iOS 16.2, *)
    func startPillReminderLiveActivity(
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledTime: Date,
        previousPillName: String? = nil,
        doseIndex: Int = 0
    ) async {
        print("🎯 startPillReminderLiveActivity called:")
        print("   itemId: \(itemId)")
        print("   itemName: \(itemName)")
        print("   scheduledTime: \(scheduledTime)")
        print("   timeUntil: \(scheduledTime.timeIntervalSinceNow)s")
        
        // Check if Live Activities are supported and enabled
        let authInfo = ActivityAuthorizationInfo()
        print("   Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ Live Activities are not enabled on this device")
            return
        }

        // End any existing activity
        await endAllPillReminderActivities()

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
            staleDate: Calendar.current.date(byAdding: .hour, value: 2, to: scheduledTime)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            print("✅ Started Live Activity for \(itemName) - ID: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Update existing Live Activity with new state
    @available(iOS 16.2, *)
    func updatePillReminderLiveActivity(
        itemId: String,
        pillName: String,
        scheduledTime: Date,
        previousPillName: String?,
        isActive: Bool
    ) async {
        // Find the activity for this item
        for activity in Activity<PillReminderAttributes>.activities {
            if activity.attributes.itemId == itemId {
                let updatedState = PillReminderAttributes.ContentState(
                    pillName: pillName,
                    scheduledTime: scheduledTime,
                    previousPillName: previousPillName,
                    isActive: isActive
                )

                let updatedContent = ActivityContent(
                    state: updatedState,
                    staleDate: Calendar.current.date(byAdding: .hour, value: 2, to: scheduledTime)
                )

                await activity.update(updatedContent)
                print("✅ Updated Live Activity for \(pillName)")
                return
            }
        }

        print("⚠️ No Live Activity found for item: \(itemId)")
    }

    /// End Live Activity for a specific item (when taken or skipped)
    @available(iOS 16.2, *)
    func endPillReminderLiveActivity(for itemId: String, wasTaken: Bool) async {
        for activity in Activity<PillReminderAttributes>.activities {
            if activity.attributes.itemId == itemId {
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
                print("✅ Ended Live Activity for item: \(itemId) - \(wasTaken ? "Taken" : "Skipped")")
                return
            }
        }
    }

    /// End all pill reminder Live Activities
    @available(iOS 16.2, *)
    func endAllPillReminderActivities() async {
        for activity in Activity<PillReminderAttributes>.activities {
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
        }
        print("✅ Ended all Live Activities")
    }

    /// Check if there's an active Live Activity for an item
    @available(iOS 16.2, *)
    func hasActiveLiveActivity(for itemId: String) -> Bool {
        for activity in Activity<PillReminderAttributes>.activities {
            if activity.attributes.itemId == itemId && activity.activityState == .active {
                return true
            }
        }
        return false
    }

    /// Get the previous pill name for Live Activity display
    func getPreviousPillName(currentItemId: String) async -> String? {
        return await MainActor.run {
            // Get all items sorted by their most recent log time
            let items = LoggingViewModel.shared.items

            // Find items that have been taken recently (today)
            let takenItems = items.filter { item in
                item.id != currentItemId && item.isTakenToday
            }

            // Return the most recently taken item's name
            return takenItems.first?.name
        }
    }

    /// Start Live Activity when notification fires
    func handleNotificationForLiveActivity(
        itemId: String,
        itemName: String,
        itemType: String,
        scheduledTime: Date
    ) async {
        if #available(iOS 16.2, *) {
            let previousPill = await getPreviousPillName(currentItemId: itemId)
            await startPillReminderLiveActivity(
                itemId: itemId,
                itemName: itemName,
                itemType: itemType,
                scheduledTime: scheduledTime,
                previousPillName: previousPill
            )
        }
    }
}
