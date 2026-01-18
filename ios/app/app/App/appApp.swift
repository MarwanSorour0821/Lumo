//
//  LumoApp.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Combine
import Supabase
import BackgroundTasks
import UserNotifications
import ActivityKit

// MARK: - App Delegate for Background Tasks and Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background task for blood test analysis
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lumo.analyzeBloodTest", using: nil) { task in
            self.handleBackgroundAnalysis(task: task as! BGProcessingTask)
        }
        
        // Register background task for Live Activity checks
        if #available(iOS 16.2, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lumo.checkLiveActivities", using: nil) { task in
                self.handleLiveActivityCheck(task: task as! BGAppRefreshTask)
            }
        }

        // Set up notification delegate and register categories
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerNotificationCategories()
        
        // Check for upcoming reminders and start Live Activities when app launches
        if #available(iOS 16.2, *) {
            Task {
                await checkAndStartUpcomingLiveActivities()
                // Schedule next background check
                await scheduleLiveActivityBackgroundCheck()
            }
        }

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Check for upcoming reminders and start Live Activities when app becomes active
        if #available(iOS 16.2, *) {
            Task {
                await checkAndStartUpcomingLiveActivities()
                // Schedule next background check
                await scheduleLiveActivityBackgroundCheck()
            }
        }
        
        // Cancel notifications that have passed their end date
        Task {
            await cancelExpiredNotifications()
        }
    }
    
    /// Cancel repeating notifications that have passed their end date
    private func cancelExpiredNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        let now = Date()
        
        var expiredIds: [String] = []
        
        for request in pendingRequests {
            guard let userInfo = request.content.userInfo["endDate"] as? String,
                  let endDate = ISO8601DateFormatter().date(from: userInfo) else {
                continue
            }
            
            // If end date has passed, cancel this notification
            if endDate < now {
                expiredIds.append(request.identifier)
                print("🗑️ Cancelling expired notification: \(request.identifier) (end date: \(endDate))")
            }
        }
        
        if !expiredIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: expiredIds)
            print("✅ Cancelled \(expiredIds.count) expired notifications")
        }
    }
    
    /// Schedule a background task to check for Live Activities
    @available(iOS 16.2, *)
    private func scheduleLiveActivityBackgroundCheck() async {
        let request = BGAppRefreshTaskRequest(identifier: "com.lumo.checkLiveActivities")
        // Schedule to run in 5 minutes (iOS will decide the exact time, may be delayed)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled background task to check Live Activities")
        } catch {
            print("❌ Failed to schedule background task: \(error.localizedDescription)")
        }
    }
    
    /// Handle background task to check for Live Activities
    @available(iOS 16.2, *)
    private func handleLiveActivityCheck(task: BGAppRefreshTask) {
        print("🔄 Background task: Checking for Live Activities...")
        
        // Schedule the next check
        Task {
            await scheduleLiveActivityBackgroundCheck()
        }
        
        // Check and start Live Activities
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await checkAndStartUpcomingLiveActivities()
            task.setTaskCompleted(success: true)
        }
    }
    
    /// Check for reminders that should have Live Activities started (10 minutes before scheduled time)
    @available(iOS 16.2, *)
    private func checkAndStartUpcomingLiveActivities() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled, skipping check")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        print("🔍 Checking \(pendingRequests.count) pending notifications for Live Activity triggers...")
        
        for request in pendingRequests {
            guard let notificationType = request.content.userInfo["notificationType"] as? String,
                  notificationType == MedicationNotificationType.startLiveActivity.rawValue,
                  let itemId = request.content.userInfo["itemId"] as? String,
                  let scheduledTimeStr = request.content.userInfo["scheduledTime"] as? String else {
                continue
            }
            
            // Parse scheduled time
            let isoFormatter = ISO8601DateFormatter()
            guard let scheduledTime = isoFormatter.date(from: scheduledTimeStr) else {
                print("⚠️ Could not parse scheduledTime: \(scheduledTimeStr)")
                continue
            }
            
            // Check if we're within 10 minutes of the scheduled time (or past the 10-min mark but before scheduled time)
            let timeUntilScheduled = scheduledTime.timeIntervalSinceNow
            let tenMinutesBefore = scheduledTime.addingTimeInterval(-10 * 60)
            let timeSinceTenMinBefore = tenMinutesBefore.timeIntervalSinceNow
            
            // Start Live Activity if we're past the 10-minute-before mark but before the scheduled time
            if timeSinceTenMinBefore <= 0 && timeUntilScheduled > 0 {
                print("⏰ Found reminder that should have Live Activity: \(itemId)")
                print("   Scheduled: \(scheduledTime)")
                print("   Time until scheduled: \(timeUntilScheduled)s")
                print("   Time since 10-min mark: \(timeSinceTenMinBefore)s")
                
                // Check if Live Activity already exists
                var hasActiveActivity = false
                for activity in Activity<PillReminderAttributes>.activities {
                    if activity.attributes.itemId == itemId && activity.content.state.isActive {
                        hasActiveActivity = true
                        print("   ✅ Live Activity already exists for \(itemId)")
                        break
                    }
                }
                
                if !hasActiveActivity {
                    print("🚀 Starting Live Activity for \(itemId)")
                    startLiveActivityForNotification(userInfo: request.content.userInfo, itemId: itemId)
                }
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let notificationType = userInfo["notificationType"] as? String
        
        print("🔔 willPresent notification: type=\(notificationType ?? "nil"), identifier=\(notification.request.identifier)")
        
        // Check if notification has passed its end date
        if let endDateStr = userInfo["endDate"] as? String,
           let endDate = ISO8601DateFormatter().date(from: endDateStr),
           endDate < Date() {
            // End date has passed - cancel this notification
            print("🗑️ Cancelling notification past end date: \(notification.request.identifier)")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notification.request.identifier])
            completionHandler([])
            return
        }
        
        // Start Live Activity for on-time notifications if flag is set
        if notificationType == "ontime",
           let itemId = userInfo["itemId"] as? String,
           let shouldStart = userInfo["shouldStartLiveActivity"] as? Bool,
           shouldStart {
            print("🚀 willPresent: Starting Live Activity for on-time notification itemId=\(itemId)")
            startLiveActivityForNotification(userInfo: userInfo, itemId: itemId)
        }

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification action response
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let notificationType = userInfo["notificationType"] as? String

        print("🔔 didReceive notification: type=\(notificationType ?? "nil"), identifier=\(response.notification.request.identifier), action=\(response.actionIdentifier)")

        // Extract item ID and notification metadata from userInfo
        if let itemId = userInfo["itemId"] as? String {
            let scheduledTime = userInfo["scheduledTime"] as? String
            
            // Start Live Activity for on-time notifications if flag is set
            if notificationType == "ontime",
               let shouldStart = userInfo["shouldStartLiveActivity"] as? Bool,
               shouldStart {
                print("🚀 didReceive: Starting Live Activity for on-time notification itemId=\(itemId)")
                startLiveActivityForNotification(userInfo: userInfo, itemId: itemId)
            }

            // End Live Activity if user interacted with notification
            if #available(iOS 16.2, *) {
                let wasTaken = response.actionIdentifier == NotificationManager.takenActionIdentifier
                Task {
                    await NotificationManager.shared.endPillReminderLiveActivity(for: itemId, wasTaken: wasTaken)
                }
            }

            NotificationManager.shared.handleNotificationAction(
                actionIdentifier: response.actionIdentifier,
                itemId: itemId,
                notificationType: notificationType,
                scheduledTime: scheduledTime,
                completion: completionHandler
            )
        } else {
            completionHandler()
        }
    }

    /// Start a Live Activity when a pill reminder notification fires
    private func startLiveActivityForNotification(userInfo: [AnyHashable: Any], itemId: String) {
        guard #available(iOS 16.2, *) else {
            print("⚠️ Live Activities not supported on this iOS version")
            return
        }

        print("📱 startLiveActivityForNotification called for itemId=\(itemId)")
        
        Task {
            // Parse scheduled time from userInfo
            var scheduledTime = Date()
            if let scheduledTimeStr = userInfo["scheduledTime"] as? String {
                print("   Parsing scheduledTime: \(scheduledTimeStr)")
                // Try ISO8601 format first (from startLiveActivity notification)
                let isoFormatter = ISO8601DateFormatter()
                if let date = isoFormatter.date(from: scheduledTimeStr) {
                    scheduledTime = date
                    print("   Parsed ISO8601 date: \(scheduledTime)")
                } else {
                    // Fallback to old format (hour_minute)
                    let components = scheduledTimeStr.split(separator: "_")
                    if components.count == 2,
                       let hour = Int(components[0]),
                       let minute = Int(components[1]) {
                        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                        dateComponents.hour = hour
                        dateComponents.minute = minute
                        scheduledTime = Calendar.current.date(from: dateComponents) ?? Date()
                        print("   Parsed hour_minute date: \(scheduledTime)")
                    }
                }
            } else {
                print("   ⚠️ No scheduledTime in userInfo")
            }
            
            // Get item details - try from userInfo first (for startLiveActivity), then from LoggingViewModel
            let itemName: String
            let itemType: String
            
            if let name = userInfo["itemName"] as? String,
               let type = userInfo["itemType"] as? String {
                // Use values from notification (for startLiveActivity)
                itemName = name
                itemType = type
            } else {
                // Fallback: get from LoggingViewModel
                guard let item = await MainActor.run(body: {
                    LoggingViewModel.shared.items.first(where: { $0.id == itemId })
                }) else {
                    print("⚠️ Item not found for Live Activity: \(itemId)")
                    return
                }
                itemName = item.name
                itemType = item.type.rawValue
            }

            print("   itemName=\(itemName), itemType=\(itemType), scheduledTime=\(scheduledTime)")

            // Get previous pill name
            let previousPillName = await NotificationManager.shared.getPreviousPillName(currentItemId: itemId)

            // Start the Live Activity
            await NotificationManager.shared.startPillReminderLiveActivity(
                itemId: itemId,
                itemName: itemName,
                itemType: itemType,
                scheduledTime: scheduledTime,
                previousPillName: previousPillName
            )
        }
    }
    
    func scheduleBackgroundAnalysisIfNeeded() {
        // Check if there are any pending processing items
        let hasPendingItems = AnalysisProcessingManager.shared.processingItems.contains { 
            !$0.isComplete && !$0.isCancelled && $0.error == nil 
        }
        
        if hasPendingItems {
            let request = BGProcessingTaskRequest(identifier: "com.lumo.analyzeBloodTest")
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("🔵 Background task scheduled")
            } catch {
                print("⚠️ Failed to schedule background task: \(error)")
            }
        }
    }
    
    private func handleBackgroundAnalysis(task: BGProcessingTask) {
        // Schedule a new background task in case we need more time
        scheduleBackgroundAnalysisIfNeeded()
        
        task.expirationHandler = {
            // Handle expiration - processing manager handles persistence
            print("⚠️ Background task expired")
        }
        
        // The processing manager automatically resumes pending items when initialized
        // Just mark the task as complete after a delay to allow processing to continue
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            task.setTaskCompleted(success: true)
        }
    }
}

