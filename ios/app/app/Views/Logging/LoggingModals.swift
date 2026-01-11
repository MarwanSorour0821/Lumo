//
//  LoggingModals.swift
//  app
//
//  Modal views for logging feature
//

import SwiftUI

// MARK: - Add Item Sheet
struct AddItemSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: LoggingViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var selectedType: LogItemType = .supplement
    @State private var description: String = ""
    @State private var selectedFrequency: LogFrequency = .daily
    @State private var timesPerWeek: Int = 7
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            
                            TextField("e.g., Vitamin D3, Fish Oil", text: $name)
                                .font(.custom("ProductSans-Regular", size: 16))
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.inputBackground(themeManager.colorScheme))
                                )
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        
                        // Type selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            
                            HStack(spacing: 12) {
                                ForEach(LogItemType.allCases, id: \.self) { type in
                                    TypeButton(
                                        type: type,
                                        isSelected: selectedType == type
                                    ) {
                                        selectedType = type
                                    }
                                }
                            }
                        }
                        
                        // Frequency selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How often do you take it?")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(LogFrequency.allCases, id: \.self) { frequency in
                                    FrequencyButton(
                                        frequency: frequency,
                                        isSelected: selectedFrequency == frequency
                                    ) {
                                        selectedFrequency = frequency
                                    }
                                }
                            }
                        }
                        
                        // Times per week (only show if weekly selected)
                        if selectedFrequency == .weekly {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Times per week: \(timesPerWeek)")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                
                                Slider(value: Binding(
                                    get: { Double(timesPerWeek) },
                                    set: { timesPerWeek = Int($0) }
                                ), in: 1...7, step: 1)
                                .tint(AppColors.primary)
                            }
                        }
                        
                        // Description (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (optional)")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            
                            TextField("e.g., 1000 IU, take with food", text: $description)
                                .font(.custom("ProductSans-Regular", size: 16))
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.inputBackground(themeManager.colorScheme))
                                )
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Add button
                        Button {
                            addItem()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus")
                                    Text("Add \(selectedType.displayName)")
                                }
                            }
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(name.isEmpty ? AppColors.primary.opacity(0.5) : AppColors.primary)
                            )
                        }
                        .disabled(name.isEmpty || isSubmitting)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private func addItem() {
        isSubmitting = true
        Task {
            await viewModel.createItem(
                name: name,
                type: selectedType,
                description: description.isEmpty ? nil : description,
                frequency: selectedFrequency,
                timesPerWeek: timesPerWeek
            )
            isSubmitting = false
            dismiss()
        }
    }
}

// MARK: - Type Button
struct TypeButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let type: LogItemType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                Text(type.displayName)
                    .font(.custom("ProductSans-Medium", size: 14))
            }
            .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme))
            )
        }
    }
}

// MARK: - Frequency Button
struct FrequencyButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let frequency: LogFrequency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(frequency.displayName)
                .font(.custom("ProductSans-Medium", size: 14))
                .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme))
                )
        }
    }
}

