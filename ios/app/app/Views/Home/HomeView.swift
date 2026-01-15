//
//  HomeView.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Supabase
import UIKit
import UniformTypeIdentifiers
import WebKit
import UserNotifications
import Photos
import AVFoundation
import Combine
import StoreKit

extension Notification.Name {
    static let switchTab = Notification.Name("SwitchTabNotification")
}

// MARK: - Identifiable URL Wrapper for sheet(item:)
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Persistent Processing Analysis Item
struct ProcessingAnalysis: Identifiable, Codable {
    let id: String
    let fileName: String
    let startTime: Date
    var progress: Double
    var isComplete: Bool
    var isCancelled: Bool
    var error: String?
    var fileData: Data? // Store file data for persistence
    var fileType: String? // "image" or "pdf"
    
    // Not persisted - set at runtime
    var analysisData: AnalysisData?
    
    enum CodingKeys: String, CodingKey {
        case id, fileName, startTime, progress, isComplete, isCancelled, error, fileData, fileType
    }
}

// MARK: - Analysis Processing Manager (Persistent & Robust)
class AnalysisProcessingManager: ObservableObject {
    static let shared = AnalysisProcessingManager()
    
    @Published var processingItems: [ProcessingAnalysis] = []
    
    private let userDefaultsKey = "ProcessingAnalysisItems"
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var progressTimers: [String: Timer] = [:]
    private let queue = DispatchQueue(label: "com.lumo.processingManager", qos: .userInitiated)
    
    private init() {
        requestNotificationPermission()
        loadPersistedItems()
        resumePendingProcessing()
    }
    
    // MARK: - Persistence
    
    private func loadPersistedItems() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let items = try? JSONDecoder().decode([ProcessingAnalysis].self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            // Filter out items older than 24 hours or completed items without errors
            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
            self.processingItems = items.filter { item in
                // Keep if: not older than 24 hours AND (not complete OR has error OR is cancelled)
                item.startTime > cutoffDate && (!item.isComplete || item.error != nil || item.isCancelled)
            }
            self.savePersistedItems()
        }
    }
    
    private func savePersistedItems() {
        queue.async {
            // Only persist items that are still processing or have errors
            let itemsToSave = self.processingItems.filter { !$0.isComplete || $0.error != nil || $0.isCancelled }
            if let data = try? JSONEncoder().encode(itemsToSave) {
                UserDefaults.standard.set(data, forKey: self.userDefaultsKey)
            }
        }
    }
    
    private func resumePendingProcessing() {
        // Resume any items that were processing when app closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            for item in self.processingItems {
                if !item.isComplete && !item.isCancelled && item.error == nil {
                    // Resume processing if we have file data
                    if let fileData = item.fileData, let fileType = item.fileType {
                        self.resumeProcessing(for: item.id, fileData: fileData, fileType: fileType)
                    } else {
                        // Can't resume without file data - mark as failed
                        self.failProcessing(for: item.id, error: "Unable to resume - file data lost. Please try again.")
                    }
                }
            }
        }
    }
    
    // MARK: - Notification Permission
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            }
        }
    }
    
    // MARK: - Add Processing Item
    
    func addProcessingItem(id: String, fileName: String, fileData: Data?, fileType: String?) {
        let item = ProcessingAnalysis(
            id: id,
            fileName: fileName,
            startTime: Date(),
            progress: 0.0,
            isComplete: false,
            isCancelled: false,
            error: nil,
            fileData: fileData,
            fileType: fileType,
            analysisData: nil
        )
        DispatchQueue.main.async {
            self.processingItems.insert(item, at: 0)
            self.savePersistedItems()
        }
        startProgressSimulation(for: id)
    }
    
    // MARK: - Update Progress
    
    func updateProgress(for id: String, progress: Double) {
        DispatchQueue.main.async {
            if let index = self.processingItems.firstIndex(where: { $0.id == id }) {
                self.processingItems[index].progress = progress
            }
        }
    }
    
    // MARK: - Complete Processing
    
    func completeProcessing(for id: String, analysisData: AnalysisData) {
        // Stop any timers
        progressTimers[id]?.invalidate()
        progressTimers.removeValue(forKey: id)
        activeTasks.removeValue(forKey: id)
        
        let fileName = processingItems.first(where: { $0.id == id })?.fileName ?? "Blood Test"
        
        DispatchQueue.main.async {
            if let index = self.processingItems.firstIndex(where: { $0.id == id }) {
                self.processingItems[index].progress = 1.0
                self.processingItems[index].isComplete = true
                self.processingItems[index].analysisData = analysisData
                self.processingItems[index].fileData = nil // Clear file data to save memory
            }
            self.savePersistedItems()
        }
        
        sendCompletionNotification(fileName: fileName, success: true)
    }
    
    // MARK: - Fail Processing
    
    func failProcessing(for id: String, error: String) {
        // Stop any timers
        progressTimers[id]?.invalidate()
        progressTimers.removeValue(forKey: id)
        activeTasks.removeValue(forKey: id)
        
        let fileName = processingItems.first(where: { $0.id == id })?.fileName ?? "Blood Test"
        
        DispatchQueue.main.async {
            if let index = self.processingItems.firstIndex(where: { $0.id == id }) {
                self.processingItems[index].error = error
                self.processingItems[index].isComplete = true
                self.processingItems[index].fileData = nil // Clear file data
            }
            self.savePersistedItems()
        }
        
        sendCompletionNotification(fileName: fileName, success: false, error: error)
    }
    
    // MARK: - Cancel Processing
    
    func cancelProcessing(for id: String) {
        // Cancel the active task
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        
        // Stop any timers
        progressTimers[id]?.invalidate()
        progressTimers.removeValue(forKey: id)
        
        DispatchQueue.main.async {
            if let index = self.processingItems.firstIndex(where: { $0.id == id }) {
                self.processingItems[index].isCancelled = true
                self.processingItems[index].isComplete = true
                self.processingItems[index].fileData = nil
            }
            self.savePersistedItems()
        }
        
        print("🛑 Processing cancelled for item: \(id)")
    }
    
    // MARK: - Remove Processing Item
    
    func removeProcessingItem(id: String) {
        // Cancel any active task first
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        progressTimers[id]?.invalidate()
        progressTimers.removeValue(forKey: id)
        
        DispatchQueue.main.async {
            self.processingItems.removeAll { $0.id == id }
            self.savePersistedItems()
        }
    }
    
    // MARK: - Retry Processing
    
    func retryProcessing(for id: String) {
        guard let item = processingItems.first(where: { $0.id == id }),
              let fileData = item.fileData,
              let fileType = item.fileType else {
            // Can't retry without file data
            return
        }
        
        // Reset item state
        DispatchQueue.main.async {
            if let index = self.processingItems.firstIndex(where: { $0.id == id }) {
                self.processingItems[index].progress = 0.0
                self.processingItems[index].isComplete = false
                self.processingItems[index].isCancelled = false
                self.processingItems[index].error = nil
            }
            self.savePersistedItems()
        }
        
        startProgressSimulation(for: id)
        resumeProcessing(for: id, fileData: fileData, fileType: fileType)
    }
    
    // MARK: - Resume Processing
    
    private func resumeProcessing(for id: String, fileData: Data, fileType: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if cancelled
                if Task.isCancelled { return }
                
                // Create temporary file from data
                let tempURL = self.createTempFile(from: fileData, fileType: fileType)
                
                guard let fileURL = tempURL else {
                    await MainActor.run {
                        self.failProcessing(for: id, error: "Failed to restore file for processing")
                    }
                    return
                }
                
                // Check if cancelled
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: fileURL)
                    return
                }
                
                print("🔵 Resuming blood test analysis for \(id)...")
                
                // Step 1: Analyze the blood test with AI
                let analyzeResult = try await AnalysisService.shared.analyzeBloodTest(fileURL: fileURL)
                
                // Check if cancelled
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: fileURL)
                    return
                }
                
                print("🔵 Analysis complete, saving to database...")
                
                // Step 2: Save the analysis to the database
                let savedResult = try await AnalysisService.shared.saveAnalysis(
                    parsedData: analyzeResult.parsed_data,
                    structuredAnalysis: analyzeResult.structured_analysis
                )
                
                // Step 3: Convert to view model
                let analysisData = AnalysisService.shared.convertToAnalysisData(
                    analyzeResponse: analyzeResult,
                    savedResponse: savedResult
                )
                
                // Cleanup temp file
                try? FileManager.default.removeItem(at: fileURL)
                
                await MainActor.run {
                    print("✅ Processing complete for \(id)")
                    self.completeProcessing(for: id, analysisData: analysisData)
                }
                
            } catch {
                if Task.isCancelled { return }
                
                await MainActor.run {
                    print("❌ Processing failed for \(id): \(error.localizedDescription)")
                    self.failProcessing(for: id, error: error.localizedDescription)
                }
            }
        }
        
        activeTasks[id] = task
    }
    
    // MARK: - Start New Processing
    
    func startProcessing(for id: String, fileURL: URL) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if cancelled
                if Task.isCancelled { return }
                
                print("🔵 Starting blood test analysis for \(id)...")
                
                // Step 1: Analyze the blood test with AI
                let analyzeResult = try await AnalysisService.shared.analyzeBloodTest(fileURL: fileURL)
                
                // Check if cancelled
                if Task.isCancelled { return }
                
                print("🔵 Analysis complete, saving to database...")
                
                // Step 2: Save the analysis to the database
                let savedResult = try await AnalysisService.shared.saveAnalysis(
                    parsedData: analyzeResult.parsed_data,
                    structuredAnalysis: analyzeResult.structured_analysis
                )
                
                // Step 3: Convert to view model
                let analysisData = AnalysisService.shared.convertToAnalysisData(
                    analyzeResponse: analyzeResult,
                    savedResponse: savedResult
                )
                
                await MainActor.run {
                    print("✅ Processing complete for \(id)")
                    self.completeProcessing(for: id, analysisData: analysisData)
                }
                
            } catch {
                if Task.isCancelled { return }
                
                await MainActor.run {
                    print("❌ Processing failed for \(id): \(error.localizedDescription)")
                    self.failProcessing(for: id, error: error.localizedDescription)
                }
            }
        }
        
        activeTasks[id] = task
    }
    
    // MARK: - Helper Methods
    
    private func createTempFile(from data: Data, fileType: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + (fileType == "pdf" ? ".pdf" : ".jpg")
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to create temp file: \(error)")
            return nil
        }
    }
    
    private func startProgressSimulation(for id: String) {
        // Create timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var progress: Double = 0.0
            let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if let item = self.processingItems.first(where: { $0.id == id }) {
                    if item.isComplete || item.isCancelled {
                        timer.invalidate()
                        self.progressTimers.removeValue(forKey: id)
                        return
                    }
                    
                    // Slowly increase progress, max out at 90% until complete
                    progress = min(0.9, progress + Double.random(in: 0.03...0.08))
                    self.updateProgress(for: id, progress: progress)
                } else {
                    timer.invalidate()
                    self.progressTimers.removeValue(forKey: id)
                }
            }
            
            self.progressTimers[id] = timer
        }
    }
    
    private func sendCompletionNotification(fileName: String, success: Bool, error: String? = nil) {
        let content = UNMutableNotificationContent()
        
        if success {
            content.title = "Analysis Complete! 🎉"
            content.body = "Your blood test '\(fileName)' has been analyzed and is ready to view."
        } else {
            content.title = "Analysis Failed ❌"
            content.body = "Failed to analyze '\(fileName)'. \(error ?? "Please try again.")"
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Notification sent successfully")
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAnalyseModal = false
    @State private var selectedTab: Int = 0
    @State private var analysisResultForDisplay: AnalysisData? = nil
    @State private var showAnalysisResultsFromHome = false
    @State private var showNotificationPrompt = false
    @State private var hasCheckedNotifications = false
    @StateObject private var processingManager = AnalysisProcessingManager.shared

    var body: some View {
        tabViewContent
            .onAppear {
                checkNotificationPermissions()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Re-check when app becomes active (user might have changed settings)
                    checkNotificationPermissions()
                }
            }
            .fullScreenCover(isPresented: $showNotificationPrompt) {
                NotificationPermissionView(
                    isPresented: $showNotificationPrompt,
                    isPostSignUp: false
                )
                .environmentObject(themeManager)
            }
    }

    private func checkNotificationPermissions() {
        // Only show once per app session unless user changes settings
        guard !hasCheckedNotifications else { return }

        Task {
            let enabled = await NotificationManager.shared.areNotificationsEnabled()
            let status = await NotificationManager.shared.checkPermissionStatus()

            await MainActor.run {
                // Only prompt if notifications are denied (not if never asked)
                // If status is .notDetermined, we'll ask when they try to enable a reminder
                if status == .denied && !enabled {
                    hasCheckedNotifications = true
                    showNotificationPrompt = true
                }
            }
        }
    }

    // MARK: - TabView with sidebar adaptable style
    private var tabViewContent: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath", value: 0) {
                TodayTabView()
            }

            Tab("Medication", systemImage: "pills.fill", value: 1) {
                LoggingTabView()
            }

            Tab("Health", systemImage: "stethoscope", value: 2) {
                HomeTabView()
            }

            Tab("Me", systemImage: "brain.filled.head.profile", value: 3) {
                SettingsTabView()
            }

            // Search role tab - will be separated to the right
            Tab("Add", systemImage: "plus", value: 4, role: .search) {
                Color.clear
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(AppColors.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 4 {
                // Prevent switching to the plus tab
                selectedTab = oldValue
                // Open the modal
                showAnalyseModal = true
            } else {
                // Normal tab switch - haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.userInfo?["tab"] as? Int {
                selectedTab = tab
            }
        }
        .sheet(isPresented: $showAnalyseModal) {
            AnalyseModalView(
                isPresented: $showAnalyseModal,
                onAnalysisStarted: { fileName in
                    selectedTab = 2
                },
                onAnalysisComplete: { analysisData in
                    self.analysisResultForDisplay = analysisData
                    self.showAnalysisResultsFromHome = true
                }
            )
        }
        .fullScreenCover(isPresented: $showAnalysisResultsFromHome) {
            if let analysisData = analysisResultForDisplay {
                NavigationView {
                    AnalysisResultsView(analysisData: analysisData)
                        .environmentObject(themeManager)
                }
            }
        }
    }
    
}

