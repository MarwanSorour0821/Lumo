//
//  SupplementSpendView.swift
//  app
//
//  Interactive onboarding screen: "How much do you spend on supplements?"
//

import SwiftUI
import UIKit

struct SupplementSpendView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Selection state
    @State private var selectedAmount: SpendAmount? = nil
    @State private var sliderValue: CGFloat = 0.5
    @State private var isDragging = false

    // Animation states
    @State private var contentBlur: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var sliderOpacity: Double = 0


    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    private var isDarkMode: Bool {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark
    }

    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // Gradient effect
            RadialGradient(
                gradient: Gradient(colors: [
                    (selectedAmount?.accentColor ?? AppColors.primary).opacity(isDarkMode ? 0.2 : 0.1),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: screenHeight * 0.5
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: selectedAmount)

            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Question text
                VStack(spacing: 8) {
                    Text("How much do you")
                        .font(.custom("ProductSans-Regular", size: 30))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    HStack(spacing: 8) {
                        Text("spend")
                            .font(.custom("InstrumentSerif-Italic", size: 36))
                            .foregroundColor(AppColors.primary)

                        Text("on supplements?")
                            .font(.custom("ProductSans-Regular", size: 30))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
                .multilineTextAlignment(.center)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 30)

                // Dynamic amount display
                amountDisplay
                    .opacity(sliderOpacity)

                Spacer()
                    .frame(height: 40)

                // Interactive amount selector
                amountSelector
                    .opacity(sliderOpacity)
                    .padding(.horizontal, 24)

                Spacer()

                // Continue button
                continueButton
                    .blur(radius: buttonBlur)
                    .opacity(buttonOpacity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationDestination(isPresented: $navigateToNext) {
            SupplementCombinationView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            selectionFeedback.prepare()
            startAnimations()
        }
    }

    // MARK: - Amount Display
    var amountDisplay: some View {
        VStack(spacing: 16) {
            // Animated dollar signs
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Text("$")
                        .font(.custom("ProductSans-Bold", size: 32))
                        .foregroundColor(index < (selectedAmount?.dollarCount ?? 0) ?
                                         (selectedAmount?.accentColor ?? AppColors.primary) :
                                            AppColors.textSecondary(themeManager.colorScheme).opacity(0.3))
                        .scaleEffect(index < (selectedAmount?.dollarCount ?? 0) ? 1.1 : 0.9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedAmount)
                }
            }

            // Amount text
            if let amount = selectedAmount {
                VStack(spacing: 4) {
                    Text(amount.displayText)
                        .font(.custom("ProductSans-Bold", size: 28))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text(amount.subtitle)
                        .font(.custom("ProductSans-Regular", size: 15))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                Text("Select an amount")
                    .font(.custom("ProductSans-Regular", size: 18))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
        }
        .frame(height: 120)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedAmount)
    }

    // MARK: - Amount Selector
    var amountSelector: some View {
        VStack(spacing: 20) {
            // Amount option buttons in a grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SpendAmount.allCases, id: \.self) { amount in
                    amountOption(amount)
                }
            }
        }
    }

    func amountOption(_ amount: SpendAmount) -> some View {
        let isSelected = selectedAmount == amount

        return Button(action: {
            selectAmount(amount)
        }) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? amount.accentColor : AppColors.surface(themeManager.colorScheme))
                        .frame(width: 56, height: 56)

                    Image(systemName: amount.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : AppColors.textSecondary(themeManager.colorScheme))
                }

                Text(amount.displayText)
                    .font(.custom("ProductSans-Bold", size: 15))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text("per month")
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ?
                          amount.accentColor.opacity(isDarkMode ? 0.15 : 0.08) :
                            AppColors.surface(themeManager.colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? amount.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: isSelected ? amount.accentColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(SpendButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Selection Handler
    private func selectAmount(_ amount: SpendAmount) {
        guard selectedAmount != amount else { return }

        // Haptic intensity based on amount
        let intensity: CGFloat
        switch amount {
        case .under25: intensity = 0.4
        case .between25and50: intensity = 0.6
        case .between50and100: intensity = 0.8
        case .over100: intensity = 1.0
        }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred(intensity: intensity)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedAmount = amount
        }
    }

    // MARK: - Continue Button
    var continueButton: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            // Save to coordinator
            if let amount = selectedAmount {
                switch amount {
                case .under25: onboardingData.monthlySpend = .under25
                case .between25and50: onboardingData.monthlySpend = .between25and50
                case .between50and100: onboardingData.monthlySpend = .between50and100
                case .over100: onboardingData.monthlySpend = .over100
                }
            }
            navigateToNext = true
        }) {
            HStack {
                Spacer()
                Text("Continue")
                    .font(.custom("ProductSans-Bold", size: 17))
                    .foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(selectedAmount != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
            )
            .shadow(color: AppColors.primary.opacity(selectedAmount != nil ? 0.4 : 0.2), radius: 16, x: 0, y: 8)
        }
        .disabled(selectedAmount == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedAmount)
    }

    // MARK: - Animations
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            contentBlur = 0
            contentOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            sliderOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }
}

// MARK: - Spend Amount Enum
enum SpendAmount: CaseIterable {
    case under25
    case between25and50
    case between50and100
    case over100

    var displayText: String {
        switch self {
        case .under25: return "Under $25"
        case .between25and50: return "$25 - $50"
        case .between50and100: return "$50 - $100"
        case .over100: return "$100+"
        }
    }

    var subtitle: String {
        switch self {
        case .under25: return "Just the basics"
        case .between25and50: return "A modest routine"
        case .between50and100: return "A solid investment"
        case .over100: return "Health is wealth"
        }
    }

    var icon: String {
        switch self {
        case .under25: return "leaf.fill"
        case .between25and50: return "star.fill"
        case .between50and100: return "sparkles"
        case .over100: return "crown.fill"
        }
    }

    var dollarCount: Int {
        switch self {
        case .under25: return 1
        case .between25and50: return 2
        case .between50and100: return 3
        case .over100: return 4
        }
    }

    var accentColor: Color {
        switch self {
        case .under25: return Color(hex: "#4ECDC4")
        case .between25and50: return Color(hex: "#45B7D1")
        case .between50and100: return Color(hex: "#96CEB4")
        case .over100: return AppColors.primary
        }
    }
}

// MARK: - Button Style
struct SpendButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SupplementSpendView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