@main
struct LumoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onOpenURL { url in
                    // Log when the app receives a deep link
                    print("🔵 App received deep link: \(url.absoluteString)")

                    // Handle pill reminder actions from Live Activity
                    handlePillReminderURL(url)
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // App is going to background - schedule background task if needed
                appDelegate.scheduleBackgroundAnalysisIfNeeded()
            case .active:
                // App became active - processing manager will resume automatically
                print("🔵 App became active")
                // Check subscription status and cancel notifications if subscription ended
                if appState.isAuthenticated {
                    Task {
                        await SubscriptionService.shared.checkAndHandleSubscriptionStatus()
                    }
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    /// Handle pill reminder URLs from Live Activity (lumo://pill-reminder/take/itemId or lumo://pill-reminder/skip/itemId)
    private func handlePillReminderURL(_ url: URL) {
        guard url.scheme == "lumo",
              url.host == "pill-reminder",
              let pathComponents = url.pathComponents.dropFirst().first else {
            return
        }

        let action = pathComponents
        let itemId = url.pathComponents.last ?? ""

        guard !itemId.isEmpty else {
            print("⚠️ Invalid pill reminder URL: missing itemId")
            return
        }

        print("🔵 Handling pill reminder action: \(action) for item: \(itemId)")

        Task {
            switch action {
            case "take":
                // Mark the pill as taken
                await handleTakePill(itemId: itemId)

            case "skip":
                // Skip the pill
                await handleSkipPill(itemId: itemId)

            default:
                print("⚠️ Unknown pill reminder action: \(action)")
            }
        }
    }

    /// Handle taking a pill from Live Activity
    private func handleTakePill(itemId: String) async {
        do {
            let response = try await LoggingService.shared.toggleTaken(itemId: itemId)

            await MainActor.run {
                if let index = LoggingViewModel.shared.items.firstIndex(where: { $0.id == itemId }) {
                    LoggingViewModel.shared.items[index] = response.item
                }

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            // End the Live Activity
            if #available(iOS 16.2, *) {
                await NotificationManager.shared.endPillReminderLiveActivity(for: itemId, wasTaken: true)
            }

            print("✅ Pill marked as taken from Live Activity")

        } catch {
            print("❌ Failed to mark pill as taken: \(error.localizedDescription)")
        }
    }

    /// Handle skipping a pill from Live Activity
    private func handleSkipPill(itemId: String) async {
        // End the Live Activity
        if #available(iOS 16.2, *) {
            await NotificationManager.shared.endPillReminderLiveActivity(for: itemId, wasTaken: false)
        }

        await MainActor.run {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        print("✅ Pill skipped from Live Activity")
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    
    init() {
        checkAuthentication()
    }
    
    func checkAuthentication() {
        Task {
            isLoading = true
            do {
                // Check if there's an existing session
                guard let client = SupabaseManager.shared.getClient() else {
                    await MainActor.run {
                        self.isAuthenticated = false
                        self.isLoading = false
                    }
                    return
                }
                
                // Try to get the current session
                let session = try? await client.auth.session
                
                let hasSession = (session != nil)
                
                await MainActor.run {
                    self.isAuthenticated = hasSession
                    self.isLoading = false
                    print("🔵 Authentication check: \(self.isAuthenticated ? "Authenticated" : "Not authenticated")")
                }
                
                // Load user data if authenticated
                if hasSession {
                    await UserDataViewModel.shared.loadAllUserData()
                    // Reset and load logging data for fresh session
                    await MainActor.run {
                        LoggingViewModel.shared.reset()
                    }
                    await LoggingViewModel.shared.refreshData()
                    // Note: We don't reschedule reminders here because iOS notifications persist across app launches
                    // Reminders are only rescheduled when:
                    // 1. User actively logs in (handled in login flows)
                    // 2. Reminders are updated (handled in updateReminder)
                    // Check subscription status and cancel notifications if subscription ended
                    await SubscriptionService.shared.checkAndHandleSubscriptionStatus()
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.isLoading = false
                    print("⚠️ Error checking authentication: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                guard let client = SupabaseManager.shared.getClient() else { return }
                try await client.auth.signOut()
                
                // Cancel all notifications before clearing data
                await NotificationManager.shared.cancelAllNotifications()
                
                await MainActor.run {
                    // Clear all user data
                    UserDataViewModel.shared.clearAllData()
                    LoggingViewModel.shared.reset()
                    self.isAuthenticated = false
                }
            } catch {
                print("⚠️ Error signing out: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .environmentObject(ThemeManager.shared)
                    .transition(.opacity)
            } else {
                if appState.isLoading {
                    // Still checking authentication
                    AppColors.background(ThemeManager.shared.colorScheme)
                        .ignoresSafeArea()
                } else if appState.isAuthenticated {
                    // User is authenticated, show home
                    HomeView()
                        .environmentObject(appState)
                        .environmentObject(ThemeManager.shared)
                        .transition(.opacity)
                } else {
                    // User is not authenticated, show onboarding
                    OnboardingView()
                        .environmentObject(appState)
                        .environmentObject(ThemeManager.shared)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Show splash for 1.5 seconds, then check authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}
