import SwiftUI
import SafariServices

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
        ("drop.fill", "Analyze Blood Tests", "Get detailed AI analysis of your blood test results"),
        ("chart.line.uptrend.xyaxis", "Smart Analytics", "Track trends and patterns in your health data"),
        ("bubble.left.and.bubble.right.fill", "Ask Questions", "Chat with AI about your results"),
        ("sparkles", "Full Access", "Unlock all premium features"),
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
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.primary)
                            
                            Text("Get Credits")
                                .font(.custom("ProductSans-Bold", size: 28))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            Text("Credits are used to analyze your blood tests and unlock premium features.")
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
                            Text("Choose a Bundle")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                            
                            ForEach(CreditBundle.bundles) { bundle in
                                BundleCard(
                                    bundle: bundle,
                                    isSelected: selectedBundle?.id == bundle.id,
                                    onSelect: { selectedBundle = bundle }
                                )
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        // Purchase button
                        Button(action: handlePurchase) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(selectedBundle != nil ? "Purchase \(selectedBundle!.credits) Credit\(selectedBundle!.credits > 1 ? "s" : "")" : "Select a Bundle")
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
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Credits count
                VStack(spacing: 2) {
                    Text("\(bundle.credits)")
                        .font(.custom("ProductSans-Bold", size: 28))
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.text(themeManager.colorScheme))
                    
                    Text("Credit\(bundle.credits > 1 ? "s" : "")")
                        .font(.custom("ProductSans-Regular", size: 12))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .frame(width: 70)
                
                // Divider
                Rectangle()
                    .fill(AppColors.textSecondary(themeManager.colorScheme).opacity(0.3))
                    .frame(width: 1, height: 40)
                
                // Price and savings
                VStack(alignment: .leading, spacing: 4) {
                    Text(bundle.priceDisplay)
                        .font(.custom("ProductSans-Bold", size: 20))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    if let savings = bundle.savings {
                        Text(savings)
                            .font(.custom("ProductSans-Bold", size: 12))
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.primary : AppColors.textSecondary(themeManager.colorScheme).opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 14, height: 14)
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

#Preview {
    CreditsModalView(isPresented: .constant(true))
        .environmentObject(ThemeManager.shared)
}
