//
//  OnboardingDataCoordinator.swift
//  app
//
//  Coordinator to store user inputs during onboarding flow
//

import SwiftUI
import Combine

class OnboardingDataCoordinator: ObservableObject {
    static let shared = OnboardingDataCoordinator()

    // User inputs from onboarding screens
    @Published var supplementCount: Int = 3
    @Published var forgetFrequency: ForgetFrequencyOption = .sometimes
    @Published var monthlySpend: SpendAmountOption = .between25and50
    @Published var takesTogether: CombinationChoice = .sometimes

    // Calculated results
    @Published var wastedPillsPerMonth: Int = 0
    @Published var wastedMoneyPerMonth: Double = 0
    @Published var potentialSavingsPerYear: Double = 0

    private init() {}

    func reset() {
        supplementCount = 3
        forgetFrequency = .sometimes
        monthlySpend = .between25and50
        takesTogether = .sometimes
        wastedPillsPerMonth = 0
        wastedMoneyPerMonth = 0
        potentialSavingsPerYear = 0
    }

    func calculateWaste() {
        // Base waste from forgetting
        let forgetMultiplier: Double
        switch forgetFrequency {
        case .never:
            forgetMultiplier = 0.02 // Even "never" has some waste
        case .rarely:
            forgetMultiplier = 0.08
        case .sometimes:
            forgetMultiplier = 0.20
        case .often:
            forgetMultiplier = 0.35
        }

        // Monthly spend value
        let monthlySpendValue: Double
        switch monthlySpend {
        case .under25:
            monthlySpendValue = 20
        case .between25and50:
            monthlySpendValue = 37.50
        case .between50and100:
            monthlySpendValue = 75
        case .over100:
            monthlySpendValue = 150
        }

        // Additional waste from improper stacking
        let stackingWasteMultiplier: Double
        switch takesTogether {
        case .yes:
            stackingWasteMultiplier = 0.25 // 25% reduced absorption
        case .sometimes:
            stackingWasteMultiplier = 0.12
        case .no:
            stackingWasteMultiplier = 0.03
        }

        // Calculate wasted pills (assuming ~30 pills per supplement per month)
        let totalPillsPerMonth = supplementCount * 30
        let pillsWastedFromForgetting = Int(Double(totalPillsPerMonth) * forgetMultiplier)
        let pillsWastedFromStacking = Int(Double(totalPillsPerMonth) * stackingWasteMultiplier)
        wastedPillsPerMonth = pillsWastedFromForgetting + pillsWastedFromStacking

        // Calculate money wasted
        let moneyWastedFromForgetting = monthlySpendValue * forgetMultiplier
        let moneyWastedFromStacking = monthlySpendValue * stackingWasteMultiplier
        wastedMoneyPerMonth = moneyWastedFromForgetting + moneyWastedFromStacking

        // Yearly savings potential
        potentialSavingsPerYear = wastedMoneyPerMonth * 12
    }
}

// MARK: - Enums for Onboarding Data
enum ForgetFrequencyOption: CaseIterable {
    case never, rarely, sometimes, often
}

enum SpendAmountOption: CaseIterable {
    case under25, between25and50, between50and100, over100
}

enum CombinationChoice: CaseIterable {
    case yes, sometimes, no
}
