import SwiftUI
import SafariServices
import UIKit

/// A modal view that displays credit purchase options
struct CreditsModalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var selectedBundle: CreditBundle?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSafari = false
    @State private var checkoutURL: URL?
    
    var onPurchaseComplete: (() -> Void)?
    
    private let features = [
        ("drop.fill", "See what needs attention", "Get detailed AI analysis of your blood test results"),
        ("chart.bar.xaxis.ascending", "Know which markers matter most", "Track trends and patterns in your health data"),
        ("quote.bubble.fill", "Ask AI about your restults", "Chat with AI about your results"),
        ("sparkles", "Get clear steps to improve them", "Unlock all premium features"),
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.modalBackground(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            VStack(spacing: 0) {
                                Text("Know What Matters in")
                                    .font(.custom("ProductSans-Bold", size: 28))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                Text("Your Health")
                                    .font(.custom("instrumentserif-italic", size: 28))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            
                            Text("Clear explanations. Clear actionable steps.")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 16)
                        
                        // Features list
                        VStack(spacing: 16) {
                            ForEach(features, id: \.0) { feature in
                                HStack(spacing: 16) {
                                    Image(systemName: feature.0)
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.primary)
                                        .frame(width: 32, height: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feature.1)
                                            .font(.custom("ProductSans-Bold", size: 15))
                                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        
                                        Text(feature.2)
                                            .font(.custom("ProductSans-Regular", size: 13))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                            .background(AppColors.textSecondary(themeManager.colorScheme).opacity(0.3))
                            .padding(.horizontal, 24)
                        
                        // Credit bundles
                        VStack(spacing: 12) {
                            Text("1 Credit = 1 Full Blood Test Analysis")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.horizontal, 24)
                            
                            // Horizontal row of bundles
                            HStack(spacing: 12) {
                                ForEach(CreditBundle.bundles) { bundle in
                                    BundleCard(
                                        bundle: bundle,
                                        isSelected: selectedBundle?.id == bundle.id,
                                        isMostPopular: bundle.id == "3",
                                        onSelect: {
                                            // Haptic feedback on selection
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                            selectedBundle = bundle
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        // Purchase button
                        Button(action: {
                            // Haptic feedback on continue
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            handlePurchase()
                        }) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(selectedBundle != nil ? "Continue" : "Select a Bundle")
                                        .font(.custom("ProductSans-Bold", size: 16))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(selectedBundle != nil ? AppColors.primary : Color.gray.opacity(0.5))
                            )
                            .shadow(color: selectedBundle != nil ? Color(hex: "#BB3E4F").opacity(0.6) : Color.clear, radius: 16, x: 0, y: 6)
                        }
                        .disabled(selectedBundle == nil || isLoading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Text("Close")
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }

                // Centered logo in the navigation bar
                ToolbarItem(placement: .principal) {
                    HStack {
                        Spacer(minLength: 0)
                        Image("Logo")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(height: 28)
                            .accessibilityHidden(true)
                        Spacer(minLength: 0)
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
    
    private func handlePurchase() {
        guard let bundle = selectedBundle else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let checkoutURLString = try await CreditService.shared.createCheckoutSession(bundle: bundle.id)
                
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
        if url.scheme == "lumo" && url.host == "credits-success" {
            showSafari = false
            isPresented = false
            onPurchaseComplete?()
        } else if url.scheme == "lumo" && url.host == "credits-cancel" {
            showSafari = false
        }
    }
}

// MARK: - Bundle Card
struct BundleCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let bundle: CreditBundle
    let isSelected: Bool
    let isMostPopular: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .top) {
                VStack(spacing: 12) {
                    // Most Popular banner
                    if isMostPopular {
                        Text("MOST POPULAR")
                            .font(.custom("ProductSans-Bold", size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.primary)
                            )
                            .offset(y: -8)
                    } else {
                        Spacer()
                            .frame(height: 20)
                    }
                    
                    // Credits count
                    VStack(spacing: 4) {
                        Text("\(bundle.credits)")
                            .font(.custom("ProductSans-Bold", size: 36))
                            .foregroundColor(isSelected ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                        
                        Text("Credit\(bundle.credits > 1 ? "s" : "")")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .padding(.top, isMostPopular ? 0 : 8)
                    
                    // Divider
                    Rectangle()
                        .fill(AppColors.textSecondary(themeManager.colorScheme).opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                    
                    // Price
                    Text(bundle.priceDisplay)
                        .font(.custom("ProductSans-Bold", size: 22))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    // Savings badge
                    if let savings = bundle.savings {
                        Text(savings)
                            .font(.custom("ProductSans-Bold", size: 11))
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.primary.opacity(0.15))
                            )
                    } else {
                        Spacer()
                            .frame(height: 20)
                    }
                    
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme).opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        if (isSelected) {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.inputBackground(themeManager.colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? AppColors.primary : (isMostPopular ? AppColors.primary.opacity(0.3) : Color.clear), lineWidth: isSelected ? 2 : 1)
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            // Ensure haptic if user taps the card directly
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        })
    }
}

#Preview {
    CreditsModalView(isPresented: .constant(true))
        .environmentObject(ThemeManager.shared)
}
