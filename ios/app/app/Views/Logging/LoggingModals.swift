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

    @State private var reminderTime: Date
    @State private var selectedDays: Set<Int>
    @State private var isSaving = false

    let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(item: FoodSupplementItem, viewModel: LoggingViewModel) {
        self.item = item
        self.viewModel = viewModel

        // Parse reminder time
        if let timeString = item.reminderTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            _reminderTime = State(initialValue: formatter.date(from: timeString) ?? Date())
        } else {
            // Default to 9:00 AM
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        }

        _selectedDays = State(initialValue: Set(item.reminderDays.isEmpty ? [0,1,2,3,4,5,6] : item.reminderDays))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Time picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Reminder Time")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                                DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 150)
                                    .clipped()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppColors.surface(themeManager.colorScheme))
                                    )
                            }

                            // Day selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Repeat on")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                                HStack(spacing: 8) {
                                    ForEach(0..<7, id: \.self) { day in
                                        DayButton(
                                            day: dayNames[day],
                                            isSelected: selectedDays.contains(day)
                                        ) {
                                            if selectedDays.contains(day) {
                                                selectedDays.remove(day)
                                            } else {
                                                selectedDays.insert(day)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }

                    // Save button (pill-shaped, fixed at bottom)
                    Button {
                        saveReminder()
                    } label: {
                        HStack {
                            if isSaving {
                                CustomSpinner(size: 20, lineWidth: 2.5)
                            } else {
                                Text("Save Reminder")
                            }
                        }
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(AppColors.primary)
                        )
                    }
                    .disabled(isSaving || selectedDays.isEmpty)
                    .opacity(selectedDays.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Set Reminder")
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

    private func saveReminder() {
        isSaving = true
        Task {
            // Saving means enabling the reminder
            await viewModel.updateReminder(
                for: item,
                enabled: true,
                time: reminderTime,
                days: Array(selectedDays)
            )
            isSaving = false
            dismiss()
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

    let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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

                        // Day selector (synced with reminder days)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days to take")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { day in
                                    DayButton(
                                        day: dayNames[day],
                                        isSelected: selectedDays.contains(day)
                                    ) {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Start and End dates
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            
                            HStack(spacing: 12) {
                                // Start date
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showStartDatePicker.toggle()
                                        showEndDatePicker = false
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Start")
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        Text(formattedStartDate)
                                            .font(.custom("ProductSans-Medium", size: 14))
                                            .foregroundColor(showStartDatePicker ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AppColors.inputBackground(themeManager.colorScheme))
                                    )
                                }
                                
                                // End date
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showEndDatePicker.toggle()
                                        showStartDatePicker = false
                                        if !hasEndDate {
                                            hasEndDate = true
                                        }
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("End")
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        Text(hasEndDate ? formattedEndDate : "No end date")
                                            .font(.custom("ProductSans-Medium", size: 14))
                                            .foregroundColor(showEndDatePicker ? AppColors.primary : (hasEndDate ? AppColors.text(themeManager.colorScheme) : AppColors.textSecondary(themeManager.colorScheme)))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AppColors.inputBackground(themeManager.colorScheme))
                                    )
                                }
                            }
                            
                            // Start date picker
                            if showStartDatePicker {
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .scaleEffect(0.9)
                                    .frame(height: 300)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppColors.surface(themeManager.colorScheme))
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                            
                            // End date picker
                            if showEndDatePicker {
                                VStack(spacing: 8) {
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .scaleEffect(0.9)
                                        .frame(height: 300)
                                    
                                    Button {
                                        hasEndDate = false
                                        showEndDatePicker = false
                                    } label: {
                                        Text("Remove end date")
                                            .font(.custom("ProductSans-Medium", size: 14))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.surface(themeManager.colorScheme))
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }

                        Spacer(minLength: 40)

                        // Save button (pill-shaped, fixed at bottom)
                        Button {
                            saveItem()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    CustomSpinner(size: 20, lineWidth: 2.5)
                                } else {
                                    Text("Save Changes")
                                }
                            }
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(name.isEmpty || selectedDays.isEmpty ? AppColors.primary.opacity(0.5) : AppColors.primary)
                            )
                        }
                        .disabled(name.isEmpty || selectedDays.isEmpty || isSubmitting)
                        .opacity(name.isEmpty || selectedDays.isEmpty ? 0.5 : 1)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
                .animation(.easeInOut(duration: 0.2), value: showStartDatePicker)
                .animation(.easeInOut(duration: 0.2), value: showEndDatePicker)
            }
            .navigationTitle("Edit \(item.type.displayName)")
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
