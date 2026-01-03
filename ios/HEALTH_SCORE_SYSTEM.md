# Health Score System Implementation

## Overview

The Lumo health score system has been completely redesigned based on the principles of **clinical plausibility + human believability**. The new system moves away from simple pass/fail biomarker analysis to a sophisticated, personalized health assessment.

## Mental Model

> "How far am I from *my* healthy state — and what matters most right now?"

## Key Files

- **`/ios/app/app/Services/HealthScoreCalculator.swift`** - New sophisticated scoring engine
- **`/ios/app/app/Services/BiomarkerNormalizer.swift`** - Biomarker name normalization (enhanced with ApoB, Lp(a))
- **`/ios/app/app/Utilities/HealthScoreService.swift`** - Updated to use new calculator
- **`/ios/app/app/ViewModels/UserDataViewModel.swift`** - Updated to pass user profile for personalization

## Architecture

### 1. Biomarker Sub-Scores (0-100)

Each biomarker is normalized to a **sub-score** creating gradients, not cliffs:

| Score Range | Status     | Meaning                    |
|-------------|------------|----------------------------|
| 90-100      | Optimal    | In optimal range           |
| 70-89       | Good       | Close to optimal           |
| 50-69       | Borderline | Worth monitoring           |
| 30-49       | Elevated/Low | Needs attention          |
| 0-29        | Critical   | Outside normal range       |

**Important**: Optimal ≠ reference range midpoint. We use **outcome-based targets** where possible.

### 2. Personalization

Scoring is personalized based on:

- **Age**: Risk weights increase for certain markers after 50/60
- **Biological Sex**: Different optimal ranges (e.g., hemoglobin, ferritin)
- **Health Conditions**: Stricter targets for relevant conditions
- **Health Goals**: (Future) Different emphasis based on user goals

Example personalizations:
- ApoB target is **stricter** for family history of CVD
- HbA1c penalty increases with age and diabetes status
- Ferritin ranges differ by sex

### 3. Risk Weights

Not all markers matter equally. We assign **clinical risk weights**:

| Biomarker       | Risk Weight | Rationale                           |
|-----------------|-------------|-------------------------------------|
| ApoB            | 1.6         | Primary CVD predictor               |
| HbA1c           | 1.5         | Key metabolic risk marker           |
| hs-CRP          | 1.4         | Inflammation/CVD risk               |
| Lp(a)           | 1.4         | Genetic CVD risk                    |
| LDL             | 1.3         | Cardiovascular risk                 |
| eGFR            | 1.3         | Kidney function                     |
| Triglycerides   | 1.2         | Metabolic health                    |
| Glucose         | 1.3         | Metabolic health                    |
| Hemoglobin      | 1.1         | Oxygen carrying capacity            |
| Vitamin D       | 0.7         | Important but less predictive       |
| Magnesium       | 0.5         | Supplemental marker                 |

This prevents users from "gaming" the score with supplements while important markers are drowned out.

### 4. Aggregation: Weighted Geometric Mean

We use a **weighted geometric mean** instead of arithmetic mean:

```
Health Score = exp(Σ(weight × log(score)) / Σ(weight))
```

**Why?**
- One bad marker hurts more than 10 good ones help
- This mirrors biological risk
- Prevents hiding serious issues behind good numbers

### 5. Trend Modifiers

Trajectory matters as much as absolute value:

- **Improving trend** (+5%): Softens penalty for markers moving in right direction
- **Worsening trend** (-5%): Adds penalty for markers trending poorly
- **Stable**: No adjustment

Example:
- ApoB is high **but falling** → softer penalty
- HbA1c is "normal" **but rising** → small penalty

### 6. Confidence Score

The system calculates a **confidence level** based on:

- Presence of key biomarkers (50% weight)
- Total number of biomarkers (50% weight)

This helps communicate when more data is needed.

## Data Structures

### `HealthScoreResult`

