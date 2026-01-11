//
//  BiomarkerNormalizer.swift
//  app
//
//  Normalizes biomarker names to canonical IDs for consistent tracking
//

import Foundation

// MARK: - Canonical Biomarker Model
struct CanonicalBiomarker {
    let id: String                    // Internal ID, never changes
    let canonicalName: String         // Display name in the app
    let aliases: [String]             // All known variations (lowercase)
    let defaultUnit: String           // Preferred unit
    let alternativeUnits: [String: Double]  // Unit -> conversion factor to default
    let category: BiomarkerCategory
    
    enum BiomarkerCategory: String {
        case hematology = "Hematology"
        case metabolic = "Metabolic Panel"
        case lipids = "Lipid Panel"
        case liver = "Liver Function"
        case kidney = "Kidney Function"
        case thyroid = "Thyroid"
        case vitamins = "Vitamins & Minerals"
        case hormones = "Hormones"
        case inflammation = "Inflammation"
        case cardiac = "Cardiac Markers"
        case electrolytes = "Electrolytes"
        case other = "Other"
    }
}

// MARK: - Biomarker Normalizer
class BiomarkerNormalizer {
    static let shared = BiomarkerNormalizer()
    
    // Lookup tables for fast access
    private var aliasToId: [String: String] = [:]
    private var idToBiomarker: [String: CanonicalBiomarker] = [:]
    
    private init() {
        setupCanonicalBiomarkers()
    }
    
