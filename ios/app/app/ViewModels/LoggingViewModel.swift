//
//  LoggingViewModel.swift
//  app
//
//  ViewModel for medication and supplement tracking
//

import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation

@MainActor
class LoggingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [FoodSupplementItem] = []
    @Published var recentLogs: [LogEntry] = []
    @Published var weekLogs: [Date: [LogEntry]] = [:] // Logs grouped by date for the week view
    @Published var isLoading: Bool = false
    @Published var isProcessingVoice: Bool = false
    @Published var error: String? = nil
    @Published var successMessage: String? = nil

    // Track if initial load has happened to avoid reloading
    private var hasLoadedOnce: Bool = false
    
    // Voice recording
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    
    // Filter state
    @Published var selectedFilter: LogItemType? = nil
    
    // Speech recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Singleton
    static let shared = LoggingViewModel()
    
    private init() {
        setupSpeechRecognition()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    // MARK: - Data Loading
    
    func loadItems() async {
        isLoading = true
        error = nil
        
        do {
            items = try await LoggingService.shared.getItems(type: selectedFilter)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    func loadRecentLogs() async {
        do {
            recentLogs = try await LoggingService.shared.getLogs(limit: 20)
        } catch {
            print("Failed to load recent logs: \(error.localizedDescription)")
        }
    }
    
    func refreshData() async {
        await loadItems()
        await loadRecentLogs()
        await loadWeekLogs()
        hasLoadedOnce = true
    }

    /// Load logs for the past week grouped by date
    func loadWeekLogs() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return }
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: today) else { return }

        do {
            let logs = try await LoggingService.shared.getLogsByDate(startDate: weekAgo, endDate: endOfToday)

            // Group logs by date
            var grouped: [Date: [LogEntry]] = [:]
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            for log in logs {
                if let logDate = dateFormatter.date(from: log.loggedAt) {
                    let dayStart = calendar.startOfDay(for: logDate)
                    if grouped[dayStart] != nil {
                        grouped[dayStart]?.append(log)
                    } else {
                        grouped[dayStart] = [log]
                    }
                }
            }

            weekLogs = grouped
        } catch {
            print("Failed to load week logs: \(error.localizedDescription)")
        }
    }

    /// Get logs for a specific date
    func logsForDate(_ date: Date) -> [LogEntry] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return weekLogs[dayStart] ?? []
    }

    /// Get item names that were taken on a specific date
    func itemsTakenOnDate(_ date: Date) -> Set<String> {
        let logs = logsForDate(date)
        return Set(logs.compactMap { $0.itemName })
    }

    /// Check if an item was taken on a specific date
    func wasItemTaken(_ item: FoodSupplementItem, on date: Date) -> Bool {
        let logs = logsForDate(date)
        return logs.contains { $0.itemId == item.id }
    }

    /// Load data only if not already loaded (for views that shouldn't reload on every appear)
    func loadDataIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await refreshData()
    }
    
    // MARK: - Item Actions
    
    func createItem(name: String, type: LogItemType, description: String? = nil, frequency: LogFrequency = .daily, timesPerWeek: Int = 7) async {
        isLoading = true
        error = nil
        
        do {
            let newItem = try await LoggingService.shared.createItem(
                name: name,
                type: type,
                description: description,
                frequency: frequency,
                timesPerWeek: timesPerWeek
            )
            items.insert(newItem, at: 0)
            successMessage = "\(name) added successfully"
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    func deleteItem(_ item: FoodSupplementItem) async {
        do {
            try await LoggingService.shared.deleteItem(itemId: item.id)
            items.removeAll { $0.id == item.id }
            successMessage = "\(item.name) removed"
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func archiveItem(_ item: FoodSupplementItem) async {
        do {
            let updated = try await LoggingService.shared.archiveItem(itemId: item.id, isArchived: true)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
            successMessage = "\(updated.name) archived"
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleTaken(_ item: FoodSupplementItem) async {
        do {
            let response = try await LoggingService.shared.toggleTaken(itemId: item.id)

            // Update local item
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = response.item
            }

            // Haptic feedback only (no toast notification)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Logging Actions
    
    func logItem(_ item: FoodSupplementItem, quantity: String? = nil, notes: String? = nil) async {
        do {
            let log = try await LoggingService.shared.logItem(itemId: item.id, quantity: quantity, notes: notes)
            recentLogs.insert(log, at: 0)
            
            // Update the item's log count locally
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                // Refresh the item to get updated log count
                await loadItems()
            }
            
            successMessage = "\(item.name) marked as taken"
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteLog(_ log: LogEntry) async {
        do {
            try await LoggingService.shared.deleteLog(logId: log.id)
            recentLogs.removeAll { $0.id == log.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Quick Log (Voice/Text)
    
    func quickLog(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isProcessingVoice = true
        error = nil
        
        do {
            let response = try await LoggingService.shared.quickLog(inputText: text)
            
            if response.success {
                // Refresh data to show new items/logs
                await refreshData()
                
                let itemCount = response.logsCreated?.count ?? 0
                successMessage = "Logged \(itemCount) item\(itemCount == 1 ? "" : "s")"
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            transcribedText = ""
            isProcessingVoice = false
        } catch {
            self.error = error.localizedDescription
            isProcessingVoice = false
        }
    }
    
    // MARK: - Voice Recording
    
    func requestSpeechPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() async {
        // Check permissions
        guard await requestSpeechPermission() else {
            error = "Speech recognition permission denied"
            return
        }
        
        guard await requestMicrophonePermission() else {
            error = "Microphone permission denied"
            return
        }
        
        // Cancel any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Failed to configure audio session"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            self.error = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            transcribedText = ""
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            self.error = "Failed to start recording"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - Biomarker Impacts
    
    func generateBiomarkerImpacts(for item: FoodSupplementItem) async -> [BiomarkerImpact]? {
        do {
            let response = try await LoggingService.shared.generateBiomarkerImpacts(itemId: item.id)
            
            // Update the item in our list
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                await loadItems() // Refresh to get updated impacts
            }
            
            return response.impacts
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Reminders

    func updateReminder(for item: FoodSupplementItem, enabled: Bool, time: Date?, days: [Int]) async {
        do {
            var timeString: String? = nil
            if let time = time {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                timeString = formatter.string(from: time)
            }

            let updated = try await LoggingService.shared.updateReminder(
                itemId: item.id,
                enabled: enabled,
                time: timeString,
                days: days
            )

            // Update local item
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updated
            }

            if enabled {
                // Schedule local notification with actionable buttons
                await scheduleLocalReminder(for: updated)
            } else {
                // Cancel local notification
                NotificationManager.shared.cancelReminders(for: item.id)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Check if notifications (including critical alerts) are enabled
    func checkNotificationPermissions() async -> Bool {
        // Request permissions including critical alerts
        let granted = await NotificationManager.shared.requestPermissions()
        return granted
    }

    private func scheduleLocalReminder(for item: FoodSupplementItem) async {
        guard item.reminderEnabled, let timeString = item.reminderTime else { return }

        // Request permission (including critical alerts)
        let granted = await NotificationManager.shared.requestPermissions()
        guard granted else {
            self.error = "Please enable notifications in Settings to receive medication reminders"
            return
        }

        // Parse time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeString) else { return }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        // Determine item type string
        let itemType = item.type == .supplement ? "supplement" : "medication"

        // Cancel existing reminders first
        NotificationManager.shared.cancelReminders(for: item.id)

        // Schedule for each reminder day using NotificationManager
        for day in item.reminderDays {
            // Convert from 0-6 (Sun=0) to iOS weekday 1-7 (Sun=1)
            let weekday = day + 1

            await NotificationManager.shared.scheduleReminder(
                itemId: item.id,
                itemName: item.name,
                itemType: itemType,
                hour: hour,
                minute: minute,
                weekday: weekday
            )
        }
    }
    
    // MARK: - Helpers
    
    func clearMessages() {
        error = nil
        successMessage = nil
    }
    
    var filteredItems: [FoodSupplementItem] {
        guard let filter = selectedFilter else { return items }
        return items.filter { $0.type == filter }
    }
    
    var supplementItems: [FoodSupplementItem] {
        items.filter { $0.type == .supplement }
    }

    var medicationItems: [FoodSupplementItem] {
        items.filter { $0.type == .medication }
    }
}
