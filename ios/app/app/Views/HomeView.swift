//
//  HomeView.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Supabase
import UIKit
import UniformTypeIdentifiers
import WebKit
import UserNotifications
import Photos
import AVFoundation
import Combine

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showAnalyseModal = false
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeTabView()
                    .tag(0)
                    .tabItem {
                        Label("Home", systemImage: "apple.homekit")
                    }
                
                HistoryTabView()
                    .tag(1)
                    .tabItem {
                        Label("History", systemImage: "gauge.chart.lefthalf.righthalf")
                    }
                
                ChatTabView()
                    .tag(2)
                    .tabItem {
                        Label("Chat", systemImage: "quote.bubble")
                    }
                
                SettingsTabView()
                    .tag(3)
                    .tabItem {
                        Label("Me", systemImage: "brain.filled.head.profile")
                    }
            }
            .accentColor(AppColors.primary)
            .onChange(of: selectedTab) { _ in
                // Trigger haptic feedback when switching tabs
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            .onAppear {
                // Customize tab bar appearance for even spacing
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                let bgColor = AppColors.background(themeManager.colorScheme)
                appearance.backgroundColor = UIColor(bgColor)
                
                // Configure normal state
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor.gray,
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                
                // Configure selected state
                let primaryColor = UIColor(red: 199/255.0, green: 0/255.0, blue: 43/255.0, alpha: 1.0) // #C7002B
                appearance.stackedLayoutAppearance.selected.iconColor = primaryColor
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: primaryColor,
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                
                // Apply to all tab bars
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            }
            
            // Floating Analyse Button (hidden on Chat tab)
            if selectedTab != 2 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            showAnalyseModal = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(Color(hex: "#C7002B"))
                                        .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                                )
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 70) // Position above tab bar
                    }
                }
            }
        }
        .sheet(isPresented: $showAnalyseModal) {
            AnalyseModalView(isPresented: $showAnalyseModal)
        }
    }
}

// MARK: - Home Tab View
struct HomeTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var userData = UserDataViewModel.shared
    @State private var showInfoModal: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        AppColors.gradientStart(themeManager.colorScheme),
                        AppColors.gradientEnd(themeManager.colorScheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 40) {
                    
                    // Health Score Section
                    VStack(spacing: 12) {
                        // Circular progress indicator
                        ZStack {
                            // Background circle (light gray, partial - cut off at bottom)
                            Circle()
                                .trim(from: 0.125, to: 0.875) // C-shape: gap at bottom
                                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(90)) // Rotate so gap is at bottom
                            
                            // Progress fill (adaptive color, partial - cut off at bottom) - animated
                            Circle()
                                .trim(from: 0.125, to: 0.125 + (userData.animatedProgress * 0.75)) // Fill based on animated progress
                                .stroke(AppColors.text(themeManager.colorScheme), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 280, height: 280)
                                .rotationEffect(.degrees(90)) // Rotate so gap is at bottom
                                .animation(.easeInOut(duration: 1.5), value: userData.animatedProgress)
                            
                            // Center score display
                            if userData.isLoadingHealthScore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.text(themeManager.colorScheme)))
                            } else if let error = userData.healthScoreError {
                                VStack(spacing: 4) {
                                    Text("Error")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    Text(error)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                            } else {
                                VStack(spacing: 4) {
                                    Text(String(format: "%.1f", userData.healthScore))
                                        .font(.system(size: 72, weight: .bold))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    // "your health score" with info button
                                    HStack(spacing: 6) {
                                        Text("your health score")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        
                                        Button(action: {
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                            impactFeedback.impactOccurred()
                                            showInfoModal = true
                                        }) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: 300, height: 300)
                        
                        // Your Trends Button with Icon
                        HStack(spacing: 12) {
                            NavigationLink(destination: ComingSoonView()) {
                                Text("Your trends")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.background(themeManager.colorScheme))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(AppColors.text(themeManager.colorScheme))
                                    .cornerRadius(25) // Pill shape
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            })
                            
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                        .padding(.top, -8) // Bring it closer to the health score
                    }
                    .padding(.top, 20)
                    
                    // Top Biomarkers Section
                    if userData.hasAnalyses {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 0) {
                                Text("What Needs ")
                                    .font(.custom("ProductSans-Bold", size: 24))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                Text("Attention")
                                    .font(.custom("InstrumentSerif-Italic", size: 24))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                            }
                            .padding(.horizontal, 24)
                            
                            if !userData.topBiomarkers.isEmpty {
                                ForEach(userData.topBiomarkers) { biomarker in
                                    BiomarkerCard(biomarker: biomarker)
                                }
                            } else {
                                // All biomarkers are optimal
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.green)
                                    
                                    Text("All biomarkers are within optimal ranges")
                                        .font(.custom("ProductSans-Bold", size: 18))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("Great job! Your blood test results look healthy.")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            }
            .refreshable {
                await userData.refreshHealthScore()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Do nothing
                    }) {
                        if let name = userData.userName {
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        } else {
                            Text("User")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                    }
                }
            }
        }
        .onAppear {
            // Data is loaded centrally, no need to reload here
        }
        .sheet(isPresented: $showInfoModal) {
            HealthScoreInfoModal(isPresented: $showInfoModal)
        }
    }
}