// MARK: - Today Tab View
struct TodayTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var loggingViewModel = LoggingViewModel.shared
    @State private var selectedDate = Date()
    @State private var reminderSheetItem: FoodSupplementItem? = nil
    @State private var editSheetItem: FoodSupplementItem? = nil
    @State private var showDatePicker = false
    @State private var gradientAnimation: Bool = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning"
        } else if hour < 17 {
            return "Good Afternoon"
        } else {
            return "Good Evening"
        }
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // Get items with reminders enabled for the selected date
    private var medicationsForSelectedDate: [FoodSupplementItem] {
        let weekday = Calendar.current.component(.weekday, from: selectedDate) - 1 // 0-6 (Sunday = 0)
        return loggingViewModel.items.filter { item in
            item.reminderEnabled && item.reminderDays.contains(weekday)
        }
    }

    // Get logs for the selected date
    private var logsForSelectedDate: [LogEntry] {
        loggingViewModel.logsForDate(selectedDate)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground(
                    animate: $gradientAnimation,
                    colorScheme: themeManager.colorScheme
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Week Calendar with Date Picker Button
                        HStack(spacing: 8) {
                            // Date Picker Button on the left
                            DatePickerButton(
                                showDatePicker: $showDatePicker,
                                selectedDate: $selectedDate
                            )

                            // Week Calendar
                            WeekCalendarView(
                                selectedDate: $selectedDate,
                                loggingViewModel: loggingViewModel
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Header with greeting
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.custom("ProductSans-Bold", size: 28))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            Text(formattedSelectedDate)
                                .font(.custom("ProductSans-Regular", size: 15))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .padding(.horizontal, 24)

                        // Medications Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(isSelectedDateToday ? "Today's Medications" : "Medications")
                                    .font(.custom("ProductSans-Bold", size: 20))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                                Spacer()

                                if !loggingViewModel.isLoading && !medicationsForSelectedDate.isEmpty {
                                    Text("\(medicationsForSelectedDate.count) items")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                            }
                            .padding(.horizontal, 24)

                            // Show loading if: actively loading OR haven't loaded yet
                            if loggingViewModel.isLoading || !loggingViewModel.hasLoadedOnce {
                                // Loading state
                                VStack(spacing: 16) {
                                    CustomSpinner(size: 32, lineWidth: 3)

                                    Text("Loading medications...")
                                        .font(.custom("ProductSans-Regular", size: 16))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(32)
                            } else if medicationsForSelectedDate.isEmpty && logsForSelectedDate.isEmpty {
                                // Empty state - only shown after data has loaded
                                VStack(spacing: 16) {
                                    Image(systemName: "pills.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(AppColors.primary.opacity(0.3))

                                    Text(isSelectedDateToday ? "No medications scheduled for today" : "No medications on this day")
                                        .font(.custom("ProductSans-Medium", size: 16))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                                    Text("Add medications and set reminders in the Medication tab")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(32)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppColors.surface(themeManager.colorScheme))
                                )
                                .padding(.horizontal, 24)
                            } else if isSelectedDateToday {
                                // Today - show medications with toggle
                                ForEach(medicationsForSelectedDate) { item in
                                    TodayMedicationCard(
                                        item: item,
                                        onToggleTaken: {
                                            Task {
                                                await loggingViewModel.toggleTaken(item)
                                                await loggingViewModel.loadWeekLogs()
                                            }
                                        },
                                        onReminder: {
                                            reminderSheetItem = item
                                        },
                                        onEdit: {
                                            editSheetItem = item
                                        },
                                        onDelete: {
                                            Task {
                                                await loggingViewModel.deleteItem(item)
                                            }
                                        },
                                        onToggleDose: { timeIndex in
                                            Task {
                                                await loggingViewModel.toggleDose(item, timeIndex: timeIndex)
                                                await loggingViewModel.loadWeekLogs()
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            } else {
                                // Past date - show logs only (read-only)
                                if logsForSelectedDate.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "xmark.circle")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
                                        Text("No medications were taken on this day")
                                            .font(.custom("ProductSans-Medium", size: 14))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(AppColors.surface(themeManager.colorScheme))
                                    )
                                    .padding(.horizontal, 24)
                                } else {
                                    ForEach(logsForSelectedDate) { log in
                                        HistoryLogRow(log: log)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(AppColors.surface(themeManager.colorScheme))
                                            )
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: loggingViewModel.isLoading)
                        .animation(.easeInOut(duration: 0.3), value: selectedDate)

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    selectedDate = Date()
                    await loggingViewModel.refreshData()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .sheet(item: $reminderSheetItem) { item in
                ReminderSheet(item: item, viewModel: loggingViewModel)
                    .environmentObject(themeManager)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showDatePicker) {
                HistoryDatePickerSheet(
                    selectedDate: $selectedDate,
                    isPresented: $showDatePicker
                )
                .environmentObject(themeManager)
                .presentationDetents([.medium])
            }
            .sheet(item: $editSheetItem) { item in
                EditItemSheet(item: item, viewModel: loggingViewModel)
                    .environmentObject(themeManager)
                    .presentationDetents([.large])
            }
        }
        .task {
            await loggingViewModel.loadDataIfNeeded()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                gradientAnimation = true
            }
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @Binding var animate: Bool
    let colorScheme: ColorScheme?

    var body: some View {
        LinearGradient(
            colors: [
                AppColors.gradientStart(colorScheme),
                AppColors.gradientEnd(colorScheme)
            ],
            startPoint: animate ? .topLeading : .topTrailing,
            endPoint: animate ? .bottomTrailing : .bottomLeading
        )
        .overlay(
            LinearGradient(
                colors: [
                    AppColors.gradientEnd(colorScheme).opacity(animate ? 0.3 : 0),
                    AppColors.gradientStart(colorScheme).opacity(animate ? 0 : 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Week Calendar View with Glass Effect
struct WeekCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @ObservedObject var loggingViewModel: LoggingViewModel

    private let calendar = Calendar.current

    // Get the past 7 days (including today)
    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            weekCalendarContent
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        } else {
            weekCalendarContent
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(glassBorder, lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
        }
    }

    private var weekCalendarContent: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { date in
                WeekDayButton(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    hasLogs: !loggingViewModel.logsForDate(date).isEmpty
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDate = date
                    }
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }

    private var glassBackground: Color {
        themeManager.colorScheme == .dark
            ? Color(white: 0.15).opacity(0.9)
            : Color(white: 0.96).opacity(0.95)
    }

    private var glassBorder: Color {
        themeManager.colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.06)
    }
}

// MARK: - Week Day Button
struct WeekDayButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasLogs: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Day name (Mon, Tue, etc.)
                Text(dayName)
                    .font(.custom("ProductSans-Medium", size: 10))
                    .foregroundColor(isSelected ? .white : AppColors.textSecondary(themeManager.colorScheme))

                // Day number
                Text(dayNumber)
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))

                // Indicator dot for logs
                Circle()
                    .fill(hasLogs ? Color.green : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday && !isSelected ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Picker Button
struct DatePickerButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showDatePicker: Bool
    @Binding var selectedDate: Date

    var body: some View {
        if #available(iOS 26.0, *) {
            Button {
                showDatePicker = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                    Text("Pick")
                        .font(.custom("ProductSans-Medium", size: 10))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .frame(width: 48)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        } else {
            Button {
                showDatePicker = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                    Text("Pick")
                        .font(.custom("ProductSans-Medium", size: 10))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .frame(width: 48)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.colorScheme == .dark
                            ? Color(white: 0.15).opacity(0.9)
                            : Color(white: 0.96).opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeManager.colorScheme == .dark
                                    ? Color.white.opacity(0.12)
                                    : Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - History Date Picker Sheet
struct HistoryDatePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    @State private var tempDate: Date = Date()

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Select a date to view your history")
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .padding(.top, 8)

                    DatePicker(
                        "",
                        selection: $tempDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("View History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedDate = tempDate
                        isPresented = false
                    }
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            tempDate = selectedDate
        }
    }
}

// MARK: - Today Medication Card (Pill-shaped UI with checkmark on left, expandable for multi-dose)
struct TodayMedicationCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    let onToggleTaken: () -> Void
    let onReminder: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onToggleDose: ((Int) -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main card row
            HStack(spacing: 12) {
                // Left side: Checkmark or expand icon for multi-dose
                if item.hasMultipleDoses {
                    // Multi-dose: show expand/collapse arrow
                    if #available(iOS 26.0, *) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(item.allDosesTakenToday ? Color.green : Color.clear)
                                // Border for incomplete state
                                if !item.allDosesTakenToday {
                                    Circle()
                                        .stroke(AppColors.textSecondary(themeManager.colorScheme).opacity(0.25), lineWidth: 2)
                                }
                                // Icon
                                Image(systemName: isExpanded ? "chevron.up" : "arrow.turn.down.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(item.allDosesTakenToday ? .white : (themeManager.colorScheme == .dark ? .white : .black))
                                    .opacity(item.allDosesTakenToday ? 1 : 0.85)
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                        .clipShape(Circle())
                    } else {
                        multiDoseButtonFallback
                    }
                } else {
                    // Single dose: show checkmark button
                    if #available(iOS 26.0, *) {
                        Button {
                            onToggleTaken()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(item.isTakenToday ? Color.green : Color.clear)
                                // Border for unselected state
                                if !item.isTakenToday {
                                    Circle()
                                        .stroke(AppColors.textSecondary(themeManager.colorScheme).opacity(0.25), lineWidth: 2)
                                }
                                // Checkmark
                                if item.isTakenToday {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.colorScheme == .dark ? .white : .black)
                                        .opacity(0.85)
                                }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                        .clipShape(Circle())
                    } else {
                        checkmarkButtonFallback
                    }
                }

                // Pill-shaped content
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(item.type == .supplement ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: item.type.icon)
                            .font(.system(size: 14))
                            .foregroundColor(item.type == .supplement ? .purple : .blue)
                    }

                    // Name and Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.custom("ProductSans-Bold", size: 15))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))

                        if item.hasMultipleDoses {
                            // Show dose progress for multi-dose items
                            let takenCount = item.doseStatusesToday?.filter { $0.isTaken }.count ?? 0
                            let totalCount = item.reminderTimes.count
                            Text("\(takenCount)/\(totalCount) doses taken")
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(takenCount == totalCount ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        } else if !item.reminderTimes.isEmpty {
                            Text(formatReminderTimes(item.reminderTimes))
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }

                    Spacer()

                    // Action buttons in glass container
                    if #available(iOS 26.0, *) {
                        HStack(spacing: 16) {
                            Button {
                                onReminder()
                            } label: {
                                Image(systemName: item.reminderEnabled ? "alarm.waves.left.and.right.fill" : "alarm.waves.left.and.right")
                                    .font(.system(size: 20))
                                    .foregroundColor(item.reminderEnabled ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button {
                                    onEdit()
                                } label: {
                                    Label("Edit", systemImage: "scribble.variable")
                                }

                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive())
                    } else {
                        actionButtonsWithoutGlass
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(AppColors.surface(themeManager.colorScheme))
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                )
            }

            // Expandable dose list for multi-dose items
            if item.hasMultipleDoses && isExpanded {
                TodayDoseListView(
                    item: item,
                    onToggleDose: { timeIndex in
                        onToggleDose?(timeIndex)
                    }
                )
                .padding(.top, 8)
                .padding(.leading, 56) // Align with the pill content
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }
        }
    }

    // Multi-dose button fallback for older iOS
    private var multiDoseButtonFallback: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(item.allDosesTakenToday ? Color.green : Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(item.allDosesTakenToday ? Color.green : AppColors.textSecondary(themeManager.colorScheme).opacity(0.3), lineWidth: 2)
                    )

                Image(systemName: isExpanded ? "chevron.up" : "arrow.turn.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(item.allDosesTakenToday ? .white : (themeManager.colorScheme == .dark ? .white : .black))
                    .opacity(item.allDosesTakenToday ? 1 : 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    // Checkmark button fallback for older iOS
    private var checkmarkButtonFallback: some View {
        Button {
            onToggleTaken()
        } label: {
            ZStack {
                Circle()
                    .fill(item.isTakenToday ? Color.green : Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(item.isTakenToday ? Color.green : AppColors.textSecondary(themeManager.colorScheme).opacity(0.3), lineWidth: 2)
                    )

                if item.isTakenToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // Action buttons without glass effect for older iOS
    private var actionButtonsWithoutGlass: some View {
        HStack(spacing: 16) {
            Button {
                onReminder()
            } label: {
                Image(systemName: item.reminderEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 20))
                    .foregroundColor(item.reminderEnabled ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "scribble.variable")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: themeManager.colorScheme == .dark ? 0.18 : 0.94).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: themeManager.colorScheme == .dark ? 1.0 : 0.0).opacity(themeManager.colorScheme == .dark ? 0.15 : 0.08), lineWidth: 0.5)
                )
        )
    }

    private func formatReminderTimes(_ timeStrings: [String]) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm:ss"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"

        let formattedTimes = timeStrings.compactMap { timeString -> String? in
            if let date = inputFormatter.date(from: timeString) {
                return outputFormatter.string(from: date)
            }
            return nil
        }

        if formattedTimes.count == 1 {
            return formattedTimes[0]
        } else if formattedTimes.count == 2 {
            return formattedTimes.joined(separator: " & ")
        } else {
            return "\(formattedTimes.count) times daily"
        }
    }
}

// MARK: - Today Dose List View (for multi-dose medications in Today tab)
struct TodayDoseListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    let onToggleDose: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(item.doseStatusesToday ?? [], id: \.timeIndex) { doseStatus in
                // Make the entire row tappable for better responsiveness
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onToggleDose(doseStatus.timeIndex)
                } label: {
                    HStack(spacing: 12) {
                        // Checkmark indicator
                        ZStack {
                            Circle()
                                .fill(doseStatus.isTaken ? Color.green : Color.clear)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(doseStatus.isTaken ? Color.green : AppColors.textSecondary(themeManager.colorScheme).opacity(0.3), lineWidth: 1.5)
                                )

                            if doseStatus.isTaken {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }

                        // Time label
                        Text(doseStatus.formattedTime)
                            .font(.custom("ProductSans-Medium", size: 14))
                            .foregroundColor(doseStatus.isTaken ? AppColors.primary : AppColors.text(themeManager.colorScheme))

                        Spacer()

                        // Status indicator
                        if doseStatus.isTaken {
                            Text("Taken")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle()) // Ensure entire row is tappable
                }
                .buttonStyle(DoseRowButtonStyle())

                // Divider between doses (except last)
                if doseStatus.timeIndex < (item.doseStatusesToday?.count ?? 1) - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface(themeManager.colorScheme))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}

// Custom button style for dose rows that provides visual feedback
struct DoseRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Recent Log Card
struct RecentLogCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let log: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.primary.opacity(0.1))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.itemName ?? "Unknown")
                    .font(.custom("ProductSans-Medium", size: 14))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(log.formattedDate)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green.opacity(0.7))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Medication History View
struct MedicationHistoryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var loggingViewModel = LoggingViewModel.shared

    // Group logs by date
    private var groupedLogs: [(String, [LogEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: loggingViewModel.recentLogs) { log -> String in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: log.loggedAt) {
                if calendar.isDateInToday(date) {
                    return "Today"
                } else if calendar.isDateInYesterday(date) {
                    return "Yesterday"
                } else {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEEE, MMM d"
                    return dateFormatter.string(from: date)
                }
            }
            return "Unknown"
        }

        // Sort by date (most recent first)
        let sortedKeys = grouped.keys.sorted { key1, key2 in
            if key1 == "Today" { return true }
            if key2 == "Today" { return false }
            if key1 == "Yesterday" { return true }
            if key2 == "Yesterday" { return false }
            return key1 > key2
        }

        return sortedKeys.map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.6))
                        Text("Today")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.6))

                        Spacer()
                    }

                    Text("History")
                        .font(.custom("ProductSans-Bold", size: 32))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("Your medication tracking history")
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                if loggingViewModel.recentLogs.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.primary.opacity(0.3))

                        Text("No history yet")
                            .font(.custom("ProductSans-Medium", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("Your medication history will appear here once you start tracking")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
                    .padding(.horizontal, 24)
                } else {
                    // History grouped by date
                    ForEach(groupedLogs, id: \.0) { dateGroup in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(dateGroup.0)
                                .font(.custom("ProductSans-Bold", size: 16))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(.horizontal, 24)

                            VStack(spacing: 0) {
                                ForEach(dateGroup.1) { log in
                                    HistoryLogRow(log: log)

                                    if log.id != dateGroup.1.last?.id {
                                        Divider()
                                            .background(AppColors.textSecondary(themeManager.colorScheme).opacity(0.1))
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }

                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - History Log Row
struct HistoryLogRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let log: LogEntry

    private var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: log.loggedAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return timeFormatter.string(from: date)
        }
        return ""
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkmark icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }

            // Item name and time
            VStack(alignment: .leading, spacing: 2) {
                Text(log.itemName ?? "Unknown")
                    .font(.custom("ProductSans-Medium", size: 15))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(formattedTime)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()

            // Taken badge
            Text("Taken")
                .font(.custom("ProductSans-Medium", size: 11))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Home Tab View
struct HomeTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var userData = UserDataViewModel.shared
    @State private var showInfoModal: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        AppColors.gradientStart(themeManager.colorScheme),
                        AppColors.gradientEnd(themeManager.colorScheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Show loading indicator when initially loading
                if userData.isLoadingHealthScore && userData.healthScore == 0.0 {
                    VStack(spacing: 16) {
                        CustomSpinner(size: 32, lineWidth: 3)
                        
                        Text("Loading your health data...")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    homeContent
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: userData.isLoadingHealthScore)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Do nothing
                    }) {
                        if let name = userData.userName {
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        } else {
                            Text("User")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                    }
                }
            }
        }
        .onAppear {
            // Data is loaded centrally, no need to reload here
        }
        .sheet(isPresented: $showInfoModal) {
            HealthScoreInfoModal(isPresented: $showInfoModal)
        }
    }
    
    // MARK: - Home Content
    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 40) {
                
                // Health Score Section
                VStack(spacing: 12) {
                        // Circular progress indicator
                        ZStack {
                            // Background circle (light gray, partial - cut off at bottom)
                            Circle()
                                .trim(from: 0.125, to: 0.875) // C-shape: gap at bottom
                                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(90)) // Rotate so gap is at bottom
                            
                            // Progress fill (adaptive color, partial - cut off at bottom) - animated
                            Circle()
                                .trim(from: 0.125, to: 0.125 + (userData.animatedProgress * 0.75)) // Fill based on animated progress
                                .stroke(AppColors.text(themeManager.colorScheme), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(90)) // Rotate so gap is at bottom
                                .animation(.easeOut(duration: 1.8), value: userData.animatedProgress)
                            
                            // Center score display
                            if userData.isLoadingHealthScore {
                                CustomSpinner(size: 24, lineWidth: 2.5)
                                    .transition(.opacity.combined(with: .scale))
                            } else if let error = userData.healthScoreError {
                                VStack(spacing: 4) {
                                    Text("Error")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    Text(error)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                .transition(.opacity)
                            } else {
                                VStack(spacing: 4) {
                                    AnimatedScoreView(
                                        targetScore: userData.healthScore,
                                        textColor: AppColors.text(themeManager.colorScheme)
                                    )
                                    
                                    // "your health score" with info button
                                    HStack(spacing: 6) {
                                        Text("your health score")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        
                                        Button(action: {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                            showInfoModal = true
                                        }) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.4), value: userData.isLoadingHealthScore)
                        .frame(width: 300, height: 300)
                        
                        // Your Trends Button with Icon
                        HStack(spacing: 12) {
                            NavigationLink(destination: ComingSoonView()) {
                                Text("Your trends")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.background(themeManager.colorScheme))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(AppColors.text(themeManager.colorScheme))
                                    .cornerRadius(25) // Pill shape
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            })
                            
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .padding(.top, -8) // Bring it closer to the health score
                    }
                    .padding(.top, 20)
                    
                    // Top Biomarkers Section
                    if userData.hasAnalyses {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 0) {
                                Text("What Needs ")
                                    .font(.custom("ProductSans-Bold", size: 24))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                Text("Attention")
                                    .font(.custom("InstrumentSerif-Italic", size: 24))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                            }
                            .padding(.horizontal, 24)
                            
                            if !userData.topBiomarkers.isEmpty {
                                ForEach(Array(userData.topBiomarkers.enumerated()), id: \.element.id) { index, biomarker in
                                    BiomarkerCard(biomarker: biomarker)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
                                            removal: .opacity
                                        ))
                                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: userData.topBiomarkers.count)
                                }
                            } else {
                                // All biomarkers are optimal
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.green)
                                    
                                    Text("All biomarkers are within optimal ranges")
                                        .font(.custom("ProductSans-Bold", size: 18))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("Great job! Your blood test results look healthy.")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: userData.hasAnalyses)
                    }
                }
                .padding(.bottom, 40)
            }
            .refreshable {
                await userData.refreshHealthScore()
            }
        }
    }


