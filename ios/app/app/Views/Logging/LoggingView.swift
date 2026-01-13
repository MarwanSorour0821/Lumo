//
//  LoggingView.swift
//  app
//
//  Main view for medication and supplement tracking
//

import SwiftUI
import Combine

// MARK: - Main Logging Tab View
struct LoggingTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = LoggingViewModel.shared
    @State private var selectedItem: FoodSupplementItem? = nil
    @State private var showImpactModal = false
    @State private var showReminderSheet = false
    @State private var showEditSheet = false
    @State private var selectedNavTab: MedicationNavTab = .new
    @State private var gradientAnimation: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground(
                    animate: $gradientAnimation,
                    colorScheme: themeManager.colorScheme
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Items List
                    if viewModel.isLoading && viewModel.items.isEmpty {
                        Spacer()
                        CustomSpinner(size: 32, lineWidth: 3)
                        Spacer()
                    } else if viewModel.items.isEmpty {
                        EmptyStateView(onAddTapped: {})
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Filter chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        FilterChip(title: "All", isSelected: viewModel.selectedFilter == nil) {
                                            viewModel.selectedFilter = nil
                                        }
                                        FilterChip(title: "Supplements", isSelected: viewModel.selectedFilter == .supplement) {
                                            viewModel.selectedFilter = .supplement
                                        }
                                        FilterChip(title: "Medication", isSelected: viewModel.selectedFilter == .medication) {
                                            viewModel.selectedFilter = .medication
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.top, 16)

                                // Items
                                ForEach(viewModel.filteredItems) { item in
                                    ItemCard(
                                        item: item,
                                        onLog: {
                                            Task {
                                                await viewModel.toggleTaken(item)
                                            }
                                        },
                                        onImpact: {
                                            selectedItem = item
                                            showImpactModal = true
                                        },
                                        onReminder: {
                                            selectedItem = item
                                            showReminderSheet = true
                                        },
                                        onEdit: {
                                            selectedItem = item
                                            showEditSheet = true
                                        },
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteItem(item)
                                            }
                                        },
                                        onToggleDose: { timeIndex in
                                            Task {
                                                await viewModel.toggleDose(item, timeIndex: timeIndex)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 180) // Space for input
                        }
                    }

                    Spacer(minLength: 0)
                }

                // Bottom Input Section
                VStack(spacing: 0) {
                    Spacer()

                    ReminderInputCard(viewModel: viewModel)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .navigationBarTitle("Medication", displayMode: .inline)
            .sheet(isPresented: $showImpactModal) {
                if let item = selectedItem {
                    BiomarkerImpactModal(item: item, viewModel: viewModel)
                        .environmentObject(themeManager)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showReminderSheet) {
                if let item = selectedItem {
                    ReminderSheet(item: item, viewModel: viewModel)
                        .environmentObject(themeManager)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let item = selectedItem {
                    EditItemSheet(item: item, viewModel: viewModel)
                        .environmentObject(themeManager)
                        .presentationDetents([.large])
                }
            }
            .task {
                await viewModel.refreshData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                    gradientAnimation = true
                }
            }
        }
    }
}

// MARK: - Medication Nav Tab
enum MedicationNavTab {
    case new, reminders, settings
}

