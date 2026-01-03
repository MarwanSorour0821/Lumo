//
//  AnalysisChatStorage.swift
//  app
//
//  Service for persisting analysis-specific chat messages locally
//

import Foundation

// MARK: - Stored Chat Message Model
struct StoredChatMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let createdAt: Date
    
    init(id: String = UUID().uuidString, role: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Analysis Chat Storage
class AnalysisChatStorage {
    static let shared = AnalysisChatStorage()
    
    private let userDefaults = UserDefaults.standard
    private let storageKeyPrefix = "analysis_chat_"
    
    private init() {}
    
    /// Get the storage key for a specific analysis
    private func storageKey(for analysisId: String) -> String {
        return "\(storageKeyPrefix)\(analysisId)"
    }
    
    /// Load chat messages for a specific analysis
    func loadMessages(for analysisId: String) -> [StoredChatMessage] {
        let key = storageKey(for: analysisId)
        
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        
        do {
            let messages = try JSONDecoder().decode([StoredChatMessage].self, from: data)
            return messages.sorted { $0.createdAt < $1.createdAt }
        } catch {
            print("Error loading chat messages: \(error)")
            return []
        }
    }
    
    /// Save chat messages for a specific analysis
    func saveMessages(_ messages: [StoredChatMessage], for analysisId: String) {
        let key = storageKey(for: analysisId)
        
        do {
            let data = try JSONEncoder().encode(messages)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Error saving chat messages: \(error)")
        }
    }
    
    /// Add a single message to an analysis's chat history
    func addMessage(_ message: StoredChatMessage, for analysisId: String) {
        var messages = loadMessages(for: analysisId)
        messages.append(message)
        saveMessages(messages, for: analysisId)
    }
    
    /// Clear all messages for a specific analysis
    func clearMessages(for analysisId: String) {
        let key = storageKey(for: analysisId)
        userDefaults.removeObject(forKey: key)
    }
    
    /// Get all analysis IDs that have stored chats
    func getAllAnalysisIdsWithChats() -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys
            .filter { $0.hasPrefix(storageKeyPrefix) }
            .map { String($0.dropFirst(storageKeyPrefix.count)) }
    }
    
    /// Delete chats for analyses that no longer exist
    func cleanupOrphanedChats(existingAnalysisIds: Set<String>) {
        let storedIds = getAllAnalysisIdsWithChats()
        for storedId in storedIds {
            if !existingAnalysisIds.contains(storedId) {
                clearMessages(for: storedId)
            }
        }
    }
}