// MARK: - History Tab View
struct HistoryTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var processingManager = AnalysisProcessingManager.shared
    @State private var analyses: [Analysis] = []
    @State private var isLoading: Bool = false // Changed: don't load on first appear
    @State private var hasLoaded: Bool = false // Track if we've loaded once
    @State private var errorMessage: String? = nil
    @State private var selectedAnalysis: Analysis? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var analysisToDelete: Analysis? = nil
    @State private var isDeleting: Bool = false
    @State private var completedProcessingAnalysis: AnalysisData? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                if isLoading && processingManager.processingItems.isEmpty {
                    CustomSpinner(size: 32, lineWidth: 3)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.yellow)
                        Text("Failed to load analyses")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Text(error)
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else if analyses.isEmpty && processingManager.processingItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        Text("No analyses yet")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Text("Upload a lab report to see your history")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            // Show processing items first
                            ForEach(processingManager.processingItems) { item in
                                if item.isCancelled {
                                    // Show cancelled item - can be dismissed
                                    ProcessingCancelledCard(
                                        item: item,
                                        onDismiss: {
                                            processingManager.removeProcessingItem(id: item.id)
                                        }
                                    )
                                    .environmentObject(themeManager)
                                } else if let error = item.error {
                                    // Show error item - can retry or dismiss
                                    ProcessingErrorCard(
                                        item: item,
                                        onRetry: {
                                            processingManager.retryProcessing(for: item.id)
                                        },
                                        onDismiss: {
                                            processingManager.removeProcessingItem(id: item.id)
                                        }
                                    )
                                    .environmentObject(themeManager)
                                } else if item.isComplete, let analysisData = item.analysisData {
                                    // Show completed processing item as tappable
                                    ProcessingCompleteCard(
                                        item: item,
                                        onTap: {
                                            completedProcessingAnalysis = analysisData
                                            processingManager.removeProcessingItem(id: item.id)
                                            Task { await loadAnalyses() }
                                        }
                                    )
                                    .environmentObject(themeManager)
                                } else {
                                    // Show processing progress with cancel option
                                    ProcessingAnalysisCard(
                                        item: item,
                                        onCancel: {
                                            processingManager.cancelProcessing(for: item.id)
                                        }
                                    )
                                    .environmentObject(themeManager)
                                }
                            }

                            // Show completed analyses
                            ForEach(analyses, id: \.id) { analysis in
                                AnalysisGridCard(
                                    analysis: analysis,
                                    onTap: {
                                        selectedAnalysis = analysis
                                    },
                                    onDelete: {
                                        analysisToDelete = analysis
                                        showDeleteConfirmation = true
                                    }
                                )
                                .environmentObject(themeManager)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await loadAnalyses()
                    }
                }

                // Delete loading overlay
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        CustomSpinner(size: 36, lineWidth: 3)
                    }
                }
            }
            .navigationBarTitle("History", displayMode: .inline)
            .onAppear {
                if !hasLoaded {
                    Task { await loadAnalyses() }
                }
            }
            .navigationDestination(item: $selectedAnalysis) { analysis in
                if let analysisData = analysis.toAnalysisData() {
                    AnalysisResultsView(analysisData: analysisData)
                        .environmentObject(themeManager)
                } else {
                    Text("Unable to load analysis")
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
            }
            .navigationDestination(item: $completedProcessingAnalysis) { analysisData in
                AnalysisResultsView(analysisData: analysisData)
                        .environmentObject(themeManager)
            }
            .confirmationDialog(
                "Delete Analysis",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let analysis = analysisToDelete {
                        Task {
                            await deleteAnalysis(analysis)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    analysisToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this analysis? This action cannot be undone.")
            }
        }
    }

    // MARK: - Helpers
    private func loadAnalyses() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let uid = try await AuthService.shared.getCurrentUserId()
            let fetched = try await HealthScoreService.shared.fetchAnalyses(userId: uid)
            await MainActor.run {
                self.analyses = fetched
                self.isLoading = false
                self.hasLoaded = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.hasLoaded = true
            }
        }
    }
    
    private func deleteAnalysis(_ analysis: Analysis) async {
        await MainActor.run { isDeleting = true }
        do {
            try await HealthScoreService.shared.deleteAnalysis(analysisId: analysis.id)
            await MainActor.run {
                analyses.removeAll { $0.id == analysis.id }
                analysisToDelete = nil
                isDeleting = false
            }
            // Trigger haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } catch {
            await MainActor.run {
                isDeleting = false
                errorMessage = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: iso) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            return "\(dateString) at \(timeString)"
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            return "\(dateString) at \(timeString)"
        }
        
        return iso
    }

    private func listTitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData(), let name = parsed.patientInfo?.name, !name.isEmpty {
            return name
        }
        // fallback to ID short
        return "Analysis \(analysis.id.prefix(8))"
    }

    private func listSubtitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData() {
            let count = parsed.testResults.count
            return "\(count) markers · Report"
        }
        return "Lab report"
    }
}

