//
//  BadNewsResultsView.swift
//  app
//
//  Shows the negative impact - wasted pills and money
//

import SwiftUI
import UIKit

struct BadNewsResultsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20

    // Card reveal animations
    @State private var pillsCardScale: CGFloat = 0.8
    @State private var pillsCardOpacity: Double = 0
    @State private var moneyCardScale: CGFloat = 0.8
    @State private var moneyCardOpacity: Double = 0

    // Counter animations
    @State private var displayedPills: Int = 0
    @State private var displayedMoney: Double = 0

    // Impact animations
    @State private var pillsImpactScale: CGFloat = 1.0
    @State private var moneyImpactScale: CGFloat = 1.0

    // Falling pills animation
    @State private var fallingPills: [FallingPillParticle] = []
    @State private var pillTimer: Timer?

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

    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // Red gradient overlay
            LinearGradient(
                colors: [
                    Color(hex: "#FF6B6B").opacity(isDarkMode ? 0.15 : 0.08),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Falling pill particles
            ForEach(fallingPills) { pill in
                Capsule()
                    .fill(Color.gray.opacity(pill.opacity * 0.5))
                    .frame(width: pill.size * 0.4, height: pill.size)
                    .rotationEffect(.degrees(pill.rotation))
                    .position(x: pill.x, y: pill.y)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Header
                VStack(spacing: 12) {
                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FF6B6B").opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                    }

                    Text("Here's the reality")
                        .font(.custom("ProductSans-Bold", size: 28))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("Based on your routine")
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .opacity(headerOpacity)
                .offset(y: headerOffset)

                Spacer()
                    .frame(height: 50)

                // Stats cards
                VStack(spacing: 20) {
                    // Pills wasted card
                    wasteStat(
                        icon: "pills.fill",
                        value: "\(displayedPills)",
                        unit: "pills",
                        description: "wasted every month",
                        color: Color(hex: "#FF6B6B")
                    )
                    .scaleEffect(pillsCardScale * pillsImpactScale)
                    .opacity(pillsCardOpacity)

                    // Money wasted card
                    wasteStat(
                        icon: "dollarsign.circle.fill",
                        value: "$\(Int(displayedMoney))",
                        unit: "",
                        description: "thrown away monthly",
                        color: Color(hex: "#FF8E53")
                    )
                    .scaleEffect(moneyCardScale * moneyImpactScale)
                    .opacity(moneyCardOpacity)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Yearly impact callout
                yearlyImpact
                    .opacity(buttonOpacity)

                Spacer()
                    .frame(height: 20)

                // Continue button
                Button(action: {
                    impactFeedback.impactOccurred()
                    navigateToNext = true
                }) {
                    HStack {
                        Spacer()
                        Text("But there's hope")
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
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToNext) {
            GoodNewsResultsView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            notificationFeedback.prepare()
            startAnimations()
            startFallingPills()
        }
        .onDisappear {
            pillTimer?.invalidate()
        }
    }

    // MARK: - Waste Stat Card
    func wasteStat(icon: String, value: String, unit: String, description: String, color: Color) -> some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.custom("ProductSans-Bold", size: 40))
                        .foregroundColor(color)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(color.opacity(0.8))
                    }
                }

                Text(description)
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }

            Spacer()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isDarkMode ? Color(hex: "#1A1A1A") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.1), radius: 20, x: 0, y: 10)
    }

    // MARK: - Yearly Impact
    var yearlyImpact: some View {
        VStack(spacing: 8) {
            Text("That's")
                .font(.custom("ProductSans-Regular", size: 16))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

            Text("$\(Int(onboardingData.wastedMoneyPerMonth * 12))/year")
                .font(.custom("ProductSans-Bold", size: 24))
                .foregroundColor(Color(hex: "#FF6B6B"))

            Text("going to waste")
                .font(.custom("ProductSans-Regular", size: 16))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#FF6B6B").opacity(isDarkMode ? 0.1 : 0.05))
        )
    }

    // MARK: - Animations
    private func startAnimations() {
        // Header appears
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            headerOpacity = 1
            headerOffset = 0
        }

        // Warning haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            notificationFeedback.notificationOccurred(.warning)
        }

        // Pills card reveals
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            pillsCardScale = 1.0
            pillsCardOpacity = 1.0
        }

        // Start pills counter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            startPillsCounter()
        }

        // Money card reveals
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.3)) {
            moneyCardScale = 1.0
            moneyCardOpacity = 1.0
        }

        // Start money counter
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            startMoneyCounter()
        }

        // Button appears
        withAnimation(.easeOut(duration: 0.6).delay(2.5)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    private func startPillsCounter() {
        let target = onboardingData.wastedPillsPerMonth
        let duration: Double = 1.0
        let steps = 20
        let interval = duration / Double(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let easedProgress = 1 - pow(1 - progress, 3)

            displayedPills = Int(Double(target) * easedProgress)

            // Haptic ticks
            if currentStep % 4 == 0 {
                let tick = UIImpactFeedbackGenerator(style: .light)
                tick.impactOccurred(intensity: 0.4)
            }

            if currentStep >= steps {
                timer.invalidate()
                displayedPills = target

                // Impact effect
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    pillsImpactScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pillsImpactScale = 1.0
                    }
                }

                notificationFeedback.notificationOccurred(.warning)
            }
        }
    }

    private func startMoneyCounter() {
        let target = onboardingData.wastedMoneyPerMonth
        let duration: Double = 1.0
        let steps = 20
        let interval = duration / Double(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let easedProgress = 1 - pow(1 - progress, 3)

            displayedMoney = target * easedProgress

            // Haptic ticks
            if currentStep % 4 == 0 {
                let tick = UIImpactFeedbackGenerator(style: .light)
                tick.impactOccurred(intensity: 0.5)
            }

            if currentStep >= steps {
                timer.invalidate()
                displayedMoney = target

                // Impact effect
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    moneyImpactScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        moneyImpactScale = 1.0
                    }
                }

                notificationFeedback.notificationOccurred(.error)
            }
        }
    }

    private func startFallingPills() {
        pillTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Add new pill
            let pill = FallingPillParticle(
                x: CGFloat.random(in: 40...(screenWidth - 40)),
                y: -20,
                size: CGFloat.random(in: 15...25),
                rotation: Double.random(in: 0...360),
                speed: CGFloat.random(in: 1...2),
                opacity: Double.random(in: 0.2...0.4)
            )
            fallingPills.append(pill)

            // Limit particles
            if fallingPills.count > 15 {
                fallingPills.removeFirst()
            }
        }

        // Animate falling
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            for i in fallingPills.indices {
                withAnimation(.linear(duration: 0.03)) {
                    fallingPills[i].y += fallingPills[i].speed
                    fallingPills[i].rotation += Double.random(in: -1...1)
                }
            }
            fallingPills.removeAll { $0.y > screenHeight + 50 }
        }
    }
}

// MARK: - Falling Pill Particle
struct FallingPillParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var rotation: Double
    var speed: CGFloat
    var opacity: Double
}

#Preview {
    NavigationStack {
        BadNewsResultsView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
