//
//  TrendsService.swift
//  app
//
//  Service for processing biomarker trends from blood test analyses
//

import Foundation

// MARK: - Biomarker Data Point
struct BiomarkerDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let status: String?
    let unit: String?
    let referenceRange: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var fullFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Biomarker Trend
struct BiomarkerTrend: Identifiable {
    let id = UUID()
    let marker: String           // Canonical display name
    let biomarkerId: String      // Internal ID for logic (never changes)
    let unit: String
    let dataPoints: [BiomarkerDataPoint]
    let referenceMin: Double?
    let referenceMax: Double?
    let latestStatus: String
    let aliases: [String]?       // Other known names for tooltip
    
    var hasMultiplePoints: Bool {
        dataPoints.count > 1
    }
    
    var latestValue: Double? {
        dataPoints.last?.value
    }
    
    var trend: TrendDirection {
        guard dataPoints.count >= 2 else { return .stable }
        let lastTwo = dataPoints.suffix(2)
        guard let first = lastTwo.first, let second = lastTwo.last else { return .stable }
        
        let difference = second.value - first.value
        let percentChange = abs(difference) / first.value * 100
        
        // Consider a change significant if it's more than 5%
        if percentChange < 5 {
            return .stable
        }
        return difference > 0 ? .increasing : .decreasing
    }
    
    /// Returns a user-friendly tooltip showing alternative names
    var aliasTooltip: String? {
        guard let aliases = aliases, !aliases.isEmpty else { return nil }
        // Filter out the canonical name and limit to 3 aliases
        let otherNames = aliases.filter { $0.lowercased() != marker.lowercased() }.prefix(3)
        guard !otherNames.isEmpty else { return nil }
        return "Also known as: \(otherNames.joined(separator: ", "))"
    }
    
    enum TrendDirection {
        case increasing
        case decreasing
        case stable
        
        var iconName: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .decreasing: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
    }
}

// MARK: - Trends Service
class TrendsService {
    static let shared = TrendsService()
    
    private init() {}
    
    // MARK: - Process Analyses into Trends
    func processTrends(from analyses: [Analysis]) -> [BiomarkerTrend] {
        // Dictionary to collect all data points for each biomarker
        // Use normalized names as keys to group variations together
        var biomarkerData: [String: [(date: Date, value: Double, status: String?, unit: String?, referenceRange: String?, originalName: String)]] = [:]
        
        for analysis in analyses {
            guard let parsedData = analysis.getParsedData() else { continue }
            
            // Parse the date from created_at
            let date = parseDate(analysis.created_at) ?? Date()
            
            for result in parsedData.testResults {
                guard let value = Double(result.value) else { continue }
                
                // Normalize the biomarker name to handle variations
                let originalMarker = result.marker
                let normalizedMarker = BiomarkerNormalizer.shared.normalize(originalMarker)
                
                if biomarkerData[normalizedMarker] == nil {
                    biomarkerData[normalizedMarker] = []
                }
                
                biomarkerData[normalizedMarker]?.append((
                    date: date,
                    value: value,
                    status: result.status,
                    unit: result.unit,
                    referenceRange: result.referenceRange,
                    originalName: originalMarker
                ))
            }
        }
        
        // Convert to BiomarkerTrend objects
        var trends: [BiomarkerTrend] = []
        
        for (normalizedMarker, dataPoints) in biomarkerData {
            // Sort data points by date
            let sortedPoints = dataPoints.sorted { $0.date < $1.date }
            
            // Convert to BiomarkerDataPoint
            let points = sortedPoints.map { point in
                BiomarkerDataPoint(
                    date: point.date,
                    value: point.value,
                    status: point.status,
                    unit: point.unit,
                    referenceRange: point.referenceRange
                )
            }
            
            guard !points.isEmpty else { continue }
            
            // Parse reference range from the latest point
            let latestRefRange = sortedPoints.last?.referenceRange ?? nil
            let (refMin, refMax) = parseReferenceRange(latestRefRange ?? "")
            
            // Get canonical ID and aliases for this biomarker
            let biomarkerId = BiomarkerNormalizer.shared.getCanonicalId(for: normalizedMarker)
            let aliases = BiomarkerNormalizer.shared.getAliases(for: normalizedMarker)
            
            let trend = BiomarkerTrend(
                marker: normalizedMarker,
                biomarkerId: biomarkerId,
                unit: points.first?.unit ?? nil ?? "",
                dataPoints: points,
                referenceMin: refMin,
                referenceMax: refMax,
                latestStatus: points.last?.status ?? nil ?? "normal",
                aliases: aliases
            )
            
            trends.append(trend)
        }
        
        // Sort trends: abnormal first, then by marker name
        return trends.sorted { first, second in
            let firstAbnormal = first.latestStatus != "normal"
            let secondAbnormal = second.latestStatus != "normal"
            
            if firstAbnormal != secondAbnormal {
                return firstAbnormal
            }
            return first.marker < second.marker
        }
    }
    
    // MARK: - Get Unique Biomarkers
    /// Returns unique normalized biomarker names from all analyses
    func getUniqueBiomarkers(from analyses: [Analysis]) -> [String] {
        var markers: Set<String> = []
        
        for analysis in analyses {
            guard let parsedData = analysis.getParsedData() else { continue }
            for result in parsedData.testResults {
                // Use normalized name to avoid duplicates
                let normalizedMarker = BiomarkerNormalizer.shared.normalize(result.marker)
                markers.insert(normalizedMarker)
            }
        }
        
        return markers.sorted()
    }
    
    // MARK: - Helper: Parse Date
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
            createDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
            createDateFormatter("yyyy-MM-dd'T'HH:mm:ssZ"),
            createDateFormatter("yyyy-MM-dd HH:mm:ss.SSSSSSZ"),
            createDateFormatter("yyyy-MM-dd HH:mm:ss.SSSSSS+00"),
            createDateFormatter("yyyy-MM-dd HH:mm:ss"),
            createDateFormatter("yyyy-MM-dd HH:mm")
        ]
        
        for formatter in formatters {
            if let isoFormatter = formatter as? ISO8601DateFormatter {
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
            } else if let dateFormatter = formatter as? DateFormatter {
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func createDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    // MARK: - Helper: Parse Reference Range
    private func parseReferenceRange(_ referenceRange: String) -> (min: Double?, max: Double?) {
        // Handle "Up to X" format
        if referenceRange.lowercased().starts(with: "up to") {
            let numbers = referenceRange.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Double($0) }
            if let max = numbers.first {
                return (nil, max)
            }
        }
        
        // Handle "X - Y" or "X-Y" format
        let pattern = #"(\d+\.?\d*)\s*[-–—to]+\s*(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (nil, nil)
        }
        
        let range = NSRange(location: 0, length: referenceRange.utf16.count)
        guard let match = regex.firstMatch(in: referenceRange, options: [], range: range) else {
            return (nil, nil)
        }
        
        guard let minRange = Range(match.range(at: 1), in: referenceRange),
              let maxRange = Range(match.range(at: 2), in: referenceRange),
              let min = Double(referenceRange[minRange]),
              let max = Double(referenceRange[maxRange]) else {
            return (nil, nil)
        }
        
        return (min, max)
    }
}
