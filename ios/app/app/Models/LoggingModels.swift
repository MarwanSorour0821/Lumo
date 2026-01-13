//
//  LoggingModels.swift
//  app
//
//  Models for medication and supplement tracking
//

import Foundation

// MARK: - Item Type Enum
enum LogItemType: String, Codable, CaseIterable {
    case supplement = "supplement"
    case medication = "medication"

    var displayName: String {
        switch self {
        case .supplement: return "Supplement"
        case .medication: return "Medication"
        }
    }

    var icon: String {
        switch self {
        case .supplement: return "pills.fill"
        case .medication: return "cross.case.fill"
        }
    }
}

// MARK: - Frequency Enum
enum LogFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case asNeeded = "as_needed"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .asNeeded: return "As Needed"
        }
    }
}

// MARK: - Impact Type Enum
enum BiomarkerImpactType: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    
    var color: String {
        switch self {
        case .positive: return "green"
        case .negative: return "red"
        case .neutral: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "arrow.up.circle.fill"
        case .negative: return "arrow.down.circle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
}

// MARK: - Biomarker Impact Model
struct BiomarkerImpact: Codable, Identifiable {
    let id: String
    let biomarkerName: String
    let impactType: BiomarkerImpactType
    let impactDescription: String?
    let impactScore: Int
    let scientificSource: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case biomarkerName = "biomarker_name"
        case impactType = "impact_type"
        case impactDescription = "impact_description"
        case impactScore = "impact_score"
        case scientificSource = "scientific_source"
        case createdAt = "created_at"
    }
}

// MARK: - Dose Status Model (for multi-dose medications)
struct DoseStatus: Codable, Identifiable {
    let id: String?
    let timeIndex: Int
    let time: String?
    let isTaken: Bool
    let takenAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case timeIndex = "time_index"
        case time
        case isTaken = "is_taken"
        case takenAt = "taken_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        timeIndex = try container.decode(Int.self, forKey: .timeIndex)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        isTaken = try container.decodeIfPresent(Bool.self, forKey: .isTaken) ?? false
        takenAt = try container.decodeIfPresent(String.self, forKey: .takenAt)
    }

    // Manual init
    init(id: String?, timeIndex: Int, time: String?, isTaken: Bool, takenAt: String? = nil) {
        self.id = id
        self.timeIndex = timeIndex
        self.time = time
        self.isTaken = isTaken
        self.takenAt = takenAt
    }

    var formattedTime: String {
        guard let time = time else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm:ss"

        if let date = inputFormatter.date(from: time) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "h:mm a"
            return outputFormatter.string(from: date)
        }
        return time
    }
}

// MARK: - Log Entry Model
struct LogEntry: Codable, Identifiable {
    let id: String
    let userId: String?
    let itemId: String?
    let itemName: String?
    let itemType: String?
    let loggedAt: String
    let notes: String?
    let quantity: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case itemName = "item_name"
        case itemType = "item_type"
        case loggedAt = "logged_at"
        case notes
        case quantity
        case createdAt = "created_at"
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: loggedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return loggedAt
    }
}

