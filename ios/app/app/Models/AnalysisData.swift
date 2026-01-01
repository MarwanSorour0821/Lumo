//
//  AnalysisData.swift
//  app
//
//  Analysis data models matching the React Native frontend
//

import Foundation

// MARK: - Patient Info
struct PatientInfo: Codable {
    let name: String?
    let age: String?
    let testDate: String?
    let birthDate: String?
    let sex: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case age
        case testDate = "test_date"
        case birthDate = "birth_date"
        case sex
    }
    
    // Explicit memberwise initializer for manual creation
    init(name: String? = nil, age: String? = nil, testDate: String? = nil, birthDate: String? = nil, sex: String? = nil) {
        self.name = name
        self.age = age
        self.testDate = testDate
        self.birthDate = birthDate
        self.sex = sex
    }
}

// MARK: - Blood Test Result (renamed from TestResult to avoid XCTest conflict)
struct BloodTestResult: Codable, Identifiable {
    var id: String { marker }
    let marker: String
    let value: String
    let unit: String?
    let referenceRange: String?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case marker
        case value
        case unit
        case referenceRange = "reference_range"
        case status
    }
    
    // Explicit memberwise initializer for manual creation
    init(marker: String, value: String, unit: String? = nil, referenceRange: String? = nil, status: String? = nil) {
        self.marker = marker
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.status = status
    }
}

// MARK: - Parsed Blood Test Data
struct ParsedBloodTestData: Codable {
    let patientInfo: PatientInfo?
    let testResults: [BloodTestResult]
    
    enum CodingKeys: String, CodingKey {
        case patientInfo = "patient_info"
        case testResults = "test_results"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        patientInfo = try container.decodeIfPresent(PatientInfo.self, forKey: .patientInfo)
        testResults = try container.decodeIfPresent([BloodTestResult].self, forKey: .testResults) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(patientInfo, forKey: .patientInfo)
        try container.encode(testResults, forKey: .testResults)
    }
    
    init(patientInfo: PatientInfo?, testResults: [BloodTestResult]) {
        self.patientInfo = patientInfo
        self.testResults = testResults
    }
}

// MARK: - Analysis Section (AI Insights)
struct AnalysisSection: Codable, Identifiable {
    var id: String { category ?? UUID().uuidString }
    let category: String?
    let icon: String?
    let summary: String?
    let details: String?
    let biomarkers: [String]?
    
    enum CodingKeys: String, CodingKey {
        case category
        case icon
        case summary
        case details
        case biomarkers
    }
    
    // Explicit memberwise initializer for manual creation
    init(category: String? = nil, icon: String? = nil, summary: String? = nil, details: String? = nil, biomarkers: [String]? = nil) {
        self.category = category
        self.icon = icon
        self.summary = summary
        self.details = details
        self.biomarkers = biomarkers
    }
}

// MARK: - Biomarker Insight
struct BiomarkerInsight: Codable {
    let general: String?
    let specific: String?
    
    init(general: String? = nil, specific: String? = nil) {
        self.general = general
        self.specific = specific
    }
}

// MARK: - Structured Analysis
struct StructuredAnalysis: Codable {
    let testOverview: String?
    let sections: [AnalysisSection]?
    let biomarkerInsights: [String: BiomarkerInsight]?
    
    enum CodingKeys: String, CodingKey {
        case testOverview = "test_overview"
        case sections
        case biomarkerInsights = "biomarker_insights"
    }
    
    // Manual initializer for programmatic creation
    init(testOverview: String? = nil, sections: [AnalysisSection]? = nil, biomarkerInsights: [String: BiomarkerInsight]? = nil) {
        self.testOverview = testOverview
        self.sections = sections
        self.biomarkerInsights = biomarkerInsights
    }
}

// MARK: - Analysis Data (Full Response)
struct AnalysisData: Codable, Identifiable {
    let id: String?
    let parsedData: ParsedBloodTestData
    let analysis: StructuredAnalysisWrapper?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case parsedData = "parsed_data"
        case analysis
        case createdAt = "created_at"
    }
    
    // Explicit memberwise initializer for manual creation
    init(id: String? = nil, parsedData: ParsedBloodTestData, analysis: StructuredAnalysisWrapper? = nil, createdAt: String) {
        self.id = id
        self.parsedData = parsedData
        self.analysis = analysis
        self.createdAt = createdAt
    }
    
    // Helper computed properties
    var testResults: [BloodTestResult] {
        parsedData.testResults
    }
    
    var patientInfo: PatientInfo? {
        parsedData.patientInfo
    }
    
    var structuredAnalysis: StructuredAnalysis? {
        analysis?.structuredAnalysis
    }
    
    var testOverview: String? {
        structuredAnalysis?.testOverview
    }
    
    var biomarkerInsights: [String: BiomarkerInsight]? {
        structuredAnalysis?.biomarkerInsights
    }
    
    var sections: [AnalysisSection] {
        // First try structured analysis sections
        if let sections = structuredAnalysis?.sections, !sections.isEmpty {
            return sections
        }
        // Fallback to parsing legacy text (matching React Native behavior)
        return analysis?.parsedSections ?? []
    }
    
    // Calculate health score
    var overallScore: Int {
        guard !testResults.isEmpty else { return 0 }
        let normalCount = testResults.filter { $0.status == "normal" }.count
        return Int(round(Double(normalCount) / Double(testResults.count) * 100))
    }
    
    var normalCount: Int {
        testResults.filter { $0.status == "normal" }.count
    }
    
    var abnormalCount: Int {
        testResults.count - normalCount
    }
    
    var normalRangePercentage: Int {
        guard !testResults.isEmpty else { return 0 }
        return Int(round(Double(normalCount) / Double(testResults.count) * 100))
    }
    
    // Format date helper
    func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "N/A" }
        
        // Try ISO8601 format first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd/MM/yyyy"
            return displayFormatter.string(from: date)
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd/MM/yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    var formattedCreatedAt: String {
        // Try ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return createdAt
    }
}

