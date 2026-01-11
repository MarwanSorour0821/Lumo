//
//  HealthScoreCalculator.swift
//  app
//
//  Sophisticated health score calculation based on weighted risk-adjusted biomarker health.
//  Goal: Clinical plausibility + human believability
//
//  Mental model: "How far am I from my healthy state — and what matters most right now?"
//

import Foundation
import Supabase

// MARK: - User Health Profile (for personalization)
struct UserHealthProfile {
    let age: Int?
    let biologicalSex: String?  // "male", "female", "other"
    let healthConditions: [String]
    let healthGoals: [HealthGoal]
    
    enum HealthGoal: String, CaseIterable {
        case cardiovascular = "Heart Health"
        case metabolic = "Metabolic Health"
        case longevity = "Longevity"
        case athletic = "Athletic Performance"
        case general = "General Wellness"
    }
    
    static var `default`: UserHealthProfile {
        UserHealthProfile(age: nil, biologicalSex: nil, healthConditions: [], healthGoals: [.general])
    }
}

// MARK: - Biomarker Sub-Score Result
struct BiomarkerSubScore {
    let biomarkerId: String
    let displayName: String
    let rawValue: Double
    let unit: String
    let subScore: Double           // 0-100 normalized score
    let riskWeight: Double         // How much this marker matters
    let weightedScore: Double      // subScore * riskWeight
    let status: BiomarkerStatus
    let trend: BiomarkerTrend
    let trendModifier: Double      // -0.1 to +0.1 adjustment
    let category: CanonicalBiomarker.BiomarkerCategory
    let explanation: String        // Why this score
    
    enum BiomarkerStatus: String {
        case optimal = "Optimal"
        case good = "Good"
        case borderline = "Borderline"
        case elevated = "Elevated"
        case low = "Low"
        case critical = "Critical"
        
        var colorHex: String {
            switch self {
            case .optimal: return "#22C55E"   // Green
            case .good: return "#84CC16"      // Lime
            case .borderline: return "#F59E0B" // Amber
            case .elevated, .low: return "#EF4444" // Red
            case .critical: return "#DC2626"  // Dark red
            }
        }
    }
    
    enum BiomarkerTrend: String {
        case improving = "↑ Improving"
        case stable = "→ Stable"
        case worsening = "↓ Worsening"
        case unknown = "— New"
        
        var modifier: Double {
            switch self {
            case .improving: return 0.05   // Softens penalty
            case .stable: return 0.0
            case .worsening: return -0.05  // Adds penalty
            case .unknown: return 0.0
            }
        }
    }
}

// MARK: - Health Score Result
struct HealthScoreResult {
    let score: Double                           // 0-10 scale
    let scoreOutOf100: Double                   // 0-100 scale
    let confidence: Double                      // 0-1, based on data completeness
    let biomarkerScores: [BiomarkerSubScore]    // Individual marker scores
    let topConcerns: [BiomarkerSubScore]        // Top 3 dragging score down
    let topImprovements: [BiomarkerSubScore]    // Top 2 improving markers
    let summaryExplanation: String              // One-sentence summary
    let detailedExplanation: String             // Full breakdown
    let scoreDrivers: [String]                  // "Your score is driven mostly by..."
    let timestamp: Date
    
    var formattedScore: String {
        String(format: "%.1f", score)
    }
    
    var scoreCategory: String {
        switch score {
        case 9.0...10.0: return "Excellent"
        case 7.5..<9.0: return "Very Good"
        case 6.0..<7.5: return "Good"
        case 4.5..<6.0: return "Fair"
        case 3.0..<4.5: return "Needs Attention"
        default: return "Critical"
        }
    }
}

// MARK: - Optimal Range Definition
struct OptimalRange {
    let optimal: ClosedRange<Double>        // Best range (score 90-100)
    let good: ClosedRange<Double>           // Good range (score 70-89)
    let acceptable: ClosedRange<Double>     // Acceptable range (score 50-69)
    let riskWeight: Double                  // Base risk weight (0.3-2.0)
    let category: CanonicalBiomarker.BiomarkerCategory
    
    // Personalization adjustments
    struct PersonalizationRules {
        let ageMultiplier: (Int) -> Double      // Age-based weight adjustment
        let sexMultiplier: (String?) -> Double  // Sex-based optimal shift
        let conditionMultipliers: [String: Double] // Condition-based weight changes
    }
    let personalization: PersonalizationRules?
}

// MARK: - Health Score Calculator
class HealthScoreCalculator {
    static let shared = HealthScoreCalculator()
    
    private let normalizer = BiomarkerNormalizer.shared
    
    // Biomarker optimal ranges with outcome-based targets
    private var optimalRanges: [String: OptimalRange] = [:]
    
    private init() {
        setupOptimalRanges()
    }
    