// MARK: - Biomarker Impact Modal
struct BiomarkerImpactModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    @ObservedObject var viewModel: LoggingViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var impacts: [BiomarkerImpact] = []
    @State private var isLoading = false
    @State private var hasGenerated = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(item.type == .supplement ? Color.purple.opacity(0.15) : Color.orange.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: item.type.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(item.type == .supplement ? .purple : .orange)
                            }
                            
                            Text(item.name)
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            Text("Biomarker Impact Analysis")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .padding(.top, 20)
                        
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(AppColors.primary)
                                    .scaleEffect(1.2)
                                Text("Analyzing impact on biomarkers...")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                            .padding(40)
                        } else if impacts.isEmpty && !hasGenerated {
                            // Generate button
                            VStack(spacing: 16) {
                                Text("See how \(item.name) affects your biomarkers")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    generateImpacts()
                                } label: {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("Analyze Impact")
                                    }
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.primary)
                                    )
                                }
                            }
                            .padding(40)
                        } else if impacts.isEmpty && hasGenerated {
                            Text("No significant biomarker impacts found")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .padding(40)
                        } else {
                            // Impact cards
                            VStack(spacing: 12) {
                                ForEach(impacts) { impact in
                                    ImpactCard(impact: impact)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Disclaimer
                            Text("This analysis is AI-generated and for informational purposes only. Consult a healthcare professional for medical advice.")
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .padding(.top, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Impact Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .onAppear {
                // Load existing impacts
                if let existingImpacts = item.biomarkerImpacts, !existingImpacts.isEmpty {
                    impacts = existingImpacts
                    hasGenerated = true
                }
            }
        }
    }
    
    private func generateImpacts() {
        isLoading = true
        Task {
            if let generatedImpacts = await viewModel.generateBiomarkerImpacts(for: item) {
                impacts = generatedImpacts
            }
            hasGenerated = true
            isLoading = false
        }
    }
}

// MARK: - Impact Card
struct ImpactCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let impact: BiomarkerImpact
    
    var impactColor: Color {
        switch impact.impactType {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Impact indicator
                ZStack {
                    Circle()
                        .fill(impactColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: impact.impactType.icon)
                        .font(.system(size: 16))
                        .foregroundColor(impactColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(impact.biomarkerName)
                        .font(.custom("ProductSans-Bold", size: 15))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    HStack(spacing: 4) {
                        Text(impact.impactType.rawValue.capitalized)
                            .font(.custom("ProductSans-Medium", size: 12))
                            .foregroundColor(impactColor)
                        
                        if impact.impactScore != 0 {
                            Text("(\(impact.impactScore > 0 ? "+" : "")\(impact.impactScore))")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
                
                Spacer()
            }
            
            if let description = impact.impactDescription, !description.isEmpty {
                Text(description)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .lineLimit(3)
            }
            
            if let source = impact.scientificSource, !source.isEmpty {
                Text(source)
                    .font(.custom("ProductSans-Regular", size: 11))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.7))
                    .italic()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface(themeManager.colorScheme))
        )
    }
}

// MARK: - Reminder Sheet
struct ReminderSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    @ObservedObject var viewModel: LoggingViewModel
    @Environment(\.dismiss) var dismiss

    @State private var reminderTimes: [Date]
    @State private var selectedDays: Set<Int>
    @State private var isSaving = false
    @State private var showingTimePicker = false
    @State private var editingTimeIndex: Int? = nil
    @State private var tempTime: Date = Date()
    @State private var appearAnimation = false

    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    init(item: FoodSupplementItem, viewModel: LoggingViewModel) {
        self.item = item
        self.viewModel = viewModel

        // Parse reminder times
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        if !item.reminderTimes.isEmpty {
            let times = item.reminderTimes.compactMap { formatter.date(from: $0) }
            _reminderTimes = State(initialValue: times.isEmpty ? [ReminderSheet.defaultTime(hour: 9)] : times)
        } else {
            // Default to 9:00 AM
            _reminderTimes = State(initialValue: [ReminderSheet.defaultTime(hour: 9)])
        }

        _selectedDays = State(initialValue: Set(item.reminderDays.isEmpty ? [0,1,2,3,4,5,6] : item.reminderDays))
    }

    private static func defaultTime(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private var selectedDaysDescription: String {
        if selectedDays.count == 7 {
            return "Every day"
        } else if selectedDays.count == 0 {
            return "No days selected"
        } else if selectedDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if selectedDays == Set([0, 6]) {
            return "Weekends"
        } else {
            let sortedDays = selectedDays.sorted()
            return sortedDays.map { String(fullDayNames[$0].prefix(3)) }.joined(separator: ", ")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerIcon
                            reminderTimesSection
                            if showingTimePicker { timePickerSection }
                            daySelectorSection
                            presetsSection
                            Spacer(minLength: 80)
                        }
                        .padding(20)
                    }
                    saveButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
                }
                ToolbarItem(placement: .principal) {
                    Text("Set Reminder")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Subviews

    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.12))
                .frame(width: 64, height: 64)
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 26))
                .foregroundColor(AppColors.primary)
        }
        .scaleEffect(appearAnimation ? 1 : 0.8)
        .opacity(appearAnimation ? 1 : 0)
        .padding(.top, 8)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppColors.inputBackground(themeManager.colorScheme)))
        }
    }

    private var reminderTimesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REMINDER TIMES")
                    .font(.custom("ProductSans-Medium", size: 11))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .tracking(1.2)
                Spacer()
                if reminderTimes.count < 5 {
                    Button { addNewTime() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 14))
                            Text("Add Time").font(.custom("ProductSans-Medium", size: 13))
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
            VStack(spacing: 8) {
                ForEach(Array(reminderTimes.enumerated()), id: \.offset) { index, time in
                    timeRow(index: index, time: time)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface(themeManager.colorScheme).opacity(0.5)))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    private func timeRow(index: Int, time: Date) -> some View {
        HStack {
            ZStack {
                Circle().fill(AppColors.primary.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: timeIcon(for: time)).font(.system(size: 14)).foregroundColor(AppColors.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(time)).font(.custom("ProductSans-Bold", size: 17)).foregroundColor(AppColors.text(themeManager.colorScheme))
                Text(timePeriodLabel(for: time)).font(.custom("ProductSans-Regular", size: 12)).foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            Spacer()
            Button {
                editingTimeIndex = index
                tempTime = time
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showingTimePicker = true }
            } label: {
                Image(systemName: "pencil.circle.fill").font(.system(size: 22)).foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
            }
            if reminderTimes.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        var times = reminderTimes
                        times.remove(at: index)
                        reminderTimes = times
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 22)).foregroundColor(.red.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.surface(themeManager.colorScheme)))
    }

    private var timePickerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(editingTimeIndex != nil ? "Edit Time" : "Add Time")
                    .font(.custom("ProductSans-Bold", size: 15))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingTimePicker = false
                        editingTimeIndex = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
                }
            }
            DatePicker("", selection: $tempTime, displayedComponents: .hourAndMinute).datePickerStyle(.wheel).labelsHidden().frame(height: 150)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if let idx = editingTimeIndex { reminderTimes[idx] = tempTime }
                    else { reminderTimes.append(tempTime); reminderTimes.sort { $0 < $1 } }
                    showingTimePicker = false
                    editingTimeIndex = nil
                }
            } label: {
                Text(editingTimeIndex != nil ? "Update" : "Add")
                    .font(.custom("ProductSans-Bold", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AppColors.primary))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface(themeManager.colorScheme)).shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5))
    }

    private var daySelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REPEAT ON")
                .font(.custom("ProductSans-Medium", size: 11))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .tracking(1.2)
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { day in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            if selectedDays.contains(day) { selectedDays.remove(day) }
                            else { selectedDays.insert(day) }
                        }
                    } label: {
                        Text(dayNames[day])
                            .font(.custom("ProductSans-Bold", size: 13))
                            .foregroundColor(selectedDays.contains(day) ? .white : AppColors.text(themeManager.colorScheme))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(selectedDays.contains(day) ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme)))
                    }
                }
            }
            Text(selectedDaysDescription)
                .font(.custom("ProductSans-Regular", size: 12))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface(themeManager.colorScheme).opacity(0.5)))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK PRESETS")
                .font(.custom("ProductSans-Medium", size: 11))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .tracking(1.2)
            HStack(spacing: 8) {
                PresetButton(title: "Morning", icon: "sunrise.fill") { applyPreset(times: [9]) }
                PresetButton(title: "Twice Daily", icon: "clock.badge.checkmark") { applyPreset(times: [9, 21]) }
                PresetButton(title: "Three Times", icon: "clock.fill") { applyPreset(times: [9, 14, 21]) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.surface(themeManager.colorScheme).opacity(0.5)))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    private var saveButton: some View {
        VStack {
            Button { saveReminder() } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        CustomSpinner(size: 18, lineWidth: 2)
                    } else {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                        Text("Save Reminder\(reminderTimes.count > 1 ? "s" : "")").font(.custom("ProductSans-Bold", size: 16))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(selectedDays.isEmpty || reminderTimes.isEmpty ? AppColors.primary.opacity(0.4) : AppColors.primary)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            .disabled(isSaving || selectedDays.isEmpty || reminderTimes.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 20)
        }
    }

    private func addNewTime() {
        // Find a suitable default time that's different from existing times
        let existingHours = Set(reminderTimes.map { Calendar.current.component(.hour, from: $0) })
        let defaultHours = [9, 12, 15, 18, 21, 8, 7, 10, 14, 20]
        let newHour = defaultHours.first { !existingHours.contains($0) } ?? 12

        tempTime = ReminderSheet.defaultTime(hour: newHour)
        editingTimeIndex = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingTimePicker = true
        }
    }

    private func applyPreset(times: [Int]) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            reminderTimes = times.map { ReminderSheet.defaultTime(hour: $0) }
        }
    }

    private func timeIcon(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 5 && hour < 12 {
            return "sunrise.fill"
        } else if hour >= 12 && hour < 17 {
            return "sun.max.fill"
        } else if hour >= 17 && hour < 21 {
            return "sunset.fill"
        } else {
            return "moon.fill"
        }
    }

    private func timePeriodLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 5 && hour < 12 {
            return "Morning"
        } else if hour >= 12 && hour < 17 {
            return "Afternoon"
        } else if hour >= 17 && hour < 21 {
            return "Evening"
        } else {
            return "Night"
        }
    }

    private func saveReminder() {
        isSaving = true
        Task {
            // Saving means enabling the reminder with all times
            await viewModel.updateReminder(
                for: item,
                enabled: true,
                times: reminderTimes,
                days: Array(selectedDays)
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.custom("ProductSans-Medium", size: 11))
            }
            .foregroundColor(AppColors.text(themeManager.colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.inputBackground(themeManager.colorScheme))
            )
        }
    }
}