// MARK: - History Tab View
struct HistoryTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var userData = UserDataViewModel.shared
    @State private var selectedAnalysis: Analysis? = nil
    @State private var showDetail: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                if userData.isLoadingAnalyses {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                } else if let error = userData.analysesError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.yellow)
                        Text("Failed to load analyses")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Text(error)
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else if userData.analyses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        Text("No analyses yet")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Text("Upload a lab report to see your history")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(userData.analyses, id: \.id) { analysis in
                                Button(action: {
                                    selectedAnalysis = analysis
                                    showDetail = true
                                }) {
                                    GeometryReader { geometry in
                                        VStack(alignment: .leading, spacing: 0) {
                                            // Top section with icon
                                            HStack {
                                                Spacer()
                                                Image(systemName: "arrow.up.forward.app")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                            }
                                            .padding(12)
                                            
                                            Spacer()
                                            
                                            // Bottom section with info
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(listTitle(for: analysis))
                                                    .font(.custom("ProductSans-Bold", size: 16))
                                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                                    .lineLimit(2)

                                                Text(listSubtitle(for: analysis))
                                                    .font(.custom("ProductSans-Regular", size: 13))
                                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                    .lineLimit(1)
                                                
                                                Text(formattedDate(analysis.created_at))
                                                    .font(.custom("ProductSans-Regular", size: 11))
                                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                                    .lineLimit(1)
                                            }
                                            .padding(12)
                                        }
                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                        .background(AppColors.surface(themeManager.colorScheme))
                                        .cornerRadius(16)
                                        .shadow(color: Color.black.opacity(themeManager.colorScheme == .light ? 0.05 : 0.0), radius: 2, x: 0, y: 1)
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await userData.refreshAnalyses()
                    }
                }
            }
            .navigationBarTitle("History", displayMode: .inline)
            .sheet(isPresented: $showDetail) {
                if let analysis = selectedAnalysis {
                    AnalysisDetailView(analysis: analysis)
                        .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Helpers
    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: iso) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            return "\(dateString) at \(timeString)"
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeString = timeFormatter.string(from: date)
            
            return "\(dateString) at \(timeString)"
        }
        
        return iso
    }

    private func listTitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData(), let name = parsed.patientInfo?.name, !name.isEmpty {
            return name
        }
        // fallback to ID short
        return "Analysis \(analysis.id.prefix(8))"
    }

    private func listSubtitle(for analysis: Analysis) -> String {
        if let parsed = analysis.getParsedData() {
            let count = parsed.testResults.count
            return "\(count) markers · Report"
        }
        return "Lab report"
    }
}

// MARK: - Analysis Detail View
struct AnalysisDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let analysis: Analysis

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Report")
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        Spacer()
                        Text(formattedDate(analysis.created_at))
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }

                    if let parsed = analysis.getParsedData() {
                        if let patient = parsed.patientInfo {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Patient")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                if let name = patient.name { Text(name).foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                                if let age = patient.age { Text("Age: \(age)").foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                                if let sex = patient.sex { Text("Sex: \(sex)").foregroundColor(AppColors.textSecondary(themeManager.colorScheme)) }
                            }
                            .padding()
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            ForEach(parsed.testResults, id: \ .marker) { result in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.marker)
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        Text(result.referenceRange)
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing) {
                                        Text(result.value + " " + result.unit)
                                            .font(.custom("ProductSans-Bold", size: 14))
                                            .foregroundColor(AppColors.primary)
                                        Text(result.status)
                                            .font(.custom("ProductSans-Regular", size: 12))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }
                                }
                                .padding(12)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(10)
                            }
                        }
                    } else {
                        Text("Unable to parse report details")
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { }
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .background(AppColors.background(themeManager.colorScheme).ignoresSafeArea())
        }
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: date)
        }
        return iso
    }
}

