//
//  LoggingView.swift
//  app
//
//  Main view for medication and supplement tracking
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Items List
                    if viewModel.isLoading && viewModel.items.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(AppColors.primary)
                        Spacer()
                    } else if viewModel.items.isEmpty {
                        EmptyStateView(onAddTapped: { showAddSheet = true })
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Quick Actions
                                QuickLogSection(viewModel: viewModel)
                                    .padding(.top, 8)
                                
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
                                .padding(.top, 8)
                                
                                // Items
                                ForEach(viewModel.filteredItems) { item in
                                    ItemCard(
                                        item: item,
                                        onLog: { 
                                            Task {
                                                await viewModel.logItem(item)
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
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteItem(item)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 100) // Space for bottom input
                        }
                    }
                    
                    Spacer()
                }
                
                // Bottom Input Section (Fixed at bottom)
                VStack {
                    Spacer()
                    VoiceInputSection(viewModel: viewModel)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarTitle("Medication", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        NotificationCenter.default.post(name: .switchTab, object: nil, userInfo: ["tab": 0])
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.custom("ProductSans-Regular", size: 17))
                        }
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showAddSheet) {
                AddItemSheet(viewModel: viewModel)
                    .environmentObject(themeManager)
            }
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
                        .presentationDetents(item.reminderEnabled ? [.large] : [.medium, .large])
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
    
    // Glass effect colors
    private var glassBackground: Color {
        themeManager.colorScheme == .dark
            ? Color(white: 0.18).opacity(0.92)
            : Color(white: 0.94).opacity(0.92)
    }
    
    private var glassBorder: Color {
        themeManager.colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.08)
    }
    
    // Helper to check if there's input text
    private var hasInputText: Bool {
        !manualInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
        !viewModel.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Input field with mic button
            if #available(iOS 26.0, *) {
                GlassEffectContainer{
                    HStack(spacing: 12) {
                        // Text field with padding
                        TextField("Add medication or supplement...", text: viewModel.isRecording ? $viewModel.transcribedText : $manualInput)
                            .font(.custom("ProductSans-Regular", size: 18))
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                submitInput()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .glassEffect(.regular.interactive())
                        
                        // Microphone / Send button (morphs based on input)
                        Button {
                            Task {
                                if hasInputText {
                                    // Send the message
                                    submitInput()
                                } else if viewModel.isRecording {
                                    // Stop recording
                                    viewModel.stopRecording()
                                } else {
                                    // Start recording
                                    await viewModel.startRecording()
                                }
                            }
                        } label: {
                            // Icon morphs based on state
                            if hasInputText {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                            } else {
                                Image(systemName: viewModel.isRecording ? "stop.fill" : "waveform")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isRecording)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasInputText)
                    }
                    
                    // Processing indicator
                    if viewModel.isProcessingVoice {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(AppColors.primary)
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
            } else {
                // Fallback on earlier versions
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
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
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
                    Text(item.frequency.displayName)
                        .font(.custom("ProductSans-Regular", size: 11))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    
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
            if #available(iOS 18.0, *) {
                if #available(iOS 26.0, *) {
                    HStack(spacing: 12) {
                        Button {
                            onReminder()
                        } label: {
                            Image(systemName: item.reminderEnabled ? "alarm.waves.left.and.right.fill" : "alarm.waves.left.and.right")
                                .font(.system(size: 16))
                                .foregroundColor(item.reminderEnabled ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onImpact()
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)
                        
                        Menu {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.interactive())
                } else {
                    // Fallback on earlier versions
                }
            } else {
                // Fallback for older iOS versions
                HStack(spacing: 12) {
                    Button {
                        onReminder()
                    } label: {
                        Image(systemName: item.reminderEnabled ? "bell.fill" : "bell")
                            .font(.system(size: 16))
                            .foregroundColor(item.reminderEnabled ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onImpact()
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
        .background(
            Capsule()
                .fill(AppColors.surface(themeManager.colorScheme))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
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
