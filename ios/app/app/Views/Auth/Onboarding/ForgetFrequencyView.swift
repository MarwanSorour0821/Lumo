//
//  ForgetFrequencyView.swift
//  app
//
//  Interactive onboarding screen: "How often do you forget to take them?"
//

import SwiftUI
import UIKit

struct ForgetFrequencyView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Selection state
    @State private var selectedFrequency: ForgetFrequency? = nil

    // Animation states
    @State private var contentBlur: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var optionsOpacity: Double = 0
    @State private var optionScales: [CGFloat] = [0.8, 0.8, 0.8, 0.8]

    // Wave animation for selected option
    @State private var wavePhase: CGFloat = 0
    @State private var waveTimer: Timer?

    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

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

            // Subtle gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(isDarkMode ? 0.2 : 0.1),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 0,
                endRadius: screenHeight * 0.5
            )
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Question text
                VStack(spacing: 8) {
                    Text("How often do you")
                        .font(.custom("ProductSans-Regular", size: 30))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    HStack(spacing: 8) {
                        Text("forget")
                            .font(.custom("InstrumentSerif-Italic", size: 36))
                            .foregroundColor(AppColors.primary)

                        Text("to take them?")
                            .font(.custom("ProductSans-Regular", size: 30))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
                .multilineTextAlignment(.center)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 50)

                // Frequency options
                VStack(spacing: 16) {
                    ForEach(Array(ForgetFrequency.allCases.enumerated()), id: \.element) { index, frequency in
                        frequencyOption(frequency, index: index)
                            .scaleEffect(optionScales[safe: index] ?? 1.0)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(optionsOpacity)

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
            StatisticsOnboardingView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            selectionFeedback.prepare()
            startAnimations()
            startWaveAnimation()
        }
        .onDisappear {
            waveTimer?.invalidate()
        }
    }

    // MARK: - Frequency Option Card
    func frequencyOption(_ frequency: ForgetFrequency, index: Int) -> some View {
        let isSelected = selectedFrequency == frequency

        return Button(action: {
            selectFrequency(frequency, index: index)
        }) {
            HStack(spacing: 16) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                        .frame(width: 52, height: 52)

                    // Icon with wave animation for selected
                    Image(systemName: frequency.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? .white : AppColors.textSecondary(themeManager.colorScheme))
                        .rotationEffect(.degrees(isSelected ? Double(sin(Double(wavePhase))) * 8 : 0))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(frequency.title)
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text(frequency.subtitle)
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }

                Spacer()

                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ?
                          AppColors.primary.opacity(isDarkMode ? 0.15 : 0.08) :
                            AppColors.surface(themeManager.colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: isSelected ? AppColors.primary.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isSelected ? 12 : 4, x: 0, y: isSelected ? 6 : 2)
        }
        .buttonStyle(FrequencyButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Selection Handler
    private func selectFrequency(_ frequency: ForgetFrequency, index: Int) {
        guard selectedFrequency != frequency else { return }

        // Progressive haptic based on frequency severity
        let intensity: CGFloat
        switch frequency {
        case .never:
            intensity = 0.4
        case .rarely:
            intensity = 0.6
        case .sometimes:
            intensity = 0.8
        case .often:
            intensity = 1.0
        }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred(intensity: intensity)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedFrequency = frequency
        }

        // Subtle bounce effect on selected option
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            optionScales[index] = 1.05
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                optionScales[index] = 1.0
            }
        }
    }

    // MARK: - Continue Button
    var continueButton: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            // Save to coordinator
            if let freq = selectedFrequency {
                switch freq {
                case .never: onboardingData.forgetFrequency = .never
                case .rarely: onboardingData.forgetFrequency = .rarely
                case .sometimes: onboardingData.forgetFrequency = .sometimes
                case .often: onboardingData.forgetFrequency = .often
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
                    .fill(selectedFrequency != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
            )
            .shadow(color: AppColors.primary.opacity(selectedFrequency != nil ? 0.4 : 0.2), radius: 16, x: 0, y: 8)
        }
        .disabled(selectedFrequency == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedFrequency)
    }

    // MARK: - Animations
    private func startAnimations() {
        // Content fades in
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            contentBlur = 0
            contentOpacity = 1
        }

        // Options fade in with stagger
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            optionsOpacity = 1
        }

        // Staggered scale animation for options
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    optionScales[i] = 1.0
                }
            }
        }

        // Button fades in
        withAnimation(.easeOut(duration: 0.8).delay(0.7)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    private func startWaveAnimation() {
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                wavePhase += 0.15
            }
        }
    }
}

// MARK: - Forget Frequency Enum
enum ForgetFrequency: CaseIterable {
    case never
    case rarely
    case sometimes
    case often

    var title: String {
        switch self {
        case .never: return "Never"
        case .rarely: return "Rarely"
        case .sometimes: return "Sometimes"
        case .often: return "Often"
        }
    }

    var subtitle: String {
        switch self {
        case .never: return "I'm pretty consistent"
        case .rarely: return "Maybe once a month"
        case .sometimes: return "A few times a week"
        case .often: return "More often than I'd like"
        }
    }

    var icon: String {
        switch self {
        case .never: return "checkmark.seal.fill"
        case .rarely: return "clock.fill"
        case .sometimes: return "questionmark.circle.fill"
        case .often: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Button Style
struct FrequencyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ForgetFrequencyView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