// MARK: - Chat Tab View
struct ChatTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var userData = UserDataViewModel.shared
    @State private var messageText: String = ""
    @State private var userId: String? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var selectedDocumentURL: URL? = nil
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var showAttachmentActionSheet: Bool = false
    @State private var scrollProxyId = UUID()
    @State private var isTyping: Bool = false
    @State private var isUploading: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    HStack {
                        Spacer()
                    }
                    Text("Chat")
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(AppColors.background(themeManager.colorScheme))

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if userData.isLoadingChat {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                    .padding(.top, 40)
                            } else if userData.chatMessages.isEmpty {
                                VStack(spacing: 8) {
                                    Text("Hello \(userData.userName ?? "")")
                                        .font(.custom("ProductSans-Bold", size: 28))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    Text("How may I assist you?")
                                        .font(.custom("ProductSans-Regular", size: 16))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .padding(.top, 40)
                            } else {
                                ForEach(userData.chatMessages) { msg in
                                    MessageRow(message: msg)
                                        .id(msg.id)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                if isTyping {
                                    TypingIndicatorView()
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8, blendDuration: 0), value: userData.chatMessages.count)
                        .onChange(of: userData.chatMessages.count) { _ in
                            // Scroll to bottom when new messages arrive
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                                if let last = userData.chatMessages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            })
                        }
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping on chat messages
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }

                // Selected file preview
                if let image = selectedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)

                        Text("Image ready to send")
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Spacer()

                        Button(action: {
                            selectedImage = nil
                        }) {
                            Text("×")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface(themeManager.colorScheme))
                } else if let doc = selectedDocumentURL {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(AppColors.primary)
                            .frame(width: 40, height: 40)

                        Text(doc.lastPathComponent)
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineLimit(1)

                        Spacer()

                        Button(action: {
                            selectedDocumentURL = nil
                        }) {
                            Text("×")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface(themeManager.colorScheme))
                }

                // Input bar
                HStack(spacing: 12) {
                    // Attachment button: circular and same height as input
                    Button(action: {
                        showAttachmentActionSheet = true
                    }) {
                        Image(systemName: "paperclip.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .actionSheet(isPresented: $showAttachmentActionSheet) {
                        ActionSheet(title: Text("Add attachment"), buttons: [
                            .default(Text("Photo")) { showImagePicker = true },
                            .default(Text("File (PDF)")) { showDocumentPicker = true },
                            .cancel()
                        ])
                    }

                    // Rounded input (pill shaped)
                    TextField("Ask anything", text: $messageText, onCommit: sendMessage)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .clipShape(Capsule())
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .overlay(
                            // optional placeholder color alignment
                            EmptyView()
                        )
                        .frame(maxWidth: .infinity)

                    // Send button: same height as input
                    Button(action: sendMessage) {
                        if isUploading || isTyping {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                .frame(width: 24, height: 24)
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                        }
                    }
                    .disabled((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil && selectedDocumentURL == nil) || isUploading || isTyping)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.background(themeManager.colorScheme))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let img = image {
                        self.selectedImage = img
                    }
                    showImagePicker = false
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    if let u = url {
                        self.selectedDocumentURL = u
                    }
                    showDocumentPicker = false
                }
            }
            .onAppear {
                Task {
                    await initializeChat()
                }
            }
        }
    }

    // MARK: - Actions
    private func initializeChat() async {
        do {
            let uid = try await AuthService.shared.getCurrentUserId()
            userId = uid
        } catch {
            print("Error getting user ID: \(error)")
        }
    }

    private func sendMessage() {
        Task {
            guard let uid = userId else { return }
            let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Prepare optimistic local user message
            let tempId = Int(Date().timeIntervalSince1970 * 1000)
            var tempContent = userMessage
            var messageType = "text"
            var fileName: String? = nil

            if let img = selectedImage {
                messageType = "image"
                fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                tempContent = "[Shared an image: \(fileName!)] \(userMessage)"
            } else if let doc = selectedDocumentURL {
                messageType = "pdf"
                fileName = doc.lastPathComponent
                tempContent = "[Shared a PDF: \(fileName!)] \(userMessage)"
            }

            let tempMsg = ChatMessageDTO(id: tempId, role: "user", content: tempContent, message_type: messageType, file_name: fileName, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))

            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    userData.addChatMessage(tempMsg)
                }
                self.messageText = ""
                self.isUploading = (self.selectedImage != nil || self.selectedDocumentURL != nil)
                self.isTyping = true
            }

            do {
                if let img = selectedImage {
                    // write image to temp file
                    let data = img.jpegData(compressionQuality: 0.8) ?? Data()
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName ?? "upload.jpg")
                    try data.write(to: tmpURL)

                    let result = try await ChatService.shared.sendChatFile(userId: uid, fileUrl: tmpURL, fileName: fileName ?? "image.jpg", mimeType: "image/jpeg", message: userMessage.isEmpty ? nil : userMessage)

                    if let assistant = result.response {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: assistant, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                userData.addChatMessage(assistantMsg)
                            }
                        }
                    }
                } else if let doc = selectedDocumentURL {
                    let mime = "application/pdf"
                    let result = try await ChatService.shared.sendChatFile(userId: uid, fileUrl: doc, fileName: doc.lastPathComponent, mimeType: mime, message: userMessage.isEmpty ? nil : userMessage)
                    if let assistant = result.response {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: assistant, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                userData.addChatMessage(assistantMsg)
                            }
                        }
                    }
                } else {
                    // text message
                    let response = try await ChatService.shared.sendChatMessage(userId: uid, message: userMessage)
                    if !response.isEmpty {
                        let assistantMsg = ChatMessageDTO(id: Int(Date().timeIntervalSince1970 * 1000) + 1, role: "assistant", content: response, message_type: "text", file_name: nil, file_size: nil, created_at: ISO8601DateFormatter().string(from: Date()))
                        await MainActor.run {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                userData.addChatMessage(assistantMsg)
                            }
                        }
                    }
                }
            } catch {
                print("Error sending message: \(error)")
                // Optionally show error UI
            }

            await MainActor.run {
                self.selectedImage = nil
                self.selectedDocumentURL = nil
                self.isUploading = false
                self.isTyping = false
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func MessageRow(message: ChatMessageDTO) -> some View {
        HStack {
            if message.role == "assistant" {
                // assistant flush left
                VStack(alignment: .leading, spacing: 6) {
                    if message.message_type != "text", let name = message.file_name {
                        HStack(spacing: 8) {
                            Image(systemName: message.message_type == "image" ? "photo" : "doc.richtext")
                                .foregroundColor(AppColors.primary)
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        .padding(10)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(12)
                        .transition(.scale)
                    }

                    if !message.content.isEmpty {
                        if isLaTeX(message.content) {
                            LaTeXView(latex: message.content)
                                .frame(minHeight: 40)
                                .padding(8)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .cornerRadius(12)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        } else {
                            FormattedTextView(message.content, textColor: AppColors.text(themeManager.colorScheme), fontSize: 16)
                                .padding(12)
                                .background(AppColors.surface(themeManager.colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 80)

                Spacer(minLength: 8)
            } else {
                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if message.message_type != "text", let name = message.file_name {
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(Color.white)
                            Image(systemName: message.message_type == "image" ? "photo" : "doc.richtext")
                                .foregroundColor(Color.white.opacity(0.9))
                        }
                        .padding(10)
                        .background(AppColors.primary.opacity(0.95))
                        .cornerRadius(12)
                        .transition(.scale)
                    }

                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(Color.white)
                            .padding(12)
                            .background(AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.leading, 80)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: UUID())
    }

        private func TypingIndicatorView() -> some View {
        HStack {
            AnimatedTypingDots()
                .padding(10)
                .background(AppColors.surface(themeManager.colorScheme))
                .cornerRadius(16)
            
            Spacer()
        }
        .padding(.leading, 8)
    }
}

// MARK: - Animated Typing Dots
struct AnimatedTypingDots: View {
    @State private var animationPhase: Int = 0
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 0 ? 1.0 : 0.4)
                .scaleEffect(animationPhase == 0 ? 1.2 : 1.0)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 1 ? 1.0 : 0.4)
                .scaleEffect(animationPhase == 1 ? 1.2 : 1.0)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 2 ? 1.0 : 0.4)
                .scaleEffect(animationPhase == 2 ? 1.2 : 1.0)
        }
        .animation(.easeInOut(duration: 0.3), value: animationPhase)
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType { case camera, photoLibrary }
    var sourceType: SourceType = .photoLibrary
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = (sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera)) ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.completion(image)
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker Wrapper
struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.completion(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.completion(nil)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showEditInformation = false
    @State private var showNotificationSettings = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountFinalAlert = false
    @State private var isRefreshing = false
    @State private var hasActiveSubscription = false
    @State private var showAppearancePicker = false
    @State private var creditBalance: Int = 0
    @State private var showCreditsModal = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Title with Gear Icon
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            Text("Settings")
                                .font(.custom("ProductSans-Bold", size: 32))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 32)

                        // Settings Items
                        VStack(spacing: 0) {
                            // Credit Balance Card
                            CreditBalanceCard(credits: creditBalance) {
                                showCreditsModal = true
                            }
                            .padding(.bottom, 16)
                            
                            SettingsItem(icon: "sun.max.fill", text: "Appearance") {
                                showAppearancePicker = true
                            }

                            SettingsItem(icon: "bell.fill", text: "Notifications") {
                                showNotificationSettings = true
                            }

                            SettingsItem(icon: "person.fill", text: "Edit information") {
                                showEditInformation = true
                            }

                            SettingsItem(icon: "arrow.right.square.fill", text: "Sign Out") {
                                showSignOutAlert = true
                            }

                            SettingsItem(icon: "trash.fill", text: "Delete Account") {
                                showDeleteAccountAlert = true
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                            .frame(height: 40)
                    }
                }
                .refreshable {
                    await refreshSettings()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEditInformation) {
            EditInformationView(isPresented: $showEditInformation)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView(isPresented: $showNotificationSettings)
        }
        .sheet(isPresented: $showCreditsModal) {
            CreditsModalView(isPresented: $showCreditsModal) {
                // Refresh credits after purchase
                Task { await refreshSettings() }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                handleSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteAccountFinalAlert = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data including analyses and chat history will be permanently deleted.")
        }
        .alert("Final Confirmation", isPresented: $showDeleteAccountFinalAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, Delete My Account", role: .destructive) {
                handleDeleteAccount()
            }
        } message: {
            Text("This is your last chance. Your account and all data will be permanently deleted. Are you absolutely sure?")
        }
        .onAppear {
            Task { await refreshSettings() }
        }
        .confirmationDialog("Choose Appearance", isPresented: $showAppearancePicker, titleVisibility: .visible) {
            Button("Light Mode") { themeManager.setColorScheme(.light) }
            Button("Dark Mode") { themeManager.setColorScheme(.dark) }
            Button("System") { themeManager.setColorScheme(nil) }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func refreshSettings() async {
        isRefreshing = true
        
        // Fetch credit balance
        do {
            let credits = try await CreditService.shared.getCredits()
            await MainActor.run {
                creditBalance = credits
            }
        } catch {
            print("Error fetching credits: \(error.localizedDescription)")
        }
        
        isRefreshing = false
    }

    private func handleSignOut() {
        Task {
            do {
                guard let client = SupabaseManager.shared.getClient() else { return }
                try await client.auth.signOut()
                await MainActor.run {
                    // Clear all user data
                    UserDataViewModel.shared.clearAllData()
                    appState.isAuthenticated = false
                }
            } catch {
                await MainActor.run { print("Error signing out: \(error.localizedDescription)") }
            }
        }
    }

    private func handleDeleteAccount() {
        Task {
            do {
                let userId = try await AuthService.shared.getCurrentUserId()
                guard let apiURLString = SupabaseManager.shared.getAPIURL(),
                      let apiURL = URL(string: "\(apiURLString)/api/analyses/delete-account/") else {
                    throw NSError(domain: "Settings", code: 1, userInfo: [NSLocalizedDescriptionKey: "API URL not configured"])
                }

                let accessToken = try await AuthService.shared.getAccessToken()

                var request = URLRequest(url: apiURL)
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "Settings", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to delete account data"])
                }

                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "Settings", code: 3, userInfo: [NSLocalizedDescriptionKey: "Supabase client not configured"])
                }

                try await client.auth.signOut()

                await MainActor.run {
                    appState.isAuthenticated = false
                    print("Account deleted successfully")
                }
            } catch {
                await MainActor.run { print("Error deleting account: \(error.localizedDescription)") }
            }
        }
    }
}