    // MARK: - Setup Optimal Ranges (Outcome-Based, Not Just Reference Ranges)
    private func setupOptimalRanges() {
        // ===== CARDIOVASCULAR RISK MARKERS (High Impact) =====
        
        // ApoB - Primary cardiovascular risk marker
        // Optimal < 60 for high risk, < 80 for moderate risk, < 100 for low risk
        optimalRanges["apob"] = OptimalRange(
            optimal: 0...60,
            good: 60...80,
            acceptable: 80...100,
            riskWeight: 1.6,
            category: .lipids,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 50 ? 1.3 : 1.0 },
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Heart disease": 1.5, "Family history of CVD": 1.4, "Diabetes": 1.3]
            )
        )
        
        // LDL Cholesterol
        optimalRanges["ldl"] = OptimalRange(
            optimal: 0...70,
            good: 70...100,
            acceptable: 100...130,
            riskWeight: 1.3,
            category: .lipids,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 45 ? 1.2 : 1.0 },
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Heart disease": 1.4, "High cholesterol": 1.3]
            )
        )
        
        // Lp(a) - Lipoprotein(a), genetic cardiovascular risk marker
        optimalRanges["lpa"] = OptimalRange(
            optimal: 0...30,
            good: 30...50,
            acceptable: 50...75,
            riskWeight: 1.4,
            category: .lipids,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 }, // Genetic, doesn't change with age
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Heart disease": 1.5, "Family history of CVD": 1.4]
            )
        )
        
        // HDL Cholesterol (higher is better)
        optimalRanges["hdl"] = OptimalRange(
            optimal: 60...100,
            good: 50...60,
            acceptable: 40...50,
            riskWeight: 1.1,
            category: .lipids,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 1.1 : 1.0 },
                conditionMultipliers: [:]
            )
        )
        
        // Triglycerides
        optimalRanges["triglycerides"] = OptimalRange(
            optimal: 0...100,
            good: 100...150,
            acceptable: 150...200,
            riskWeight: 1.2,
            category: .lipids,
            personalization: nil
        )
        
        // VLDL
        optimalRanges["vldl"] = OptimalRange(
            optimal: 5...25,
            good: 2...30,
            acceptable: 0...40,
            riskWeight: 0.7,
            category: .lipids,
            personalization: nil
        )
        
        // Total Cholesterol
        optimalRanges["total_cholesterol"] = OptimalRange(
            optimal: 0...180,
            good: 180...200,
            acceptable: 200...240,
            riskWeight: 0.9,
            category: .lipids,
            personalization: nil
        )
        
        // ===== METABOLIC MARKERS (High Impact) =====
        
        // HbA1c - Key metabolic marker
        optimalRanges["hba1c"] = OptimalRange(
            optimal: 4.0...5.4,
            good: 5.4...5.7,
            acceptable: 5.7...6.4,
            riskWeight: 1.5,
            category: .metabolic,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 60 ? 1.2 : 1.0 },
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Type 2 diabetes": 1.6, "Prediabetes": 1.4, "Obesity": 1.2]
            )
        )
        
        // Fasting Glucose
        optimalRanges["glucose"] = OptimalRange(
            optimal: 70...90,
            good: 90...100,
            acceptable: 100...126,
            riskWeight: 1.3,
            category: .metabolic,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 50 ? 1.1 : 1.0 },
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Type 2 diabetes": 1.5, "Prediabetes": 1.3]
            )
        )
        
        // Fasting Insulin
        optimalRanges["insulin"] = OptimalRange(
            optimal: 2...6,
            good: 6...12,
            acceptable: 12...25,
            riskWeight: 1.2,
            category: .hormones,
            personalization: nil
        )
        
        // ===== INFLAMMATION MARKERS (High Impact) =====
        
        // hs-CRP - High-sensitivity C-reactive protein
        optimalRanges["hs_crp"] = OptimalRange(
            optimal: 0...1.0,
            good: 1.0...2.0,
            acceptable: 2.0...3.0,
            riskWeight: 1.4,
            category: .inflammation,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 50 ? 1.2 : 1.0 },
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Heart disease": 1.4, "Autoimmune disease": 1.3]
            )
        )
        
        // CRP
        optimalRanges["crp"] = OptimalRange(
            optimal: 0...3,
            good: 3...5,
            acceptable: 5...10,
            riskWeight: 1.2,
            category: .inflammation,
            personalization: nil
        )
        
        // ESR
        optimalRanges["esr"] = OptimalRange(
            optimal: 0...10,
            good: 10...15,
            acceptable: 15...20,
            riskWeight: 0.9,
            category: .inflammation,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.9 : 1.0 }, // Women have naturally higher ESR
                conditionMultipliers: [:]
            )
        )
        
        // ===== KIDNEY FUNCTION =====
        
        // eGFR (higher is better)
        optimalRanges["egfr"] = OptimalRange(
            optimal: 90...120,
            good: 60...90,
            acceptable: 45...60,
            riskWeight: 1.3,
            category: .kidney,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 60 ? 0.9 : 1.0 }, // Natural decline with age
                sexMultiplier: { _ in 1.0 },
                conditionMultipliers: ["Kidney disease": 1.5, "High blood pressure": 1.2, "Type 2 diabetes": 1.3]
            )
        )
        
        // Creatinine
        optimalRanges["creatinine"] = OptimalRange(
            optimal: 0.7...1.1,
            good: 0.6...1.3,
            acceptable: 0.5...1.5,
            riskWeight: 1.1,
            category: .kidney,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.9 : 1.0 },
                conditionMultipliers: [:]
            )
        )
        
        // BUN
        optimalRanges["bun"] = OptimalRange(
            optimal: 7...18,
            good: 6...20,
            acceptable: 5...25,
            riskWeight: 0.8,
            category: .kidney,
            personalization: nil
        )
        
        // Uric Acid
        optimalRanges["uric_acid"] = OptimalRange(
            optimal: 3.5...6.0,
            good: 3.0...7.0,
            acceptable: 2.5...8.0,
            riskWeight: 0.9,
            category: .kidney,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.9 : 1.0 },
                conditionMultipliers: ["Gout": 1.4]
            )
        )
        
        // ===== LIVER FUNCTION =====
        
        // ALT
        optimalRanges["alt"] = OptimalRange(
            optimal: 7...30,
            good: 5...40,
            acceptable: 3...56,
            riskWeight: 1.0,
            category: .liver,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.85 : 1.0 }, // Lower optimal for women
                conditionMultipliers: ["Fatty liver": 1.3]
            )
        )
        
        // AST
        optimalRanges["ast"] = OptimalRange(
            optimal: 10...30,
            good: 8...40,
            acceptable: 5...50,
            riskWeight: 0.9,
            category: .liver,
            personalization: nil
        )
        
        // GGT
        optimalRanges["ggt"] = OptimalRange(
            optimal: 9...35,
            good: 5...45,
            acceptable: 3...65,
            riskWeight: 0.8,
            category: .liver,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.8 : 1.0 },
                conditionMultipliers: [:]
            )
        )
        
        // ALP
        optimalRanges["alp"] = OptimalRange(
            optimal: 44...100,
            good: 35...120,
            acceptable: 30...150,
            riskWeight: 0.7,
            category: .liver,
            personalization: nil
        )
        
        // Bilirubin
        optimalRanges["bilirubin_total"] = OptimalRange(
            optimal: 0.2...1.0,
            good: 0.1...1.2,
            acceptable: 0.1...1.5,
            riskWeight: 0.7,
            category: .liver,
            personalization: nil
        )
        
        // Albumin
        optimalRanges["albumin"] = OptimalRange(
            optimal: 4.0...5.0,
            good: 3.5...5.2,
            acceptable: 3.2...5.5,
            riskWeight: 0.8,
            category: .liver,
            personalization: nil
        )
        
        // ===== HEMATOLOGY (Medium Impact) =====
        
        // Hemoglobin
        optimalRanges["hemoglobin"] = OptimalRange(
            optimal: 13.5...16.5,
            good: 12.5...17.5,
            acceptable: 11.5...18.5,
            riskWeight: 1.1,
            category: .hematology,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.9 : 1.0 }, // Women have lower range
                conditionMultipliers: ["Anemia": 1.4]
            )
        )
        
        // Hematocrit
        optimalRanges["hematocrit"] = OptimalRange(
            optimal: 40...50,
            good: 37...52,
            acceptable: 35...55,
            riskWeight: 1.0,
            category: .hematology,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.9 : 1.0 },
                conditionMultipliers: [:]
            )
        )
        
        // RBC
        optimalRanges["rbc"] = OptimalRange(
            optimal: 4.5...5.5,
            good: 4.2...5.8,
            acceptable: 4.0...6.0,
            riskWeight: 0.9,
            category: .hematology,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.9 : 1.0 },
                conditionMultipliers: [:]
            )
        )
        
        // WBC
        optimalRanges["wbc"] = OptimalRange(
            optimal: 4.5...10.0,
            good: 4.0...11.0,
            acceptable: 3.5...12.0,
            riskWeight: 1.0,
            category: .hematology,
            personalization: nil
        )
        
        // Platelets
        optimalRanges["platelets"] = OptimalRange(
            optimal: 150...350,
            good: 140...400,
            acceptable: 100...450,
            riskWeight: 0.9,
            category: .hematology,
            personalization: nil
        )
        
        // MCV
        optimalRanges["mcv"] = OptimalRange(
            optimal: 82...98,
            good: 80...100,
            acceptable: 78...102,
            riskWeight: 0.7,
            category: .hematology,
            personalization: nil
        )
        
        // MCH
        optimalRanges["mch"] = OptimalRange(
            optimal: 27...32,
            good: 26...34,
            acceptable: 25...35,
            riskWeight: 0.6,
            category: .hematology,
            personalization: nil
        )
        
        // MCHC
        optimalRanges["mchc"] = OptimalRange(
            optimal: 32...36,
            good: 31...37,
            acceptable: 30...38,
            riskWeight: 0.6,
            category: .hematology,
            personalization: nil
        )
        
        // RDW
        optimalRanges["rdw"] = OptimalRange(
            optimal: 11.5...14.0,
            good: 11.0...14.5,
            acceptable: 10.5...15.5,
            riskWeight: 0.7,
            category: .hematology,
            personalization: nil
        )
        
        // Neutrophils
        optimalRanges["neutrophils"] = OptimalRange(
            optimal: 2.0...7.0,
            good: 1.8...7.5,
            acceptable: 1.5...8.0,
            riskWeight: 0.8,
            category: .hematology,
            personalization: nil
        )
        
        // Lymphocytes
        optimalRanges["lymphocytes"] = OptimalRange(
            optimal: 1.0...3.5,
            good: 0.8...4.0,
            acceptable: 0.7...4.5,
            riskWeight: 0.8,
            category: .hematology,
            personalization: nil
        )
        
        // ===== THYROID (Medium Impact) =====
        
        // TSH
        optimalRanges["tsh"] = OptimalRange(
            optimal: 1.0...2.5,
            good: 0.5...4.0,
            acceptable: 0.4...4.5,
            riskWeight: 1.1,
            category: .thyroid,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 60 ? 0.9 : 1.0 },
                sexMultiplier: { sex in sex == "female" ? 1.1 : 1.0 },
                conditionMultipliers: ["Thyroid disorder": 1.4, "Hypothyroidism": 1.4, "Hyperthyroidism": 1.4]
            )
        )
        
        // Free T4
        optimalRanges["t4_free"] = OptimalRange(
            optimal: 1.0...1.5,
            good: 0.8...1.8,
            acceptable: 0.7...2.0,
            riskWeight: 0.9,
            category: .thyroid,
            personalization: nil
        )
        
        // Free T3
        optimalRanges["t3_free"] = OptimalRange(
            optimal: 2.5...4.0,
            good: 2.3...4.2,
            acceptable: 2.0...4.5,
            riskWeight: 0.8,
            category: .thyroid,
            personalization: nil
        )
        
        // ===== VITAMINS & MINERALS (Lower Impact) =====
        
        // Vitamin D
        optimalRanges["vitamin_d"] = OptimalRange(
            optimal: 40...60,
            good: 30...70,
            acceptable: 20...80,
            riskWeight: 0.7,
            category: .vitamins,
            personalization: nil
        )
        
        // Vitamin B12
        optimalRanges["vitamin_b12"] = OptimalRange(
            optimal: 500...900,
            good: 400...1000,
            acceptable: 200...1100,
            riskWeight: 0.6,
            category: .vitamins,
            personalization: nil
        )
        
        // Folate
        optimalRanges["folate"] = OptimalRange(
            optimal: 10...20,
            good: 5...25,
            acceptable: 3...30,
            riskWeight: 0.5,
            category: .vitamins,
            personalization: nil
        )
        
        // Iron
        optimalRanges["iron"] = OptimalRange(
            optimal: 60...170,
            good: 50...180,
            acceptable: 40...200,
            riskWeight: 0.7,
            category: .vitamins,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 1.1 : 1.0 },
                conditionMultipliers: ["Anemia": 1.3]
            )
        )
        
        // Ferritin
        optimalRanges["ferritin"] = OptimalRange(
            optimal: 50...150,
            good: 30...200,
            acceptable: 15...300,
            riskWeight: 0.7,
            category: .vitamins,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { _ in 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.8 : 1.0 }, // Women have lower optimal
                conditionMultipliers: ["Anemia": 1.3]
            )
        )
        
        // ===== ELECTROLYTES (Lower Impact) =====
        
        // Sodium
        optimalRanges["sodium"] = OptimalRange(
            optimal: 137...142,
            good: 136...145,
            acceptable: 135...146,
            riskWeight: 0.6,
            category: .electrolytes,
            personalization: nil
        )
        
        // Potassium
        optimalRanges["potassium"] = OptimalRange(
            optimal: 3.8...4.8,
            good: 3.5...5.0,
            acceptable: 3.3...5.3,
            riskWeight: 0.7,
            category: .electrolytes,
            personalization: nil
        )
        
        // Calcium
        optimalRanges["calcium"] = OptimalRange(
            optimal: 9.0...10.0,
            good: 8.5...10.5,
            acceptable: 8.2...10.8,
            riskWeight: 0.6,
            category: .electrolytes,
            personalization: nil
        )
        
        // Magnesium
        optimalRanges["magnesium"] = OptimalRange(
            optimal: 2.0...2.4,
            good: 1.8...2.6,
            acceptable: 1.5...2.8,
            riskWeight: 0.5,
            category: .electrolytes,
            personalization: nil
        )
        
        // ===== CARDIAC MARKERS (High Impact when present) =====
        
        // Troponin
        optimalRanges["troponin"] = OptimalRange(
            optimal: 0...0.01,
            good: 0...0.03,
            acceptable: 0...0.04,
            riskWeight: 1.5,
            category: .cardiac,
            personalization: nil
        )
        
        // BNP
        optimalRanges["bnp"] = OptimalRange(
            optimal: 0...50,
            good: 50...100,
            acceptable: 100...300,
            riskWeight: 1.4,
            category: .cardiac,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 70 ? 0.8 : 1.0 }, // Higher normal with age
                sexMultiplier: { sex in sex == "female" ? 1.1 : 1.0 },
                conditionMultipliers: ["Heart failure": 1.5]
            )
        )
        
        // ===== HORMONES =====
        
        // Testosterone (complex - depends heavily on sex)
        optimalRanges["testosterone"] = OptimalRange(
            optimal: 400...700,       // Male range
            good: 300...800,
            acceptable: 250...900,
            riskWeight: 0.7,
            category: .hormones,
            personalization: OptimalRange.PersonalizationRules(
                ageMultiplier: { age in age > 50 ? 0.9 : 1.0 },
                sexMultiplier: { sex in sex == "female" ? 0.1 : 1.0 }, // Much lower importance for women
                conditionMultipliers: [:]
            )
        )
        
        // Cortisol
        optimalRanges["cortisol"] = OptimalRange(
            optimal: 6...18,
            good: 4...22,
            acceptable: 3...25,
            riskWeight: 0.6,
            category: .hormones,
            personalization: nil
        )
    }
    
    // MARK: - Main Calculation Method
    
    /// Calculate comprehensive health score from analyses
    /// - Parameters:
    ///   - analyses: Array of blood test analyses (sorted newest first)
    ///   - userProfile: User's health profile for personalization
    /// - Returns: HealthScoreResult with detailed breakdown
    func calculateHealthScore(
        analyses: [Analysis],
        userProfile: UserHealthProfile = .default
    ) -> HealthScoreResult {
        guard !analyses.isEmpty else {
            return emptyResult()
        }
        
        // Sort analyses by date (newest first)
        let sortedAnalyses = analyses.sorted { a1, a2 in
            let date1 = ISO8601DateFormatter().date(from: a1.created_at) ?? Date.distantPast
            let date2 = ISO8601DateFormatter().date(from: a2.created_at) ?? Date.distantPast
            return date1 > date2
        }
        
        // Get latest biomarker values and their trends
        let biomarkerData = extractBiomarkerData(from: sortedAnalyses)
        
        // Calculate sub-scores for each biomarker
        var biomarkerScores: [BiomarkerSubScore] = []
        
        for (biomarkerId, data) in biomarkerData {
            if let subScore = calculateBiomarkerSubScore(
                biomarkerId: biomarkerId,
                currentValue: data.currentValue,
                previousValue: data.previousValue,
                unit: data.unit,
                userProfile: userProfile
            ) {
                biomarkerScores.append(subScore)
            }
        }
        
        // Calculate final score using weighted geometric mean
        let finalScore = calculateWeightedGeometricMean(biomarkerScores: biomarkerScores)
        
        // Apply trend modifiers
        let trendAdjustedScore = applyTrendModifiers(baseScore: finalScore, biomarkerScores: biomarkerScores)
        
        // Calculate confidence based on data completeness
        let confidence = calculateConfidence(biomarkerScores: biomarkerScores)
        
        // Get top concerns (lowest scores with high weights)
        let topConcerns = biomarkerScores
            .filter { $0.status != .optimal && $0.status != .good }
            .sorted { ($0.riskWeight * (100 - $0.subScore)) > ($1.riskWeight * (100 - $1.subScore)) }
            .prefix(3)
        
        // Get improving markers
        let topImprovements = biomarkerScores
            .filter { $0.trend == .improving }
            .sorted { $0.riskWeight > $1.riskWeight }
            .prefix(2)
        
        // Generate explanations
        let (summary, detailed, drivers) = generateExplanations(
            score: trendAdjustedScore,
            biomarkerScores: biomarkerScores,
            topConcerns: Array(topConcerns),
            topImprovements: Array(topImprovements)
        )
        
        return HealthScoreResult(
            score: trendAdjustedScore,
            scoreOutOf100: trendAdjustedScore * 10,
            confidence: confidence,
            biomarkerScores: biomarkerScores.sorted { $0.riskWeight > $1.riskWeight },
            topConcerns: Array(topConcerns),
            topImprovements: Array(topImprovements),
            summaryExplanation: summary,
            detailedExplanation: detailed,
            scoreDrivers: drivers,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private struct BiomarkerDataPoint {
        let currentValue: Double
        let previousValue: Double?
        let unit: String
        let displayName: String
    }
    
    private func extractBiomarkerData(from analyses: [Analysis]) -> [String: BiomarkerDataPoint] {
        var latestValues: [String: (value: Double, date: Date, unit: String, displayName: String)] = [:]
        var previousValues: [String: Double] = [:]
        
        for analysis in analyses {
            guard let parsedData = analysis.getParsedData() else { continue }
            let analysisDate = ISO8601DateFormatter().date(from: analysis.created_at) ?? Date.distantPast
            
            for result in parsedData.testResults {
                guard let value = parseValue(result.value) else { continue }
                
                let biomarkerId = normalizer.getCanonicalId(for: result.marker)
                let displayName = normalizer.normalize(result.marker)
                let unit = result.unit ?? ""
                
                // Normalize value to standard unit
                let (normalizedValue, _) = normalizer.normalizeValue(value, fromUnit: unit, forBiomarker: result.marker)
                
                if let existing = latestValues[biomarkerId] {
                    if analysisDate > existing.date {
                        previousValues[biomarkerId] = existing.value
                        latestValues[biomarkerId] = (normalizedValue, analysisDate, unit, displayName)
                    } else if previousValues[biomarkerId] == nil {
                        previousValues[biomarkerId] = normalizedValue
                    }
                } else {
                    latestValues[biomarkerId] = (normalizedValue, analysisDate, unit, displayName)
                }
            }
        }
        
        var result: [String: BiomarkerDataPoint] = [:]
        for (id, data) in latestValues {
            result[id] = BiomarkerDataPoint(
                currentValue: data.value,
                previousValue: previousValues[id],
                unit: data.unit,
                displayName: data.displayName
            )
        }
        return result
    }
    
    private func calculateBiomarkerSubScore(
        biomarkerId: String,
        currentValue: Double,
        previousValue: Double?,
        unit: String,
        userProfile: UserHealthProfile
    ) -> BiomarkerSubScore? {
        guard let optimalRange = optimalRanges[biomarkerId] else {
            // Unknown biomarker - skip
            return nil
        }
        
        let displayName = normalizer.normalize(biomarkerId)
        
        // Calculate base sub-score (0-100)
        let subScore = calculateSubScoreFromRange(
            value: currentValue,
            optimal: optimalRange.optimal,
            good: optimalRange.good,
            acceptable: optimalRange.acceptable
        )
        
        // Calculate personalized risk weight
        var riskWeight = optimalRange.riskWeight
        
        if let personalization = optimalRange.personalization {
            // Age adjustment
            if let age = userProfile.age {
                riskWeight *= personalization.ageMultiplier(age)
            }
            
            // Sex adjustment
            riskWeight *= personalization.sexMultiplier(userProfile.biologicalSex)
            
            // Health conditions adjustment
            for condition in userProfile.healthConditions {
                if let multiplier = personalization.conditionMultipliers[condition] {
                    riskWeight *= multiplier
                }
            }
        }
        
        // Determine status
        let status = determineStatus(value: currentValue, optimal: optimalRange.optimal, good: optimalRange.good, acceptable: optimalRange.acceptable)
        
        // Calculate trend
        let trend = calculateTrend(current: currentValue, previous: previousValue, biomarkerId: biomarkerId)
        
        // Generate explanation
        let explanation = generateBiomarkerExplanation(
            displayName: displayName,
            value: currentValue,
            unit: unit,
            status: status,
            trend: trend
        )
        
        let weightedScore = subScore * riskWeight
        
        return BiomarkerSubScore(
            biomarkerId: biomarkerId,
            displayName: displayName,
            rawValue: currentValue,
            unit: unit,
            subScore: subScore,
            riskWeight: riskWeight,
            weightedScore: weightedScore,
            status: status,
            trend: trend,
            trendModifier: trend.modifier,
            category: optimalRange.category,
            explanation: explanation
        )
    }
    
    private func calculateSubScoreFromRange(
        value: Double,
        optimal: ClosedRange<Double>,
        good: ClosedRange<Double>,
        acceptable: ClosedRange<Double>
    ) -> Double {
        // Check if higher is better (like HDL, eGFR)
        let higherIsBetter = optimal.lowerBound > acceptable.lowerBound
        
        if optimal.contains(value) {
            // In optimal range: 90-100
            let position = (value - optimal.lowerBound) / (optimal.upperBound - optimal.lowerBound)
            return higherIsBetter ? 90 + (position * 10) : 90 + ((1 - abs(position - 0.5) * 2) * 10)
        } else if good.contains(value) {
            // In good range: 70-89
            if value < optimal.lowerBound {
                let distance = optimal.lowerBound - value
                let range = optimal.lowerBound - good.lowerBound
                return 89 - (distance / range) * 19
            } else {
                let distance = value - optimal.upperBound
                let range = good.upperBound - optimal.upperBound
                return 89 - (distance / range) * 19
            }
        } else if acceptable.contains(value) {
            // In acceptable range: 50-69
            if value < good.lowerBound {
                let distance = good.lowerBound - value
                let range = good.lowerBound - acceptable.lowerBound
                return 69 - (distance / range) * 19
            } else {
                let distance = value - good.upperBound
                let range = acceptable.upperBound - good.upperBound
                return 69 - (distance / range) * 19
            }
        } else {
            // Outside acceptable range: 0-49
            if value < acceptable.lowerBound {
                let distance = acceptable.lowerBound - value
                let penalty = min(distance / acceptable.lowerBound, 1.0)
                return max(49 - (penalty * 49), 0)
            } else {
                let distance = value - acceptable.upperBound
                let penalty = min(distance / acceptable.upperBound, 1.0)
                return max(49 - (penalty * 49), 0)
            }
        }
    }
    
    private func determineStatus(
        value: Double,
        optimal: ClosedRange<Double>,
        good: ClosedRange<Double>,
        acceptable: ClosedRange<Double>
    ) -> BiomarkerSubScore.BiomarkerStatus {
        if optimal.contains(value) {
            return .optimal
        } else if good.contains(value) {
            return .good
        } else if acceptable.contains(value) {
            return .borderline
        } else if value < acceptable.lowerBound {
            return value < acceptable.lowerBound * 0.7 ? .critical : .low
        } else {
            return value > acceptable.upperBound * 1.5 ? .critical : .elevated
        }
    }
    
    private func calculateTrend(
        current: Double,
        previous: Double?,
        biomarkerId: String
    ) -> BiomarkerSubScore.BiomarkerTrend {
        guard let previous = previous else { return .unknown }
        
        let percentChange = (current - previous) / previous * 100
        let threshold: Double = 5.0 // 5% change threshold
        
        // Determine if higher is better for this biomarker
        let higherIsBetter = ["hdl", "egfr", "albumin"].contains(biomarkerId)
        
        if abs(percentChange) < threshold {
            return .stable
        } else if percentChange > 0 {
            return higherIsBetter ? .improving : .worsening
        } else {
            return higherIsBetter ? .worsening : .improving
        }
    }
    
    /// Calculate weighted geometric mean for fairer aggregation
    /// One bad marker hurts more than many good ones help
    private func calculateWeightedGeometricMean(biomarkerScores: [BiomarkerSubScore]) -> Double {
        guard !biomarkerScores.isEmpty else { return 5.0 }
        
        var weightedLogSum: Double = 0
        var totalWeight: Double = 0
        
        for score in biomarkerScores {
            // Avoid log(0) by using minimum of 1
            let safeScore = max(score.subScore, 1)
            weightedLogSum += score.riskWeight * log(safeScore)
            totalWeight += score.riskWeight
        }
        
        guard totalWeight > 0 else { return 5.0 }
        
        // Geometric mean
        let geometricMean = exp(weightedLogSum / totalWeight)
        
        // Convert from 0-100 to 0-10 scale
        return geometricMean / 10.0
    }
    
    private func applyTrendModifiers(baseScore: Double, biomarkerScores: [BiomarkerSubScore]) -> Double {
        guard !biomarkerScores.isEmpty else { return baseScore }
        
        var totalModifier: Double = 0
        var totalWeight: Double = 0
        
        for score in biomarkerScores {
            // Only apply trend modifier if marker is not optimal
            if score.status != .optimal {
                totalModifier += score.trendModifier * score.riskWeight
                totalWeight += score.riskWeight
            }
        }
        
        let averageModifier = totalWeight > 0 ? totalModifier / totalWeight : 0
        
        // Apply modifier (clamped to reasonable range)
        let adjusted = baseScore + (averageModifier * baseScore)
        return min(max(adjusted, 0), 10)
    }
    
    private func calculateConfidence(biomarkerScores: [BiomarkerSubScore]) -> Double {
        // Key markers that should be present for high confidence
        let keyMarkers = Set(["hemoglobin", "glucose", "ldl", "hdl", "triglycerides", "creatinine", "alt", "tsh"])
        
        let presentKeyMarkers = biomarkerScores.filter { keyMarkers.contains($0.biomarkerId) }.count
        let totalMarkers = biomarkerScores.count
        
        // Base confidence on coverage of key markers (50%) and total markers (50%)
        let keyMarkerScore = Double(presentKeyMarkers) / Double(keyMarkers.count)
        let totalMarkerScore = min(Double(totalMarkers) / 15.0, 1.0) // 15+ markers = 100%
        
        return (keyMarkerScore * 0.5) + (totalMarkerScore * 0.5)
    }
    
    private func generateExplanations(
        score: Double,
        biomarkerScores: [BiomarkerSubScore],
        topConcerns: [BiomarkerSubScore],
        topImprovements: [BiomarkerSubScore]
    ) -> (summary: String, detailed: String, drivers: [String]) {
        
        // Summary
        var summary: String
        if topConcerns.isEmpty {
            summary = "\(String(format: "%.1f", score)) — All biomarkers look healthy"
        } else if topConcerns.count == 1 {
            summary = "\(String(format: "%.1f", score)) — \(topConcerns[0].displayName) needs attention"
        } else {
            let names = topConcerns.prefix(2).map { $0.displayName }.joined(separator: " and ")
            summary = "\(String(format: "%.1f", score)) — \(names) are holding you back"
        }
        
        if !topImprovements.isEmpty {
            summary += ", but \(topImprovements[0].displayName) is improving"
        }
        
        // Drivers
        var drivers: [String] = []
        if !topConcerns.isEmpty {
            let concernNames = topConcerns.map { $0.displayName }.joined(separator: ", ")
            drivers.append("Your score is driven mostly by \(concernNames)")
        }
        
        // Detailed explanation
        var detailed = "Your health score reflects current biomarker risk relative to optimal health.\n\n"
        
        if !topConcerns.isEmpty {
            detailed += "**Areas needing attention:**\n"
            for concern in topConcerns {
                detailed += "• \(concern.displayName): \(concern.explanation)\n"
            }
            detailed += "\n"
        }
        
        if !topImprovements.isEmpty {
            detailed += "**Improving markers:**\n"
            for improvement in topImprovements {
                detailed += "• \(improvement.displayName) is trending in the right direction\n"
            }
        }
        
        return (summary, detailed, drivers)
    }
    
    private func generateBiomarkerExplanation(
        displayName: String,
        value: Double,
        unit: String,
        status: BiomarkerSubScore.BiomarkerStatus,
        trend: BiomarkerSubScore.BiomarkerTrend
    ) -> String {
        let valueStr = String(format: "%.1f", value)
        
        switch status {
        case .optimal:
            return "\(valueStr) \(unit) — In optimal range"
        case .good:
            return "\(valueStr) \(unit) — Good, close to optimal"
        case .borderline:
            return "\(valueStr) \(unit) — Borderline, worth monitoring"
        case .elevated:
            return "\(valueStr) \(unit) — Elevated, consider lifestyle changes"
        case .low:
            return "\(valueStr) \(unit) — Low, may need attention"
        case .critical:
            return "\(valueStr) \(unit) — Outside normal range, consult a doctor"
        }
    }
    
    private func parseValue(_ valueString: String) -> Double? {
        let cleaned = valueString.replacingOccurrences(of: ",", with: "")
        if let value = Double(cleaned) {
            return value
        }
        
        let numberPattern = #"(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           let range = Range(match.range(at: 1), in: cleaned),
           let value = Double(String(cleaned[range])) {
            return value
        }
        
        return nil
    }
    
    private func emptyResult() -> HealthScoreResult {
        return HealthScoreResult(
            score: 0,
            scoreOutOf100: 0,
            confidence: 0,
            biomarkerScores: [],
            topConcerns: [],
            topImprovements: [],
            summaryExplanation: "No data available. Upload a blood test to see your health score.",
            detailedExplanation: "Your health score will be calculated once you upload blood test results.",
            scoreDrivers: [],
            timestamp: Date()
        )
    }
}

// MARK: - Extension for HealthScoreService Integration
extension HealthScoreCalculator {
    
    /// Legacy compatibility method - uses new calculation but returns simple Double
    func calculateSimpleScore(analyses: [Analysis]) -> Double {
        let result = calculateHealthScore(analyses: analyses)
        return result.score
    }
    
    /// Get top biomarkers needing attention (for UI)
    func getTopBiomarkersNeedingAttention(analyses: [Analysis], limit: Int = 4) -> [BiomarkerSubScore] {
        let result = calculateHealthScore(analyses: analyses)
        return Array(result.topConcerns.prefix(limit))
    }
}

// MARK: - User Profile Fetcher
extension UserHealthProfile {
    
    /// Fetch user profile from Supabase for health score personalization
    static func fetchFromSupabase() async -> UserHealthProfile {
        do {
            guard let supabaseURL = SupabaseManager.shared.getURL(),
                  let supabaseKey = SupabaseManager.shared.getAnonKey(),
                  let client = SupabaseManager.shared.getClient() else {
                print("⚠️ Supabase configuration missing for user profile fetch")
                return .default
            }
            
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            let accessToken = session.accessToken
            
            guard let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(userId)&select=biological_sex,date_of_birth,health_conditions") else {
                return .default
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ Failed to fetch user profile for health score")
                return .default
            }
            
            struct UserProfileData: Codable {
                let biological_sex: String?
                let date_of_birth: String?
                let health_conditions: [String]?
            }
            
            let decoder = JSONDecoder()
            var profileData: UserProfileData?
            
            if let single = try? decoder.decode(UserProfileData.self, from: data) {
                profileData = single
            } else if let array = try? decoder.decode([UserProfileData].self, from: data),
                      let first = array.first {
                profileData = first
            }
            
            guard let profile = profileData else {
                return .default
            }
            
            // Calculate age from date of birth
            var age: Int? = nil
            if let dobString = profile.date_of_birth {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                
                if let dob = formatter.date(from: dobString) {
                    let calendar = Calendar.current
                    let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
                    age = ageComponents.year
                } else {
                    // Try alternative date format
                    let altFormatter = DateFormatter()
                    altFormatter.dateFormat = "yyyy-MM-dd"
                    if let dob = altFormatter.date(from: dobString) {
                        let calendar = Calendar.current
                        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
                        age = ageComponents.year
                    }
                }
            }
            
            print("✅ Fetched user profile for health score: age=\(age ?? -1), sex=\(profile.biological_sex ?? "unknown"), conditions=\(profile.health_conditions?.count ?? 0)")
            
            return UserHealthProfile(
                age: age,
                biologicalSex: profile.biological_sex,
                healthConditions: profile.health_conditions ?? [],
                healthGoals: [.general] // Default goal for now
            )
            
        } catch {
            print("⚠️ Error fetching user profile: \(error.localizedDescription)")
            return .default
        }
    }
}

// MARK: - Health Score Summary for UI
struct HealthScoreSummary {
    let score: Double
    let formattedScore: String
    let category: String
    let summaryText: String
    let topConcernNames: [String]
    let improvingMarkerNames: [String]
    let driversText: String
    let confidence: Double
    
    init(from result: HealthScoreResult) {
        self.score = result.score
        self.formattedScore = result.formattedScore
        self.category = result.scoreCategory
        self.summaryText = result.summaryExplanation
        self.topConcernNames = result.topConcerns.map { $0.displayName }
        self.improvingMarkerNames = result.topImprovements.map { $0.displayName }
        self.driversText = result.scoreDrivers.first ?? ""
        self.confidence = result.confidence
    }
}
