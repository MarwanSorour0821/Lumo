//
//  GoodNewsResultsView.swift
//  app
//
//  Shows the positive outcome - potential savings and benefits
//

import SwiftUI
import UIKit

struct GoodNewsResultsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var headerScale: CGFloat = 0.8

    // Savings reveal
    @State private var savingsOpacity: Double = 0
    @State private var savingsScale: CGFloat = 0.5
    @State private var displayedSavings: Double = 0

    // Glow effect
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8

    // Benefits cards
    @State private var benefitOpacities: [Double] = [0, 0, 0]
    @State private var benefitOffsets: [CGFloat] = [30, 30, 30]

    // Celebration particles
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var confettiTimer: Timer?

    // Button
    @State private var buttonOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20

    // Haptic generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    private var isDarkMode: Bool {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark
    }

    let benefits = [
        ("clock.badge.checkmark.fill", "Perfect Timing", "Take supplements when they work best"),
        ("bell.badge.fill", "Smart Reminders", "Never miss a dose again"),
        ("chart.line.uptrend.xyaxis", "Track Progress", "See your health improve over time")
    ]

    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // Success gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#4ECDC4").opacity(isDarkMode ? 0.2 : 0.12),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.6
            )
            .ignoresSafeArea()

            // Confetti particles
            ForEach(confettiParticles) { particle in
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 1.5)
                    .rotationEffect(.degrees(particle.rotation))
                    .position(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 50)

                // Header with sparkle icon
                VStack(spacing: 16) {
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Color(hex: "#4ECDC4").opacity(0.3))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)
                            .scaleEffect(glowScale)
                            .opacity(glowOpacity)

                        // Icon background
                        Circle()
                            .fill(Color(hex: "#4ECDC4").opacity(0.15))
                            .frame(width: 90, height: 90)

                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                    }

                    Text("Great news!")
                        .font(.custom("ProductSans-Bold", size: 32))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                .opacity(headerOpacity)
                .scaleEffect(headerScale)

                Spacer()
                    .frame(height: 40)

                // Savings showcase
                VStack(spacing: 8) {
                    Text("You could save")
                        .font(.custom("ProductSans-Regular", size: 18))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$\(Int(displayedSavings))")
                            .font(.custom("ProductSans-Bold", size: 64))
                            .foregroundColor(Color(hex: "#4ECDC4"))

                        Text("/year")
                            .font(.custom("ProductSans-Regular", size: 22))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }

                    Text("with proper supplement spacing")
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .opacity(savingsOpacity)
                .scaleEffect(savingsScale)

                Spacer()
                    .frame(height: 40)

                // Benefits list
                VStack(spacing: 12) {
                    ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                        benefitRow(icon: benefit.0, title: benefit.1, subtitle: benefit.2)
                            .opacity(benefitOpacities[index])
                            .offset(y: benefitOffsets[index])
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA button
                Button(action: {
                    impactFeedback.impactOccurred()
                    navigateToNext = true
                }) {
                    HStack {
                        Spacer()
                        Text("Let's get started")
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
                            .fill(Color(hex: "#4ECDC4"))
                    )
                    .shadow(color: Color(hex: "#4ECDC4").opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .blur(radius: buttonBlur)
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToNext) {
            MedicationSelectionView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            notificationFeedback.prepare()
            startAnimations()
        }
        .onDisappear {
            confettiTimer?.invalidate()
        }
    }

    // MARK: - Benefit Row
    func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#4ECDC4").opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#4ECDC4"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(subtitle)
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "#4ECDC4"))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color(hex: "#1A1A1A") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#4ECDC4").opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Animations
    private func startAnimations() {
        // Header appears
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
            headerOpacity = 1
            headerScale = 1.0
        }

        // Glow animation
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            glowOpacity = 1
            glowScale = 1.2
        }

        // Pulsing glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowScale = 1.4
                glowOpacity = 0.6
            }
        }

        // Savings reveal
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
            savingsOpacity = 1
            savingsScale = 1.0
        }

        // Start savings counter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            startSavingsCounter()
        }

        // Benefits appear with stagger
        for i in 0..<3 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.8 + Double(i) * 0.15)) {
                benefitOpacities[i] = 1
                benefitOffsets[i] = 0
            }

            // Haptic for each benefit
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8 + Double(i) * 0.15) {
                let light = UIImpactFeedbackGenerator(style: .light)
                light.impactOccurred(intensity: 0.5)
            }
        }

        // Button appears
        withAnimation(.easeOut(duration: 0.6).delay(2.5)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    private func startSavingsCounter() {
        let target = onboardingData.potentialSavingsPerYear
        let duration: Double = 1.5
        let steps = 30
        let interval = duration / Double(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let easedProgress = 1 - pow(1 - progress, 3)

            displayedSavings = target * easedProgress

            // Progressive haptics
            if currentStep % 4 == 0 {
                let tick = UIImpactFeedbackGenerator(style: .light)
                tick.impactOccurred(intensity: 0.3 + CGFloat(progress) * 0.5)
            }

            if currentStep >= steps {
                timer.invalidate()
                displayedSavings = target

                // Celebration!
                notificationFeedback.notificationOccurred(.success)
                triggerConfetti()
            }
        }
    }

    private func triggerConfetti() {
        let colors: [Color] = [
            Color(hex: "#4ECDC4"),
            Color(hex: "#45B7D1"),
            Color(hex: "#96CEB4"),
            Color(hex: "#FFEAA7"),
            AppColors.primary
        ]

        // Create confetti burst
        for _ in 0..<20 {
            let particle = ConfettiParticle(
                x: screenWidth / 2 + CGFloat.random(in: -20...20),
                y: screenHeight * 0.3,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                velocityX: CGFloat.random(in: -4...4),
                velocityY: CGFloat.random(in: -8 ... -2),
                rotationSpeed: Double.random(in: -10...10),
                color: colors.randomElement() ?? Color(hex: "#4ECDC4"),
                opacity: 1.0
            )
            confettiParticles.append(particle)
        }

        // Animate confetti
        confettiTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            for i in confettiParticles.indices {
                withAnimation(.linear(duration: 0.03)) {
                    confettiParticles[i].x += confettiParticles[i].velocityX
                    confettiParticles[i].y += confettiParticles[i].velocityY
                    confettiParticles[i].velocityY += 0.3 // Gravity
                    confettiParticles[i].rotation += confettiParticles[i].rotationSpeed
                    confettiParticles[i].opacity *= 0.98
                }
            }
            confettiParticles.removeAll { $0.y > screenHeight + 50 || $0.opacity < 0.1 }

            if confettiParticles.isEmpty {
                confettiTimer?.invalidate()
            }
        }
    }
}

// MARK: - Confetti Particle
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var rotation: Double
    var velocityX: CGFloat
    var velocityY: CGFloat
    var rotationSpeed: Double
    var color: Color
    var opacity: Double
}

#Preview {
    NavigationStack {
        GoodNewsResultsView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