// MARK: - Analyse Modal View
struct AnalyseModalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var selectedFile: URL? = nil
    @State private var selectedFileName: String? = nil
    @State private var selectedFileType: String? = nil
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var showDocumentPicker = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertTitle = ""
    @State private var permissionAlertMessage = ""
    @State private var isUploading = false
    @State private var showCreditsModal = false
    @State private var isCheckingCredits = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)

                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Upload a file to analyse")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        if let fileName = selectedFileName {
                            Text("Selected: \(fileName)")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(AppColors.primary)
                                .padding(.top, 4)
                        }

                        HStack(spacing: 16) {
                            uploadOption(icon: "photo", title: "Photo")
                                .onTapGesture {
                                    requestPhotoLibraryPermission()
                                }
                            uploadOption(icon: "camera", title: "Camera")
                                .onTapGesture {
                                    requestCameraPermission()
                                }
                            uploadOption(icon: "doc.fill", title: "PDF")
                                .onTapGesture {
                                    showDocumentPicker = true
                                }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue button styled like Get Started
                Button(action: {
                    handleContinue()
                }) {
                    HStack {
                        Spacer()
                        if isUploading || isCheckingCredits {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .font(.custom("ProductSans-Bold", size: 16))
                                .foregroundColor(Color.white)
                        }
                        Spacer()
                    }
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(selectedFile != nil ? AppColors.primary : Color.gray.opacity(0.5))
                    )
                    .shadow(color: selectedFile != nil ? Color(hex: "#BB3E4F").opacity(0.6) : Color.clear, radius: 16, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .disabled(selectedFile == nil || isUploading || isCheckingCredits)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 350)
            .background(AppColors.modalBackground(themeManager.colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Close")
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: .photoLibrary) { url, fileName in
                    if let url = url {
                        selectedFile = url
                        selectedFileName = fileName
                        selectedFileType = "image"
                    }
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                ImagePickerView(sourceType: .camera) { url, fileName in
                    if let url = url {
                        selectedFile = url
                        selectedFileName = fileName
                        selectedFileType = "image"
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url, fileName in
                    if let url = url {
                        selectedFile = url
                        selectedFileName = fileName
                        selectedFileType = "pdf"
                    }
                }
            }
            .alert(permissionAlertTitle, isPresented: $showPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            } message: {
                Text(permissionAlertMessage)
            }
            .sheet(isPresented: $showCreditsModal) {
                CreditsModalView(isPresented: $showCreditsModal) {
                    // On purchase complete, retry the upload
                    if let file = selectedFile {
                        performUpload(file: file)
                    }
                }
            }
        }
        .toolbarBackground(AppColors.modalBackground(themeManager.colorScheme), for: .navigationBar)
        .toolbarColorScheme(themeManager.colorScheme == .dark ? .dark : .light, for: .navigationBar)
        .background(AppColors.modalBackground(themeManager.colorScheme).ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func uploadOption(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(AppColors.inputBackground(themeManager.colorScheme))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                )

            Text(title)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
        }
    }
    
    private func requestPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            showImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showImagePicker = true
                    } else {
                        showPermissionDeniedAlert(for: "Photo Library")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Photo Library")
        @unknown default:
            showPermissionDeniedAlert(for: "Photo Library")
        }
    }
    
    private func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            showCameraPicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraPicker = true
                    } else {
                        showPermissionDeniedAlert(for: "Camera")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Camera")
        @unknown default:
            showPermissionDeniedAlert(for: "Camera")
        }
    }
    
    private func showPermissionDeniedAlert(for feature: String) {
        permissionAlertTitle = "\(feature) Access Required"
        permissionAlertMessage = "Please enable \(feature) access in Settings to upload files."
        showPermissionAlert = true
    }
    
    private func handleContinue() {
        guard let file = selectedFile else { return }
        
        isCheckingCredits = true
        
        Task {
            do {
                // Check if user has credits
                let hasCredit = try await CreditService.shared.deductCredit()
                
                await MainActor.run {
                    isCheckingCredits = false
                    
                    if hasCredit {
                        // User has credits, proceed with upload
                        performUpload(file: file)
                    } else {
                        // Insufficient credits, show purchase modal
                        showCreditsModal = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingCredits = false
                    // On error, show credits modal as fallback
                    showCreditsModal = true
                }
            }
        }
    }
    
    private func performUpload(file: URL) {
        isUploading = true
        
        // TODO: Implement actual file upload to backend
        // For now, just simulate a delay and close
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isUploading = false
            isPresented = false
            // In a real implementation, you would:
            // 1. Upload file to backend API
            // 2. Navigate to analysis results
            print("Would upload file: \(file.absoluteString)")
        }
    }
}

