//
//  CalculatingWasteView.swift
//  app
//
//  Loading screen that calculates waste and auto-navigates
//

import SwiftUI
import UIKit

struct CalculatingWasteView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var loadingProgress: CGFloat = 0
    @State private var currentPhase: Int = 0
    @State private var phaseOpacity: Double = 1

    // Orbiting pills animation
    @State private var orbitRotation: Double = 0
    @State private var orbitTimer: Timer?

    // Particle burst on completion
    @State private var showCompletionBurst = false
    @State private var burstParticles: [BurstParticle] = []

    // Progress phases
    let phases = [
        "Analyzing your routine...",
        "Checking supplement interactions...",
        "Calculating potential waste...",
        "Preparing your insights..."
    ]

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

            // Gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(isDarkMode ? 0.25 : 0.12),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: screenHeight * 0.5
            )
            .ignoresSafeArea()

            // Burst particles
            ForEach(burstParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }

            // Main content
            VStack(spacing: 40) {
                Spacer()

                // Orbiting pills animation
                ZStack {
                    // Center icon
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }

                    // Orbiting pills
                    ForEach(0..<4) { index in
                        orbitingPill(index: index)
                    }
                }
                .frame(width: 200, height: 200)

                // Phase text
                VStack(spacing: 16) {
                    Text(phases[currentPhase])
                        .font(.custom("ProductSans-Bold", size: 22))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .opacity(phaseOpacity)
                        .animation(.easeInOut(duration: 0.3), value: phaseOpacity)

                    // Progress bar
                    progressBar
                }

                Spacer()
                Spacer()
            }
            .opacity(contentOpacity)
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToNext) {
            BadNewsResultsView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            notificationFeedback.prepare()
            startAnimations()
            startOrbitAnimation()
            startLoadingSequence()
        }
        .onDisappear {
            orbitTimer?.invalidate()
        }
    }

    // MARK: - Orbiting Pill
    func orbitingPill(index: Int) -> some View {
        let colors: [Color] = [
            AppColors.primary,
            Color(hex: "#FF6B6B"),
            Color(hex: "#4ECDC4"),
            Color(hex: "#45B7D1")
        ]

        let angle = (Double(index) * 90 + orbitRotation) * .pi / 180
        let radius: CGFloat = 80

        return Capsule()
            .fill(
                LinearGradient(
                    colors: [colors[index], colors[index].opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 12, height: 28)
            .shadow(color: colors[index].opacity(0.5), radius: 6, x: 0, y: 2)
            .offset(
                x: CGFloat(cos(angle)) * radius,
                y: CGFloat(sin(angle)) * radius
            )
            .rotationEffect(.degrees(Double(index) * 90 + orbitRotation + 90))
    }

    // MARK: - Progress Bar
    var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.surface(themeManager.colorScheme))
                    .frame(height: 12)

                // Progress fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * loadingProgress, height: 12)

                // Shimmer effect
                if loadingProgress < 1.0 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60, height: 12)
                        .offset(x: geometry.size.width * loadingProgress - 30)
                        .mask(
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: geometry.size.width * loadingProgress, height: 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                }
            }
        }
        .frame(height: 12)
        .padding(.horizontal, 60)
    }

    // MARK: - Animations
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.6)) {
            contentOpacity = 1
        }
    }

    private func startOrbitAnimation() {
        orbitTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            withAnimation(.linear(duration: 0.03)) {
                orbitRotation += 1.5
            }
        }
    }

    private func startLoadingSequence() {
        // Total duration: ~3.5 seconds
        let phaseDuration: Double = 0.8
        let totalPhases = phases.count

        // Progress animation
        for i in 0..<totalPhases {
            let delay = Double(i) * phaseDuration

            // Update phase text
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if i > 0 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        phaseOpacity = 0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        currentPhase = i
                        withAnimation(.easeIn(duration: 0.2)) {
                            phaseOpacity = 1
                        }
                    }
                }

                // Haptic tick
                let tick = UIImpactFeedbackGenerator(style: .light)
                tick.impactOccurred(intensity: 0.4 + CGFloat(i) * 0.15)
            }

            // Progress bar animation
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: phaseDuration)) {
                    loadingProgress = CGFloat(i + 1) / CGFloat(totalPhases)
                }
            }
        }

        // Calculate waste
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(totalPhases) * phaseDuration * 0.5) {
            onboardingData.calculateWaste()
        }

        // Completion
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(totalPhases) * phaseDuration + 0.3) {
            triggerCompletion()
        }
    }

    private func triggerCompletion() {
        // Success haptic
        notificationFeedback.notificationOccurred(.success)

        // Create burst particles
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2

        for _ in 0..<12 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...150)

            var particle = BurstParticle(
                x: centerX,
                y: centerY,
                targetX: centerX + cos(angle) * distance,
                targetY: centerY + sin(angle) * distance,
                size: CGFloat.random(in: 8...16),
                color: [AppColors.primary, Color(hex: "#4ECDC4"), Color(hex: "#FF6B6B")].randomElement() ?? AppColors.primary
            )
            burstParticles.append(particle)
        }

        showCompletionBurst = true

        // Animate burst
        withAnimation(.easeOut(duration: 0.5)) {
            for i in burstParticles.indices {
                burstParticles[i].x = burstParticles[i].targetX
                burstParticles[i].y = burstParticles[i].targetY
            }
        }

        // Fade out burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) {
                for i in burstParticles.indices {
                    burstParticles[i].opacity = 0
                }
            }
        }

        // Navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            navigateToNext = true
        }
    }
}

// MARK: - Burst Particle
struct BurstParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var targetX: CGFloat
    var targetY: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double = 1.0
}

#Preview {
    NavigationStack {
        CalculatingWasteView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