// MARK: - Day Button
struct DayButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let day: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day)
                .font(.custom("ProductSans-Medium", size: 12))
                .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme))
                )
        }
    }
}

// MARK: - Edit Item Sheet
struct EditItemSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    @ObservedObject var viewModel: LoggingViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var selectedType: LogItemType
    @State private var selectedDays: Set<Int>
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasEndDate: Bool
    @State private var isSubmitting = false
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var appearAnimation = false

    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    init(item: FoodSupplementItem, viewModel: LoggingViewModel) {
        self.item = item
        self.viewModel = viewModel

        _name = State(initialValue: item.name)
        _selectedType = State(initialValue: item.type)
        _selectedDays = State(initialValue: Set(item.reminderDays.isEmpty ? [0,1,2,3,4,5,6] : item.reminderDays))

        // Parse start date
        if let startDateString = item.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _startDate = State(initialValue: formatter.date(from: startDateString) ?? Date())
        } else {
            _startDate = State(initialValue: Date())
        }

        // Parse end date
        if let endDateString = item.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _endDate = State(initialValue: formatter.date(from: endDateString) ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
            _hasEndDate = State(initialValue: true)
        } else {
            _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
            _hasEndDate = State(initialValue: false)
        }
    }

    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: startDate)
    }

    private var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: endDate)
    }

    private var selectedDaysDescription: String {
        if selectedDays.count == 7 {
            return "Every day"
        } else if selectedDays.count == 0 {
            return "No days selected"
        } else if selectedDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if selectedDays == Set([0, 6]) {
            return "Weekends"
        } else {
            let sortedDays = selectedDays.sorted()
            return sortedDays.map { fullDayNames[$0].prefix(3) }.joined(separator: ", ")
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header with icon
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(selectedType == .supplement ? Color.purple.opacity(0.12) : Color.blue.opacity(0.12))
                                    .frame(width: 72, height: 72)

                                Image(systemName: selectedType.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(selectedType == .supplement ? .purple : .blue)
                            }
                            .scaleEffect(appearAnimation ? 1 : 0.8)
                            .opacity(appearAnimation ? 1 : 0)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                        VStack(spacing: 20) {
                            // Name field - elegant card style
                            VStack(alignment: .leading, spacing: 10) {
                                Text("NAME")
                                    .font(.custom("ProductSans-Medium", size: 11))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    .tracking(1.2)

                                TextField("Enter name", text: $name)
                                    .font(.custom("ProductSans-Regular", size: 17))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 10)

                            // Type selector - minimal segmented style
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TYPE")
                                    .font(.custom("ProductSans-Medium", size: 11))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    .tracking(1.2)

                                HStack(spacing: 0) {
                                    ForEach(LogItemType.allCases, id: \.self) { type in
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedType = type
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: type.icon)
                                                    .font(.system(size: 14))
                                                Text(type.displayName)
                                                    .font(.custom("ProductSans-Medium", size: 14))
                                            }
                                            .foregroundColor(selectedType == type ? .white : AppColors.text(themeManager.colorScheme))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedType == type ? (type == .supplement ? Color.purple : Color.blue) : Color.clear)
                                            )
                                        }
                                    }
                                }
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.inputBackground(themeManager.colorScheme))
                                )
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 10)

                            // Schedule section - combined days and dates
                            VStack(alignment: .leading, spacing: 16) {
                                Text("SCHEDULE")
                                    .font(.custom("ProductSans-Medium", size: 11))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    .tracking(1.2)

                                // Days selector - circular buttons
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        ForEach(0..<7, id: \.self) { day in
                                            Button {
                                                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                                    if selectedDays.contains(day) {
                                                        selectedDays.remove(day)
                                                    } else {
                                                        selectedDays.insert(day)
                                                    }
                                                }
                                            } label: {
                                                Text(dayNames[day])
                                                    .font(.custom("ProductSans-Bold", size: 13))
                                                    .foregroundColor(selectedDays.contains(day) ? .white : AppColors.text(themeManager.colorScheme))
                                                    .frame(width: 38, height: 38)
                                                    .background(
                                                        Circle()
                                                            .fill(selectedDays.contains(day) ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme))
                                                    )
                                            }
                                        }
                                    }

                                    Text(selectedDaysDescription)
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }

                                Divider()
                                    .background(AppColors.border(themeManager.colorScheme))

                                // Duration - start and end dates
                                HStack(spacing: 12) {
                                    // Start date
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            showStartDatePicker.toggle()
                                            showEndDatePicker = false
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 14))
                                                .foregroundColor(showStartDatePicker ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Start")
                                                    .font(.custom("ProductSans-Regular", size: 11))
                                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                Text(formattedStartDate)
                                                    .font(.custom("ProductSans-Medium", size: 13))
                                                    .foregroundColor(showStartDatePicker ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                .rotationEffect(.degrees(showStartDatePicker ? 180 : 0))
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppColors.inputBackground(themeManager.colorScheme))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(showStartDatePicker ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                                )
                                        )
                                    }

                                    // End date
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            showEndDatePicker.toggle()
                                            showStartDatePicker = false
                                            if !hasEndDate {
                                                hasEndDate = true
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: hasEndDate ? "calendar.badge.checkmark" : "calendar.badge.plus")
                                                .font(.system(size: 14))
                                                .foregroundColor(showEndDatePicker ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("End")
                                                    .font(.custom("ProductSans-Regular", size: 11))
                                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                Text(hasEndDate ? formattedEndDate : "Optional")
                                                    .font(.custom("ProductSans-Medium", size: 13))
                                                    .foregroundColor(showEndDatePicker ? AppColors.primary : (hasEndDate ? AppColors.text(themeManager.colorScheme) : AppColors.textSecondary(themeManager.colorScheme)))
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                .rotationEffect(.degrees(showEndDatePicker ? 180 : 0))
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppColors.inputBackground(themeManager.colorScheme))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(showEndDatePicker ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                                )
                                        )
                                    }
                                }

                                // Start date picker
                                if showStartDatePicker {
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .tint(AppColors.primary)
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(AppColors.inputBackground(themeManager.colorScheme))
                                        )
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                                            removal: .opacity.combined(with: .scale(scale: 0.98))
                                        ))
                                }

                                // End date picker
                                if showEndDatePicker {
                                    VStack(spacing: 12) {
                                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                            .datePickerStyle(.graphical)
                                            .tint(AppColors.primary)

                                        if hasEndDate {
                                            Button {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    hasEndDate = false
                                                    showEndDatePicker = false
                                                }
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 14))
                                                    Text("Remove end date")
                                                        .font(.custom("ProductSans-Medium", size: 13))
                                                }
                                                .foregroundColor(.red.opacity(0.8))
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(AppColors.inputBackground(themeManager.colorScheme))
                                    )
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .scale(scale: 0.98))
                                    ))
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 10)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }

                // Floating save button
                VStack {
                    Spacer()

                    Button {
                        saveItem()
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                CustomSpinner(size: 18, lineWidth: 2)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Save Changes")
                                    .font(.custom("ProductSans-Bold", size: 16))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(name.isEmpty || selectedDays.isEmpty ? AppColors.primary.opacity(0.4) : AppColors.primary)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                        )
                    }
                    .disabled(name.isEmpty || selectedDays.isEmpty || isSubmitting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                            )
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Edit \(item.type.displayName)")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    private func saveItem() {
        guard !name.isEmpty && !selectedDays.isEmpty else { return }
        isSubmitting = true

        Task {
            await viewModel.updateItem(
                item,
                name: name,
                type: selectedType,
                reminderDays: Array(selectedDays),
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                clearEndDate: !hasEndDate
            )
            isSubmitting = false
            dismiss()
        }
    }
}

// MARK: - Previews
#Preview("Add Item") {
    AddItemSheet(viewModel: LoggingViewModel.shared)
        .environmentObject(ThemeManager.shared)
}

#Preview("Impact Modal") {
    let sampleItem = FoodSupplementItem(
        id: "1",
        name: "Vitamin D3",
        type: .supplement
    )
    return BiomarkerImpactModal(item: sampleItem, viewModel: LoggingViewModel.shared)
        .environmentObject(ThemeManager.shared)
}

#Preview("Edit Item") {
    let sampleItem = FoodSupplementItem(
        id: "1",
        name: "Vitamin D3",
        type: .supplement,
        reminderDays: [0, 1, 2, 3, 4, 5, 6],
        startDate: "2026-01-01",
        endDate: "2026-02-01"
    )
    return EditItemSheet(item: sampleItem, viewModel: LoggingViewModel.shared)
        .environmentObject(ThemeManager.shared)
}
