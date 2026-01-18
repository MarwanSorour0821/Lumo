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
                AppColors.modalBackground(themeManager.colorScheme)
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
                AppColors.modalBackground(themeManager.colorScheme)
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
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasEndDate: Bool
    @State private var showScheduleOptions = false
    @State private var activeSection: ReminderSection? = nil

    private enum ReminderSection {
        case startDate, endDate
    }

    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    init(item: FoodSupplementItem, viewModel: LoggingViewModel) {
        self.item = item
        self.viewModel = viewModel

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        if !item.reminderTimes.isEmpty {
            let times = item.reminderTimes.compactMap { formatter.date(from: $0) }
            _reminderTimes = State(initialValue: times.isEmpty ? [ReminderSheet.defaultTime(hour: 9)] : times)
        } else {
            _reminderTimes = State(initialValue: [ReminderSheet.defaultTime(hour: 9)])
        }

        _selectedDays = State(initialValue: Set(item.reminderDays.isEmpty ? [0,1,2,3,4,5,6] : item.reminderDays))

        if let startDateString = item.startDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            _startDate = State(initialValue: dateFormatter.date(from: startDateString) ?? Date())
        } else {
            _startDate = State(initialValue: Date())
        }

        if let endDateString = item.endDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            _endDate = State(initialValue: dateFormatter.date(from: endDateString) ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
            _hasEndDate = State(initialValue: true)
        } else {
            _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
            _hasEndDate = State(initialValue: false)
        }
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

    private func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }

    private func formatTimePeriod(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: date).lowercased()
    }

    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startDate)
    }

    private var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: endDate)
    }

    var body: some View {
            ZStack {
            // Background
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                // Header
                headerSection

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Time Display & Picker
                        timeSection

                        // Quick Presets
                            presetsSection

                        // Days
                        daysSection

                        // Schedule
                            scheduleSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            // Bottom Save Button
            VStack {
                Spacer()
                saveButtonSection
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
        Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
            }

                Spacer()

            VStack(spacing: 2) {
                Text("Reminder")
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(item.name)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            // Invisible button for balance
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(spacing: 16) {
            // Time cards
            VStack(spacing: 10) {
                ForEach(Array(reminderTimes.enumerated()), id: \.offset) { index, time in
                    TimeCard(
                        time: time,
                        isEditing: showingTimePicker && editingTimeIndex == index,
                        onEdit: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                editingTimeIndex = index
                tempTime = time
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingTimePicker = true
                            }
                        },
                        onDelete: reminderTimes.count > 1 ? {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                reminderTimes.remove(at: index)
                            }
                        } : nil,
                        themeManager: themeManager
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }

            // Time picker
            if showingTimePicker {
                VStack(spacing: 16) {
                    DatePicker("", selection: $tempTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 150)

                    HStack(spacing: 12) {
                Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingTimePicker = false
                        editingTimeIndex = nil
                    }
                } label: {
                            Text("Cancel")
                                .font(.custom("ProductSans-Medium", size: 15))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.surface(themeManager.colorScheme))
                                )
                        }

            Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if let idx = editingTimeIndex {
                                    reminderTimes[idx] = tempTime
                                }
                                reminderTimes.sort { $0 < $1 }
                    showingTimePicker = false
                    editingTimeIndex = nil
                }
            } label: {
                            Text("Done")
                    .font(.custom("ProductSans-Bold", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.primary)
                                )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.surface(themeManager.colorScheme))
                        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
            }

            // Add time button
            if reminderTimes.count < 5 && !showingTimePicker {
                    Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    addNewTime()
                    } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Time")
                            .font(.custom("ProductSans-Medium", size: 14))
                    }
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.primary.opacity(0.05))
                            )
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Set")
                .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

            HStack(spacing: 10) {
                PresetChip(title: "Morning", icon: "sunrise.fill", iconColor: .orange) {
                    applyPreset(times: [8])
                }
                PresetChip(title: "2x Daily", icon: "repeat", iconColor: AppColors.primary) {
                    applyPreset(times: [8, 20])
                }
                PresetChip(title: "3x Daily", icon: "repeat.circle", iconColor: .purple) {
                    applyPreset(times: [8, 14, 20])
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appearAnimation)
    }

    // MARK: - Days Section

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Repeat")
                                .font(.custom("ProductSans-Medium", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                Text(selectedDaysDescription)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.primary)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    DayChip(
                        day: dayNames[day],
                        isSelected: selectedDays.contains(day),
                        onTap: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        },
                        themeManager: themeManager
                    )
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appearAnimation)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Duration")
                                .font(.custom("ProductSans-Medium", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showScheduleOptions.toggle()
                        if !showScheduleOptions {
                            activeSection = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(hasEndDate ? "\(formattedStartDate) - \(formattedEndDate)" : "From \(formattedStartDate)")
                            .font(.custom("ProductSans-Medium", size: 13))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(showScheduleOptions ? 180 : 0))
                    }
                    .foregroundColor(AppColors.primary)
                }
            }

            if showScheduleOptions {
                VStack(spacing: 12) {
                    // Start date
                    ScheduleRow(
                        label: "Start",
                        value: formattedStartDate,
                        icon: "play.circle.fill",
                        iconColor: .green,
                        isExpanded: activeSection == .startDate,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                activeSection = activeSection == .startDate ? nil : .startDate
                            }
                        },
                        themeManager: themeManager
                    )

                    if activeSection == .startDate {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(AppColors.primary)
                            .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                    )
                    .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.98).combined(with: .opacity)
                            ))
                    }

                    // End date
                    ScheduleRow(
                        label: "End",
                        value: hasEndDate ? formattedEndDate : "No end date",
                        icon: hasEndDate ? "stop.circle.fill" : "infinity.circle.fill",
                        iconColor: hasEndDate ? .red : AppColors.textSecondary(themeManager.colorScheme),
                        isExpanded: activeSection == .endDate,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if !hasEndDate {
                                    hasEndDate = true
                                }
                                activeSection = activeSection == .endDate ? nil : .endDate
                            }
                        },
                        themeManager: themeManager
                    )

                    if activeSection == .endDate {
                VStack(spacing: 12) {
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppColors.primary)

                    if hasEndDate {
                        Button {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                hasEndDate = false
                                        activeSection = nil
                            }
                        } label: {
                            HStack(spacing: 6) {
                                        Image(systemName: "infinity")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Continue indefinitely")
                                    .font(.custom("ProductSans-Medium", size: 13))
                            }
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
                        .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.surface(themeManager.colorScheme))
                )
                .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: appearAnimation)
    }

    // MARK: - Save Button

    private var saveButtonSection: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    AppColors.modalBackground(themeManager.colorScheme).opacity(0),
                    AppColors.modalBackground(themeManager.colorScheme)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    saveReminder()
                } label: {
                    HStack(spacing: 10) {
                    if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                    } else {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 16))
                            Text("Save Reminder")
                                .font(.custom("ProductSans-Bold", size: 16))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                    .frame(height: 56)
                .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                selectedDays.isEmpty || reminderTimes.isEmpty
                                    ? AppColors.primary.opacity(0.4)
                                    : AppColors.primary
                            )
                            .shadow(
                                color: selectedDays.isEmpty || reminderTimes.isEmpty
                                    ? Color.clear
                                    : AppColors.primary.opacity(0.3),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                )
            }
            .disabled(isSaving || selectedDays.isEmpty || reminderTimes.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(AppColors.modalBackground(themeManager.colorScheme))
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
    }

    // MARK: - Helper Functions

    private func addNewTime() {
        let existingHours = Set(reminderTimes.map { Calendar.current.component(.hour, from: $0) })
        let defaultHours = [9, 12, 15, 18, 21, 8, 7, 10, 14, 20]
        let newHour = defaultHours.first { !existingHours.contains($0) } ?? 12

        tempTime = ReminderSheet.defaultTime(hour: newHour)
        editingTimeIndex = reminderTimes.count
        reminderTimes.append(tempTime)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingTimePicker = true
        }
    }

    private func applyPreset(times: [Int]) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            reminderTimes = times.map { ReminderSheet.defaultTime(hour: $0) }
            showingTimePicker = false
            editingTimeIndex = nil
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
            await viewModel.updateItem(
                item,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                clearEndDate: !hasEndDate
            )
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            if let updatedItem = await MainActor.run(body: { viewModel.items.first(where: { $0.id == item.id }) }) {
                await viewModel.updateReminder(
                    for: updatedItem,
                    enabled: true,
                    times: reminderTimes,
                    days: Array(selectedDays)
                )
            } else {
                await viewModel.updateReminder(
                    for: item,
                    enabled: true,
                    times: reminderTimes,
                    days: Array(selectedDays)
                )
            }
            
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Time Card Component

