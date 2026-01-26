//
//  SupplementCombinationView.swift
//  app
//
//  Interactive onboarding screen: "Do you take some supplements together?"
//

import SwiftUI
import UIKit

struct SupplementCombinationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Selection state
    @State private var selectedOption: CombinationOption? = nil

    // Animation states
    @State private var contentBlur: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var cardsOpacity: Double = 0
    @State private var cardOffsets: [CGFloat] = [50, 50, 50]

    // Pill merge animation
    @State private var pillsAreMerging = false
    @State private var mergeAnimationTimer: Timer?
    @State private var leftPillOffset: CGFloat = -30
    @State private var rightPillOffset: CGFloat = 30
    @State private var mergeScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0

    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

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

            // Dynamic gradient based on selection
            RadialGradient(
                gradient: Gradient(colors: [
                    (selectedOption?.accentColor ?? AppColors.primary).opacity(isDarkMode ? 0.2 : 0.1),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.6
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: selectedOption)

            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Question text
                VStack(spacing: 8) {
                    Text("Do you take some")
                        .font(.custom("ProductSans-Regular", size: 30))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("supplements together?")
                        .font(.custom("ProductSans-Regular", size: 30))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                .multilineTextAlignment(.center)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 30)

                // Interactive pill visualization
                pillVisualization
                    .frame(height: 140)
                    .opacity(cardsOpacity)

                Spacer()
                    .frame(height: 40)

                // Option cards
                VStack(spacing: 14) {
                    ForEach(Array(CombinationOption.allCases.enumerated()), id: \.element) { index, option in
                        combinationOption(option, index: index)
                            .offset(x: cardOffsets[safe: index] ?? 0)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(cardsOpacity)

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
            AbsorptionWarningView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            selectionFeedback.prepare()
            notificationFeedback.prepare()
            startAnimations()
        }
        .onDisappear {
            mergeAnimationTimer?.invalidate()
        }
    }

    // MARK: - Pill Visualization
    var pillVisualization: some View {
        ZStack {
            // Glow effect when merged
            if selectedOption == .yes {
                Circle()
                    .fill(AppColors.primary.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .opacity(glowOpacity)
            }

            // Left pill
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 60)
                .shadow(color: Color(hex: "#FF6B6B").opacity(0.4), radius: 8, x: 0, y: 4)
                .offset(x: leftPillOffset)
                .rotationEffect(.degrees(-15))

            // Right pill
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4ECDC4"), Color(hex: "#7EDDD6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 60)
                .shadow(color: Color(hex: "#4ECDC4").opacity(0.4), radius: 8, x: 0, y: 4)
                .offset(x: rightPillOffset)
                .rotationEffect(.degrees(15))

            // Merged state indicator
            if selectedOption == .yes && pillsAreMerging {
                // Spark effect
                ForEach(0..<6) { i in
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 6, height: 6)
                        .offset(
                            x: cos(CGFloat(i) * .pi / 3) * 45 * mergeScale,
                            y: sin(CGFloat(i) * .pi / 3) * 45 * mergeScale
                        )
                        .opacity(1 - Double(mergeScale - 1) / 0.5)
                }
            }
        }
        .scaleEffect(mergeScale)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: selectedOption)
    }

    // MARK: - Combination Option Card
    func combinationOption(_ option: CombinationOption, index: Int) -> some View {
        let isSelected = selectedOption == option

        return Button(action: {
            selectOption(option, index: index)
        }) {
            HStack(spacing: 16) {
                // Icon with animation
                ZStack {
                    Circle()
                        .fill(isSelected ? option.accentColor : AppColors.surface(themeManager.colorScheme))
                        .frame(width: 52, height: 52)

                    Image(systemName: option.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? .white : AppColors.textSecondary(themeManager.colorScheme))
                        .symbolEffect(.bounce, value: isSelected)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text(option.subtitle)
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? option.accentColor : AppColors.border(themeManager.colorScheme), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(option.accentColor)
                            .frame(width: 18, height: 18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ?
                          option.accentColor.opacity(isDarkMode ? 0.12 : 0.06) :
                            AppColors.surface(themeManager.colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? option.accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
                    )
            )
            .shadow(color: isSelected ? option.accentColor.opacity(0.15) : Color.black.opacity(0.03),
                    radius: isSelected ? 12 : 4, x: 0, y: isSelected ? 6 : 2)
        }
        .buttonStyle(CombinationButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Selection Handler
    private func selectOption(_ option: CombinationOption, index: Int) {
        guard selectedOption != option else { return }

        // Different haptic patterns for each option
        switch option {
        case .yes:
            // Satisfying "merge" haptic pattern
            impactFeedback.impactOccurred(intensity: 0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let soft = UIImpactFeedbackGenerator(style: .soft)
                soft.impactOccurred(intensity: 1.0)
            }
            triggerMergeAnimation()

        case .sometimes:
            // Medium haptic
            selectionFeedback.selectionChanged()

        case .no:
            // Light tap
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred(intensity: 0.5)
            resetPillPositions()
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedOption = option
        }

        // Animate pill positions based on selection
        updatePillAnimation(for: option)
    }

    private func triggerMergeAnimation() {
        pillsAreMerging = true

        // Pills come together
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            leftPillOffset = -8
            rightPillOffset = 8
            mergeScale = 1.1
            glowOpacity = 1.0
        }

        // Spark burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) {
                mergeScale = 1.3
            }
            notificationFeedback.notificationOccurred(.success)
        }

        // Settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                mergeScale = 1.0
                pillsAreMerging = false
            }
        }
    }

    private func resetPillPositions() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            leftPillOffset = -30
            rightPillOffset = 30
            mergeScale = 1.0
            glowOpacity = 0
            pillsAreMerging = false
        }
    }

    private func updatePillAnimation(for option: CombinationOption) {
        switch option {
        case .yes:
            // Handled by triggerMergeAnimation
            break
        case .sometimes:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                leftPillOffset = -18
                rightPillOffset = 18
                glowOpacity = 0.3
            }
        case .no:
            resetPillPositions()
        }
    }

    // MARK: - Continue Button
    var continueButton: some View {
        Button(action: {
            // Save to coordinator
            if let option = selectedOption {
                switch option {
                case .yes: onboardingData.takesTogether = .yes
                case .sometimes: onboardingData.takesTogether = .sometimes
                case .no: onboardingData.takesTogether = .no
                }
            }
            // Final satisfying haptic
            notificationFeedback.notificationOccurred(.success)
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
                    .fill(selectedOption != nil ? AppColors.primary : AppColors.primary.opacity(0.5))
            )
            .shadow(color: AppColors.primary.opacity(selectedOption != nil ? 0.4 : 0.2), radius: 16, x: 0, y: 8)
        }
        .disabled(selectedOption == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedOption)
    }

    // MARK: - Animations
    private func startAnimations() {
        // Content fades in
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            contentBlur = 0
            contentOpacity = 1
        }

        // Cards fade in with stagger
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            cardsOpacity = 1
        }

        // Staggered slide animation for cards
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    cardOffsets[i] = 0
                }
            }
        }

        // Button fades in
        withAnimation(.easeOut(duration: 0.8).delay(0.7)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }
}

// MARK: - Combination Option Enum
enum CombinationOption: CaseIterable {
    case yes
    case sometimes
    case no

    var title: String {
        switch self {
        case .yes: return "Yes, I stack them"
        case .sometimes: return "Sometimes"
        case .no: return "No, I take them separately"
        }
    }

    var subtitle: String {
        switch self {
        case .yes: return "Multiple supplements at the same time"
        case .sometimes: return "Depends on my schedule"
        case .no: return "I space them out throughout the day"
        }
    }

    var icon: String {
        switch self {
        case .yes: return "square.stack.3d.up.fill"
        case .sometimes: return "clock.badge.questionmark"
        case .no: return "arrow.left.and.right"
        }
    }

    var accentColor: Color {
        switch self {
        case .yes: return AppColors.primary
        case .sometimes: return Color(hex: "#45B7D1")
        case .no: return Color(hex: "#96CEB4")
        }
    }
}

// MARK: - Button Style
struct CombinationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SupplementCombinationView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
