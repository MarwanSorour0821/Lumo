//
//  HealthScoreService.swift
//  app
//
//  Created on iOS
//

import Foundation
import Supabase

// MARK: - Analysis Model
struct Analysis: Codable {
    let id: String
    let user_id: String?
    let parsed_data_raw: AnyCodableValue  // Can be string or dictionary
    let analysis: AnyCodableValue?
    let created_at: String
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case parsed_data
        case analysis
        case created_at
        case updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try? container.decode(String.self, forKey: .user_id)
        created_at = try container.decode(String.self, forKey: .created_at)
        updated_at = try? container.decode(String.self, forKey: .updated_at)
        
        // Handle parsed_data - can be string or dictionary
        if let stringValue = try? container.decode(String.self, forKey: .parsed_data) {
            parsed_data_raw = .string(stringValue)
        } else if let dictValue = try? container.decode([String: AnyCodableValue].self, forKey: .parsed_data) {
            parsed_data_raw = .dictionary(dictValue)
        } else {
            throw DecodingError.typeMismatch(AnyCodableValue.self, DecodingError.Context(codingPath: [CodingKeys.parsed_data], debugDescription: "parsed_data must be String or Dictionary"))
        }
        
        // Handle analysis - can be string or dictionary
        if let stringValue = try? container.decode(String.self, forKey: .analysis) {
            analysis = .string(stringValue)
        } else if let dictValue = try? container.decode([String: AnyCodableValue].self, forKey: .analysis) {
            analysis = .dictionary(dictValue)
        } else {
            analysis = nil
        }
    }
    
    // Helper to get parsed_data as ParsedData
    func getParsedData() -> ParsedData? {
        let jsonString: String?
        
        switch parsed_data_raw {
        case .string(let str):
            jsonString = str
        case .dictionary(let dict):
            // Convert dictionary to JSON string
            let anyDict = dict.mapValues { $0.toAny() }
            if let jsonData = try? JSONSerialization.data(withJSONObject: anyDict),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                jsonString = jsonStr
            } else {
                jsonString = nil
            }
        case .array, .number, .bool, .null:
            jsonString = nil
        }
        
        guard let jsonString = jsonString else {
            print("❌ Could not convert parsed_data to string for analysis \(id)")
            return nil
        }
        
        print("🔵 Parsing parsed_data for analysis \(id) (length: \(jsonString.count))")
        if let parsed = HealthScoreService.shared.parseAnalysisData(jsonString) {
            print("✅ Successfully parsed parsed_data")
            return parsed
        } else {
            print("❌ Failed to parse parsed_data")
            return nil
        }
    }
    
    // Helper to get structured analysis (test_overview and sections)
    func getStructuredAnalysis() -> StructuredAnalysis? {
        guard let analysis = analysis else {
            print("❌ No analysis field for analysis \(id)")
            return nil
        }
        
        let jsonData: Data?
        
        switch analysis {
        case .string(let str):
            // Legacy text analysis - wrap it
            print("📝 Analysis is legacy text format for \(id)")
            return nil  // Will be handled by fallback in view
        case .dictionary(let dict):
            // Convert dictionary to JSON data
            let anyDict = dict.mapValues { $0.toAny() }
            jsonData = try? JSONSerialization.data(withJSONObject: anyDict)
        case .array, .number, .bool, .null:
            jsonData = nil
        }
        
        guard let jsonData = jsonData else {
            print("❌ Could not convert analysis to JSON data for \(id)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let structured = try decoder.decode(StructuredAnalysis.self, from: jsonData)
            print("✅ Successfully parsed structured analysis - sections: \(structured.sections?.count ?? 0)")
            return structured
        } catch {
            print("❌ Failed to parse structured analysis: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Convert to AnalysisData for use with AnalysisResultsView
    func toAnalysisData() -> AnalysisData? {
        guard let parsed = getParsedData() else {
            print("❌ Cannot convert to AnalysisData - failed to get parsed data")
            return nil
        }
        
        // Convert ParsedData to ParsedBloodTestData
        let patientInfo = PatientInfo(
            name: parsed.patientInfo?.name,
            age: parsed.patientInfo?.age,
            testDate: parsed.patientInfo?.testDate,
            birthDate: parsed.patientInfo?.birthDate,
            sex: parsed.patientInfo?.sex
        )
        
        let testResults: [BloodTestResult] = parsed.testResults.map { result in
            BloodTestResult(
                marker: result.marker,
                value: result.value,
                unit: result.unit,
                referenceRange: result.referenceRange,
                status: result.status
            )
        }
        
        let parsedBloodTestData = ParsedBloodTestData(
            patientInfo: patientInfo,
            testResults: testResults
        )
        
        // Get structured analysis
        var analysisWrapper: StructuredAnalysisWrapper? = nil
        
        if let structured = getStructuredAnalysis() {
            analysisWrapper = StructuredAnalysisWrapper(structuredAnalysis: structured)
            print("✅ Converted structured analysis with \(structured.sections?.count ?? 0) sections")
        } else if case .string(let legacyText) = analysis {
            // Handle legacy text analysis
            analysisWrapper = StructuredAnalysisWrapper(structuredAnalysis: nil, legacyText: legacyText)
            print("📝 Using legacy text analysis")
        }
        
        return AnalysisData(
            id: id,
            parsedData: parsedBloodTestData,
            analysis: analysisWrapper,
            createdAt: created_at
        )
    }
    
    // Make it Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(user_id, forKey: .user_id)
        try container.encode(parsed_data_raw, forKey: .parsed_data)
        try container.encodeIfPresent(analysis, forKey: .analysis)
        try container.encode(created_at, forKey: .created_at)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }
}

// Helper enum to handle Any value in JSON
enum AnyCodableValue: Codable {
    case string(String)
    case dictionary([String: AnyCodableValue])
    case array([AnyCodableValue])
    case number(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodableValue value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .dictionary(let value):
            return value.mapValues { $0.toAny() }
        case .array(let value):
            return value.map { $0.toAny() }
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        }
    }
}

struct ParsedData: Codable {
    let patientInfo: PatientInfo?
    let testResults: [TestResult]
    
    enum CodingKeys: String, CodingKey {
        case patientInfo = "patient_info"
        case testResults = "test_results"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        patientInfo = try container.decodeIfPresent(PatientInfo.self, forKey: .patientInfo)
        testResults = try container.decodeIfPresent([TestResult].self, forKey: .testResults) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(patientInfo, forKey: .patientInfo)
        try container.encode(testResults, forKey: .testResults)
    }
}

struct TestResult: Codable {
    let unit: String?
    let value: String
    let marker: String
    let status: String?
    let referenceRange: String?
    
    enum CodingKeys: String, CodingKey {
        case unit, value, marker, status
        case referenceRange = "reference_range"
    }
}

// MARK: - Health Score Service
class HealthScoreService {
    static let shared = HealthScoreService()
    
    private init() {}
    
    // MARK: - Analysis List Item (simplified from backend)
    struct AnalysisListItem: Codable {
        let id: String
        let title: String?
        let markers_count: Int?
        let summary: String?
        let created_at: String
    }
    
    // MARK: - Fetch Analyses
    func fetchAnalyses(userId: String) async throws -> [Analysis] {
        // Get API URL and auth token
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let apiURL = URL(string: "\(apiURLString)/api/analyses/") else {
            throw NSError(domain: "HealthScoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        // Get auth token from Supabase
        guard let client = SupabaseManager.shared.getClient() else {
            throw NSError(domain: "HealthScoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not configured"])
        }
        
        let session = try await client.auth.session
        let accessToken = session.accessToken
        
        // Step 1: Get list of analyses
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "HealthScoreService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                throw NSError(domain: "HealthScoreService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"])
            }
            
            // Decode as list items
            let decoder = JSONDecoder()
            let listItems = try decoder.decode([AnalysisListItem].self, from: data)
            print("✅ Got \(listItems.count) analysis list items from backend")
            
            // Step 2: Fetch full details for each analysis
            var fullAnalyses: [Analysis] = []
            for (index, listItem) in listItems.enumerated() {
                print("🔵 Fetching full details for analysis \(index + 1)/\(listItems.count) - ID: \(listItem.id)")
                do {
                    let fullAnalysis = try await fetchAnalysisDetails(analysisId: listItem.id, accessToken: accessToken, apiURLString: apiURLString)
                    print("✅ Successfully fetched full details for analysis \(index + 1)")
                    fullAnalyses.append(fullAnalysis)
                } catch {
                    print("❌ Failed to fetch full details for analysis \(index + 1): \(error.localizedDescription)")
                }
            }
            
            print("✅ Fetched \(fullAnalyses.count) full analyses out of \(listItems.count) list items")
            return fullAnalyses
        } catch {
            print("❌ Error fetching analyses: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Fetch Single Analysis Details
    private func fetchAnalysisDetails(analysisId: String, accessToken: String, apiURLString: String) async throws -> Analysis {
        guard let apiURL = URL(string: "\(apiURLString)/api/analyses/\(analysisId)/") else {
            throw NSError(domain: "HealthScoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid analysis URL"])
        }
        
        print("   🔵 Requesting: \(apiURL.absoluteString)")
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "HealthScoreService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("   🔵 Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
            print("   ❌ Server error: \(errorMessage)")
            throw NSError(domain: "HealthScoreService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"])
        }
        
        // Log response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("   🔵 Response data (first 500 chars): \(String(jsonString.prefix(500)))")
        }
        
        let decoder = JSONDecoder()
        do {
            let analysis = try decoder.decode(Analysis.self, from: data)
            // Get parsed_data length for logging
            let parsedDataLength: Int
            switch analysis.parsed_data_raw {
            case .string(let str):
                parsedDataLength = str.count
            case .dictionary:
                parsedDataLength = 0 // Dictionary, will be converted
            default:
                parsedDataLength = 0
            }
            print("   ✅ Successfully decoded analysis with parsed_data length: \(parsedDataLength)")
            return analysis
        } catch {
            print("   ❌ Decoding error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   ❌ Missing key: \(key.stringValue), context: \(context)")
                case .typeMismatch(let type, let context):
                    print("   ❌ Type mismatch: \(type), context: \(context)")
                case .valueNotFound(let type, let context):
                    print("   ❌ Value not found: \(type), context: \(context)")
                case .dataCorrupted(let context):
                    print("   ❌ Data corrupted: \(context)")
                @unknown default:
                    print("   ❌ Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    // MARK: - Calculate Health Score
    func calculateHealthScore(analyses: [Analysis]) -> Double {
        guard !analyses.isEmpty else {
            print("⚠️ No analyses provided for score calculation")
            return 0.0
        }
        
        var allScores: [Double] = []
        
        for (index, analysis) in analyses.enumerated() {
            print("🔵 Processing analysis \(index + 1)/\(analyses.count) - ID: \(analysis.id)")
            // Get parsed_data info for logging
            switch analysis.parsed_data_raw {
            case .string(let str):
                print("   - parsed_data is string, length: \(str.count)")
            case .dictionary:
                print("   - parsed_data is dictionary")
            default:
                print("   - parsed_data is other type")
            }
            
            guard let parsedData = analysis.getParsedData() else {
                print("⚠️ Skipping analysis \(index + 1) - failed to parse data")
                continue
            }
            
            
            print("   - test_results count: \(parsedData.testResults.count)")
            let score = calculateScoreForAnalysis(parsedData: parsedData)
            print("✅ Analysis \(index + 1) score: \(score)")
            allScores.append(score)
        }
        
        guard !allScores.isEmpty else {
            print("⚠️ No valid analyses to calculate score from")
            return 0.0
        }
        
        // Average all scores
        let averageScore = allScores.reduce(0, +) / Double(allScores.count)
        print("✅ Final health score: \(averageScore)")
        return min(max(averageScore, 0.0), 10.0) // Clamp between 0-10
    }
    
    // MARK: - Parse Analysis Data (public for helper)
    func parseAnalysisData(_ jsonString: String) -> ParsedData? {
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            // Don't convert snake_case since our structs already use snake_case
            return try decoder.decode(ParsedData.self, from: data)
        } catch {
            print("❌ JSON Decoding Error: \(error.localizedDescription)")
            print("❌ JSON String: \(jsonString.prefix(200))...")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch: expected \(type), context: \(context)")
                case .valueNotFound(let type, let context):
                    print("❌ Value not found: \(type), context: \(context)")
                case .keyNotFound(let key, let context):
                    print("❌ Key not found: \(key), context: \(context)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted: \(context)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            return nil
        }
    }
    
    // MARK: - Calculate Score for Single Analysis
    private func calculateScoreForAnalysis(parsedData: ParsedData) -> Double {
        let testResults = parsedData.testResults
        
        // 1. Core Risk Biomarkers (40-50% weight)
        let coreRiskScore = calculateCoreRiskScore(testResults: testResults)
        
        // 2. Optimal vs Normal Ranges (15-20% weight)
        let optimalRangeScore = calculateOptimalRangeScore(testResults: testResults)
        
        // 3. Data Completeness (5% weight)
        let completenessScore = calculateCompletenessScore(testResults: testResults)
        
        // Weighted combination
        let finalScore = (coreRiskScore * 0.45) + (optimalRangeScore * 0.175) + (completenessScore * 0.05)
        
        // Normalize to 0-10 scale
        return min(max(finalScore * 10, 0.0), 10.0)
    }
    
    // MARK: - Core Risk Biomarkers (40-50% weight)
    private func calculateCoreRiskScore(testResults: [TestResult]) -> Double {
        var score: Double = 0.0
        var count: Int = 0
        
        // Key risk markers with their optimal ranges
        let riskMarkers: [String: (optimalLow: Double, optimalHigh: Double, weight: Double)] = [
            "Hemoglobin (Hb)": (13.0, 17.0, 0.15),
            "Total RBC count": (4.5, 5.5, 0.10),
            "Packed Cell Volume (PCV)": (40.0, 50.0, 0.10),
            "Total WBC count": (4000.0, 11000.0, 0.10),
            "Platelet Count": (150000.0, 410000.0, 0.10),
            "ESR": (0.0, 15.0, 0.05),
            "Neutrophils": (50.0, 62.0, 0.08),
            "Lymphocytes": (20.0, 40.0, 0.08),
            "MCH": (27.0, 32.0, 0.07),
            "MCHC": (32.5, 34.5, 0.07),
            "MCV": (83.0, 101.0, 0.05),
            "RDW": (11.6, 14.0, 0.05)
        ]
        
        for result in testResults {
            guard let markerInfo = riskMarkers[result.marker],
                  let value = parseValue(result.value, unit: result.unit) else { continue }
            
            let markerScore = calculateMarkerScore(
                value: value,
                optimalLow: markerInfo.optimalLow,
                optimalHigh: markerInfo.optimalHigh,
                status: result.status
            )
            
            score += markerScore * markerInfo.weight
            count += 1
        }
        
        // Normalize by number of markers found
        if count > 0 {
            score = score / Double(count) * Double(riskMarkers.count)
        }
        
        return min(max(score, 0.0), 1.0)
    }
    
    // MARK: - Optimal vs Normal Ranges (15-20% weight)
    private func calculateOptimalRangeScore(testResults: [TestResult]) -> Double {
        var optimalCount: Double = 0.0
        var totalCount = 0
        
        for result in testResults {
            totalCount += 1
            // Reward "normal" status, penalize "low" or "high"
            let status = result.status?.lowercased() ?? ""
            if status == "normal" {
                optimalCount += 1.0
            } else if status == "high" || status == "low" {
                // Partial credit for borderline
                optimalCount += 0.5
            }
        }
        
        return totalCount > 0 ? optimalCount / Double(totalCount) : 0.0
    }
    
    // MARK: - Data Completeness (5% weight)
    private func calculateCompletenessScore(testResults: [TestResult]) -> Double {
        // Expected markers for a complete CBC
        let expectedMarkers = 15
        let actualMarkers = testResults.count
        
        // Score based on completeness
        let completeness = min(Double(actualMarkers) / Double(expectedMarkers), 1.0)
        return completeness
    }
    
    // MARK: - Calculate Marker Score
    private func calculateMarkerScore(value: Double, optimalLow: Double, optimalHigh: Double, status: String?) -> Double {
        let statusLower = (status ?? "").lowercased()
        
        // Perfect score for normal
        if statusLower == "normal" {
            return 1.0
        }
        
        // Calculate how far from optimal
        let range = optimalHigh - optimalLow
        let center = optimalLow + (range / 2)
        let distance = abs(value - center)
        let maxDistance = range / 2
        
        // Score decreases as distance increases
        let normalizedDistance = min(distance / maxDistance, 1.0)
        return 1.0 - (normalizedDistance * 0.5) // Lose up to 50% for being outside range
    }
    
    // MARK: - Parse Value
    private func parseValue(_ valueString: String, unit: String?) -> Double? {
        // Remove commas and extract number
        let cleaned = valueString.replacingOccurrences(of: ",", with: "")
        
        // Handle different formats
        if let value = Double(cleaned) {
            return value
        }
        
        // Try to extract number from string
        let numberPattern = #"(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let range = Range(match.range(at: 1), in: cleaned),
           let value = Double(String(cleaned[range])) {
            return value
        }
        
        return nil
    }
    
    // MARK: - Biomarker Attention Model
    struct BiomarkerAttention: Identifiable {
        let id: String
        let name: String
        let status: String // "Optimal", "Borderline", "Elevated"
        let trend: String // "↑", "↓", "→"
        let reason: String
        let attentionScore: Double
    }
    
    // MARK: - Get Top Biomarkers Needing Attention
    func getTopBiomarkers(analyses: [Analysis], limit: Int = 4) -> [BiomarkerAttention] {
        guard analyses.count > 0 else { return [] }
        
        // Get latest and previous analyses (if available)
        let sortedAnalyses = analyses.sorted { analysis1, analysis2 in
            let date1 = ISO8601DateFormatter().date(from: analysis1.created_at) ?? Date.distantPast
            let date2 = ISO8601DateFormatter().date(from: analysis2.created_at) ?? Date.distantPast
            return date1 > date2
        }
        
        guard let latestAnalysis = sortedAnalyses.first,
              let latestParsedData = latestAnalysis.getParsedData() else {
            return []
        }
        
        let previousParsedData: ParsedData? = sortedAnalyses.count > 1 ? sortedAnalyses[1].getParsedData() : nil
        
        // Biomarker definitions with optimal ranges and weights
        struct BiomarkerDef {
            let optimalLow: Double
            let optimalHigh: Double
            let borderlineLow: Double?
            let borderlineHigh: Double?
            let weight: Double
            let reason: String
            let trendThreshold: Double
        }
        
        let biomarkerDefs: [String: BiomarkerDef] = [
            "Hemoglobin (Hb)": BiomarkerDef(
                optimalLow: 13.0, optimalHigh: 17.0,
                borderlineLow: 12.0, borderlineHigh: 18.0,
                weight: 1.5, reason: "Oxygen-carrying capacity. Low levels can indicate anemia.",
                trendThreshold: 0.5
            ),
            "Total RBC count": BiomarkerDef(
                optimalLow: 4.5, optimalHigh: 5.5,
                borderlineLow: 4.0, borderlineHigh: 6.0,
                weight: 1.4, reason: "Red blood cell count. Important for overall blood health.",
                trendThreshold: 0.3
            ),
            "Packed Cell Volume (PCV)": BiomarkerDef(
                optimalLow: 40.0, optimalHigh: 50.0,
                borderlineLow: 35.0, borderlineHigh: 55.0,
                weight: 1.3, reason: "Percentage of blood that is red blood cells.",
                trendThreshold: 2.0
            ),
            "Total WBC count": BiomarkerDef(
                optimalLow: 4000.0, optimalHigh: 11000.0,
                borderlineLow: 3000.0, borderlineHigh: 12000.0,
                weight: 1.4, reason: "White blood cell count. Indicates immune system health.",
                trendThreshold: 1000.0
            ),
            "Platelet Count": BiomarkerDef(
                optimalLow: 150000.0, optimalHigh: 410000.0,
                borderlineLow: 100000.0, borderlineHigh: 450000.0,
                weight: 1.3, reason: "Important for blood clotting and wound healing.",
                trendThreshold: 20000.0
            ),
            "ESR": BiomarkerDef(
                optimalLow: 0.0, optimalHigh: 15.0,
                borderlineLow: nil, borderlineHigh: 20.0,
                weight: 1.2, reason: "Erythrocyte sedimentation rate. High levels indicate inflammation.",
                trendThreshold: 2.0
            ),
            "Neutrophils": BiomarkerDef(
                optimalLow: 50.0, optimalHigh: 62.0,
                borderlineLow: 45.0, borderlineHigh: 70.0,
                weight: 1.1, reason: "Type of white blood cell. Key component of immune response.",
                trendThreshold: 5.0
            ),
            "Lymphocytes": BiomarkerDef(
                optimalLow: 20.0, optimalHigh: 40.0,
                borderlineLow: 15.0, borderlineHigh: 45.0,
                weight: 1.1, reason: "Type of white blood cell. Important for immune function.",
                trendThreshold: 5.0
            ),
            "MCH": BiomarkerDef(
                optimalLow: 27.0, optimalHigh: 32.0,
                borderlineLow: 25.0, borderlineHigh: 34.0,
                weight: 0.9, reason: "Mean corpuscular hemoglobin. Average hemoglobin per red blood cell.",
                trendThreshold: 1.0
            ),
            "MCHC": BiomarkerDef(
                optimalLow: 32.5, optimalHigh: 34.5,
                borderlineLow: 31.0, borderlineHigh: 36.0,
                weight: 0.9, reason: "Mean corpuscular hemoglobin concentration.",
                trendThreshold: 1.0
            ),
            "MCV": BiomarkerDef(
                optimalLow: 83.0, optimalHigh: 101.0,
                borderlineLow: 80.0, borderlineHigh: 105.0,
                weight: 0.8, reason: "Mean corpuscular volume. Average size of red blood cells.",
                trendThreshold: 3.0
            ),
            "RDW": BiomarkerDef(
                optimalLow: 11.6, optimalHigh: 14.0,
                borderlineLow: nil, borderlineHigh: 15.0,
                weight: 0.8, reason: "Red cell distribution width. Measures variation in red blood cell size.",
                trendThreshold: 1.0
            )
        ]
        
        var biomarkerScores: [BiomarkerAttention] = []
        
        // Process each test result from latest analysis
        for result in latestParsedData.testResults {
            guard let def = biomarkerDefs[result.marker],
                  let currentValue = parseValue(result.value, unit: result.unit) else {
                continue
            }
            
            // Determine status
            let status: String
            if currentValue >= def.optimalLow && currentValue <= def.optimalHigh {
                status = "Optimal"
            } else if let bl = def.borderlineLow, let bh = def.borderlineHigh,
                      currentValue >= bl && currentValue <= bh {
                status = "Borderline"
            } else {
                status = "Elevated"
            }
            
            // Calculate severity score (distance from optimal)
            let range = def.optimalHigh - def.optimalLow
            let center = def.optimalLow + (range / 2)
            let distance = abs(currentValue - center)
            let maxDistance = range / 2
            let normalizedDistance = min(distance / maxDistance, 1.0)
            let severityScore = normalizedDistance * def.weight
            
            // Calculate trend
            var trend = "→"
            var trendPenalty: Double = 0.0
            
            if let previousData = previousParsedData,
               let previousResult = previousData.testResults.first(where: { $0.marker == result.marker }),
               let previousValue = parseValue(previousResult.value, unit: previousResult.unit) {
                
                let delta = currentValue - previousValue
                let threshold = def.trendThreshold
                
                if delta > threshold {
                    trend = "↑"
                    // Worsening trend adds penalty
                    if status != "Optimal" {
                        trendPenalty = 0.3
                    }
                } else if delta < -threshold {
                    trend = "↓"
                    // Improving trend (no penalty, could add bonus later)
                }
            }
            
            // Calculate attention score
            let attentionScore = severityScore + trendPenalty
            
            // Only include biomarkers that need attention (not optimal)
            if status != "Optimal" {
                biomarkerScores.append(BiomarkerAttention(
                    id: result.marker,
                    name: result.marker,
                    status: status,
                    trend: trend,
                    reason: def.reason,
                    attentionScore: attentionScore
                ))
            }
        }
        
        // Sort by attention score (highest first) and take top N
        return Array(biomarkerScores.sorted { $0.attentionScore > $1.attentionScore }.prefix(limit))
    }
}