// MARK: - Processing Analysis Card (Shows progress while analyzing)
struct ProcessingAnalysisCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: ProcessingAnalysis
    let onCancel: () -> Void
    @State private var showCancelConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Top row with loading indicator and cancel button
                HStack {
                    // Pulsing indicator
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                        .modifier(PulsingAnimation())
                    
                    Spacer()
                    
                    // Cancel button
                    Button(action: {
                        showCancelConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom section with info and progress
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.fileName)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .lineLimit(2)
                    
                    Text("Analyzing...")
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.primary)
                        .lineLimit(1)
                    
                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                                    .frame(height: 6)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.primary)
                                    .frame(width: geo.size.width * item.progress, height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: item.progress)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("Usually takes ~2 minutes")
                            .font(.custom("ProductSans-Regular", size: 10))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .background(AppColors.surface(themeManager.colorScheme))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.05 : 0.0), radius: 2, x: 0, y: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .confirmationDialog("Cancel Analysis", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel Analysis", role: .destructive) {
                onCancel()
            }
            Button("Continue Processing", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel? No credit will be charged.")
        }
    }
}

// MARK: - Pulsing Animation Modifier
struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Processing Complete Card (Shows when analysis is done)
struct ProcessingCompleteCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: ProcessingAnalysis
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    // Top row with checkmark
                    HStack {
                        // Success indicator
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        // Arrow icon
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // Bottom section with info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.fileName)
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineLimit(2)
                        
                        Text("Analysis Complete!")
                            .font(.custom("ProductSans-Bold", size: 13))
                            .foregroundColor(.green)
                            .lineLimit(1)
                        
                        Text("Tap to view results")
                            .font(.custom("ProductSans-Regular", size: 11))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
                .background(AppColors.surface(themeManager.colorScheme))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.05 : 0.0), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Processing Error Card (Shows when analysis failed)
struct ProcessingErrorCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: ProcessingAnalysis
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Top row with error icon and dismiss
                HStack {
                    // Error indicator
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    // Dismiss button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom section with info and retry
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .lineLimit(1)
                    
                    Text("Analysis Failed")
                        .font(.custom("ProductSans-Bold", size: 13))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                    
                    // Retry button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onRetry()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Retry")
                                .font(.custom("ProductSans-Bold", size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primary)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .background(AppColors.surface(themeManager.colorScheme))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.05 : 0.0), radius: 2, x: 0, y: 1)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Processing Cancelled Card (Shows when analysis was cancelled)
struct ProcessingCancelledCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: ProcessingAnalysis
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Top row with cancelled icon and dismiss
                HStack {
                    // Cancelled indicator
                    Image(systemName: "slash.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Dismiss button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom section with info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fileName)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .lineLimit(2)
                    
                    Text("Cancelled")
                        .font(.custom("ProductSans-Bold", size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Text("No credit charged")
                        .font(.custom("ProductSans-Regular", size: 11))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .background(AppColors.surface(themeManager.colorScheme))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.05 : 0.0), radius: 2, x: 0, y: 1)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Analysis Grid Card
struct AnalysisGridCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let analysis: Analysis
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    // Top row with ellipsis (left) and arrow (right)
                    HStack {
                        // Ellipsis menu button
                        Menu {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete Analysis", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                        
                        // Arrow icon
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // Bottom section with info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(listTitle(for: analysis))
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineLimit(2)
                        
                        Text(listSubtitle(for: analysis))
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .lineLimit(1)
                        
                        Text(formattedDate(analysis.created_at))
                            .font(.custom("ProductSans-Regular", size: 11))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
                .background(AppColors.surface(themeManager.colorScheme))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.05 : 0.0), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Helpers
    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: iso) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            return "\(dateString) at \(timeString)"
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            return "\(dateString) at \(timeString)"
        }
        
        return iso
    }
    
    private func listTitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData(), let name = parsed.patientInfo?.name, !name.isEmpty {
            return name
        }
        return "Analysis \(analysis.id.prefix(8))"
    }
    
    private func listSubtitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData() {
            let count = parsed.testResults.count
            return "\(count) markers · Report"
        }
        return "Lab report"
    }
}

// MARK: - Analysis Detail View
struct AnalysisDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let analysis: Analysis

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Report")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Spacer()
                        Text(formattedDate(analysis.created_at))
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }

                    if let parsed = analysis.getParsedData() {
                        if let patient = parsed.patientInfo {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Patient")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                if let name = patient.name { Text(name).foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                                if let age = patient.age { Text("Age: \(age)").foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                                if let sex = patient.sex { Text("Sex: \(sex)").foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                            }
                            .padding()
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            ForEach(parsed.testResults, id: \ .marker) { result in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.marker)
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        Text(result.referenceRange ?? "N/A")
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text(result.value + " " + (result.unit ?? ""))
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(AppColors.primary)
                                        Text(result.status ?? "N/A")
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }
                                }
                                .padding(12)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(10)
                            }
                        }
                    } else {
                        Text("Unable to parse report details")
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { }
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .background(AppColors.background(themeManager.colorScheme).ignoresSafeArea())
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: date)
        }
        return iso
    }
}