// MARK: - Image Picker View
struct ImagePickerView: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary
    }
    
    let sourceType: SourceType
    let completion: (URL?, String?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType == .camera ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (URL?, String?) -> Void
        
        init(completion: @escaping (URL?, String?) -> Void) {
            self.completion = completion
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            if let image = info[.originalImage] as? UIImage {
                // Save to temporary directory
                let fileName = "captured_image_\(Date().timeIntervalSince1970).jpg"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    try? imageData.write(to: tempURL)
                    completion(tempURL, fileName)
                } else {
                    completion(nil, nil)
                }
            } else {
                completion(nil, nil)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            completion(nil, nil)
        }
    }
}

// MARK: - Document Picker View
struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: (URL?, String?) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (URL?, String?) -> Void
        
        init(completion: @escaping (URL?, String?) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                completion(nil, nil)
                return
            }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                completion(nil, nil)
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copy to temporary directory
            let fileName = url.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                completion(tempURL, fileName)
            } catch {
                print("Error copying file: \(error)")
                completion(nil, nil)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil, nil)
        }
    }
}

// MARK: - Health Score Info Modal
struct HealthScoreInfoModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How the Health Score is calculated")
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("Summary")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("We analyse your uploaded blood tests and compute a score between 0 and 10 that reflects overall blood health. The score is a weighted combination of three components:")
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primary)
                            VStack(alignment: .leading) {
                                Text("Core Risk Biomarkers — 45%")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                Text("Key biomarkers (e.g. Hemoglobin, RBC, WBC, Platelets, ESR, Neutrophils, Lymphocytes, MCH/MCHC/MCV/RDW) are scored against optimal ranges. Each marker contributes a weighted value based on how far it is from the optimal range.")
                                    .font(.custom("ProductSans-Regular", size: 13))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                        }

                        HStack(alignment: .top) {
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primary)
                            VStack(alignment: .leading) {
                                Text("Optimal vs Normal — 17.5%")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                Text("A broader check across all reported markers rewards values listed as 'normal' and gives partial credit for borderline values.")
                                    .font(.custom("ProductSans-Regular", size: 13))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                        }

                        HStack(alignment: .top) {
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primary)
                            VStack(alignment: .leading) {
                                Text("Data Completeness — 5%")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                Text("We reward reports that include a full set of expected markers (e.g. a complete CBC). Missing markers reduce the completeness score.")
                                    .font(.custom("ProductSans-Regular", size: 13))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                        }
                    }

                    Divider()

                    Text("Calculation details")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("1) For each analysis we compute:")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("   • coreRiskScore (0–1) — weighted sum of key biomarkers")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("   • optimalRangeScore (0–1) — fraction of markers marked ‘normal’ (partial credit for borderline)")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("   • completenessScore (0–1) — how complete the report is relative to expected markers")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("2) Combine with weights:")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("   finalScore = coreRiskScore * 0.45 + optimalRangeScore * 0.175 + completenessScore * 0.05")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Text("3) Normalize to 0–10 scale and clamp values.")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }

                    Divider()

                    Text("Key markers and optimal ranges (examples)")
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    // Show a concise list of markers and ranges used in calculation
                    VStack(alignment: .leading, spacing: 8) {
                        Group {
                            Text("Hemoglobin (Hb): 13.0 - 17.0")
                            Text("Total RBC count: 4.5 - 5.5")
                            Text("Packed Cell Volume (PCV): 40.0 - 50.0")
                            Text("Total WBC count: 4000 - 11000")
                            Text("Platelet Count: 150000 - 410000")
                        }
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        Group {
                            Text("ESR: 0 - 15")
                            Text("Neutrophils: 50 - 62")
                            Text("Lymphocytes: 20 - 40")
                            Text("MCH / MCHC / MCV / RDW: see ranges in code")
                        }
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }

                    Spacer().frame(height: 24)

                    Text("Notes")
                        .font(.custom("ProductSans-Bold", size: 14))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("- The score is an overall indicator and does not replace a clinician's interpretation. If any marker is flagged, consult your doctor.")
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .padding(16)
                .background(AppColors.background(themeManager.colorScheme))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Close")
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
            }
        }
    }
}