    // MARK: - Canonical Biomarker Database
    private func setupCanonicalBiomarkers() {
        let biomarkers: [CanonicalBiomarker] = [
            // ===== HEMATOLOGY =====
            CanonicalBiomarker(
                id: "hemoglobin",
                canonicalName: "Hemoglobin",
                aliases: ["hemoglobin", "haemoglobin", "hb", "hgb", "hemoglobin (hb)", "haemoglobin (hb)", "hgb (hemoglobin)", "blood hemoglobin"],
                defaultUnit: "g/dL",
                alternativeUnits: ["g/l": 0.1, "mmol/l": 1.61],  // g/L ÷ 10 = g/dL
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "hematocrit",
                canonicalName: "Hematocrit",
                aliases: ["hematocrit", "haematocrit", "hct", "pcv", "packed cell volume", "hematocrit (hct)"],
                defaultUnit: "%",
                alternativeUnits: ["l/l": 100, "ratio": 100],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "rbc",
                canonicalName: "Red Blood Cells",
                aliases: ["rbc", "red blood cells", "red blood cell count", "erythrocytes", "erythrocyte count", "rbc count", "red cell count"],
                defaultUnit: "M/µL",
                alternativeUnits: ["10^12/l": 1, "x10^12/l": 1, "million/ul": 1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "wbc",
                canonicalName: "White Blood Cells",
                aliases: ["wbc", "white blood cells", "white blood cell count", "leukocytes", "leukocyte count", "wbc count", "white cell count", "total wbc"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "x10^9/l": 1, "thousand/ul": 1, "cells/ul": 0.001],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "platelets",
                canonicalName: "Platelets",
                aliases: ["platelets", "platelet count", "plt", "thrombocytes", "thrombocyte count"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "x10^9/l": 1, "thousand/ul": 1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "mcv",
                canonicalName: "MCV",
                aliases: ["mcv", "mean corpuscular volume", "mean cell volume"],
                defaultUnit: "fL",
                alternativeUnits: [:],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "mch",
                canonicalName: "MCH",
                aliases: ["mch", "mean corpuscular hemoglobin", "mean cell hemoglobin", "mean corpuscular haemoglobin"],
                defaultUnit: "pg",
                alternativeUnits: [:],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "mchc",
                canonicalName: "MCHC",
                aliases: ["mchc", "mean corpuscular hemoglobin concentration", "mean cell hemoglobin concentration"],
                defaultUnit: "g/dL",
                alternativeUnits: ["g/l": 0.1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "rdw",
                canonicalName: "RDW",
                aliases: ["rdw", "red cell distribution width", "rdw-cv", "rdw cv", "red blood cell distribution width"],
                defaultUnit: "%",
                alternativeUnits: [:],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "neutrophils",
                canonicalName: "Neutrophils",
                aliases: ["neutrophils", "neutrophil count", "neut", "neu", "absolute neutrophils", "anc", "neutrophils %", "neutrophils absolute"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "%": 1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "lymphocytes",
                canonicalName: "Lymphocytes",
                aliases: ["lymphocytes", "lymphocyte count", "lymph", "lym", "absolute lymphocytes", "lymphocytes %", "lymphocytes absolute"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "%": 1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "monocytes",
                canonicalName: "Monocytes",
                aliases: ["monocytes", "monocyte count", "mono", "absolute monocytes", "monocytes %", "monocytes absolute"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "%": 1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "eosinophils",
                canonicalName: "Eosinophils",
                aliases: ["eosinophils", "eosinophil count", "eos", "absolute eosinophils", "eosinophils %", "eosinophils absolute"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "%": 1],
                category: .hematology
            ),
            CanonicalBiomarker(
                id: "basophils",
                canonicalName: "Basophils",
                aliases: ["basophils", "basophil count", "baso", "absolute basophils", "basophils %", "basophils absolute"],
                defaultUnit: "K/µL",
                alternativeUnits: ["10^9/l": 1, "%": 1],
                category: .hematology
            ),
            
            // ===== METABOLIC PANEL =====
            CanonicalBiomarker(
                id: "glucose",
                canonicalName: "Glucose",
                aliases: ["glucose", "blood glucose", "fasting glucose", "fbs", "fasting blood sugar", "blood sugar", "serum glucose", "plasma glucose", "glucose fasting"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 18.0182],  // mmol/L × 18.0182 = mg/dL
                category: .metabolic
            ),
            CanonicalBiomarker(
                id: "hba1c",
                canonicalName: "HbA1c",
                aliases: ["hba1c", "hemoglobin a1c", "haemoglobin a1c", "glycated hemoglobin", "glycated haemoglobin", "a1c", "glycohemoglobin", "hb a1c"],
                defaultUnit: "%",
                alternativeUnits: ["mmol/mol": 0.0915],  // (mmol/mol × 0.0915) + 2.15 = %
                category: .metabolic
            ),
            CanonicalBiomarker(
                id: "bun",
                canonicalName: "BUN",
                aliases: ["bun", "blood urea nitrogen", "urea nitrogen", "urea", "serum urea"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 2.8],
                category: .kidney
            ),
            CanonicalBiomarker(
                id: "creatinine",
                canonicalName: "Creatinine",
                aliases: ["creatinine", "serum creatinine", "creat", "cr", "blood creatinine"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["umol/l": 0.0113, "µmol/l": 0.0113],
                category: .kidney
            ),
            CanonicalBiomarker(
                id: "egfr",
                canonicalName: "eGFR",
                aliases: ["egfr", "estimated gfr", "gfr", "glomerular filtration rate", "estimated glomerular filtration rate"],
                defaultUnit: "mL/min/1.73m²",
                alternativeUnits: [:],
                category: .kidney
            ),
            CanonicalBiomarker(
                id: "uric_acid",
                canonicalName: "Uric Acid",
                aliases: ["uric acid", "urate", "serum uric acid", "blood uric acid"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["umol/l": 0.0168, "µmol/l": 0.0168],
                category: .kidney
            ),
            
            // ===== LIPID PANEL =====
            CanonicalBiomarker(
                id: "total_cholesterol",
                canonicalName: "Total Cholesterol",
                aliases: ["total cholesterol", "cholesterol", "cholesterol total", "serum cholesterol", "tc"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 38.67],
                category: .lipids
            ),
            CanonicalBiomarker(
                id: "ldl",
                canonicalName: "LDL Cholesterol",
                aliases: ["ldl", "ldl cholesterol", "ldl-c", "low density lipoprotein", "ldl-cholesterol", "bad cholesterol"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 38.67],
                category: .lipids
            ),
            CanonicalBiomarker(
                id: "apob",
                canonicalName: "ApoB",
                aliases: ["apob", "apolipoprotein b", "apo b", "apolipoprotein b-100", "apo b-100", "apob-100"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["g/l": 100],  // g/L × 100 = mg/dL
                category: .lipids
            ),
            CanonicalBiomarker(
                id: "lpa",
                canonicalName: "Lp(a)",
                aliases: ["lp(a)", "lpa", "lipoprotein(a)", "lipoprotein a", "lp a"],
                defaultUnit: "nmol/L",
                alternativeUnits: ["mg/dl": 2.5],  // Approximate conversion
                category: .lipids
            ),
            CanonicalBiomarker(
                id: "hdl",
                canonicalName: "HDL Cholesterol",
                aliases: ["hdl", "hdl cholesterol", "hdl-c", "high density lipoprotein", "hdl-cholesterol", "good cholesterol"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 38.67],
                category: .lipids
            ),
            CanonicalBiomarker(
                id: "triglycerides",
                canonicalName: "Triglycerides",
                aliases: ["triglycerides", "tg", "trigs", "serum triglycerides", "blood triglycerides"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 88.57],
                category: .lipids
            ),
            CanonicalBiomarker(
                id: "vldl",
                canonicalName: "VLDL Cholesterol",
                aliases: ["vldl", "vldl cholesterol", "vldl-c", "very low density lipoprotein"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 38.67],
                category: .lipids
            ),
            
            // ===== LIVER FUNCTION =====
            CanonicalBiomarker(
                id: "alt",
                canonicalName: "ALT",
                aliases: ["alt", "alanine aminotransferase", "sgpt", "alanine transaminase", "alt (sgpt)", "sgpt (alt)"],
                defaultUnit: "U/L",
                alternativeUnits: ["iu/l": 1],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "ast",
                canonicalName: "AST",
                aliases: ["ast", "aspartate aminotransferase", "sgot", "aspartate transaminase", "ast (sgot)", "sgot (ast)"],
                defaultUnit: "U/L",
                alternativeUnits: ["iu/l": 1],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "alp",
                canonicalName: "ALP",
                aliases: ["alp", "alkaline phosphatase", "alk phos", "alkp"],
                defaultUnit: "U/L",
                alternativeUnits: ["iu/l": 1],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "ggt",
                canonicalName: "GGT",
                aliases: ["ggt", "gamma-glutamyl transferase", "gamma gt", "ggtp", "gamma-glutamyl transpeptidase"],
                defaultUnit: "U/L",
                alternativeUnits: ["iu/l": 1],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "bilirubin_total",
                canonicalName: "Total Bilirubin",
                aliases: ["total bilirubin", "bilirubin", "bilirubin total", "tbil", "t. bilirubin", "serum bilirubin"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["umol/l": 0.0585, "µmol/l": 0.0585],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "bilirubin_direct",
                canonicalName: "Direct Bilirubin",
                aliases: ["direct bilirubin", "bilirubin direct", "conjugated bilirubin", "dbil", "d. bilirubin"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["umol/l": 0.0585, "µmol/l": 0.0585],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "albumin",
                canonicalName: "Albumin",
                aliases: ["albumin", "serum albumin", "alb"],
                defaultUnit: "g/dL",
                alternativeUnits: ["g/l": 0.1],
                category: .liver
            ),
            CanonicalBiomarker(
                id: "total_protein",
                canonicalName: "Total Protein",
                aliases: ["total protein", "protein total", "serum protein", "tp"],
                defaultUnit: "g/dL",
                alternativeUnits: ["g/l": 0.1],
                category: .liver
            ),
            
            // ===== ELECTROLYTES =====
            CanonicalBiomarker(
                id: "sodium",
                canonicalName: "Sodium",
                aliases: ["sodium", "na", "na+", "serum sodium", "blood sodium"],
                defaultUnit: "mEq/L",
                alternativeUnits: ["mmol/l": 1],
                category: .electrolytes
            ),
            CanonicalBiomarker(
                id: "potassium",
                canonicalName: "Potassium",
                aliases: ["potassium", "k", "k+", "serum potassium", "blood potassium"],
                defaultUnit: "mEq/L",
                alternativeUnits: ["mmol/l": 1],
                category: .electrolytes
            ),
            CanonicalBiomarker(
                id: "chloride",
                canonicalName: "Chloride",
                aliases: ["chloride", "cl", "cl-", "serum chloride", "blood chloride"],
                defaultUnit: "mEq/L",
                alternativeUnits: ["mmol/l": 1],
                category: .electrolytes
            ),
            CanonicalBiomarker(
                id: "bicarbonate",
                canonicalName: "Bicarbonate",
                aliases: ["bicarbonate", "co2", "hco3", "carbon dioxide", "total co2", "serum bicarbonate"],
                defaultUnit: "mEq/L",
                alternativeUnits: ["mmol/l": 1],
                category: .electrolytes
            ),
            CanonicalBiomarker(
                id: "calcium",
                canonicalName: "Calcium",
                aliases: ["calcium", "ca", "ca2+", "serum calcium", "total calcium", "blood calcium"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 4.0],
                category: .electrolytes
            ),
            CanonicalBiomarker(
                id: "magnesium",
                canonicalName: "Magnesium",
                aliases: ["magnesium", "mg", "mg2+", "serum magnesium", "blood magnesium"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 2.43],
                category: .electrolytes
            ),
            CanonicalBiomarker(
                id: "phosphorus",
                canonicalName: "Phosphorus",
                aliases: ["phosphorus", "phosphate", "phos", "serum phosphorus", "inorganic phosphorus"],
                defaultUnit: "mg/dL",
                alternativeUnits: ["mmol/l": 3.1],
                category: .electrolytes
            ),
            
            // ===== THYROID =====
            CanonicalBiomarker(
                id: "tsh",
                canonicalName: "TSH",
                aliases: ["tsh", "thyroid stimulating hormone", "thyrotropin", "serum tsh"],
                defaultUnit: "mIU/L",
                alternativeUnits: ["uiu/ml": 1, "µiu/ml": 1],
                category: .thyroid
            ),
            CanonicalBiomarker(
                id: "t4_free",
                canonicalName: "Free T4",
                aliases: ["free t4", "ft4", "t4 free", "free thyroxine", "thyroxine free"],
                defaultUnit: "ng/dL",
                alternativeUnits: ["pmol/l": 0.0777],
                category: .thyroid
            ),
            CanonicalBiomarker(
                id: "t4_total",
                canonicalName: "Total T4",
                aliases: ["total t4", "t4", "t4 total", "thyroxine", "serum t4"],
                defaultUnit: "µg/dL",
                alternativeUnits: ["nmol/l": 0.0777],
                category: .thyroid
            ),
            CanonicalBiomarker(
                id: "t3_free",
                canonicalName: "Free T3",
                aliases: ["free t3", "ft3", "t3 free", "free triiodothyronine", "triiodothyronine free"],
                defaultUnit: "pg/mL",
                alternativeUnits: ["pmol/l": 0.651],
                category: .thyroid
            ),
            CanonicalBiomarker(
                id: "t3_total",
                canonicalName: "Total T3",
                aliases: ["total t3", "t3", "t3 total", "triiodothyronine", "serum t3"],
                defaultUnit: "ng/dL",
                alternativeUnits: ["nmol/l": 65.1],
                category: .thyroid
            ),
            
            // ===== VITAMINS & MINERALS =====
            CanonicalBiomarker(
                id: "vitamin_d",
                canonicalName: "Vitamin D",
                aliases: ["vitamin d", "vit d", "25-hydroxy vitamin d", "25-oh vitamin d", "vitamin d 25-hydroxy", "25(oh)d", "cholecalciferol", "vitamin d3", "vitamin d total"],
                defaultUnit: "ng/mL",
                alternativeUnits: ["nmol/l": 0.4],
                category: .vitamins
            ),
            CanonicalBiomarker(
                id: "vitamin_b12",
                canonicalName: "Vitamin B12",
                aliases: ["vitamin b12", "b12", "vit b12", "cobalamin", "serum b12", "cyanocobalamin"],
                defaultUnit: "pg/mL",
                alternativeUnits: ["pmol/l": 1.355],
                category: .vitamins
            ),
            CanonicalBiomarker(
                id: "folate",
                canonicalName: "Folate",
                aliases: ["folate", "folic acid", "serum folate", "vitamin b9", "b9"],
                defaultUnit: "ng/mL",
                alternativeUnits: ["nmol/l": 0.4536],
                category: .vitamins
            ),
            CanonicalBiomarker(
                id: "iron",
                canonicalName: "Iron",
                aliases: ["iron", "serum iron", "fe", "blood iron"],
                defaultUnit: "µg/dL",
                alternativeUnits: ["umol/l": 5.587, "µmol/l": 5.587],
                category: .vitamins
            ),
            CanonicalBiomarker(
                id: "ferritin",
                canonicalName: "Ferritin",
                aliases: ["ferritin", "serum ferritin", "blood ferritin"],
                defaultUnit: "ng/mL",
                alternativeUnits: ["ug/l": 1, "µg/l": 1, "pmol/l": 0.4484],
                category: .vitamins
            ),
            CanonicalBiomarker(
                id: "tibc",
                canonicalName: "TIBC",
                aliases: ["tibc", "total iron binding capacity", "iron binding capacity"],
                defaultUnit: "µg/dL",
                alternativeUnits: ["umol/l": 5.587, "µmol/l": 5.587],
                category: .vitamins
            ),
            CanonicalBiomarker(
                id: "transferrin_saturation",
                canonicalName: "Transferrin Saturation",
                aliases: ["transferrin saturation", "tsat", "iron saturation", "% saturation"],
                defaultUnit: "%",
                alternativeUnits: [:],
                category: .vitamins
            ),
            
            // ===== INFLAMMATION =====
            CanonicalBiomarker(
                id: "crp",
                canonicalName: "CRP",
                aliases: ["crp", "c-reactive protein", "c reactive protein", "serum crp"],
                defaultUnit: "mg/L",
                alternativeUnits: ["mg/dl": 10],
                category: .inflammation
            ),
            CanonicalBiomarker(
                id: "hs_crp",
                canonicalName: "hs-CRP",
                aliases: ["hs-crp", "high sensitivity crp", "high-sensitivity c-reactive protein", "hscrp", "cardiac crp"],
                defaultUnit: "mg/L",
                alternativeUnits: ["mg/dl": 10],
                category: .inflammation
            ),
            CanonicalBiomarker(
                id: "esr",
                canonicalName: "ESR",
                aliases: ["esr", "erythrocyte sedimentation rate", "sed rate", "sedimentation rate"],
                defaultUnit: "mm/hr",
                alternativeUnits: [:],
                category: .inflammation
            ),
            
            // ===== CARDIAC MARKERS =====
            CanonicalBiomarker(
                id: "troponin",
                canonicalName: "Troponin",
                aliases: ["troponin", "troponin i", "troponin t", "hs-troponin", "high sensitivity troponin", "cardiac troponin"],
                defaultUnit: "ng/mL",
                alternativeUnits: ["ng/l": 0.001, "pg/ml": 0.001],
                category: .cardiac
            ),
            CanonicalBiomarker(
                id: "bnp",
                canonicalName: "BNP",
                aliases: ["bnp", "b-type natriuretic peptide", "brain natriuretic peptide", "nt-probnp", "pro-bnp"],
                defaultUnit: "pg/mL",
                alternativeUnits: ["ng/l": 1],
                category: .cardiac
            ),
            
            // ===== HORMONES =====
            CanonicalBiomarker(
                id: "testosterone",
                canonicalName: "Testosterone",
                aliases: ["testosterone", "total testosterone", "serum testosterone", "free testosterone"],
                defaultUnit: "ng/dL",
                alternativeUnits: ["nmol/l": 28.84],
                category: .hormones
            ),
            CanonicalBiomarker(
                id: "estradiol",
                canonicalName: "Estradiol",
                aliases: ["estradiol", "e2", "estrogen", "serum estradiol"],
                defaultUnit: "pg/mL",
                alternativeUnits: ["pmol/l": 0.2724],
                category: .hormones
            ),
            CanonicalBiomarker(
                id: "cortisol",
                canonicalName: "Cortisol",
                aliases: ["cortisol", "serum cortisol", "blood cortisol", "morning cortisol"],
                defaultUnit: "µg/dL",
                alternativeUnits: ["nmol/l": 0.0362],
                category: .hormones
            ),
            CanonicalBiomarker(
                id: "insulin",
                canonicalName: "Insulin",
                aliases: ["insulin", "fasting insulin", "serum insulin"],
                defaultUnit: "µIU/mL",
                alternativeUnits: ["pmol/l": 0.1442],
                category: .hormones
            ),
            
            // ===== OTHER =====
            CanonicalBiomarker(
                id: "psa",
                canonicalName: "PSA",
                aliases: ["psa", "prostate specific antigen", "prostate-specific antigen", "total psa"],
                defaultUnit: "ng/mL",
                alternativeUnits: ["ug/l": 1, "µg/l": 1],
                category: .other
            ),
        ]
        
        // Build lookup tables
        for biomarker in biomarkers {
            idToBiomarker[biomarker.id] = biomarker
            for alias in biomarker.aliases {
                aliasToId[alias] = biomarker.id
            }
        }
    }
    
    // MARK: - Public API
    
    /// Normalize a raw biomarker name to its canonical display name
    /// Returns the canonical name if found, otherwise returns the original name
    func normalize(_ rawName: String) -> String {
        let id = getCanonicalId(for: rawName)
        if let biomarker = idToBiomarker[id] {
            return biomarker.canonicalName
        }
        // Return original with first letter capitalized if no match
        return rawName.prefix(1).uppercased() + rawName.dropFirst()
    }
    
    /// Get the canonical ID for a raw biomarker name
    /// This ID should be used for all internal logic and comparisons
    func getCanonicalId(for rawName: String) -> String {
        let normalized = preprocessName(rawName)
        
        // 1. Try exact match first
        if let id = aliasToId[normalized] {
            return id
        }
        
        // 2. Try matching without numbers and special chars
        let cleanedName = normalized.components(separatedBy: CharacterSet.decimalDigits).joined()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if let id = aliasToId[cleanedName] {
            return id
        }
        
        // 3. Try fuzzy matching
        if let (id, confidence) = fuzzyMatch(normalized), confidence > 0.85 {
            return id
        }
        
        // 4. Return normalized name as ID if no match found
        return normalized.replacingOccurrences(of: " ", with: "_")
    }
    
    /// Get full biomarker info by ID
    func getBiomarker(byId id: String) -> CanonicalBiomarker? {
        return idToBiomarker[id]
    }
    
    /// Get all known aliases for a biomarker
    func getAliases(for rawName: String) -> [String]? {
        let id = getCanonicalId(for: rawName)
        return idToBiomarker[id]?.aliases
    }
    
    /// Convert a value from one unit to the canonical unit
    func normalizeValue(_ value: Double, fromUnit: String, forBiomarker rawName: String) -> (value: Double, unit: String) {
        let id = getCanonicalId(for: rawName)
        guard let biomarker = idToBiomarker[id] else {
            return (value, fromUnit)
        }
        
        let normalizedUnit = fromUnit.lowercased().trimmingCharacters(in: .whitespaces)
        
        // If already in default unit, return as-is
        if normalizedUnit == biomarker.defaultUnit.lowercased() {
            return (value, biomarker.defaultUnit)
        }
        
        // Try to find conversion factor
        for (altUnit, factor) in biomarker.alternativeUnits {
            if normalizedUnit == altUnit.lowercased() {
                return (value * factor, biomarker.defaultUnit)
            }
        }
        
        // No conversion found, return original
        return (value, fromUnit)
    }
    
    // MARK: - Private Helpers
    
    /// Preprocess a name for matching
    private func preprocessName(_ name: String) -> String {
        var result = name.lowercased()
        
        // Remove content in parentheses at the end (but keep the main name)
        // e.g., "Hemoglobin (Hb)" -> "hemoglobin"
        if let range = result.range(of: #"\s*\([^)]*\)\s*$"#, options: .regularExpression) {
            result = String(result[..<range.lowerBound])
        }
        
        // Remove common prefixes
        let prefixes = ["serum ", "blood ", "plasma ", "total ", "fasting "]
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }
        
        // Normalize whitespace
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Fuzzy match using Levenshtein distance
    private func fuzzyMatch(_ name: String) -> (id: String, confidence: Double)? {
        var bestMatch: (id: String, confidence: Double)?
        
        for (alias, id) in aliasToId {
            let distance = levenshteinDistance(name, alias)
            let maxLength = max(name.count, alias.count)
            let confidence = 1.0 - (Double(distance) / Double(maxLength))
            
            if confidence > (bestMatch?.confidence ?? 0) {
                bestMatch = (id, confidence)
            }
        }
        
        return bestMatch
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}