// MARK: - Food/Supplement Item Model
struct FoodSupplementItem: Codable, Identifiable {
    let id: String
    let userId: String?
    let name: String
    let type: LogItemType
    let description: String?
    let frequency: LogFrequency
    let timesPerWeek: Int
    let reminderEnabled: Bool
    let reminderTimes: [String]  // Array of time strings, e.g., ["09:00:00", "14:00:00", "21:00:00"]
    let reminderDays: [Int]
    let startDate: String?
    let endDate: String?
    let lastTakenAt: String?
    let isTakenToday: Bool
    let isArchived: Bool
    let createdAt: String?
    let updatedAt: String?
    let biomarkerImpacts: [BiomarkerImpact]?
    let recentLogs: [LogEntry]?
    let logCount: Int?
    // Multi-dose fields
    let doseStatusesToday: [DoseStatus]?
    let hasMultipleDoses: Bool
    let allDosesTakenToday: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case type
        case description
        case frequency
        case timesPerWeek = "times_per_week"
        case reminderEnabled = "reminder_enabled"
        case reminderTimes = "reminder_times"
        case reminderDays = "reminder_days"
        case startDate = "start_date"
        case endDate = "end_date"
        case lastTakenAt = "last_taken_at"
        case isTakenToday = "is_taken_today"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case biomarkerImpacts = "biomarker_impacts"
        case recentLogs = "recent_logs"
        case logCount = "log_count"
        case doseStatusesToday = "dose_statuses_today"
        case hasMultipleDoses = "has_multiple_doses"
        case allDosesTakenToday = "all_doses_taken_today"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(LogItemType.self, forKey: .type) ?? .supplement
        description = try container.decodeIfPresent(String.self, forKey: .description)
        frequency = try container.decodeIfPresent(LogFrequency.self, forKey: .frequency) ?? .daily
        timesPerWeek = try container.decodeIfPresent(Int.self, forKey: .timesPerWeek) ?? 7
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderTimes = try container.decodeIfPresent([String].self, forKey: .reminderTimes) ?? []
        reminderDays = try container.decodeIfPresent([Int].self, forKey: .reminderDays) ?? [0,1,2,3,4,5,6]
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        lastTakenAt = try container.decodeIfPresent(String.self, forKey: .lastTakenAt)
        isTakenToday = try container.decodeIfPresent(Bool.self, forKey: .isTakenToday) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        biomarkerImpacts = try container.decodeIfPresent([BiomarkerImpact].self, forKey: .biomarkerImpacts)
        recentLogs = try container.decodeIfPresent([LogEntry].self, forKey: .recentLogs)
        logCount = try container.decodeIfPresent(Int.self, forKey: .logCount)
        doseStatusesToday = try container.decodeIfPresent([DoseStatus].self, forKey: .doseStatusesToday)
        hasMultipleDoses = try container.decodeIfPresent(Bool.self, forKey: .hasMultipleDoses) ?? false
        allDosesTakenToday = try container.decodeIfPresent(Bool.self, forKey: .allDosesTakenToday) ?? false
    }

    // Manual init for creating items locally
    init(id: String, name: String, type: LogItemType, description: String? = nil, frequency: LogFrequency = .daily, timesPerWeek: Int = 7, reminderEnabled: Bool = false, reminderTimes: [String] = [], reminderDays: [Int] = [0,1,2,3,4,5,6], startDate: String? = nil, endDate: String? = nil, lastTakenAt: String? = nil, isTakenToday: Bool = false, isArchived: Bool = false, biomarkerImpacts: [BiomarkerImpact]? = nil, recentLogs: [LogEntry]? = nil, logCount: Int? = nil, doseStatusesToday: [DoseStatus]? = nil, hasMultipleDoses: Bool = false, allDosesTakenToday: Bool = false) {
        self.id = id
        self.userId = nil
        self.name = name
        self.type = type
        self.description = description
        self.frequency = frequency
        self.timesPerWeek = timesPerWeek
        self.reminderEnabled = reminderEnabled
        self.reminderTimes = reminderTimes
        self.reminderDays = reminderDays
        self.startDate = startDate
        self.endDate = endDate
        self.lastTakenAt = lastTakenAt
        self.isTakenToday = isTakenToday
        self.isArchived = isArchived
        self.createdAt = nil
        self.updatedAt = nil
        self.biomarkerImpacts = biomarkerImpacts
        self.recentLogs = recentLogs
        self.logCount = logCount
        self.doseStatusesToday = doseStatusesToday
        self.hasMultipleDoses = hasMultipleDoses
        self.allDosesTakenToday = allDosesTakenToday
    }
}

// MARK: - Quick Log Response
struct QuickLogResponse: Codable {
    let success: Bool
    let parsedInput: String?
    let itemsCreated: [FoodSupplementItem]?
    let logsCreated: [LogEntry]?
    
    enum CodingKeys: String, CodingKey {
        case success
        case parsedInput = "parsed_input"
        case itemsCreated = "items_created"
        case logsCreated = "logs_created"
    }
}

// MARK: - Biomarker Impacts Response
struct BiomarkerImpactsResponse: Codable {
    let itemName: String
    let impacts: [BiomarkerImpact]

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case impacts
    }
}

// MARK: - Toggle Taken Response
struct ToggleTakenResponse: Codable {
    let item: FoodSupplementItem
    let message: String
    let isTakenToday: Bool

    enum CodingKeys: String, CodingKey {
        case item
        case message
        case isTakenToday = "is_taken_today"
    }
}

// MARK: - Toggle Dose Response (for multi-dose medications)
struct ToggleDoseResponse: Codable {
    let item: FoodSupplementItem
    let doseStatus: DoseStatus
    let message: String
    let allDosesTakenToday: Bool

    enum CodingKeys: String, CodingKey {
        case item
        case doseStatus = "dose_status"
        case message
        case allDosesTakenToday = "all_doses_taken_today"
    }
}