// MARK: - Biomarker Card
struct BiomarkerCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let biomarker: HealthScoreService.BiomarkerAttention

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(biomarker.name)
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                // Show concise reason and status instead of non-existent `detail` property
                Text(biomarker.reason)
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .lineLimit(2)

                Text(biomarker.status)
                    .font(.custom("ProductSans-Bold", size: 12))
                    .foregroundColor(AppColors.primary)
            }
            Spacer()
        }
        .padding()
        .background(AppColors.surface(themeManager.colorScheme))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
}

// MARK: - Credit Balance Card
struct CreditBalanceCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let credits: Int
    let onBuyCredits: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Credit icon and count
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(credits)")
                        .font(.custom("ProductSans-Bold", size: 24))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    Text("Credit\(credits == 1 ? "" : "s") Available")
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
            }
            
            Spacer()
            
            // Buy button
            Button(action: onBuyCredits) {
                Text("Buy More")
                    .font(.custom("ProductSans-Bold", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppColors.primary)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.inputBackground(themeManager.colorScheme))
        )
    }
}

// New: SettingsItem used by the Settings tab
struct SettingsItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.colorScheme == .dark ? Color.white : Color.black)
                    .frame(width: 28)

                Text(text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .padding(12)
            // Removed background and corner radius so items sit flat on the screen
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 6)
    }
}

