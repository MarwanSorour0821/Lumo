//
//  MedicationOnboardingCoordinator.swift
//  app
//
//  Coordinates the medication-first onboarding flow
//

import SwiftUI
import Combine

// MARK: - Medication Frequency
enum MedicationFrequency: String, CaseIterable {
    case onceDaily = "once_daily"
    case multipleTimes = "multiple_times"
    case asNeeded = "as_needed"

    var displayName: String {
        switch self {
        case .onceDaily: return "Once a day"
        case .multipleTimes: return "Multiple times a day"
        case .asNeeded: return "As needed"
        }
    }
}

// MARK: - Dosage Unit
enum DosageUnit: String, CaseIterable {
    case mg = "mg"
    case mcg = "mcg"
    case g = "g"
    case ml = "ml"
    case pill = "pill"
    case capsule = "capsule"
    case tablet = "tablet"
    case drop = "drop"

    var displayName: String {
        switch self {
        case .pill: return "pill(s)"
        case .capsule: return "capsule(s)"
        case .tablet: return "tablet(s)"
        case .drop: return "drop(s)"
        default: return rawValue
        }
    }
}

// MARK: - Onboarding Step
enum MedicationOnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissionFraming = 1
    case actionFraming = 2
    case medicationName = 3
    case dosage = 4
    case frequency = 5
    case timeSelection = 6
    case review = 7
    case success = 8
    case expansion = 9
}

// MARK: - Medication Onboarding Data
struct MedicationOnboardingData {
    var medicationName: String = ""
    var dosageAmount: Double = 1
    var dosageUnit: DosageUnit = .pill
    var frequency: MedicationFrequency = .onceDaily
    var reminderTimes: [Date] = [defaultMorningTime()]
    var notificationsEnabled: Bool = false

    static func defaultMorningTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Coordinator
class MedicationOnboardingCoordinator: ObservableObject {
    @Published var currentStep: MedicationOnboardingStep = .welcome
    @Published var data = MedicationOnboardingData()
    @Published var isComplete: Bool = false

    // Common medications for autocomplete
    static let commonMedications: [String] = [
        "Aspirin", "Ibuprofen", "Acetaminophen", "Lisinopril", "Metformin",
        "Atorvastatin", "Amlodipine", "Metoprolol", "Omeprazole", "Losartan",
        "Gabapentin", "Hydrochlorothiazide", "Sertraline", "Simvastatin",
        "Montelukast", "Escitalopram", "Rosuvastatin", "Bupropion",
        "Furosemide", "Pantoprazole", "Trazodone", "Duloxetine",
        "Prednisone", "Tamsulosin", "Meloxicam", "Carvedilol",
        "Levothyroxine", "Albuterol", "Fluticasone", "Clopidogrel",
        // Supplements
        "Vitamin D", "Vitamin D3", "Vitamin B12", "Vitamin C", "Multivitamin",
        "Fish Oil", "Omega-3", "Magnesium", "Zinc", "Iron",
        "Calcium", "Probiotics", "Melatonin", "Biotin", "Collagen",
        "Turmeric", "Ashwagandha", "CoQ10", "Folic Acid", "B Complex"
    ]

    func nextStep() {
        guard let nextIndex = MedicationOnboardingStep(rawValue: currentStep.rawValue + 1) else {
            isComplete = true
            return
        }
        currentStep = nextIndex
    }

    func previousStep() {
        guard let prevIndex = MedicationOnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentStep = prevIndex
    }

    func goToStep(_ step: MedicationOnboardingStep) {
        currentStep = step
    }

    func updateMedicationName(_ name: String) {
        data.medicationName = name
    }

    func updateDosage(amount: Double, unit: DosageUnit) {
        data.dosageAmount = amount
        data.dosageUnit = unit
    }

    func updateFrequency(_ frequency: MedicationFrequency) {
        data.frequency = frequency
        // Adjust reminder times based on frequency
        switch frequency {
        case .onceDaily:
            data.reminderTimes = [MedicationOnboardingData.defaultMorningTime()]
        case .multipleTimes:
            // Default to morning and evening
            var morning = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            morning.hour = 9
            morning.minute = 0
            var evening = morning
            evening.hour = 21
            data.reminderTimes = [
                Calendar.current.date(from: morning) ?? Date(),
                Calendar.current.date(from: evening) ?? Date()
            ]
        case .asNeeded:
            data.reminderTimes = []
        }
    }

    func updateReminderTimes(_ times: [Date]) {
        data.reminderTimes = times
    }

    func addReminderTime(_ time: Date) {
        data.reminderTimes.append(time)
        data.reminderTimes.sort()
    }

    func removeReminderTime(at index: Int) {
        guard index < data.reminderTimes.count else { return }
        data.reminderTimes.remove(at: index)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        data.notificationsEnabled = enabled
    }

    // Filter medications for autocomplete
    func filteredMedications(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        return Self.commonMedications.filter {
            $0.lowercased().contains(query.lowercased())
        }.prefix(5).map { $0 }
    }

    // Save the medication and set up reminders
    func saveMedication() async -> Bool {
        guard !data.medicationName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        do {
            // Create the medication item
            let newItem = try await LoggingService.shared.createItem(
                name: data.medicationName.trimmingCharacters(in: .whitespaces),
                type: .medication,
                description: nil,
                frequency: .daily,
                timesPerWeek: 7,
                startDate: Date(),
                endDate: nil
            )

            // If notifications are enabled and we have reminder times, set up reminders
            if data.notificationsEnabled && !data.reminderTimes.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let timeStrings = data.reminderTimes.map { formatter.string(from: $0) }

                // Update reminder settings
                _ = try await LoggingService.shared.updateReminder(
                    itemId: newItem.id,
                    enabled: true,
                    times: timeStrings,
                    days: [0, 1, 2, 3, 4, 5, 6] // All days
                )

                // Schedule local notifications
                let itemType = "medication"
                let calendar = Calendar.current

                await NotificationManager.shared.cancelReminders(for: newItem.id)

                for (timeIndex, time) in data.reminderTimes.enumerated() {
                    let hour = calendar.component(.hour, from: time)
                    let minute = calendar.component(.minute, from: time)

                    for day in 0..<7 {
                        let weekday = day + 1 // Convert to iOS weekday (1 = Sunday)
                        await NotificationManager.shared.scheduleReminder(
                            itemId: newItem.id,
                            itemName: newItem.name,
                            itemType: itemType,
                            hour: hour,
                            minute: minute,
                            weekday: weekday,
                            timeIndex: timeIndex,
                            startDate: Date(),
                            endDate: nil
                        )
                    }
                }
            }

            // Refresh the logging view model
            await MainActor.run {
                Task {
                    await LoggingViewModel.shared.refreshData()
                }
            }

            return true
        } catch {
            print("Failed to save medication: \(error.localizedDescription)")
            return false
        }
    }
}