private struct TimeCard: View {
    let time: Date
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    let themeManager: ThemeManager

    private var timeIcon: String {
        let hour = Calendar.current.component(.hour, from: time)
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

    private var iconColor: Color {
        let hour = Calendar.current.component(.hour, from: time)
        if hour >= 5 && hour < 12 {
            return .orange
        } else if hour >= 12 && hour < 17 {
            return .yellow
        } else if hour >= 17 && hour < 21 {
            return .orange
        } else {
            return .indigo
        }
    }

    private var periodLabel: String {
        let hour = Calendar.current.component(.hour, from: time)
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

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: timeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // Time info
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTime)
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(periodLabel)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                        )
                }

                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface(themeManager.colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEditing ? AppColors.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Preset Chip Component

private struct PresetChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.custom("ProductSans-Medium", size: 13))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppColors.surface(themeManager.colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Day Chip Component

private struct DayChip: View {
    let day: String
    let isSelected: Bool
    let onTap: () -> Void
    let themeManager: ThemeManager

    var body: some View {
        Button(action: onTap) {
            Text(day)
                .font(.custom("ProductSans-Bold", size: 13))
                .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Schedule Row Component

private struct ScheduleRow: View {
    let label: String
    let value: String
    let icon: String
    let iconColor: Color
    let isExpanded: Bool
    let onTap: () -> Void
    let themeManager: ThemeManager

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(label)
                    .font(.custom("ProductSans-Regular", size: 15))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                Spacer()

                Text(value)
                    .font(.custom("ProductSans-Medium", size: 15))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface(themeManager.colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isExpanded ? AppColors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Reminder Config Sheet (for new items)
struct ReminderConfigSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @Binding var reminderTimes: [Date]
    @Binding var reminderDays: Set<Int>
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var hasEndDate: Bool
    var onSave: () -> Void

    @State private var showingTimePicker = false
    @State private var editingTimeIndex: Int? = nil
    @State private var tempTime: Date = Date()
    @State private var showScheduleOptions = false
    @State private var activeSection: ConfigSection? = nil
    @State private var appearAnimation = false

    private enum ConfigSection {
        case startDate, endDate
    }

    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private var selectedDaysDescription: String {
        if reminderDays.count == 7 {
            return "Every day"
        } else if reminderDays.count == 0 {
            return "No days selected"
        } else if reminderDays == Set([1, 2, 3, 4, 5]) {
            return "Weekdays"
        } else if reminderDays == Set([0, 6]) {
            return "Weekends"
        } else {
            let sortedDays = reminderDays.sorted()
            return sortedDays.map { String(fullDayNames[$0].prefix(3)) }.joined(separator: ", ")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: startDate)
    }

    private var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: endDate)
    }

    var body: some View {
            ZStack {
            // Background
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                // Header
                headerSection

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Time Display & Picker
                        timeSection

                        // Quick Presets
                            presetsSection

                        // Days
                        daysSection

                        // Schedule
                            scheduleSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            // Bottom Save Button
            VStack {
                Spacer()
                saveButtonSection
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
        Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            dismiss()
        } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
            }

            Spacer()

            Text("Set Reminder")
                .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Spacer()
                        
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                ForEach(Array(reminderTimes.enumerated()), id: \.offset) { index, time in
                    ConfigTimeCard(
                        time: time,
                        isEditing: showingTimePicker && editingTimeIndex == index,
                        onEdit: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            editingTimeIndex = index
                            tempTime = time
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingTimePicker = true
                            }
                        },
                        onDelete: reminderTimes.count > 1 ? {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                reminderTimes.remove(at: index)
                            }
                        } : nil,
                        themeManager: themeManager
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }

            // Time picker
            if showingTimePicker {
                VStack(spacing: 16) {
            DatePicker("", selection: $tempTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                        .frame(height: 150)
            
            HStack(spacing: 12) {
                Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingTimePicker = false
                        editingTimeIndex = nil
                    }
                } label: {
                    Text("Cancel")
                                .font(.custom("ProductSans-Medium", size: 15))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        .background(
                                    RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                }
                
                Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if let idx = editingTimeIndex {
                                    reminderTimes[idx] = tempTime
                                }
                                reminderTimes.sort { $0 < $1 }
                        showingTimePicker = false
                        editingTimeIndex = nil
                    }
                } label: {
                            Text("Done")
                                .font(.custom("ProductSans-Bold", size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        .background(
                                    RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.primary)
                        )
                }
            }
        }
                .padding(20)
        .background(
                    RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.surface(themeManager.colorScheme))
                        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
            }

            // Add time button
            if reminderTimes.count < 5 && !showingTimePicker {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    addNewTime()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Time")
                            .font(.custom("ProductSans-Medium", size: 14))
                    }
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.primary.opacity(0.05))
                            )
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Set")
                .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

            HStack(spacing: 10) {
                PresetChip(title: "Morning", icon: "sunrise.fill", iconColor: .orange) {
                    setPresetTime(hour: 8)
                }
                PresetChip(title: "2x Daily", icon: "repeat", iconColor: AppColors.primary) {
                    setPresetTimes(hours: [8, 20])
                }
                PresetChip(title: "3x Daily", icon: "repeat.circle", iconColor: .purple) {
                    setPresetTimes(hours: [8, 14, 20])
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appearAnimation)
    }

    // MARK: - Days Section

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Repeat")
                    .font(.custom("ProductSans-Medium", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                
                Spacer()
                
                Text(selectedDaysDescription)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.primary)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    DayChip(
                        day: dayNames[day],
                        isSelected: reminderDays.contains(day),
                        onTap: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if reminderDays.contains(day) {
                                    reminderDays.remove(day)
                            } else {
                                    reminderDays.insert(day)
                                }
                            }
                        },
                        themeManager: themeManager
                    )
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appearAnimation)
    }

    // MARK: - Schedule Section
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Duration")
                    .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
                Spacer()

                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showScheduleOptions.toggle()
                        if !showScheduleOptions {
                            activeSection = nil
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(hasEndDate ? "\(formattedStartDate) - \(formattedEndDate)" : "From \(formattedStartDate)")
                            .font(.custom("ProductSans-Medium", size: 13))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(showScheduleOptions ? 180 : 0))
                    }
                            .foregroundColor(AppColors.primary)
                }
            }

            if showScheduleOptions {
                VStack(spacing: 12) {
                    // Start date
                    ScheduleRow(
                        label: "Start",
                        value: formattedStartDate,
                        icon: "play.circle.fill",
                        iconColor: .green,
                        isExpanded: activeSection == .startDate,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                activeSection = activeSection == .startDate ? nil : .startDate
                            }
                        },
                        themeManager: themeManager
                    )

                    if activeSection == .startDate {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                            .tint(AppColors.primary)
                        .padding(12)
                        .background(
                                RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.98).combined(with: .opacity)
                            ))
                    }

                    // End date
                    ScheduleRow(
                        label: "End",
                        value: hasEndDate ? formattedEndDate : "No end date",
                        icon: hasEndDate ? "stop.circle.fill" : "infinity.circle.fill",
                        iconColor: hasEndDate ? .red : AppColors.textSecondary(themeManager.colorScheme),
                        isExpanded: activeSection == .endDate,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if !hasEndDate {
                                    hasEndDate = true
                                }
                                activeSection = activeSection == .endDate ? nil : .endDate
                            }
                        },
                        themeManager: themeManager
                    )

                    if activeSection == .endDate {
                        VStack(spacing: 12) {
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(AppColors.primary)

                if hasEndDate {
                    Button {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        hasEndDate = false
                                        activeSection = nil
                        }
                    } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "infinity")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Continue indefinitely")
                                            .font(.custom("ProductSans-Medium", size: 13))
                                    }
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                        }
                            .padding(12)
                            .background(
                            RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: appearAnimation)
    }

    // MARK: - Save Button

    private var saveButtonSection: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    AppColors.modalBackground(themeManager.colorScheme).opacity(0),
                    AppColors.modalBackground(themeManager.colorScheme)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
        Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
            onSave()
            dismiss()
        } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16))
                Text("Save Reminder")
                    .font(.custom("ProductSans-Bold", size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
                    .frame(height: 56)
            .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                reminderDays.isEmpty || reminderTimes.isEmpty
                                    ? AppColors.primary.opacity(0.4)
                                    : AppColors.primary
                            )
                            .shadow(
                                color: reminderDays.isEmpty || reminderTimes.isEmpty
                                    ? Color.clear
                                    : AppColors.primary.opacity(0.3),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    )
                }
                .disabled(reminderDays.isEmpty || reminderTimes.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(AppColors.modalBackground(themeManager.colorScheme))
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
    }

    // MARK: - Helper Functions

    private func addNewTime() {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        let newTime = Calendar.current.date(from: components) ?? Date()

        tempTime = newTime
        editingTimeIndex = reminderTimes.count
        reminderTimes.append(newTime)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingTimePicker = true
        }
    }

    private func setPresetTime(hour: Int) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
        if let time = Calendar.current.date(from: components) {
                reminderTimes = [time]
            }
            showingTimePicker = false
            editingTimeIndex = nil
        }
    }

    private func setPresetTimes(hours: [Int]) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            reminderTimes = hours.compactMap { hour in
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = hour
                components.minute = 0
                return Calendar.current.date(from: components)
            }
            showingTimePicker = false
            editingTimeIndex = nil
        }
    }
}

