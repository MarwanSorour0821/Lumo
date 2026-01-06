//
//  LoggingViewModel.swift
//  app
//
//  ViewModel for food and supplement logging
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
    @Published var isLoading: Bool = false
    @Published var isProcessingVoice: Bool = false
    @Published var error: String? = nil
    @Published var successMessage: String? = nil
    
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
            
            successMessage = "\(item.name) logged"
            
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
                // Schedule local notification
                await scheduleLocalReminder(for: updated)
                successMessage = "Reminder set for \(item.name)"
            } else {
                // Cancel local notification
                cancelLocalReminder(for: item.id)
                successMessage = "Reminder removed"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func scheduleLocalReminder(for item: FoodSupplementItem) async {
        guard item.reminderEnabled, let timeString = item.reminderTime else { return }
        
        let center = UNUserNotificationCenter.current()
        
        // Request permission
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
        } catch {
            return
        }
        
        // Parse time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeString) else { return }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // Schedule for each reminder day
        for day in item.reminderDays {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = day + 1 // iOS uses 1-7 for Sunday-Saturday
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let content = UNMutableNotificationContent()
            content.title = "Time to take \(item.name)"
            content.body = "Don't forget your \(item.type == .supplement ? "supplement" : "healthy food")!"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "\(item.id)_day\(day)",
                content: content,
                trigger: trigger
            )
            
            try? await center.add(request)
        }
    }
    
    private func cancelLocalReminder(for itemId: String) {
        let center = UNUserNotificationCenter.current()
        let identifiers = (0...6).map { "\(itemId)_day\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
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
    
    var foodItems: [FoodSupplementItem] {
        items.filter { $0.type == .food }
    }
}
