//
//  LoggingView.swift
//  app
//
//  Main view for food and supplement logging
//

import SwiftUI

// MARK: - Main Logging Tab View
struct LoggingTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = LoggingViewModel.shared
    @State private var showAddSheet = false
    @State private var selectedItem: FoodSupplementItem? = nil
    @State private var showImpactModal = false
    @State private var showReminderSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Voice Input Section
                    VoiceInputSection(viewModel: viewModel)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    // Quick Actions
                    if !viewModel.items.isEmpty {
                        QuickLogSection(viewModel: viewModel)
                            .padding(.top, 20)
                    }
                    
                    // Items List
                    if viewModel.isLoading && viewModel.items.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(AppColors.primary)
                        Spacer()
                    } else if viewModel.items.isEmpty {
                        EmptyStateView(onAddTapped: { showAddSheet = true })
                    } else {
                        ItemsListSection(
                            viewModel: viewModel,
                            onItemTapped: { item in
                                selectedItem = item
                            },
                            onLogTapped: { item in
                                Task {
                                    await viewModel.logItem(item)
                                }
                            },
                            onImpactTapped: { item in
                                selectedItem = item
                                showImpactModal = true
                            },
                            onReminderTapped: { item in
                                selectedItem = item
                                showReminderSheet = true
                            }
                        )
                    }
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(viewModel: viewModel)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showImpactModal) {
                if let item = selectedItem {
                    BiomarkerImpactModal(item: item, viewModel: viewModel)
                        .environmentObject(themeManager)
                }
            }
            .sheet(isPresented: $showReminderSheet) {
                if let item = selectedItem {
                    ReminderSheet(item: item, viewModel: viewModel)
                        .environmentObject(themeManager)
                }
            }
            .task {
                await viewModel.refreshData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .overlay {
                // Success/Error Toast
                if let message = viewModel.successMessage {
                    ToastView(message: message, type: .success)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    viewModel.clearMessages()
                                }
                            }
                        }
                }
                
                if let error = viewModel.error {
                    ToastView(message: error, type: .error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    viewModel.clearMessages()
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: viewModel.successMessage)
            .animation(.easeInOut, value: viewModel.error)
        }
    }
}

// MARK: - Voice Input Section
struct VoiceInputSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: LoggingViewModel
    @State private var manualInput: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Input field with mic button
            HStack(spacing: 12) {
                // Text field
                HStack {
                    TextField("What did you take?", text: viewModel.isRecording ? $viewModel.transcribedText : $manualInput)
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            submitInput()
                        }
                    
                    if !manualInput.isEmpty || !viewModel.transcribedText.isEmpty {
                        Button {
                            submitInput()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppColors.inputBackground(themeManager.colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(viewModel.isRecording ? AppColors.primary : AppColors.border(themeManager.colorScheme), lineWidth: viewModel.isRecording ? 2 : 1)
                        )
                )
                
                // Microphone button
                Button {
                    Task {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? AppColors.primary : AppColors.inputBackground(themeManager.colorScheme))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(viewModel.isRecording ? .white : AppColors.primary)
                    }
                }
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isRecording)
            }
            
            // Processing indicator
            if viewModel.isProcessingVoice {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(AppColors.primary)
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
            }
            
            // Hint text
            if !viewModel.isRecording && manualInput.isEmpty && viewModel.transcribedText.isEmpty {
                Text("Tap the mic or type: \"Vitamin D 1000IU\" or \"Fish oil and zinc\"")
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func submitInput() {
        let text = viewModel.isRecording ? viewModel.transcribedText : manualInput
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if viewModel.isRecording {
            viewModel.stopRecording()
        }
        
        Task {
            await viewModel.quickLog(text: text)
            manualInput = ""
        }
        
        isInputFocused = false
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
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.primary.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                    )
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
                        FilterChip(title: "Food", isSelected: viewModel.selectedFilter == .food) {
                            viewModel.selectedFilter = .food
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
                        onDelete: {
                            Task {
                                await viewModel.deleteItem(item)
                            }
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
    let onDelete: () -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.type == .supplement ? Color.purple.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: item.type.icon)
                        .font(.system(size: 16))
                        .foregroundColor(item.type == .supplement ? .purple : .orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    HStack(spacing: 8) {
                        Text(item.frequency.displayName)
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        
                        if let logCount = item.logCount, logCount > 0 {
                            Text("•")
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            Text("\(logCount) logs")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        
                        if item.reminderEnabled {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
                
                Spacer()
                
                // Quick log button
                Button(action: onLog) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.primary)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                ActionButton(icon: "chart.bar.fill", title: "See Impact", color: .blue) {
                    onImpact()
                }
                
                ActionButton(icon: "bell.fill", title: item.reminderEnabled ? "Edit Reminder" : "Set Reminder", color: .orange) {
                    onReminder()
                }
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface(themeManager.colorScheme))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.custom("ProductSans-Medium", size: 12))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
        }
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
            
            Text("Add supplements or foods you want to track\nand see their impact on your biomarkers")
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
            
            Button(action: onAddTapped) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Your First Item")
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
            .padding(.top, 8)
            
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

// MARK: - Preview
#Preview {
    LoggingTabView()
        .environmentObject(ThemeManager.shared)
}
