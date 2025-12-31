//
//  AnalysisService.swift
//  app
//
//  Blood test analysis API service - matching the React Native frontend
//

import Foundation

// MARK: - Analysis API Response Types
struct AnalyzeResponse: Codable {
    let parsed_data: ParsedDataResponse
    let analysis: String?
    let structured_analysis: StructuredAnalysisResponse?
    let created_at: String?
}

struct ParsedDataResponse: Codable {
    let patient_info: PatientInfoResponse?
    let test_results: [TestResultResponse]?
}

struct PatientInfoResponse: Codable {
    let name: String?
    let age: String?
    let test_date: String?
    let birth_date: String?
    let sex: String?
}

struct TestResultResponse: Codable {
    let marker: String
    let value: String
    let unit: String?
    let reference_range: String?
    let status: String?
}

struct StructuredAnalysisResponse: Codable {
    let test_overview: String?
    let sections: [SectionResponse]?
}

struct SectionResponse: Codable {
    let category: String?
    let icon: String?
    let summary: String?
    let details: String?
    let biomarkers: [String]?
}

struct SaveAnalysisResponse: Codable {
    let id: String
    let user_id: String?
    let parsed_data: ParsedDataResponse
    let analysis: StructuredAnalysisResponse?
    let created_at: String
    let updated_at: String?
}

// MARK: - Analysis Service
class AnalysisService {
    static let shared = AnalysisService()
    
    private init() {}
    
    /// Analyze a blood test file (image or PDF)
    /// Matches React Native: analyzeBloodTest(fileUri)
    func analyzeBloodTest(fileURL: URL) async throws -> AnalyzeResponse {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let apiURL = URL(string: "\(apiURLString)/api/ai/analyze/") else {
            throw NSError(domain: "AnalysisService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        // Get auth token
        let accessToken = try await AuthService.shared.getAccessToken()
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        
        // Get file data
        let fileData: Data
        if fileURL.startAccessingSecurityScopedResource() {
            defer { fileURL.stopAccessingSecurityScopedResource() }
            fileData = try Data(contentsOf: fileURL)
        } else {
            fileData = try Data(contentsOf: fileURL)
        }
        
        // Determine file name and type
        let fileName = fileURL.lastPathComponent.isEmpty ? "blood_test.jpg" : fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let mimeType: String
        switch fileExtension {
        case "pdf":
            mimeType = "application/pdf"
        case "png":
            mimeType = "image/png"
        case "heic":
            mimeType = "image/heic"
        default:
            mimeType = "image/jpeg"
        }
        
        // Add file to form data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🔵 Uploading file to /api/ai/analyze/")
        print("🔵 File: \(fileName), Size: \(fileData.count) bytes, Type: \(mimeType)")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnalysisService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("🔵 Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error: \(errorMessage)")
            throw NSError(domain: "AnalysisService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to analyze blood test: \(errorMessage)"])
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let result = try decoder.decode(AnalyzeResponse.self, from: data)
        
        print("✅ Analysis complete! Found \(result.parsed_data.test_results?.count ?? 0) biomarkers")
        
        return result
    }
    
    /// Save an analysis to the database
    /// Matches React Native: saveAnalysis(parsedData, structuredAnalysis)
    func saveAnalysis(parsedData: ParsedDataResponse, structuredAnalysis: StructuredAnalysisResponse?) async throws -> SaveAnalysisResponse {
        guard let apiURLString = SupabaseManager.shared.getAPIURL(),
              let apiURL = URL(string: "\(apiURLString)/api/analyses/") else {
            throw NSError(domain: "AnalysisService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
        }
        
        // Get auth token
        let accessToken = try await AuthService.shared.getAccessToken()
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        struct SaveRequest: Codable {
            let parsed_data: ParsedDataResponse
            let analysis: StructuredAnalysisResponse?
        }
        
        let saveRequest = SaveRequest(parsed_data: parsedData, analysis: structuredAnalysis)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(saveRequest)
        
        print("🔵 Saving analysis to /api/analyses/")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnalysisService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("🔵 Response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Save Error: \(errorMessage)")
            throw NSError(domain: "AnalysisService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to save analysis: \(errorMessage)"])
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let result = try decoder.decode(SaveAnalysisResponse.self, from: data)
        
        print("✅ Analysis saved! ID: \(result.id)")
        
        return result
    }
    
    /// Convert API response to AnalysisData model for the view
    func convertToAnalysisData(analyzeResponse: AnalyzeResponse, savedResponse: SaveAnalysisResponse) -> AnalysisData {
        // Convert patient info
        let patientInfo = PatientInfo(
            name: analyzeResponse.parsed_data.patient_info?.name,
            age: analyzeResponse.parsed_data.patient_info?.age,
            testDate: analyzeResponse.parsed_data.patient_info?.test_date,
            birthDate: analyzeResponse.parsed_data.patient_info?.birth_date,
            sex: analyzeResponse.parsed_data.patient_info?.sex
        )
        
        // Convert test results
        let testResults: [BloodTestResult] = (analyzeResponse.parsed_data.test_results ?? []).map { result in
            BloodTestResult(
                marker: result.marker,
                value: result.value,
                unit: result.unit,
                referenceRange: result.reference_range,
                status: result.status
            )
        }
        
        // Create parsed data
        let parsedData = ParsedBloodTestData(
            patientInfo: patientInfo,
            testResults: testResults
        )
        
        // Create analysis data
        return AnalysisData(
            id: savedResponse.id,
            parsedData: parsedData,
            analysis: nil, // The structured analysis is already processed
            createdAt: savedResponse.created_at
        )
    }
}