// MARK: - Config Time Card Component

private struct ConfigTimeCard: View {
    let time: Date
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    let themeManager: ThemeManager

    private var timeIcon: String {
        let hour = Calendar.current.component(.hour, from: time)
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

    private var iconColor: Color {
        let hour = Calendar.current.component(.hour, from: time)
        if hour >= 5 && hour < 12 {
            return .orange
        } else if hour >= 12 && hour < 17 {
            return .yellow
        } else if hour >= 17 && hour < 21 {
            return .orange
        } else {
            return .indigo
        }
    }

    private var periodLabel: String {
        let hour = Calendar.current.component(.hour, from: time)
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

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: timeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTime)
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(periodLabel)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                        )
                }

                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface(themeManager.colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEditing ? AppColors.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let action: () -> Void

    private var iconColor: Color {
        switch icon {
        case "sunrise.fill": return .orange
        case "sun.max.fill": return .yellow
        case "sunset.fill": return .orange
        case "moon.fill": return .indigo
        default: return AppColors.primary
        }
    }

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 40, height: 40)

                Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
            }

                Text(title)
                    .font(.custom("ProductSans-Medium", size: 12))
            .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface(themeManager.colorScheme))
            )
        }
        .buttonStyle(PresetButtonStyle())
    }
}

// MARK: - Preset Button Style
private struct PresetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Day Button
struct DayButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let day: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        } label: {
            Text(day)
                .font(.custom("ProductSans-Bold", size: 13))
                .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                        .shadow(
                            color: isSelected ? AppColors.primary.opacity(0.3) : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
        }
        .buttonStyle(DayButtonStyle())
    }
}