// MARK: - Reminder Input Card
struct ReminderInputCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: LoggingViewModel
    @State private var medicationName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var reminderTimes: [Date] = [{
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()]
    @State private var reminderDays: Set<Int> = Set([0, 1, 2, 3, 4, 5, 6])
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showStartDateModal = false
    @State private var showEndDateModal = false
    @State private var showReminderModal = false
    @State private var hasConfiguredReminder = false
    @State private var showPaywall = false
    @State private var isCheckingSubscription = false
    @FocusState private var isInputFocused: Bool

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

    private var reminderChipText: String {
        if hasConfiguredReminder && !reminderTimes.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            if reminderTimes.count == 1 {
                return formatter.string(from: reminderTimes[0])
            } else {
                return "\(reminderTimes.count) times"
            }
        }
        return "Set reminder"
    }

    private var hasInput: Bool {
        !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    

    var body: some View {
        VStack(spacing: 12) {
            // Date and Time chips row
            if #available(iOS 26.0, *) {
                HStack(spacing: 8) {
                    // Start date chip
                    Button {
                        showStartDateModal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text(formattedStartDate)
                                .font(.custom("ProductSans-Medium", size: 13))
                        }
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    
                    // End date chip
                    Button {
                        showEndDateModal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                            Text(formattedEndDate)
                                .font(.custom("ProductSans-Medium", size: 13))
                        }
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())

                    // Reminder chip
                    Button {
                        showReminderModal = true
                        showStartDatePicker = false
                        showEndDatePicker = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: hasConfiguredReminder ? "alarm.fill" : "alarm")
                                .font(.system(size: 12))
                            Text(reminderChipText)
                                .font(.custom("ProductSans-Medium", size: 13))
                        }
                        .foregroundColor(hasConfiguredReminder ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())

                    Spacer()
                }

                // Input card with extra height
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remind me to take:")
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                    HStack(alignment: .center, spacing: 12) {
                        TextField("Vitamin D3", text: $medicationName)
                            .font(.custom("ProductSans-Bold", size: 20))
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                submitReminder()
                            }

                        Spacer()

                        // Send button
                        Button {
                            submitReminder()
                        } label: {
                            Circle()
                                .fill(hasInput ? AppColors.primary : AppColors.primary.opacity(0.3))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasInput)
                    }
                }
                .padding(16)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 25))

            } else {
                // Fallback for older iOS
                fallbackInputCard
            }
        }
        .sheet(isPresented: $showReminderModal) {
            ReminderConfigSheet(
                reminderTimes: $reminderTimes,
                reminderDays: $reminderDays,
                startDate: $startDate,
                endDate: $endDate,
                onSave: {
                    hasConfiguredReminder = true
                }
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showStartDateModal) {
            DatePickerModal(
                title: "Start Date",
                date: $startDate,
                isPresented: $showStartDateModal
            )
            .environmentObject(themeManager)
            .presentationDetents([.height(550)])
        }
        .sheet(isPresented: $showEndDateModal) {
            DatePickerModal(
                title: "End Date",
                date: $endDate,
                isPresented: $showEndDateModal,
                minDate: startDate
            )
            .environmentObject(themeManager)
            .presentationDetents([.height(550)])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall) {
                // On subscription complete, create the item
                createItem()
            }
            .environmentObject(themeManager)
        }
    }

    private var fallbackInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date/Time row
            HStack(spacing: 8) {
                // Start date chip
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showStartDatePicker.toggle()
                        showEndDatePicker = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(formattedStartDate)
                            .font(.custom("ProductSans-Medium", size: 13))
                    }
                    .foregroundColor(showStartDatePicker ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
                    .contentShape(Rectangle())
                }
                
                // End date chip
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEndDatePicker.toggle()
                        showStartDatePicker = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text(formattedEndDate)
                            .font(.custom("ProductSans-Medium", size: 13))
                    }
                    .foregroundColor(showEndDatePicker ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
                    .contentShape(Rectangle())
                }

                    // Reminder chip
                    Button {
                        showReminderModal = true
                        showStartDatePicker = false
                        showEndDatePicker = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: hasConfiguredReminder ? "alarm.fill" : "alarm")
                                .font(.system(size: 12))
                            Text(reminderChipText)
                                .font(.custom("ProductSans-Medium", size: 13))
                        }
                        .foregroundColor(hasConfiguredReminder ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .contentShape(Rectangle())
                    }

                Spacer()
            }

            // Input card with extra height
            VStack(alignment: .leading, spacing: 8) {
                Text("Remind me to take:")
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                HStack(alignment: .center, spacing: 12) {
                    TextField("Vitamin D3", text: $medicationName)
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Spacer()

                    Button {
                        submitReminder()
                    } label: {
                        Circle()
                            .fill(hasInput ? AppColors.primary : AppColors.primary.opacity(0.3))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .disabled(!hasInput)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(AppColors.surface(themeManager.colorScheme))
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showStartDatePicker)
        .animation(.easeInOut(duration: 0.2), value: showEndDatePicker)
    }

    private func formattedDateForDisplay() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) {
            return "today"
        } else if calendar.isDateInTomorrow(startDate) {
            return "tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: startDate).lowercased()
        }
    }

    private func submitReminder() {
        guard hasInput else { return }
        
        isCheckingSubscription = true

        Task {
            do {
                // Check if user has active subscription
                let hasSubscription = try await SubscriptionService.shared.hasActiveSubscription()
                
                await MainActor.run {
                    isCheckingSubscription = false
                    
                    if hasSubscription {
                        // User has subscription, proceed with creating the item
                        createItem()
                    } else {
                        // No subscription, show paywall
                        showPaywall = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingSubscription = false
                    // On error, show paywall as fallback
                    showPaywall = true
                }
            }
        }
    }
    
    private func createItem() {
        Task {
            // Create the item with reminder and start/end dates
            await viewModel.createItem(
                name: medicationName,
                type: .supplement,
                description: nil,
                frequency: .daily,
                timesPerWeek: 7,
                startDate: startDate,
                endDate: endDate
            )

            // Find the newly created item and set reminder with configured times and days
            if let newItem = viewModel.items.first(where: { $0.name == medicationName }) {
                await viewModel.updateReminder(
                    for: newItem,
                    enabled: true,
                    times: reminderTimes,
                    days: Array(reminderDays)
                )
            }

            // Reset input
            medicationName = ""
            hasConfiguredReminder = false
            reminderTimes = [{
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 9
                components.minute = 0
                return Calendar.current.date(from: components) ?? Date()
            }()]
            reminderDays = Set([0, 1, 2, 3, 4, 5, 6])
            isInputFocused = false
        }
    }
}