// MARK: - Wrapper for analysis field (can be string or JSON object)
struct StructuredAnalysisWrapper: Codable {
    let structuredAnalysis: StructuredAnalysis?
    let legacyText: String?
    
    // Manual initializer for programmatic creation
    init(structuredAnalysis: StructuredAnalysis?, legacyText: String? = nil) {
        self.structuredAnalysis = structuredAnalysis
        self.legacyText = legacyText
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as StructuredAnalysis directly
        if let analysis = try? container.decode(StructuredAnalysis.self) {
            structuredAnalysis = analysis
            legacyText = nil
        }
        // Try to decode as String (legacy format)
        else if let text = try? container.decode(String.self) {
            structuredAnalysis = nil
            legacyText = text
        }
        // Empty or null
        else {
            structuredAnalysis = nil
            legacyText = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(structuredAnalysis)
    }
    
    // Parse legacy text into sections (matching React Native parseAnalysisIntoInsights)
    var parsedSections: [AnalysisSection] {
        guard let text = legacyText, !text.isEmpty else { return [] }
        
        var insights: [AnalysisSection] = []
        
        // Split by common section markers like "1. ", "2. ", etc.
        let pattern = #"\n\s*\d+\.\s+"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: text.utf16.count)
        
        var sections: [String] = []
        if let regex = regex {
            let matches = regex.matches(in: text, options: [], range: range)
            var lastEnd = 0
            for match in matches {
                if let range = Range(NSRange(location: lastEnd, length: match.range.location - lastEnd), in: text) {
                    let section = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !section.isEmpty {
                        sections.append(section)
                    }
                }
                lastEnd = match.range.location + match.range.length
            }
            // Add remaining text
            if lastEnd < text.count {
                if let range = Range(NSRange(location: lastEnd, length: text.count - lastEnd), in: text) {
                    let section = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !section.isEmpty {
                        sections.append(section)
                    }
                }
            }
        }
        
        // If no sections found by regex, use the whole text
        if sections.isEmpty {
            sections = [text]
        }
        
        let icons = ["medical-outline", "water-outline", "heart-outline", "information-circle-outline"]
        
        for (index, section) in sections.enumerated() {
            let lines = section.components(separatedBy: "\n")
            let firstLine = lines.first ?? ""
            let restOfText = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract category from first line
            var category = "Analysis"
            let upperFirstLine = firstLine.uppercased()
            if upperFirstLine.contains("OVERVIEW") {
                category = "Overview"
            } else if upperFirstLine.contains("FINDINGS") {
                category = "Findings"
            } else if upperFirstLine.contains("RECOMMENDATIONS") {
                category = "Recommendations"
            } else if upperFirstLine.contains("NOTES") {
                category = "Notes"
            }
            
            let summary = firstLine.count > 100 ? String(firstLine.prefix(100)) + "..." : firstLine
            let details = restOfText.isEmpty ? firstLine : restOfText
            
            insights.append(AnalysisSection(
                category: category,
                icon: icons[index % icons.count],
                summary: summary,
                details: details,
                biomarkers: nil
            ))
        }
        
        return insights
    }
}

// MARK: - Reference Range Parser
struct ReferenceRange {
    let min: Double
    let max: Double
    
    static func parse(_ referenceRange: String?) -> ReferenceRange? {
        guard let referenceRange = referenceRange else { return nil }
        
        // Try to extract numbers from various formats like "11-16", "11 - 16", "11 to 16", etc.
        let pattern = #"(\d+\.?\d*)\s*[-–—to]+\s*(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: referenceRange.utf16.count)
        guard let match = regex.firstMatch(in: referenceRange, options: [], range: range) else {
            return nil
        }
        
        guard let minRange = Range(match.range(at: 1), in: referenceRange),
              let maxRange = Range(match.range(at: 2), in: referenceRange),
              let min = Double(referenceRange[minRange]),
              let max = Double(referenceRange[maxRange]) else {
            return nil
        }
        
        return ReferenceRange(min: min, max: max)
    }
}

