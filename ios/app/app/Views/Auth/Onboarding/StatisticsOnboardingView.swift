//
//  StatisticsOnboardingView.swift
//  app
//
//  Enhanced statistics page: "40-50% of people forget to take their medication"
//

import SwiftUI
import UIKit

// MARK: - Star Particle for Background (shared with MedicationSelectionView)
struct StarParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

// MARK: - Floating Pill Particle
struct FloatingPill: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var rotation: Double
    var opacity: Double
    var speed: CGFloat
    var color: Color
}

struct StatisticsOnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState

    // Navigation
    @State private var navigateToNext = false

    // Animation states
    @State private var contentBlur: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var statisticScale: CGFloat = 0.5
    @State private var statisticOpacity: Double = 0
    @State private var pillIconScale: CGFloat = 0
    @State private var pillIconRotation: Double = -30

    // Animated counter
    @State private var displayedPercentage: Int = 0
    @State private var counterTimer: Timer?

    // Pulsing ring animation
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    // Floating pills
    @State private var floatingPills: [FloatingPill] = []
    @State private var pillAnimationTimer: Timer?

    // Haptic generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
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

            // Radial gradient "light" effect from top
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(isDarkMode ? 0.3 : 0.15),
                    AppColors.primary.opacity(isDarkMode ? 0.1 : 0.05),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.7
            )
            .ignoresSafeArea()

            // Floating pills background
            ForEach(floatingPills) { pill in
                Capsule()
                    .fill(pill.color.opacity(pill.opacity))
                    .frame(width: pill.size * 0.4, height: pill.size)
                    .rotationEffect(.degrees(pill.rotation))
                    .position(x: pill.x, y: pill.y)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Statistics text with animated counter
                VStack(spacing: 8) {
                    (Text("On average, ")
                        .font(.custom("ProductSans-Bold", size: 34))
                        .foregroundColor(AppColors.text(themeManager.colorScheme)) +
                     Text("\(displayedPercentage)%")
                        .font(.custom("InstrumentSerif-Italic", size: 38))
                        .foregroundColor(AppColors.primary) +
                     Text(" of people forget to take their ")
                        .font(.custom("ProductSans-Bold", size: 34))
                        .foregroundColor(AppColors.text(themeManager.colorScheme)) +
                     Text("supplements.")
                        .font(.custom("ProductSans-Bold", size: 34))
                        .foregroundColor(AppColors.text(themeManager.colorScheme)))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 28)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)
                .scaleEffect(statisticScale)

                // Animated pill icon with pulsing rings
                ZStack {
                    // Pulsing rings
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(AppColors.primary.opacity(0.2), lineWidth: 2)
                            .frame(width: 80 + CGFloat(index) * 30, height: 80 + CGFloat(index) * 30)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity - Double(index) * 0.15)
                    }

                    // Main pill icon
                    Image(systemName: "pills.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pillIconScale)
                        .rotationEffect(.degrees(pillIconRotation))
                }
                .padding(.top, 48)
                .blur(radius: contentBlur * 0.5)
                .opacity(contentOpacity)

                Spacer()
                Spacer()

                // Source citation
                Text("Source: National Institutes of Health (NIH)")
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .blur(radius: buttonBlur)
                    .opacity(buttonOpacity)
                    .padding(.bottom, 24)

                // Continue button
                Button(action: {
                    impactFeedback.impactOccurred()
                    navigateToNext = true
                }) {
                    Text("Continue")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(AppColors.primary)
                        )
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .blur(radius: buttonBlur)
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationDestination(isPresented: $navigateToNext) {
            SupplementSpendView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            notificationFeedback.prepare()
            initializeFloatingPills()
            startAnimations()
            startPillAnimation()
        }
        .onDisappear {
            counterTimer?.invalidate()
            pillAnimationTimer?.invalidate()
        }
    }

    // MARK: - Initialize Floating Pills
    private func initializeFloatingPills() {
        let colors: [Color] = [
            AppColors.primary,
            AppColors.primary.opacity(0.7),
            Color(hex: "#FF6B6B"),
            Color(hex: "#4ECDC4"),
            Color(hex: "#45B7D1")
        ]

        floatingPills = (0..<15).map { _ in
            FloatingPill(
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 20...40),
                rotation: Double.random(in: -45...45),
                opacity: Double.random(in: 0.1...0.3),
                speed: CGFloat.random(in: 0.3...0.8),
                color: colors.randomElement() ?? AppColors.primary
            )
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        // Content blurs in
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            contentBlur = 0
            contentOpacity = 1
        }

        // Statistic scales up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
            statisticScale = 1.0
        }

        // Pill icon appears with bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.6)) {
            pillIconScale = 1.0
            pillIconRotation = 0
        }

        // Start counter animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startCounterAnimation()
        }

        // Start pulsing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            startPulseAnimation()
        }

        // Button blurs in
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    // MARK: - Counter Animation
    private func startCounterAnimation() {
        let targetPercentage = 45 // Middle of 40-50 range
        let duration: Double = 1.5
        let steps = 30
        let interval = duration / Double(steps)
        var currentStep = 0

        counterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)

            // Ease-out cubic
            let easedProgress = 1 - pow(1 - progress, 3)
            displayedPercentage = Int(Double(targetPercentage) * easedProgress)

            // Haptic feedback every few steps
            if currentStep % 5 == 0 {
                let softImpact = UIImpactFeedbackGenerator(style: .soft)
                softImpact.impactOccurred(intensity: 0.3 + CGFloat(progress) * 0.4)
            }

            if currentStep >= steps {
                timer.invalidate()
                displayedPercentage = targetPercentage

                // Final haptic
                notificationFeedback.notificationOccurred(.warning)
            }
        }
    }

    // MARK: - Pulse Animation
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
            pulseOpacity = 0.3
        }
    }

    // MARK: - Floating Pill Animation
    private func startPillAnimation() {
        pillAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in floatingPills.indices {
                withAnimation(.linear(duration: 0.05)) {
                    // Move upward
                    floatingPills[i].y -= floatingPills[i].speed

                    // Slight horizontal drift
                    floatingPills[i].x += CGFloat.random(in: -0.3...0.3)

                    // Slight rotation
                    floatingPills[i].rotation += Double.random(in: -0.5...0.5)

                    // Wrap around when reaching top
                    if floatingPills[i].y < -50 {
                        floatingPills[i].y = screenHeight + 50
                        floatingPills[i].x = CGFloat.random(in: 0...screenWidth)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsOnboardingView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