// MARK: - Edit Information View
struct EditInformationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var biologicalSex: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var heightCm: String = ""
    @State private var weightKg: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoadingProfile: Bool = true
    @State private var isSavingProfile: Bool = false
    @State private var isSavingPassword: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showDatePicker: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text("Edit Information")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        
                        if isLoadingProfile {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            // Profile Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Profile")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                CustomTextField(label: "First name", text: $firstName, placeholder: "First name")
                                CustomTextField(label: "Last name", text: $lastName, placeholder: "Last name")
                                CustomTextField(label: "Email", text: $email, placeholder: "you@example.com", keyboardType: .emailAddress)
                                
                                // Biological Sex
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Biological sex")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    
                                    Picker("", selection: $biologicalSex) {
                                        Text("Male").tag("male")
                                        Text("Female").tag("female")
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .disabled(isSavingProfile)
                                }
                                
                                // Date of Birth
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date of birth")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    
                                    Button(action: { showDatePicker.toggle() }) {
                                        HStack {
                                            Text(dateOfBirth, style: .date)
                                                .font(.custom("ProductSans-Regular", size: 16))
                                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                            Spacer()
                                            Image(systemName: "calendar")
                                                .foregroundColor(AppColors.primary)
                                        }
                                    }
                                    .disabled(isSavingProfile)
                                    
                                    Rectangle()
                                        .fill(AppColors.border(themeManager.colorScheme))
                                        .frame(height: 1)
                                }
                                
                                if showDatePicker {
                                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                        .datePickerStyle(WheelDatePickerStyle())
                                        .labelsHidden()
                                }
                                
                                CustomTextField(label: "Height (cm)", text: $heightCm, placeholder: "170", keyboardType: .decimalPad)
                                CustomTextField(label: "Weight (kg)", text: $weightKg, placeholder: "70", keyboardType: .decimalPad)
                                
                                Button(action: handleSaveProfile) {
                                    HStack {
                                        Spacer()
                                        if isSavingProfile {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Save profile")
                                                .font(.custom("ProductSans-Bold", size: 16))
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                    }
                                    .frame(height: 56)
                                    .background(AppColors.primary)
                                    .cornerRadius(28)
                                }
                                .disabled(isSavingProfile || isLoadingProfile)
                            }
                            .padding(24)
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                            
                            // Password Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Password")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                CustomTextField(label: "New password", text: $newPassword, placeholder: "Enter new password", isSecure: true)
                                CustomTextField(label: "Confirm new password", text: $confirmPassword, placeholder: "Confirm new password", isSecure: true)
                                
                                Button(action: handleChangePassword) {
                                    HStack {
                                        Spacer()
                                        if isSavingPassword {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Text("Change password")
                                                .font(.custom("ProductSans-Bold", size: 16))
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                    }
                                    .frame(height: 56)
                                    .background(AppColors.primary)
                                    .cornerRadius(28)
                                }
                                .disabled(isSavingPassword)
                            }
                            .padding(24)
                            .background(AppColors.surface(themeManager.colorScheme))
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Edit Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                Task { await loadProfile() }
            }
        }
    }
    
    private func loadProfile() async {
        isLoadingProfile = true
        
        do {
            guard let client = SupabaseManager.shared.getClient() else {
                throw NSError(domain: "EditInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
            }
            
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            // Fetch user profile from database
            struct UserProfile: Codable {
                let id: String
                let first_name: String?
                let last_name: String?
                let email: String?
                let biological_sex: String?
                let date_of_birth: String?
                let height_cm: Double?
                let weight_kg: Double?
            }
            
            let response: [UserProfile] = try await client.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = response.first {
                await MainActor.run {
                    firstName = profile.first_name ?? ""
                    lastName = profile.last_name ?? ""
                    email = profile.email ?? session.user.email ?? ""
                    biologicalSex = profile.biological_sex ?? "male"
                    
                    if let dobString = profile.date_of_birth {
                        let formatter = ISO8601DateFormatter()
                        if let date = formatter.date(from: dobString) {
                            dateOfBirth = date
                        }
                    }
                    
                    if let height = profile.height_cm {
                        heightCm = String(format: "%.0f", height)
                    }
                    
                    if let weight = profile.weight_kg {
                        weightKg = String(format: "%.1f", weight)
                    }
                }
            } else {
                await MainActor.run {
                    email = session.user.email ?? ""
                }
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        
        await MainActor.run {
            isLoadingProfile = false
        }
    }
    
    private func handleSaveProfile() {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
              !lastName.trimmingCharacters(in: .whitespaces).isEmpty,
              !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "Validation"
            alertMessage = "First name, last name, and email are required."
            showAlert = true
            return
        }
        
        guard let height = Double(heightCm), height > 0,
              let weight = Double(weightKg), weight > 0 else {
            alertTitle = "Validation"
            alertMessage = "Please enter valid height and weight."
            showAlert = true
            return
        }
        
        Task {
            isSavingProfile = true
            
            do {
                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "EditInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
                }
                
                let session = try await client.auth.session
                let userId = session.user.id.uuidString
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                struct UpdateProfile: Codable {
                    let first_name: String
                    let last_name: String
                    let email: String
                    let biological_sex: String
                    let date_of_birth: String
                    let height_cm: Double
                    let weight_kg: Double
                    let updated_at: String
                }
                
                let updateData = UpdateProfile(
                    first_name: firstName.trimmingCharacters(in: .whitespaces),
                    last_name: lastName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    biological_sex: biologicalSex,
                    date_of_birth: isoFormatter.string(from: dateOfBirth),
                    height_cm: height,
                    weight_kg: weight,
                    updated_at: isoFormatter.string(from: Date())
                )
                
                try await client.database
                    .from("users")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()
                
                // Update auth email if changed
                if email != session.user.email {
                    try await client.auth.update(user: UserAttributes(email: email))
                }
                
                await MainActor.run {
                    alertTitle = "Success"
                    alertMessage = "Profile updated successfully."
                    showAlert = true
                    isSavingProfile = false
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isSavingProfile = false
                }
            }
        }
    }
    
    private func handleChangePassword() {
        guard !newPassword.trimmingCharacters(in: .whitespaces).isEmpty,
              !confirmPassword.trimmingCharacters(in: .whitespaces).isEmpty else {
            alertTitle = "Validation"
            alertMessage = "Please enter and confirm your new password."
            showAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            alertTitle = "Validation"
            alertMessage = "Passwords do not match."
            showAlert = true
            return
        }
        
        guard newPassword.count >= 8 else {
            alertTitle = "Validation"
            alertMessage = "Password must be at least 8 characters."
            showAlert = true
            return
        }
        
        Task {
            isSavingPassword = true
            
            do {
                guard let client = SupabaseManager.shared.getClient() else {
                    throw NSError(domain: "EditInfo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
                }
                
                try await client.auth.update(user: UserAttributes(password: newPassword))
                
                await MainActor.run {
                    alertTitle = "Success"
                    alertMessage = "Password updated successfully."
                    showAlert = true
                    newPassword = ""
                    confirmPassword = ""
                    isSavingPassword = false
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isSavingPassword = false
                }
            }
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var notificationsEnabled: Bool = false
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text("Notifications")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        
                        Text("Manage your notification preferences")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                        
                        // Settings Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Notifications")
                                        .font(.custom("ProductSans-Bold", size: 16))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("Receive push notifications for important updates")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $notificationsEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                                    .disabled(isLoading)
                            }
                        }
                        .padding(24)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Info text
                        Text("You can manage notification permissions in your device settings.")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .padding(.horizontal, 24)
                        
                        // Button to open Settings
                        Button(action: openAppSettings) {
                            HStack {
                                Spacer()
                                Text("Open Settings")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .frame(height: 56)
                            .background(AppColors.primary)
                            .cornerRadius(28)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                checkNotificationStatus()
            }
            .onChange(of: notificationsEnabled) { newValue in
                handleToggleNotifications(enabled: newValue)
            }
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func handleToggleNotifications(enabled: Bool) {
        if enabled {
            // Request notification permission
            isLoading = true
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        notificationsEnabled = false
                        alertTitle = "Error"
                        alertMessage = error.localizedDescription
                        showAlert = true
                    } else if !granted {
                        notificationsEnabled = false
                        alertTitle = "Permission Denied"
                        alertMessage = "Please enable notifications in Settings to receive important updates."
                        showAlert = true
                    } else {
                        notificationsEnabled = true
                        // Register for remote notifications
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            }
        } else {
            // User disabled - show message that they need to disable in Settings
            alertTitle = "Notifications"
            alertMessage = "To disable notifications, please go to Settings > Notifications > Lumo and turn off notifications."
            showAlert = true
            // Revert the toggle
            notificationsEnabled = true
        }
    }
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            if (isSecure) {
                SecureField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
            
            Rectangle()
                .fill(AppColors.border(themeManager.colorScheme))
                .frame(height: 1)
        }
    }
}