// MARK: - Chat Tab View
struct ChatTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var userData = UserDataViewModel.shared
    @State private var messageText: String = ""
    @State private var userId: String? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var selectedDocumentURL: URL? = nil
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showAttachmentActionSheet: Bool = false
    @State private var scrollProxyId = UUID()
    @State private var isTyping: Bool = false
    @State private var isUploading: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    HStack {
                        Spacer()
                    }
                    Text("Chat")
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(AppColors.background(themeManager.colorScheme))

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if userData.isLoadingChat {
                                CustomSpinner(size: 32, lineWidth: 3)
                                    .padding(.top, 40)
                            } else if userData.chatMessages.isEmpty {
                                VStack(spacing: 8) {
                                    Text("Hello \(userData.userName ?? "")")
                                        .font(.custom("ProductSans-Bold", size: 28))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    Text("How may I assist you?")
                                        .font(.custom("ProductSans-Regular", size: 16))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .padding(.top, 40)
                            } else {
                                ForEach(userData.chatMessages) { msg in
                                    MessageRow(message: msg)
                                        .id(msg.id)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                if isTyping {
                                    TypingIndicatorView()
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8, blendDuration: 0), value: userData.chatMessages.count)
                        .onChange(of: userData.chatMessages.count) { _ in
                            // Scroll to bottom when new messages arrive
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                                if let last = userData.chatMessages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            })
                        }
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping on chat messages
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }

                // Selected file preview
                if let image = selectedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)

                        Text("Image ready to send")
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                        Button(action: {
                            selectedImage = nil
                        }) {
                            Text("×")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface(themeManager.colorScheme))
                } else if let doc = selectedDocumentURL {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 40, height: 40)

                        Text(doc.lastPathComponent)
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineLimit(1)

                        Spacer()

                        Button(action: {
                            selectedDocumentURL = nil
                        }) {
                            Text("×")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface(themeManager.colorScheme))
                }

                // Input bar
                HStack(spacing: 12) {
                    // Attachment button: circular and same height as input
                    Button(action: {
                        showAttachmentActionSheet = true
                    }) {
                        Image(systemName: "paperclip.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .actionSheet(isPresented: $showAttachmentActionSheet) {
                        ActionSheet(title: Text("Add attachment"), buttons: [
                            .default(Text("Photo")) { showImagePicker = true },
                            .default(Text("File (PDF)")) { showDocumentPicker = true },
                            .cancel()
                        ])
                    }

                    // Rounded input (pill shaped)
                    TextField("Ask anything", text: $messageText, onCommit: sendMessage)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .clipShape(Capsule())
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .overlay(
                            // optional placeholder color alignment
                            EmptyView()
                        )
                        .frame(maxWidth: .infinity)

                    // Send button: same height as input
                    Button(action: sendMessage) {
                        if isUploading || isTyping {
                            CustomSpinner(size: 24, lineWidth: 2.5)
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                        }
                    }
                    .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil && selectedDocumentURL == nil) || isUploading || isTyping)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.background(themeManager.colorScheme))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let img = image {
                        self.selectedImage = img
                    }
                    showImagePicker = false
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    if let u = url {
                        self.selectedDocumentURL = u
                    }
                    showDocumentPicker = false
                }
            }
            .onAppear {
                Task {
                    await initializeChat()
                }
            }
        }
    }

    // MARK: - Actions
    private func initializeChat() async {
        do {
            let uid = try await AuthService.shared.getCurrentUserId()
            userId = uid
        } catch {
            print("Error getting user ID: \(error)")
        }
    }

    private func sendMessage() {
        Task {
            guard let uid = userId else { return }
            let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Prepare optimistic local user message
            let tempId = Int(Date().timeIntervalSince1970 * 1000)
            var tempContent = userMessage
            var messageType = "text"
            var fileName: String? = nil

            if let img = selectedImage {
                messageType = "image"
                fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                tempContent = "[Shared an image: \(fileName!)] \(userMessage)"
            } else if let doc = selectedDocumentURL {
                messageType = "pdf"
                fileName = doc.lastPathComponent
                tempContent = "[Shared a PDF: \(fileName!)] \(userMessage)"
            }

            let tempMsg = ChatMessageDTO(id: tempId, role: "user", content: tempContent, message_type: messageType, file_name: fileName, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))

            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    userData.addChatMessage(tempMsg)
                }
                self.messageText = ""
                self.isUploading = (self.selectedImage != nil || self.selectedDocumentURL != nil)
                self.isTyping = true
            }

            do {
                if let img = selectedImage {
                    // write image to temp file
                    let data = img.jpegData(compressionQuality: 0.8) ?? Data()
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName ?? "upload.jpg")
                    try data.write(to: tmpURL)

                    let result = try await ChatService.shared.sendChatFile(userId: uid, fileUrl: tmpURL, fileName: fileName ?? "image.jpg", mimeType: "image/jpeg", message: userMessage.isEmpty ? nil : userMessage)

                    if let assistant = result.response {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: assistant, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                userData.addChatMessage(assistantMsg)
                            }
                        }
                    }
                } else if let doc = selectedDocumentURL {
                    let mime = "application/pdf"
                    let result = try await ChatService.shared.sendChatFile(userId: uid, fileUrl: doc, fileName: doc.lastPathComponent, mimeType: mime, message: userMessage.isEmpty ? nil : userMessage)
                    if let assistant = result.response {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: assistant, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                userData.addChatMessage(assistantMsg)
                            }
                        }
                    }
                } else {
                    // text message
                    let response = try await ChatService.shared.sendChatMessage(userId: uid, message: userMessage)
                    if !response.isEmpty {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: response, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                userData.addChatMessage(assistantMsg)
                            }
                        }
                    }
                }
            } catch {
                print("Error sending message: \(error)")
                // Optionally show error UI
            }

            await MainActor.run {
                self.selectedImage = nil
                self.selectedDocumentURL = nil
                self.isUploading = false
                self.isTyping = false
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func MessageRow(message: ChatMessageDTO) -> some View {
        HStack {
            if message.role == "assistant" {
                // assistant flush left
                VStack(alignment: .leading, spacing: 6) {
                    if message.message_type != "text", let name = message.file_name {
                        HStack(spacing: 8) {
                            Image(systemName: message.message_type == "image" ? "photo" : "doc.richtext")
                                .foregroundColor(AppColors.primary)
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        .padding(10)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(12)
                        .transition(.scale)
                    }

                    if !message.content.isEmpty {
                        if isLaTeX(message.content) {
                            LaTeXView(latex: message.content)
                                .frame(minHeight: 40)
                                .padding(8)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(12)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        } else {
                            FormattedTextView(message.content, textColor: AppColors.text(themeManager.colorScheme), fontSize: 16)
                                .padding(12)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 80)

                Spacer(minLength: 8)
            } else {
                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if message.message_type != "text", let name = message.file_name {
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(Color.white)
                            Image(systemName: message.message_type == "image" ? "photo" : "doc.richtext")
                                .foregroundColor(Color.white.opacity(0.9))
                        }
                        .padding(10)
                        .background(AppColors.primary.opacity(0.95))
                        .cornerRadius(12)
                        .transition(.scale)
                    }

                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(Color.white)
                            .padding(12)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.leading, 80)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: UUID())
    }

        private func TypingIndicatorView() -> some View {
        HStack {
            AnimatedTypingDots()
                .padding(10)
                .background(AppColors.surface(themeManager.colorScheme))
                .cornerRadius(16)
            
            Spacer()
        }
        .padding(.leading, 8)
    }
}

// MARK: - Animated Typing Dots
struct AnimatedTypingDots: View {
    @State private var animationPhase: Int = 0
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 0 ? 1.0 : 0.4)
                .scaleEffect(animationPhase == 0 ? 1.2 : 1.0)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 1 ? 1.0 : 0.4)
                .scaleEffect(animationPhase == 1 ? 1.2 : 1.0)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 2 ? 1.0 : 0.4)
                .scaleEffect(animationPhase == 2 ? 1.2 : 1.0)
        }
        .animation(.easeInOut(duration: 0.3), value: animationPhase)
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType { case camera, photoLibrary }
    var sourceType: SourceType = .photoLibrary
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = (sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera)) ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.completion(image)
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker Wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.completion(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.completion(nil)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showEditInformation = false
    @State private var showNotificationSettings = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountFinalAlert = false
    @State private var isRefreshing = false
    @State private var hasActiveSubscription = false
    @State private var showAppearancePicker = false
    @State private var showPaywall = false
    @State private var subscriptionPortalURL: IdentifiableURL? = nil  // Use item-based sheet
    @State private var showSupportModal = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Title with Gear Icon and Subscription Button
                        HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            Text("Settings")
                                .font(.custom("ProductSans-Bold", size: 32))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                            
                            Spacer()
                            
                            // Subscription Button with Red Glass Effect
                            if #available(iOS 18.0, *) {
                                if #available(iOS 26.0, *) {
                                    Button(action: hasActiveSubscription ? handleManageSubscription : { showPaywall = true }) {
                                        HStack(spacing: 6) {
                                            if hasActiveSubscription {
                                                Image(systemName: "hands.and.sparkles.fill")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                            } else {
                                                Image(systemName: "sparkles.2")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                            Text(hasActiveSubscription ? "Manage Subscription" : "Upgrade")
                                                .font(.custom("ProductSans-Bold", size: 14))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.regularMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(Color(red: 0.7, green: 0.15, blue: 0.15))
                                            )
                                    )
                                    .glassEffect(.regular.interactive())
                                } else {
                                    // Fallback on earlier versions
                                    Button(action: hasActiveSubscription ? handleManageSubscription : { showPaywall = true }) {
                                        HStack(spacing: 6) {
                                            if hasActiveSubscription {
                                                Image(systemName: "hands.and.sparkles.fill")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                            } else {
                                                Image(systemName: "sparkles.2")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                            Text(hasActiveSubscription ? "Manage Subscription" : "Upgrade")
                                                .font(.custom("ProductSans-Bold", size: 14))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.regularMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(Color(red: 0.7, green: 0.15, blue: 0.15))
                                            )
                                    )
                                }
                            } else {
                                // Fallback on earlier versions
                                Button(action: hasActiveSubscription ? handleManageSubscription : { showPaywall = true }) {
                                    HStack(spacing: 6) {
                                        if hasActiveSubscription {
                                            Image(systemName: "hands.and.sparkles.fill")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        } else {
                                            Image(systemName: "sparkles.2")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        Text(hasActiveSubscription ? "Manage Subscription" : "Upgrade")
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.regularMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color(red: 0.7, green: 0.15, blue: 0.15))
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 32)

                        // Settings Items
                        VStack(spacing: 0) {
                            SettingsItem(icon: "sun.max.fill", text: "Appearance") {
                                showAppearancePicker = true
                            }
                            .environmentObject(themeManager)

                            SettingsItem(icon: "bell.fill", text: "Notifications") {
                                showNotificationSettings = true
                            }
                            .environmentObject(themeManager)

                            SettingsItem(icon: "person.fill", text: "Edit information") {
                                showEditInformation = true
                            }
                            .environmentObject(themeManager)

                            SettingsItem(icon: "questionmark.circle.fill", text: "Support and Feedback") {
                                showSupportModal = true
                            }
                            .environmentObject(themeManager)

                            SettingsItem(icon: "star.fill", text: "Leave a Review") {
                                requestAppReview()
                            }
                            .environmentObject(themeManager)

                            SettingsItem(icon: "arrow.right.square.fill", text: "Sign Out") {
                                showSignOutAlert = true
                            }
                            .environmentObject(themeManager)

                            SettingsItem(icon: "trash.fill", text: "Delete Account") {
                                showDeleteAccountAlert = true
                            }
                            .environmentObject(themeManager)
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                            .frame(height: 40)
                    }
                }
                .refreshable {
                    await refreshSettings()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEditInformation) {
            EditInformationView(isPresented: $showEditInformation)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView(isPresented: $showNotificationSettings)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall) {
                // Refresh subscription status after purchase
                Task { await refreshSettings() }
            }
            .environmentObject(themeManager)
        }
        .sheet(item: $subscriptionPortalURL) { identifiableURL in
            SafariView(url: identifiableURL.url)
        }
        .sheet(isPresented: $showSupportModal) {
            SupportModalView(isPresented: $showSupportModal)
                .environmentObject(themeManager)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                handleSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteAccountFinalAlert = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data including analyses and chat history will be permanently deleted.")
        }
        .alert("Final Confirmation", isPresented: $showDeleteAccountFinalAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Delete My Account", role: .destructive) {
                handleDeleteAccount()
            }
        } message: {
            Text("This is your last chance. Your account and all data will be permanently deleted. Are you absolutely sure?")
        }
        .onAppear {
            Task { await refreshSettings() }
        }
        .onOpenURL { url in
            // Handle subscription success deep link as fallback
            if url.scheme == "lumo" && url.host == "subscription-success" {
                print("🔵 Settings received subscription success deep link")
                Task {
                    await refreshSettingsWithRetry()
                }
            } else if url.scheme == "lumo" && url.host == "portal-return" {
                // User returned from Stripe portal - refresh subscription status
                print("🔵 User returned from Stripe portal")
                Task {
                    await refreshSettings()
                }
            }
        }
        .confirmationDialog("Choose Appearance", isPresented: $showAppearancePicker, titleVisibility: .visible) {
            Button("Light Mode") { themeManager.setColorScheme(.light) }
            Button("Dark Mode") { themeManager.setColorScheme(.dark) }
            Button("System") { themeManager.setColorScheme(nil) }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func refreshSettings() async {
        isRefreshing = true
        
        // Check subscription status
        do {
            let isSubscribed = try await SubscriptionService.shared.hasActiveSubscription(forceRefresh: true)
            await MainActor.run {
                hasActiveSubscription = isSubscribed
            }
        } catch {
            print("Error checking subscription: \(error.localizedDescription)")
        }
        
        isRefreshing = false
    }
    
    /// Refresh settings with retry mechanism (used after checkout completion)
    private func refreshSettingsWithRetry() async {
        isRefreshing = true
        
        do {
            // Use retry mechanism to handle webhook delay
            let isSubscribed = try await SubscriptionService.shared.hasActiveSubscriptionWithRetry()
            await MainActor.run {
                hasActiveSubscription = isSubscribed
                print("✅ Settings refreshed, hasActiveSubscription: \(isSubscribed)")
            }
        } catch {
            print("Error checking subscription with retry: \(error.localizedDescription)")
        }
        
        isRefreshing = false
    }
    
    private func handleManageSubscription() {
        Task {
            do {
                let portalURLString = try await SubscriptionService.shared.createPortalSession()
                await MainActor.run {
                    if let url = URL(string: portalURLString) {
                        subscriptionPortalURL = IdentifiableURL(url: url)
                    }
                }
            } catch {
                print("Error opening subscription portal: \(error.localizedDescription)")
            }
        }
    }

    private func requestAppReview() {
        // Request app review using StoreKit
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    private func handleSignOut() {
        Task {
            do {
                guard let client = SupabaseManager.shared.getClient() else { return }
                try await client.auth.signOut()
                await MainActor.run {
                    // Clear all user data
                    UserDataViewModel.shared.clearAllData()
                    appState.isAuthenticated = false
                }
            } catch {
                await MainActor.run { print("Error signing out: \(error.localizedDescription)") }
            }
        }
    }

    private func handleDeleteAccount() {
        Task {
            do {
                let userId = try await AuthService.shared.getCurrentUserId()
                guard let apiURLString = SupabaseManager.shared.getAPIURL(),
                      let apiURL = URL(string: "\(apiURLString)/api/analyses/delete-account/") else {
                    throw NSError(domain: "Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
                }

                let accessToken = try await AuthService.shared.getAccessToken()

                var request = URLRequest(url: apiURL)
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to delete account data"])
                }

                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "Settings", code: 3, userInfo: [NSLocalizedDescriptionKey: "Supabase client not configured"])
                }

                try await client.auth.signOut()

                await MainActor.run {
                    appState.isAuthenticated = false
                    print("Account deleted successfully")
                }
            } catch {
                await MainActor.run { print("Error deleting account: \(error.localizedDescription)") }
            }
        }
    }
}