```swift
struct HealthScoreResult {
    let score: Double                  // 0-10 scale
    let scoreOutOf100: Double          // 0-100 scale
    let confidence: Double             // 0-1
    let biomarkerScores: [BiomarkerSubScore]
    let topConcerns: [BiomarkerSubScore]
    let topImprovements: [BiomarkerSubScore]
    let summaryExplanation: String
    let detailedExplanation: String
    let scoreDrivers: [String]
    let timestamp: Date
}
```

### `BiomarkerSubScore`

```swift
struct BiomarkerSubScore {
    let biomarkerId: String
    let displayName: String
    let rawValue: Double
    let unit: String
    let subScore: Double           // 0-100
    let riskWeight: Double
    let weightedScore: Double
    let status: BiomarkerStatus    // Optimal, Good, Borderline, etc.
    let trend: BiomarkerTrend      // Improving, Stable, Worsening
    let trendModifier: Double
    let category: BiomarkerCategory
    let explanation: String
}
```

### `UserHealthProfile`

```swift
struct UserHealthProfile {
    let age: Int?
    let biologicalSex: String?
    let healthConditions: [String]
    let healthGoals: [HealthGoal]
}
```

## UI Integration

### What the User Sees

Instead of just a number:

> **6.2 — Improving, but cardiovascular risk is holding you back**

The UI should show:
- Top 2-3 contributors dragging score down
- Top 1-2 improving markers
- One-sentence explanation of score drivers

### Transparency Layer

Always include:

> "Your score is driven mostly by ApoB and hs-CRP."

If users can't explain their score in one sentence, they won't trust it.

## Usage Example

```swift
// Fetch analyses
let analyses = try await HealthScoreService.shared.fetchAnalyses(userId: userId)

// Get personalized profile
let userProfile = await UserHealthProfile.fetchFromSupabase()

// Calculate detailed score
let result = HealthScoreCalculator.shared.calculateHealthScore(
    analyses: analyses,
    userProfile: userProfile
)

// Access results
print("Score: \(result.formattedScore)")        // "6.2"
print("Category: \(result.scoreCategory)")       // "Good"
print("Summary: \(result.summaryExplanation)")   // "6.2 — ApoB and hs-CRP are holding you back"
print("Confidence: \(result.confidence * 100)%") // "85%"

// Get top concerns for UI
for concern in result.topConcerns {
    print("\(concern.displayName): \(concern.status.rawValue) - \(concern.explanation)")
}
```

## Biomarkers Supported

### High Impact (Risk Weight > 1.3)
- ApoB (1.6)
- HbA1c (1.5)
- Troponin (1.5)
- hs-CRP (1.4)
- Lp(a) (1.4)
- BNP (1.4)
- Glucose (1.3)
- LDL (1.3)
- eGFR (1.3)

### Medium Impact (Risk Weight 1.0-1.3)
- Triglycerides (1.2)
- hs-CRP (1.2)
- Creatinine (1.1)
- HDL (1.1)
- Hemoglobin (1.1)
- TSH (1.1)
- WBC, RBC, Platelets (0.9-1.0)
- Liver enzymes (ALT, AST, GGT)

### Lower Impact (Risk Weight < 1.0)
- Vitamins (D, B12, Folate)
- Electrolytes (Sodium, Potassium, Calcium)
- MCV, MCH, MCHC, RDW

## Legal & Trust Notes

**Never say:**
> "This predicts your lifespan"

**Instead say:**
> "This reflects current biomarker risk relative to optimal health"

## The North Star Rule

A good health score should:
- ✅ Change slowly
- ✅ React meaningfully
- ✅ Feel harder to improve than to worsen
- ✅ Always point to *one clear next action*

## Future Enhancements

1. **Health Goals Weighting**: Adjust marker importance based on user goals (heart health, longevity, athletic performance)
2. **Time-Weighted Scoring**: Recent tests matter more than older ones
3. **Predictive Trends**: Show projected score if current trends continue
4. **Peer Comparison**: Show percentile vs similar demographics (with privacy)
5. **Recommendation Engine**: Specific actions to improve score
