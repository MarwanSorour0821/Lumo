import SwiftUI
import SafariServices

/// A modal view that displays subscription options in BitePal-style layout
struct PaywallView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSafari = false
    @State private var checkoutURL: URL?
    @State private var showMorePlans = false
    
    var onSubscribeComplete: (() -> Void)?
    
    private let features: [(icon: String, title: String, freeIncluded: Bool)] = [
        ("waveform.path.ecg", "AI blood test analysis", false),
        ("chart.line.uptrend.xyaxis", "Health trends & insights", false),
        ("bell.badge", "Medication reminders", false),
        ("bubble.left.and.bubble.right", "Chat with AI about results", false),
        ("lightbulb", "Personalized recommendations", false),
        ("clock.arrow.circlepath", "Unlimited history access", false),
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            headerSection
                            
                            // Plans
                            plansSection
                            
                            // Features comparison
                            featuresSection
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                    
                    // Bottom CTA
                    bottomCTA
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                            )
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text("Lumo")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text("Pro")
                            .font(.custom("ProductSans-Bold", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.primary)
                            )
                    }
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = checkoutURL {
                SafariView(url: url)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Achieve your health")
                .font(.custom("ProductSans-Bold", size: 28))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
            
            HStack(spacing: 8) {
                Text("goals")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                
                Text("4.2x")
                    .font(.custom("instrumentserif-italic", size: 32))
                    .foregroundColor(AppColors.primary)
                
                Text("faster")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }
    
    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(spacing: 12) {
            // Yearly Plan (Most Popular)
            PlanCard(
                plan: .yearly,
                isSelected: selectedPlan == .yearly,
                onSelect: { selectedPlan = .yearly }
            )
            
            // Show/Hide more plans
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showMorePlans.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showMorePlans ? "Hide plans" : "Show more plans")
                        .font(.custom("ProductSans-Medium", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    
                    Image(systemName: showMorePlans ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
            }
            
            // Monthly Plan (hidden by default)
            if showMorePlans {
                PlanCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    onSelect: { selectedPlan = .monthly }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            HStack {
                Text("What you get")
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                
                Spacer()
                
                Text("Free")
                    .font(.custom("ProductSans-Medium", size: 12))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .frame(width: 50)
                
                Text("Pro")
                    .font(.custom("ProductSans-Bold", size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.primary)
                    )
                    .frame(width: 60)
            }
            
            // Feature rows
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack {
                        Text(feature.title)
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Spacer()
                        
                        // Free column
                        if feature.freeIncluded {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.primary)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.5))
                        }
                        
                        Spacer()
                            .frame(width: 30)
                        
                        // Pro column
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.primary)
                        
                        Spacer()
                            .frame(width: 10)
                    }
                    .padding(.vertical, 12)
                    
                    if index < features.count - 1 {
                        Divider()
                            .background(AppColors.textSecondary(themeManager.colorScheme).opacity(0.2))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.inputBackground(themeManager.colorScheme))
            )
        }
    }
    
    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        VStack(spacing: 12) {
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(.red)
            }
            
            // Continue button
            Button(action: handleSubscribe) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black)
                )
            }
            .disabled(isLoading)
            
            // 3-day free trial note
            Text("Start your 3-day free trial")
                .font(.custom("ProductSans-Medium", size: 13))
                .foregroundColor(AppColors.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            AppColors.modalBackground(themeManager.colorScheme)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }
    
    // MARK: - Actions
    private func handleSubscribe() {
        isLoading = true
        errorMessage = nil
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let checkoutURLString = try await SubscriptionService.shared.createCheckoutSession(plan: selectedPlan)
                
                await MainActor.run {
                    isLoading = false
                    if let url = URL(string: checkoutURLString) {
                        checkoutURL = url
                        showSafari = true
                    } else {
                        errorMessage = "Invalid checkout URL"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        if url.scheme == "lumo" && url.host == "subscription-success" {
            showSafari = false
            isPresented = false
            
            // Clear subscription cache
            Task {
                await SubscriptionService.shared.clearCache()
            }
            
            onSubscribeComplete?()
        } else if url.scheme == "lumo" && url.host == "subscription-cancel" {
            showSafari = false
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Badge
                if let badge = plan.badge {
                    Text(badge)
                        .font(.custom("ProductSans-Bold", size: 11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(plan == .yearly ? AppColors.primary : Color.gray)
                        )
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.displayName)
                            .font(.custom("ProductSans-Bold", size: 20))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        if plan == .yearly {
                            HStack(spacing: 4) {
                                Text("$59.99")
                                    .font(.custom("ProductSans-Regular", size: 13))
                                    .strikethrough()
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                
                                Text("→")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                
                                Text("\(plan.price)/yr")
                                    .font(.custom("ProductSans-Medium", size: 13))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                            }
                        } else if let tagline = plan.tagline {
                            Text(tagline)
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(plan.pricePerMonth)
                            .font(.custom("ProductSans-Bold", size: 22))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text("per month")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    PaywallView(isPresented: .constant(true))
        .environmentObject(ThemeManager.shared)
}