// MARK: - Analyse Modal View
struct AnalyseModalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    var onAnalysisStarted: ((String) -> Void)?
    var onAnalysisComplete: ((AnalysisData) -> Void)?
    @State private var selectedFile: URL? = nil
    @State private var selectedFileName: String? = nil
    @State private var selectedFileType: String? = nil
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showDocumentPicker = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertTitle = ""
    @State private var permissionAlertMessage = ""
    @State private var isUploading = false
    @State private var showPaywall = false
    @State private var isCheckingSubscription = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Initializer with callbacks
    init(isPresented: Binding<Bool>, onAnalysisStarted: ((String) -> Void)? = nil, onAnalysisComplete: ((AnalysisData) -> Void)? = nil) {
        self._isPresented = isPresented
        self.onAnalysisStarted = onAnalysisStarted
        self.onAnalysisComplete = onAnalysisComplete
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Upload a blood test to analyse")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        if let fileName = selectedFileName {
                            Text("Selected: \(fileName)")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(AppColors.primary)
                                .padding(.top, 4)
                        }

                        HStack(spacing: 16) {
                            uploadOption(icon: "photo", title: "Photo")
                                .onTapGesture {
                                    requestPhotoLibraryPermission()
                                }
                            uploadOption(icon: "camera", title: "Camera")
                                .onTapGesture {
                                    requestCameraPermission()
                                }
                            uploadOption(icon: "doc.fill", title: "PDF")
                                .onTapGesture {
                                    showDocumentPicker = true
                                }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue button styled like Get Started
                Button(action: {
                    handleContinue()
                }) {
                    HStack {
                        Spacer()
                        if isUploading || isCheckingSubscription {
                            CustomSpinner(size: 24, lineWidth: 2.5)
                        } else {
                            Text("Continue")
                                .font(.custom("ProductSans-Bold", size: 16))
                                .foregroundColor(Color.white)
                        }
                        Spacer()
                    }
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(selectedFile != nil ? AppColors.primary : Color.gray.opacity(0.5))
                    )
                    .shadow(color: selectedFile != nil ? Color(hex: "#BB3E4F").opacity(0.6) : Color.clear, radius: 16, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .disabled(selectedFile == nil || isUploading || isCheckingSubscription)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 350)
            .background(AppColors.modalBackground(themeManager.colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Close")
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: .photoLibrary) { url, fileName in
                    if let url = url {
                        selectedFile = url
                        selectedFileName = fileName
                        selectedFileType = "image"
                    }
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                ImagePickerView(sourceType: .camera) { url, fileName in
                    if let url = url {
                        selectedFile = url
                        selectedFileName = fileName
                        selectedFileType = "image"
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url, fileName in
                    if let url = url {
                        selectedFile = url
                        selectedFileName = fileName
                        selectedFileType = "pdf"
                    }
                }
            }
            .alert(permissionAlertTitle, isPresented: $showPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            } message: {
                Text(permissionAlertMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(isPresented: $showPaywall) {
                    // On subscription complete, retry the upload
                    if let file = selectedFile {
                        performUpload(file: file)
                    }
                }
                .environmentObject(themeManager)
            }
            .alert("Analysis Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .toolbarBackground(AppColors.modalBackground(themeManager.colorScheme), for: .navigationBar)
        .toolbarColorScheme(themeManager.colorScheme == .dark ? .dark : .light, for: .navigationBar)
        .background(AppColors.modalBackground(themeManager.colorScheme).ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func uploadOption(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(AppColors.inputBackground(themeManager.colorScheme))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                )

            Text(title)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
        }
    }
    
    private func requestPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            showImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showImagePicker = true
                    } else {
                        showPermissionDeniedAlert(for: "Photo Library")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Photo Library")
        @unknown default:
            showPermissionDeniedAlert(for: "Photo Library")
        }
    }
    
    private func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            showCameraPicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraPicker = true
                    } else {
                        showPermissionDeniedAlert(for: "Camera")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Camera")
        @unknown default:
            showPermissionDeniedAlert(for: "Camera")
        }
    }
    
    private func showPermissionDeniedAlert(for feature: String) {
        permissionAlertTitle = "\(feature) Access Required"
        permissionAlertMessage = "Please enable \(feature) access in Settings to upload files."
        showPermissionAlert = true
    }
    
    private func handleContinue() {
        guard let file = selectedFile else { return }
        
        isCheckingSubscription = true
        
        Task {
            do {
                // Check if user has active subscription
                let hasSubscription = try await SubscriptionService.shared.hasActiveSubscription()
                
                await MainActor.run {
                    isCheckingSubscription = false
                    
                    if hasSubscription {
                        // User has subscription, proceed with upload
                        performUpload(file: file)
                    } else {
                        // No subscription, show paywall
                        showPaywall = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingSubscription = false
                    // On error, show paywall as fallback
                    showPaywall = true
                }
            }
        }
    }
    
    private func performUpload(file: URL) {
        let fileName = selectedFileName ?? "Blood Test"
        let processingId = UUID().uuidString
        let fileType = selectedFileType ?? "image"
        
        // Read file data for persistence (so we can resume if app closes)
        var fileData: Data? = nil
        do {
            fileData = try Data(contentsOf: file)
        } catch {
            print("⚠️ Could not read file data for persistence: \(error)")
        }
        
        // Immediately close modal and notify that analysis started
        isPresented = false
        onAnalysisStarted?(fileName)
        
        // Add to processing manager with file data for persistence
        AnalysisProcessingManager.shared.addProcessingItem(
            id: processingId,
            fileName: fileName,
            fileData: fileData,
            fileType: fileType
        )
        
        // Start processing (credit will be deducted only on success)
        AnalysisProcessingManager.shared.startProcessing(for: processingId, fileURL: file)
    }
}