// MARK: - LaTeX Renderer
struct LaTeXView: UIViewRepresentable {
    let latex: String
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Sanitize content minimally for HTML embedding
        let safeContent = latex
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "</", with: "&lt;/")

        // Use a unique placeholder token to avoid Swift string interpolation issues
        let placeholder = "@@LATEX@@"

        // Build a simple MathJax page and embed the sanitized LaTeX by replacing the placeholder
        let wrapped = """
        <!doctype html>
        <html>
        <head>
          <meta name='viewport' content='width=device-width, initial-scale=1'>
          <style>body{font-family:-apple-system; background:transparent; color:#000; margin:0; padding:6px 8px;}</style>
          <script>window.MathJax = { tex: {inlineMath: [['$$','$$'], ['\\(','\\)']]}, svg: { fontCache: 'global' } };</script>
          <script src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js'></script>
        </head>
        <body>
          <div>$$@@LATEX@@$$</div>
        </body>
        </html>
        """.replacingOccurrences(of: placeholder, with: safeContent)

        webView.loadHTMLString(wrapped, baseURL: nil)
    }
}

// Helper to detect LaTeX-like content
private func isLaTeX(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains("$$") { return true }
    if trimmed.contains("\\begin{") { return true }
    if trimmed.contains("\\(") || trimmed.contains("\\[") { return true }
    // simple heuristic: many backslashes indicate LaTeX
    let backslashCount = trimmed.filter { $0 == "\\" }.count
    if backslashCount >= 3 { return true }
    return false
}

// MARK: - Formatted Text View (Markdown Support)
struct FormattedTextView: View {
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    
    init(_ text: String, textColor: Color = .primary, fontSize: CGFloat = 16) {
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text(parseMarkdown(text))
            .font(.custom("ProductSans-Regular", size: fontSize))
            .foregroundColor(textColor)
    }
    
    private func parseMarkdown(_ input: String) -> AttributedString {
        var result = AttributedString()
        let lines = input.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            let parsedLine = parseLine(line)
            result.append(parsedLine)
            
            if lineIndex < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    private func parseLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        
        // Handle bullet points
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        var prefix = AttributedString()
        var contentLine = line
        
        if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") {
            prefix = AttributedString("• ")
            if let range = line.range(of: trimmedLine.hasPrefix("- ") ? "- " : "• ") {
                let leadingSpaces = String(line[..<range.lowerBound])
                contentLine = leadingSpaces + String(line[range.upperBound...])
            }
        } else if let match = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let numberPart = String(trimmedLine[match])
            prefix = AttributedString(numberPart)
            if let lineMatch = line.range(of: numberPart) {
                let leadingSpaces = String(line[..<lineMatch.lowerBound])
                contentLine = leadingSpaces + String(line[lineMatch.upperBound...])
            }
        }
        
        result.append(prefix)
        result.append(parseInlineFormatting(contentLine))
        
        return result
    }
    
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var currentIndex = text.startIndex
        
        // Regex patterns for markdown
        let boldPattern = #"\*\*(.+?)\*\*"#
        let italicPattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        let boldItalicPattern = #"\*\*\*(.+?)\*\*\*"#
        
        // Find all matches and sort by position
        var matches: [(range: Range<String.Index>, text: String, style: TextStyle)] = []
        
        // Bold italic (must check first since it contains bold and italic patterns)
        if let regex = try? NSRegularExpression(pattern: boldItalicPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text),
                   let contentRange = Range(match.range(at: 1), in: text) {
                    matches.append((range, String(text[contentRange]), .boldItalic))
                }
            }
        }
        
        // Bold
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text),
                   let contentRange = Range(match.range(at: 1), in: text) {
                    // Check if this range overlaps with existing matches
                    let overlaps = matches.contains { existingMatch in
                        range.overlaps(existingMatch.range)
                    }
                    if !overlaps {
                        matches.append((range, String(text[contentRange]), .bold))
                    }
                }
            }
        }
        
        // Italic (single asterisks, not part of bold)
        if let regex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text),
                   let contentRange = Range(match.range(at: 1), in: text) {
                    // Check if this range overlaps with existing matches
                    let overlaps = matches.contains { existingMatch in
                        range.overlaps(existingMatch.range)
                    }
                    if !overlaps {
                        matches.append((range, String(text[contentRange]), .italic))
                    }
                }
            }
        }
        
        // Sort matches by start position
        matches.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // Build result
        for match in matches {
            // Add text before this match
            if currentIndex < match.range.lowerBound {
                var plainText = AttributedString(String(text[currentIndex..<match.range.lowerBound]))
                plainText.font = .custom("ProductSans-Regular", size: fontSize)
                result.append(plainText)
            }
            
            // Add styled text
            var styledText = AttributedString(match.text)
            switch match.style {
            case .bold:
                styledText.font = .custom("ProductSans-Bold", size: fontSize)
            case .italic:
                styledText.font = .custom("ProductSans-Regular", size: fontSize).italic()
            case .boldItalic:
                styledText.font = .custom("ProductSans-Bold", size: fontSize).italic()
            }
            result.append(styledText)
            
            currentIndex = match.range.upperBound
        }
        
        // Add remaining text
        if currentIndex < text.endIndex {
            var plainText = AttributedString(String(text[currentIndex...]))
            plainText.font = .custom("ProductSans-Regular", size: fontSize)
            result.append(plainText)
        }
        
        return result
    }
    
    private enum TextStyle {
        case bold
        case italic
        case boldItalic
    }
}

#Preview {
    HomeView()
}

