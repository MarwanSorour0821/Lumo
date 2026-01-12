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
    
    private let features: [(icon: String, title: String)] = [
        ("waveform.path.ecg", "Understand your blood test results in minutes"),
        ("chart.line.uptrend.xyaxis", "Spot health trends before they become problems"),
        ("bell.badge", "Never miss a medication again"),
        ("bubble.left.and.bubble.right", "Ask questions and get instant clarity"),
        ("lightbulb", "Get recommendations tailored to your body"),
        ("clock.arrow.circlepath", "Access your full health history anytime"),
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
                            
                            // Features list (Pro only)
                            featuresSection
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                    
                    // Bottom section: Plans + CTA
                    bottomSection
                }
            }
            .ignoresSafeArea(edges: .bottom)
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
            Text("Your Personal")
                .font(.custom("ProductSans-Bold", size: 28))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
            
            HStack(spacing: 8) {
                Text("Drug")
                    .font(.custom("instrumentserif-italic", size: 32))
                    .foregroundColor(AppColors.primary)
                
                Text("Cabinet")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you get")
                .font(.custom("ProductSans-Bold", size: 18))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
            
            // Feature list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 24)
                        
                        Text(feature.title)
                            .font(.custom("ProductSans-Regular", size: 15))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.inputBackground(themeManager.colorScheme))
            )
            
            // Trust signal
            HStack(spacing: 6) {
                Text("🔒")
                    .font(.system(size: 14))
                Text("Your health data is encrypted and never sold")
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
            
            // Optional trust signal
            Text("Used by 1000+ to better understand their health.")
                .font(.custom("ProductSans-Regular", size: 12))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }
    
    // MARK: - Bottom Section (Plans + CTA)
    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }
            
            // Subscription Plans (above Continue button)
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
            .padding(.horizontal, 24)
            
            // Continue button
            Button(action: handleSubscribe) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Try for $0.00")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(AppColors.primary)
                )
            }
            .disabled(isLoading)
            .padding(.horizontal, 24)
            
            // Microcopy under button
            Text("No payment today · Cancel anytime")
                .font(.custom("ProductSans-Regular", size: 12))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                
                AppColors.modalBackground(themeManager.colorScheme)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            }
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
            
            // Show loading state while we verify the subscription
            isLoading = true
            
            Task {
                // Clear cache first
                await SubscriptionService.shared.clearCache()
                
                // Wait for webhook to process and verify subscription with retries
                // This handles the race condition where the deep link arrives before the webhook
                do {
                    let hasSubscription = try await SubscriptionService.shared.hasActiveSubscriptionWithRetry()
                    
                    await MainActor.run {
                        isLoading = false
                        isPresented = false
                        
                        if hasSubscription {
                            print("✅ Subscription verified after checkout")
                            onSubscribeComplete?()
                        } else {
                            // Subscription not found after retries - show error
                            errorMessage = "Subscription processing. Please refresh settings in a moment."
                            onSubscribeComplete?() // Still call callback to refresh
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        isPresented = false
                        onSubscribeComplete?() // Call callback anyway to attempt refresh
                    }
                }
            }
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
            HStack {
                // Plan name and badge
                HStack(spacing: 8) {
                    Text(plan.displayName)
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    // Badge
                    if let badge = plan.badge {
                        Text(badge)
                            .font(.custom("ProductSans-Bold", size: 11))
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.primary.opacity(0.15))
                            )
                    }
                }
                
                Spacer()
                
                // Price
                Text(plan == .yearly ? plan.price : plan.pricePerMonth)
                    .font(.custom("ProductSans-Bold", size: 20))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.inputBackground(themeManager.colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