// MARK: - Image Picker View
struct ImagePickerView: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary
    }
    
    let sourceType: SourceType
    let completion: (URL?, String?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType == .camera ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (URL?, String?) -> Void
        
        init(completion: @escaping (URL?, String?) -> Void) {
            self.completion = completion
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            if let image = info[.originalImage] as? UIImage {
                // Save to temporary directory
                let fileName = "captured_image_\(Date().timeIntervalSince1970).jpg"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    try? imageData.write(to: tempURL)
                    completion(tempURL, fileName)
                } else {
                    completion(nil, nil)
                }
            } else {
                completion(nil, nil)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            completion(nil, nil)
        }
    }
}

// MARK: - Document Picker View
struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: (URL?, String?) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (URL?, String?) -> Void
        
        init(completion: @escaping (URL?, String?) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                completion(nil, nil)
                return
            }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                completion(nil, nil)
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copy to temporary directory
            let fileName = url.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                completion(tempURL, fileName)
            } catch {
                print("Error copying file: \(error)")
                completion(nil, nil)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil, nil)
        }
    }
}

// MARK: - Health Score Info Modal
struct HealthScoreInfoModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How the Health Score is calculated")
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(.white)

                    Text("Summary")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)

                    Text("Your health score (0–10) reflects how your biomarkers compare to outcome-based optimal ranges. The system uses sophisticated algorithms to provide a clinically meaningful summary that's personalized to your age, sex, and health conditions.")
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.85))

                    Divider()

                    Text("How It Works: 5-Step Process")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        // ...existing code... (rest of the modal content will follow)
                        
                        // Step 1
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Normalization (0–100 sub-scores)")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(.white)
                            Text("Each biomarker is scored against outcome-based ranges:")
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Optimal range → 90–100 points")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Good range → 70–89 points")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Acceptable range → 50–69 points")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Outside ranges → 0–49 points")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        // Step 2
                        VStack(alignment: .leading, spacing: 4) {
                            Text("2. Personalization")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(.white)
                            Text("Risk weights are adjusted based on your profile:")
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Age: Some markers become more important as you age")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Sex: Different optimal ranges for males vs females")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Conditions: CVD/diabetes markers weighted higher for at-risk users")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        // Step 3
                        VStack(alignment: .leading, spacing: 4) {
                            Text("3. Risk Weighting")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(.white)
                            Text("Clinical importance determines marker weight:")
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • High impact: ApoB (1.6×), HbA1c (1.5×), hs-CRP (1.4×)")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Medium impact: LDL (1.3×), Glucose (1.3×), eGFR (1.3×)")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Lower impact: Vitamins (0.5–0.7×), Electrolytes (0.5–0.7×)")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        // Step 4
                        VStack(alignment: .leading, spacing: 4) {
                            Text("4. Aggregation (Weighted Geometric Mean)")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(.white)
                            Text("Uses geometric mean so one bad marker significantly impacts the score:")
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Score = exp(Σ(weight × ln(subscore)) / Σ(weight))")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Converted to 0–10 scale")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("This ensures safety-first: a single critical value matters more than many good ones.")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .italic()
                                .foregroundColor(.white.opacity(0.85))
                        }

                        // Step 5
                        VStack(alignment: .leading, spacing: 4) {
                            Text("5. Trend Awareness")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(.white)
                            Text("Compares to previous tests when available:")
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Improving markers: +5% boost")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Worsening markers: -5% penalty")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                            Text("  • Stable markers: no change")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    Divider()

                    Text("Confidence Score")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)

                    Text("A confidence percentage (0–100%) indicates data completeness:")
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.85))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("  • 50% weight: Coverage of key markers (ApoB, HbA1c, LDL, HDL, etc.)")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("  • 50% weight: Total number of markers (15+ markers = full credit)")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Text("Low confidence means important tests are missing—interpret the score cautiously.")
                        .font(.custom("ProductSans-Regular", size: 12))
                        .italic()
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 4)

                    Divider()

                    Text("Score Interpretation")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("  • 9.0–10.0: Excellent")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        Text("  • 7.5–9.0: Very Good")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        Text("  • 6.0–7.5: Good")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        Text("  • 4.5–6.0: Fair")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        Text("  • 3.0–4.5: Needs Attention")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                        Text("  • <3.0: Critical")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Divider()

                    Text("Key Biomarkers Tracked (60+)")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cardiovascular: ApoB, LDL, HDL, Triglycerides, Lp(a)")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Metabolic: HbA1c, Glucose, Insulin")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Inflammation: hs-CRP, CRP, ESR")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Kidney: eGFR, Creatinine, BUN, Uric Acid")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Liver: ALT, AST, GGT, ALP, Bilirubin, Albumin")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Hematology: Hemoglobin, RBC, WBC, Platelets, MCV, MCH, MCHC, RDW")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Thyroid: TSH, Free T4, Free T3")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("Vitamins & Minerals: Vitamin D, B12, Folate, Iron, Ferritin")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                        Text("...and more")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer().frame(height: 24)

                    Text("Notes")
                        .font(.custom("ProductSans-Bold", size: 14))
                        .foregroundColor(.white)

                    Text("- The score is an overall indicator and does not replace a clinician's interpretation. If any marker is flagged, consult your doctor.")
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(16)
                .background(Color.black)
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Close")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Biomarker Card
struct BiomarkerCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let biomarker: HealthScoreService.BiomarkerAttention

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(biomarker.name)
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                // Show concise reason and status instead of non-existent `detail` property
                Text(biomarker.reason)
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .lineLimit(2)

                Text(biomarker.status)
                    .font(.custom("ProductSans-Bold", size: 12))
                    .foregroundColor(AppColors.primary)
            }
            Spacer()
        }
        .padding()
        .background(AppColors.surface(themeManager.colorScheme))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
}

// MARK: - Credit Balance Card
struct SubscriptionCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let hasActiveSubscription: Bool
    let onUpgrade: () -> Void
    let onManage: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon and status
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(hasActiveSubscription ? Color.green.opacity(0.15) : AppColors.primary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: hasActiveSubscription ? "crown.fill" : "sparkles")
                        .font(.system(size: 22))
                        .foregroundColor(hasActiveSubscription ? .green : AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasActiveSubscription ? "Pro Member" : "Free Plan")
                        .font(.custom("ProductSans-Bold", size: 18))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    Text(hasActiveSubscription ? "All features unlocked" : "Upgrade for full access")
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: hasActiveSubscription ? onManage : onUpgrade) {
                Text(hasActiveSubscription ? "Manage" : "Upgrade")
                    .font(.custom("ProductSans-Bold", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(hasActiveSubscription ? Color.green : AppColors.primary)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.inputBackground(themeManager.colorScheme))
        )
    }
}

// New: SettingsItem used by the Settings tab
struct SettingsItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                Text(text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .padding(12)
            // Removed background and corner radius so items sit flat on the screen
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 6)
    }
    
    private var iconColor: Color {
        // Handle nil colorScheme (system default) by checking system appearance
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? Color.white : Color.black
    }
}