// MARK: - Time Picker Modal
struct TimePickerModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTime: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}

// MARK: - Quick Log Section (frequently logged items)
struct QuickLogSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: LoggingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Log")
                .font(.custom("ProductSans-Bold", size: 16))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.items.prefix(6)) { item in
                        QuickLogChip(item: item) {
                            Task {
                                await viewModel.logItem(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Quick Log Chip
struct QuickLogChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    let onTap: () -> Void
    
    // Color scheme for quick log buttons
    private var textColor: Color {
        themeManager.colorScheme == .dark
            ? Color.black
            : Color.white
    }
    
    private var backgroundColor: Color {
        themeManager.colorScheme == .dark
            ? Color.white
            : Color.black
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 12))
                Text(item.name)
                    .font(.custom("ProductSans-Medium", size: 14))
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
        }
    }
}

// MARK: - Items List Section
struct ItemsListSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: LoggingViewModel
    let onItemTapped: (FoodSupplementItem) -> Void
    let onLogTapped: (FoodSupplementItem) -> Void
    let onImpactTapped: (FoodSupplementItem) -> Void
    let onReminderTapped: (FoodSupplementItem) -> Void
    let onEditTapped: (FoodSupplementItem) -> Void
    var onToggleDoseTapped: ((FoodSupplementItem, Int) -> Void)? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: viewModel.selectedFilter == nil) {
                            viewModel.selectedFilter = nil
                        }
                        FilterChip(title: "Supplements", isSelected: viewModel.selectedFilter == .supplement) {
                            viewModel.selectedFilter = .supplement
                        }
                        FilterChip(title: "Medication", isSelected: viewModel.selectedFilter == .medication) {
                            viewModel.selectedFilter = .medication
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)

                // Items
                ForEach(viewModel.filteredItems) { item in
                    ItemCard(
                        item: item,
                        onLog: { onLogTapped(item) },
                        onImpact: { onImpactTapped(item) },
                        onReminder: { onReminderTapped(item) },
                        onEdit: { onEditTapped(item) },
                        onDelete: {
                            Task {
                                await viewModel.deleteItem(item)
                            }
                        },
                        onToggleDose: { timeIndex in
                            onToggleDoseTapped?(item, timeIndex)
                        }
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.custom("ProductSans-Medium", size: 14))
                .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme))
                )
        }
    }
}