// MARK: - Day Button Style
private struct DayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
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
    @State private var isSubmitting = false
    @State private var appearAnimation = false
    @State private var reminderTimes: [Date]
    @State private var selectedDays: Set<Int>
    @State private var showingTimePicker = false
    @State private var editingTimeIndex: Int? = nil
    @State private var tempTime: Date = Date()
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasEndDate: Bool
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showReminderSheet = false

    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    init(item: FoodSupplementItem, viewModel: LoggingViewModel) {
        self.item = item
        self.viewModel = viewModel

        _name = State(initialValue: item.name)
        _selectedType = State(initialValue: item.type)

        // Parse reminder times
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        if !item.reminderTimes.isEmpty {
            let times = item.reminderTimes.compactMap { formatter.date(from: $0) }
            _reminderTimes = State(initialValue: times.isEmpty ? [EditItemSheet.defaultTime(hour: 9)] : times)
        } else {
            // Default to 9:00 AM
            _reminderTimes = State(initialValue: [EditItemSheet.defaultTime(hour: 9)])
        }

        _selectedDays = State(initialValue: Set(item.reminderDays.isEmpty ? [0,1,2,3,4,5,6] : item.reminderDays))

        // Parse start date
        if let startDateString = item.startDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            _startDate = State(initialValue: dateFormatter.date(from: startDateString) ?? Date())
        } else {
            _startDate = State(initialValue: Date())
        }

        // Parse end date
        if let endDateString = item.endDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            _endDate = State(initialValue: dateFormatter.date(from: endDateString) ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
            _hasEndDate = State(initialValue: true)
        } else {
            _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
            _hasEndDate = State(initialValue: false)
        }
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

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
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
                                    ForEach(LogItemType.allCases.filter { $0 != .food }, id: \.self) { type in
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
                            
                            // Reminder sections
                            editReminderTimesSection
                            editPresetsSection
                            if showingTimePicker { editTimePickerSection }
                            editDaySelectorSection
                            editScheduleSection
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
                                .fill(name.isEmpty ? AppColors.primary.opacity(0.4) : AppColors.primary)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                        )
                    }
                    .disabled(name.isEmpty || isSubmitting)
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
        .sheet(isPresented: $showReminderSheet) {
            ReminderSheet(item: item, viewModel: viewModel)
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Reminder Section Views

    private func editTimeIconColor(for date: Date) -> Color {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 5 && hour < 12 {
            return .orange
        } else if hour >= 12 && hour < 17 {
            return .yellow
        } else if hour >= 17 && hour < 21 {
            return .orange
        } else {
            return .indigo
        }
    }
    
    private var editReminderTimesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Reminder Times")
                .font(.custom("ProductSans-Medium", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

            // Time cards
            VStack(spacing: 10) {
                ForEach(Array(reminderTimes.enumerated()), id: \.offset) { index, time in
                    editTimeRow(index: index, time: time)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }

            // Add time button
            if reminderTimes.count < 5 && !showingTimePicker {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    editAddNewTime()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add Time")
                            .font(.custom("ProductSans-Medium", size: 14))
                    }
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColors.primary.opacity(0.3), lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.primary.opacity(0.05))
                            )
                    )
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }
    
    private func editTimeRow(index: Int, time: Date) -> some View {
        let iconColor = editTimeIconColor(for: time)

        return HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: editTimeIcon(for: time))
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // Time info
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(time))
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(editTimePeriodLabel(for: time))
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
            Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                editingTimeIndex = index
                tempTime = time
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingTimePicker = true
                    }
            } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                        )
                }

            if reminderTimes.count > 1 {
                Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            reminderTimes.remove(at: index)
                    }
                } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface(themeManager.colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            showingTimePicker && editingTimeIndex == index
                                ? AppColors.primary.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private var editTimePickerSection: some View {
        VStack(spacing: 16) {
            DatePicker("", selection: $tempTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 150)

            HStack(spacing: 12) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingTimePicker = false
                        editingTimeIndex = nil
                    }
                } label: {
                    Text("Cancel")
                        .font(.custom("ProductSans-Medium", size: 15))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                }

            Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if let idx = editingTimeIndex {
                            reminderTimes[idx] = tempTime
                        } else {
                            reminderTimes.append(tempTime)
                        }
                        reminderTimes.sort { $0 < $1 }
                    showingTimePicker = false
                    editingTimeIndex = nil
                }
            } label: {
                    Text("Done")
                    .font(.custom("ProductSans-Bold", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.primary)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.surface(themeManager.colorScheme))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .move(edge: .top)),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        ))
    }
    
    private var editDaySelectorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Repeat")
                    .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                Spacer()

                Text(selectedDaysDescription)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.primary)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDays.contains(day) ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                                    .shadow(
                                        color: selectedDays.contains(day) ? AppColors.primary.opacity(0.3) : Color.clear,
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }
    
    private var editPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Set")
                .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

            HStack(spacing: 10) {
                EditPresetChip(title: "Morning", icon: "sunrise.fill", iconColor: .orange) {
                    editApplyPreset(times: [8])
                }
                EditPresetChip(title: "2x Daily", icon: "repeat", iconColor: AppColors.primary) {
                    editApplyPreset(times: [8, 20])
                }
                EditPresetChip(title: "3x Daily", icon: "repeat.circle", iconColor: .purple) {
                    editApplyPreset(times: [8, 14, 20])
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }
    
    private var editScheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Duration")
                    .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                Spacer()

                Text(hasEndDate ? "\(formattedStartDate) - \(formattedEndDate)" : "From \(formattedStartDate)")
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.primary)
            }

            VStack(spacing: 12) {
                // Start date
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showStartDatePicker.toggle()
                        showEndDatePicker = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                            .frame(width: 24)

                            Text("Start")
                            .font(.custom("ProductSans-Regular", size: 15))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                        Text(formattedStartDate)
                            .font(.custom("ProductSans-Medium", size: 15))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
                            .rotationEffect(.degrees(showStartDatePicker ? 90 : 0))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.surface(themeManager.colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(showStartDatePicker ? AppColors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
                            )
                    )
                }

                if showStartDatePicker {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppColors.primary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                }

                // End date
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if !hasEndDate {
                            hasEndDate = true
                        }
                        showEndDatePicker.toggle()
                        showStartDatePicker = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: hasEndDate ? "stop.circle.fill" : "infinity.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(hasEndDate ? .red : AppColors.textSecondary(themeManager.colorScheme))
                            .frame(width: 24)

                            Text("End")
                            .font(.custom("ProductSans-Regular", size: 15))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                        Text(hasEndDate ? formattedEndDate : "No end date")
                            .font(.custom("ProductSans-Medium", size: 15))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
                            .rotationEffect(.degrees(showEndDatePicker ? 90 : 0))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.surface(themeManager.colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(showEndDatePicker ? AppColors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
                            )
                    )
                }

            if showEndDatePicker {
                VStack(spacing: 12) {
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppColors.primary)

                    if hasEndDate {
                        Button {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                hasEndDate = false
                                showEndDatePicker = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                    Image(systemName: "infinity")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Continue indefinitely")
                                    .font(.custom("ProductSans-Medium", size: 13))
                            }
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
                    .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface(themeManager.colorScheme))
                )
                .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
            }
        }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }
    
    private func editAddNewTime() {
        let existingHours = Set(reminderTimes.map { Calendar.current.component(.hour, from: $0) })
        let defaultHours = [9, 12, 15, 18, 21, 8, 7, 10, 14, 20]
        let newHour = defaultHours.first { !existingHours.contains($0) } ?? 12

        tempTime = EditItemSheet.defaultTime(hour: newHour)
        editingTimeIndex = reminderTimes.count
        reminderTimes.append(tempTime)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingTimePicker = true
        }
    }
    
    private func editApplyPreset(times: [Int]) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            reminderTimes = times.map { EditItemSheet.defaultTime(hour: $0) }
            showingTimePicker = false
            editingTimeIndex = nil
        }
    }
    
    private func editTimeIcon(for date: Date) -> String {
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

    private func editTimePeriodLabel(for date: Date) -> String {
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

    private func saveItem() {
        guard !name.isEmpty else { return }
        isSubmitting = true

        Task {
            // First update item name, type, and dates
            await viewModel.updateItem(
                item,
                name: name,
                type: selectedType,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                clearEndDate: !hasEndDate
            )
            
            // Small delay to ensure the item is updated in the array
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Then update reminder settings (this will schedule with correct dates)
            // Need to get the updated item from the viewModel
            if let updatedItem = await MainActor.run(body: { viewModel.items.first(where: { $0.id == item.id }) }) {
                print("🔔 saveItem: Got updated item with startDate=\(updatedItem.startDate ?? "nil"), endDate=\(updatedItem.endDate ?? "nil")")
                await viewModel.updateReminder(
                    for: updatedItem,
                    enabled: !reminderTimes.isEmpty && !selectedDays.isEmpty,
                    times: reminderTimes,
                    days: Array(selectedDays)
                )
            } else {
                print("⚠️ saveItem: Item not found, using original item")
                // Fallback if item not found
                await viewModel.updateReminder(
                    for: item,
                    enabled: !reminderTimes.isEmpty && !selectedDays.isEmpty,
                    times: reminderTimes,
                    days: Array(selectedDays)
                )
            }
            
            await MainActor.run {
            isSubmitting = false
            dismiss()
            }
        }
    }
}

// MARK: - Edit Preset Chip Component

private struct EditPresetChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.custom("ProductSans-Medium", size: 13))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppColors.surface(themeManager.colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