// MARK: - Edit Information View
struct EditInformationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var biologicalSex: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoadingProfile: Bool = true
    @State private var isSavingProfile: Bool = false
    @State private var isSavingPassword: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showDatePicker: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text("Edit Information")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        
                        if isLoadingProfile {
                            CustomSpinner(size: 32, lineWidth: 3)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            // Profile Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Profile")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                CustomTextField(label: "First name", text: $firstName, placeholder: "First name")
                                CustomTextField(label: "Last name", text: $lastName, placeholder: "Last name")
                                CustomTextField(label: "Email", text: $email, placeholder: "you@example.com", keyboardType: .emailAddress)
                                
                                // Biological Sex
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Biological sex")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    
                                    Picker("", selection: $biologicalSex) {
                                        Text("Male").tag("male")
                                        Text("Female").tag("female")
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .disabled(isSavingProfile)
                                }
                                
                                // Date of Birth
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date of birth")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    
                                    Button(action: { showDatePicker.toggle() }) {
                                        HStack {
                                            Text(dateOfBirth, style: .date)
                                                .font(.custom("ProductSans-Regular", size: 16))
                                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                            Spacer()
                                            Image(systemName: "calendar")
                                                .foregroundColor(AppColors.primary)
                                        }
                                    }
                                    .disabled(isSavingProfile)
                                    
                                    Rectangle()
                                        .fill(AppColors.border(themeManager.colorScheme))
                                        .frame(height: 1)
                                }
                                
                                if showDatePicker {
                                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                        .datePickerStyle(WheelDatePickerStyle())
                                        .labelsHidden()
                                }
                                
                                CustomTextField(label: "Height (cm)", text: $heightCm, placeholder: "170", keyboardType: .decimalPad)
                                CustomTextField(label: "Weight (kg)", text: $weightKg, placeholder: "70", keyboardType: .decimalPad)
                                
                                Button(action: handleSaveProfile) {
                                    HStack {
                                        Spacer()
                                        if isSavingProfile {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Save profile")
                                                .font(.custom("ProductSans-Bold", size: 16))
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                    }
                                    .frame(height: 56)
                                    .background(AppColors.primary)
                                    .cornerRadius(28)
                                }
                                .disabled(isSavingProfile || isLoadingProfile)
                            }
                            .padding(24)
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                            
                            // Password Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Password")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                CustomTextField(label: "New password", text: $newPassword, placeholder: "Enter new password", isSecure: true)
                                CustomTextField(label: "Confirm new password", text: $confirmPassword, placeholder: "Confirm new password", isSecure: true)
                                
                                Button(action: handleChangePassword) {
                                    HStack {
                                        Spacer()
                                        if isSavingPassword {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Change password")
                                                .font(.custom("ProductSans-Bold", size: 16))
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                    }
                                    .frame(height: 56)
                                    .background(AppColors.primary)
                                    .cornerRadius(28)
                                }
                                .disabled(isSavingPassword)
                            }
                            .padding(24)
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Edit Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Task { await loadProfile() }
            }
        }
    }
    
    private func loadProfile() async {
        isLoadingProfile = true
        
        do {
            guard let client = SupabaseManager.shared.getClient() else {
                throw NSError(domain: "EditInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
            }
            
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            // Fetch user profile from database
            struct UserProfile: Codable {
                let id: String
                let first_name: String?
                let last_name: String?
                let email: String?
                let biological_sex: String?
                let date_of_birth: String?
                let height_cm: Double?
                let weight_kg: Double?
            }
            
            let response: [UserProfile] = try await client.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = response.first {
                await MainActor.run {
                    firstName = profile.first_name ?? ""
                    lastName = profile.last_name ?? ""
                    email = profile.email ?? session.user.email ?? ""
                    biologicalSex = profile.biological_sex ?? "male"
                    
                    if let dobString = profile.date_of_birth {
                        let formatter = ISO8601DateFormatter()
                        if let date = formatter.date(from: dobString) {
                            dateOfBirth = date
                        }
                    }
                    
                    if let height = profile.height_cm {
                        heightCm = String(format: "%.0f", height)
                    }
                    
                    if let weight = profile.weight_kg {
                        weightKg = String(format: "%.1f", weight)
                    }
                }
            } else {
                await MainActor.run {
                    email = session.user.email ?? ""
                }
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        
        await MainActor.run {
            isLoadingProfile = false
        }
    }
    
    private func handleSaveProfile() {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
              !lastName.trimmingCharacters(in: .whitespaces).isEmpty,
              !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "Validation"
            alertMessage = "First name, last name, and email are required."
            showAlert = true
            return
        }
        
        guard let height = Double(heightCm), height > 0,
              let weight = Double(weightKg), weight > 0 else {
            alertTitle = "Validation"
            alertMessage = "Please enter valid height and weight."
            showAlert = true
            return
        }
        
        Task {
            isSavingProfile = true
            
            do {
                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "EditInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
                }
                
                let session = try await client.auth.session
                let userId = session.user.id.uuidString
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                struct UpdateProfile: Codable {
                    let first_name: String
                    let last_name: String
                    let email: String
                    let biological_sex: String
                    let date_of_birth: String
                    let height_cm: Double
                    let weight_kg: Double
                    let updated_at: String
                }
                
                let updateData = UpdateProfile(
                    first_name: firstName.trimmingCharacters(in: .whitespaces),
                    last_name: lastName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    biological_sex: biologicalSex,
                    date_of_birth: isoFormatter.string(from: dateOfBirth),
                    height_cm: height,
                    weight_kg: weight,
                    updated_at: isoFormatter.string(from: Date())
                )
                
                try await client.database
                    .from("users")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()
                
                // Update auth email if changed
                if email != session.user.email {
                    try await client.auth.update(user: UserAttributes(email: email))
                }
                
                await MainActor.run {
                    alertTitle = "Success"
                    alertMessage = "Profile updated successfully."
                    showAlert = true
                    isSavingProfile = false
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isSavingProfile = false
                }
            }
        }
    }
    
    private func handleChangePassword() {
        guard !newPassword.trimmingCharacters(in: .whitespaces).isEmpty,
              !confirmPassword.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "Validation"
            alertMessage = "Please enter and confirm your new password."
            showAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            alertTitle = "Validation"
            alertMessage = "Passwords do not match."
            showAlert = true
            return
        }
        
        guard newPassword.count >= 8 else {
            alertTitle = "Validation"
            alertMessage = "Password must be at least 8 characters."
            showAlert = true
            return
        }
        
        Task {
            isSavingPassword = true
            
            do {
                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "EditInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
                }
                
                try await client.auth.update(user: UserAttributes(password: newPassword))
                
                await MainActor.run {
                    alertTitle = "Success"
                    alertMessage = "Password updated successfully."
                    showAlert = true
                    newPassword = ""
                    confirmPassword = ""
                    isSavingPassword = false
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isSavingPassword = false
                }
            }
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var notificationsEnabled: Bool = false
    @State private var selectedLevel: NotificationLevel = .timeSensitive
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text("Notifications")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        
                        Text("Choose how you want to be reminded about your medications")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                        
                        // Notification Level Options
                        VStack(spacing: 12) {
                            ForEach(NotificationLevel.allCases) { level in
                                SettingsNotificationLevelCard(
                                    level: level,
                                    isSelected: selectedLevel == level,
                                    colorScheme: themeManager.colorScheme
                                ) {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedLevel = level
                                    }
                                    // Save the selection and request permissions if needed
                                    handleLevelChange(level)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        // Current status
                        if notificationsEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Notifications are enabled")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Notifications are disabled")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }
                        
                        // Button to open Settings
                        Button(action: openAppSettings) {
                            HStack {
                                Spacer()
                                Text("Open System Settings")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                Spacer()
                            }
                            .frame(height: 56)
                            .background(AppColors.surface(themeManager.colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                            )
                            .cornerRadius(28)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                checkNotificationStatus()
                selectedLevel = NotificationManager.shared.notificationLevel
            }
        }
    }
    
    private func checkNotificationStatus() {
        Task {
            let enabled = await NotificationManager.shared.areNotificationsEnabled()
            await MainActor.run {
                notificationsEnabled = enabled
            }
        }
    }
    
    private func handleLevelChange(_ level: NotificationLevel) {
        isLoading = true
        Task {
            let granted = await NotificationManager.shared.requestPermissions(for: level)
            await MainActor.run {
                isLoading = false
                notificationsEnabled = granted
                if granted {
                    // Reschedule all reminders with new level
                    Task {
                        await LoggingViewModel.shared.rescheduleAllReminders()
                    }
                } else {
                    alertTitle = "Permission Required"
                    alertMessage = "Please enable notifications in Settings to receive medication reminders."
                    showAlert = true
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}

// MARK: - Settings Notification Level Card
struct SettingsNotificationLevelCard: View {
    let level: NotificationLevel
    let isSelected: Bool
    let colorScheme: ColorScheme?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primary : AppColors.primary.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: level.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : AppColors.primary)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(level.displayName)
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(AppColors.text(colorScheme))

                        if level == .timeSensitive {
                            Text("Recommended")
                                .font(.custom("ProductSans-Bold", size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(AppColors.primary)
                                )
                        }
                    }

                    Text(level.description)
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(colorScheme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Priority indicator
                    HStack(spacing: 3) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(index < priorityLevel(for: level)
                                      ? priorityColor(for: level)
                                      : AppColors.border(colorScheme))
                                .frame(width: 6, height: 6)
                        }
                        Text(priorityText(for: level))
                            .font(.custom("ProductSans-Regular", size: 11))
                            .foregroundColor(AppColors.textSecondary(colorScheme))
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.primary : AppColors.border(colorScheme), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.primary : AppColors.border(colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func priorityLevel(for level: NotificationLevel) -> Int {
        switch level {
        case .standard: return 1
        case .timeSensitive: return 2
        case .critical: return 3
        }
    }

    private func priorityColor(for level: NotificationLevel) -> Color {
        switch level {
        case .standard: return .gray
        case .timeSensitive: return .orange
        case .critical: return .red
        }
    }

    private func priorityText(for level: NotificationLevel) -> String {
        switch level {
        case .standard: return "Normal priority"
        case .timeSensitive: return "High priority"
        case .critical: return "Maximum priority"
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            if (isSecure) {
                SecureField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
            
            Rectangle()
                .fill(AppColors.border(themeManager.colorScheme))
                .frame(height: 1)
        }
    }
}

// MARK: - LaTeX Renderer
struct LaTeXView: UIViewRepresentable {
    let latex: String
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Sanitize content minimally for HTML embedding
        let safeContent = latex
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "</", with: "&lt;/")

        // Use a unique placeholder token to avoid Swift string interpolation issues
        let placeholder = "@@LATEX@@"

        // Build a simple MathJax page and embed the sanitized LaTeX by replacing the placeholder
        let wrapped = """
        <!doctype html>
        <html>
        <head>
          <meta name='viewport' content='width=device-width, initial-scale=1'>
          <style>body{font-family:-apple-system; background:transparent; color:#000; margin:0; padding:6px 8px;}</style>
          <script>window.MathJax = { tex: {inlineMath: [['$$','$$'], ['\\(','\\)']]}, svg: { fontCache: 'global' } };</script>
          <script src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js'></script>
        </head>
        <body>
          <div>$$@@LATEX@@$$</div>
        </body>
        </html>
        """.replacingOccurrences(of: placeholder, with: safeContent)

        webView.loadHTMLString(wrapped, baseURL: nil)
    }
}

// Helper to detect LaTeX-like content
private func isLaTeX(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains("$$") { return true }
    if trimmed.contains("\\begin{") { return true }
    if trimmed.contains("\\(") || trimmed.contains("\\[") { return true }
    // simple heuristic: many backslashes indicate LaTeX
    let backslashCount = trimmed.filter { $0 == "\\" }.count
    if backslashCount >= 3 { return true }
    return false
}

// MARK: - Formatted Text View (Markdown Support)
struct FormattedTextView: View {
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    
    init(_ text: String, textColor: Color = .primary, fontSize: CGFloat = 16) {
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text(parseMarkdown(text))
            .font(.custom("ProductSans-Regular", size: fontSize))
            .foregroundColor(textColor)
    }
    
    private func parseMarkdown(_ input: String) -> AttributedString {
        var result = AttributedString()
        let lines = input.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            let parsedLine = parseLine(line)
            result.append(parsedLine)
            
            if lineIndex < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    private func parseLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        
        // Handle bullet points
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        var prefix = AttributedString()
        var contentLine = line
        
        if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") {
            prefix = AttributedString("• ")
            if let range = line.range(of: trimmedLine.hasPrefix("- ") ? "- " : "• ") {
                let leadingSpaces = String(line[..<range.lowerBound])
                contentLine = leadingSpaces + String(line[range.upperBound...])
            }
        } else if let match = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let numberPart = String(trimmedLine[match])
            prefix = AttributedString(numberPart)
            if let lineMatch = line.range(of: numberPart) {
                let leadingSpaces = String(line[..<lineMatch.lowerBound])
                contentLine = leadingSpaces + String(line[lineMatch.upperBound...])
            }
        }
        
        result.append(prefix)
        result.append(parseInlineFormatting(contentLine))
        
        return result
    }
    
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var currentIndex = text.startIndex
        
        // Regex patterns for markdown
        let boldPattern = #"\*\*(.+?)\*\*"#
        let italicPattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        let boldItalicPattern = #"\*\*\*(.+?)\*\*\*"#
        
        // Find all matches and sort by position
        var matches: [(range: Range<String.Index>, text: String, style: TextStyle)] = []
        
        // Bold italic (must check first since it contains bold and italic patterns)
        if let regex = try? NSRegularExpression(pattern: boldItalicPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text),
                   let contentRange = Range(match.range(at: 1), in: text) {
                    matches.append((range, String(text[contentRange]), .boldItalic))
                }
            }
        }
        
        // Bold
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text),
                   let contentRange = Range(match.range(at: 1), in: text) {
                    // Check if this range overlaps with existing matches
                    let overlaps = matches.contains { existingMatch in
                        range.overlaps(existingMatch.range)
                    }
                    if !overlaps {
                        matches.append((range, String(text[contentRange]), .bold))
                    }
                }
            }
        }
        
        // Italic (single asterisks, not part of bold)
        if let regex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text),
                   let contentRange = Range(match.range(at: 1), in: text) {
                    // Check if this range overlaps with existing matches
                    let overlaps = matches.contains { existingMatch in
                        range.overlaps(existingMatch.range)
                    }
                    if !overlaps {
                        matches.append((range, String(text[contentRange]), .italic))
                    }
                }
            }
        }
        
        // Sort matches by start position
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build result
        for match in matches {
            // Add text before this match
            if currentIndex < match.range.lowerBound {
                var plainText = AttributedString(String(text[currentIndex..<match.range.lowerBound]))
                plainText.font = .custom("ProductSans-Regular", size: fontSize)
                result.append(plainText)
            }
            
            // Add styled text
            var styledText = AttributedString(match.text)
            switch match.style {
            case .bold:
                styledText.font = .custom("ProductSans-Bold", size: fontSize)
            case .italic:
                styledText.font = .custom("ProductSans-Regular", size: fontSize).italic()
            case .boldItalic:
                styledText.font = .custom("ProductSans-Bold", size: fontSize).italic()
            }
            result.append(styledText)
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining text
        if currentIndex < text.endIndex {
            var plainText = AttributedString(String(text[currentIndex...]))
            plainText.font = .custom("ProductSans-Regular", size: fontSize)
            result.append(plainText)
        }
        
        return result
    }
    
    private enum TextStyle {
        case bold
        case italic
        case boldItalic
    }
}

#Preview {
    HomeView()
}