// MARK: - Item Card
struct ItemCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    let onLog: () -> Void
    let onImpact: () -> Void
    let onReminder: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onToggleDose: ((Int) -> Void)? = nil

    @State private var showDeleteConfirmation = false
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main card row
            HStack(spacing: 12) {
                // Left side: Checkmark or expand icon for multi-dose
                if item.hasMultipleDoses {
                    // Multi-dose: show expand/collapse arrow
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(item.allDosesTakenToday ? AppColors.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                .frame(width: 32, height: 32)

                            Image(systemName: isExpanded ? "chevron.down" : "arrow.turn.down.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(item.allDosesTakenToday ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    // Single dose: show checkmark button
                    Button {
                        onLog()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(item.isTakenToday ? AppColors.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                .frame(width: 32, height: 32)

                            Image(systemName: item.isTakenToday ? "checkmark" : "circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(item.isTakenToday ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Icon
                ZStack {
                    Circle()
                        .fill(item.type == .supplement ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: item.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(item.type == .supplement ? .purple : .blue)
                }

                // Name and Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.custom("ProductSans-Bold", size: 15))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    HStack(spacing: 6) {
                        if item.hasMultipleDoses {
                            // Show dose progress for multi-dose items
                            let takenCount = item.doseStatusesToday?.filter { $0.isTaken }.count ?? 0
                            let totalCount = item.reminderTimes.count
                            Text("\(takenCount)/\(totalCount) doses")
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(takenCount == totalCount ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        } else {
                            Text(item.frequency.displayName)
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }

                        if let logCount = item.logCount, logCount > 0 {
                            Text("•")
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            Text("\(logCount) logs")
                                .font(.custom("ProductSans-Regular", size: 11))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }

                Spacer()

                // Action buttons in glass container
                if #available(iOS 26.0, *) {
                    HStack(spacing: 16) {
                        Button {
                            onReminder()
                        } label: {
                            Image(systemName: item.reminderEnabled ? "alarm.waves.left.and.right.fill" : "alarm.waves.left.and.right")
                                .font(.system(size: 20))
                                .foregroundColor(item.reminderEnabled ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button {
                                onEdit()
                            } label: {
                                Label("Edit", systemImage: "scribble.variable")
                            }

                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive())
                } else {
                    // iOS 18+ fallback without glassEffect
                    HStack(spacing: 16) {
                        Button {
                            onReminder()
                        } label: {
                            Image(systemName: item.reminderEnabled ? "bell.fill" : "bell")
                                .font(.system(size: 20))
                                .foregroundColor(item.reminderEnabled ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button {
                                onEdit()
                            } label: {
                                Label("Edit", systemImage: "scribble.variable")
                            }

                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: themeManager.colorScheme == .dark ? 0.18 : 0.94).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: themeManager.colorScheme == .dark ? 1.0 : 0.0).opacity(themeManager.colorScheme == .dark ? 0.15 : 0.08), lineWidth: 0.5)
                            )
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Expandable dose list for multi-dose items
            if item.hasMultipleDoses && isExpanded {
                DoseListView(
                    item: item,
                    onToggleDose: { timeIndex in
                        onToggleDose?(timeIndex)
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColors.surface(themeManager.colorScheme))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
}

// MARK: - Dose List View (for multi-dose medications)
struct DoseListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FoodSupplementItem
    let onToggleDose: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(item.doseStatusesToday ?? [], id: \.timeIndex) { doseStatus in
                HStack(spacing: 12) {
                    // Checkmark button
                    Button {
                        onToggleDose(doseStatus.timeIndex)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(doseStatus.isTaken ? AppColors.primary.opacity(0.15) : Color.gray.opacity(0.1))
                                .frame(width: 28, height: 28)

                            Image(systemName: doseStatus.isTaken ? "checkmark" : "circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(doseStatus.isTaken ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                    .buttonStyle(.plain)

                    // Time label
                    Text(doseStatus.formattedTime)
                        .font(.custom("ProductSans-Medium", size: 14))
                        .foregroundColor(doseStatus.isTaken ? AppColors.primary : AppColors.text(themeManager.colorScheme))

                    Spacer()

                    // Status indicator
                    if doseStatus.isTaken {
                        Text("Taken")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)

                // Divider between doses (except last)
                if doseStatus.timeIndex < (item.doseStatusesToday?.count ?? 1) - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.inputBackground(themeManager.colorScheme))
        )
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let onAddTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primary.opacity(0.3))
            
            Text("No items yet")
                .font(.custom("ProductSans-Bold", size: 20))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
            
            Text("Add supplements or medications you want to track\nand set reminders to stay on schedule")
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    let type: ToastType
    
    enum ToastType {
        case success, error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                Text(message)
                    .font(.custom("ProductSans-Medium", size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .padding(.top, 60)
            
            Spacer()
        }
    }
}

// MARK: - Date Picker Modal
struct DatePickerModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    let title: String
    @Binding var date: Date
    @Binding var isPresented: Bool
    var minDate: Date? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if let minDate = minDate {
                        DatePicker("", selection: $date, in: minDate..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(AppColors.primary)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                            )
                    } else {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(AppColors.primary)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                            )
                    }
                    
                    Button {
                        isPresented = false
                    } label: {
                        Text("Done")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(AppColors.primary)
                            )
                    }
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
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
                    Text(title)
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LoggingTabView()
        .environmentObject(ThemeManager.shared)
}
