//
//  AbsorptionWarningView.swift
//  app
//
//  Educational screen about supplement interactions blocking absorption
//

import SwiftUI
import UIKit

struct AbsorptionWarningView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState

    // Navigation
    @State private var navigateToNext = false

    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var contentBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20

    // Pill collision animation
    @State private var leftPillX: CGFloat = -60
    @State private var rightPillX: CGFloat = 60
    @State private var collisionScale: CGFloat = 1.0
    @State private var showCollisionEffect = false
    @State private var collisionOpacity: Double = 0
    @State private var shakeOffset: CGFloat = 0

    // Blocked text animation
    @State private var blockedTextScale: CGFloat = 0
    @State private var blockedTextOpacity: Double = 0

    // Falling waste particles
    @State private var wasteParticles: [WasteParticle] = []
    @State private var particleTimer: Timer?

    // Haptic generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
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

            // Warning gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FF6B6B").opacity(isDarkMode ? 0.2 : 0.1),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: screenHeight * 0.5
            )
            .ignoresSafeArea()

            // Falling waste particles
            ForEach(wasteParticles) { particle in
                Circle()
                    .fill(Color.gray.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(x: particle.x, y: particle.y)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Pill collision visualization
                ZStack {
                    // Collision burst effect
                    if showCollisionEffect {
                        ForEach(0..<8) { i in
                            Circle()
                                .fill(Color(hex: "#FF6B6B").opacity(0.6))
                                .frame(width: 8, height: 8)
                                .offset(
                                    x: cos(CGFloat(i) * .pi / 4) * 50 * collisionScale,
                                    y: sin(CGFloat(i) * .pi / 4) * 50 * collisionScale
                                )
                                .opacity(collisionOpacity)
                        }
                    }

                    // Left pill (Calcium)
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 35, height: 70)
                            .shadow(color: Color(hex: "#FF6B6B").opacity(0.5), radius: 10, x: 0, y: 5)
                            .rotationEffect(.degrees(-20))

                        Text("Iron")
                            .font(.custom("ProductSans-Bold", size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .offset(x: leftPillX + shakeOffset)

                    // Collision X mark
                    if showCollisionEffect {
                        Image(systemName: "xmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                            .scaleEffect(blockedTextScale)
                            .opacity(blockedTextOpacity)
                    }

                    // Right pill (Iron)
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#4ECDC4"), Color(hex: "#7EDDD6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 35, height: 70)
                            .shadow(color: Color(hex: "#4ECDC4").opacity(0.5), radius: 10, x: 0, y: 5)
                            .rotationEffect(.degrees(20))

                        Text("Calcium")
                            .font(.custom("ProductSans-Bold", size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .offset(x: rightPillX - shakeOffset)
                }
                .frame(height: 150)
                .scaleEffect(collisionScale)

                Spacer()
                    .frame(height: 50)

                // Warning text
                VStack(spacing: 16) {
                    Text("Some supplements")
                        .font(.custom("ProductSans-Regular", size: 28))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                    Text("block each other")
                        .font(.custom("ProductSans-Bold", size: 32))
                        .foregroundColor(Color(hex: "#FF6B6B"))

                    Text("When taken together, they compete for absorption.\nYour body can't use them properly.")
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 30)

                // Visual waste indicator
                HStack(spacing: 24) {
                    wasteIndicator(icon: "pills.fill", text: "Pills become waste")
                    wasteIndicator(icon: "dollarsign.circle.fill", text: "Money down the drain")
                }
                .blur(radius: contentBlur * 0.5)
                .opacity(contentOpacity)

                Spacer()

                // Continue button
                Button(action: {
                    impactFeedback.impactOccurred()
                    navigateToNext = true
                }) {
                    HStack {
                        Spacer()
                        Text("See my impact")
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
            CalculatingWasteView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            notificationFeedback.prepare()
            startAnimations()
        }
        .onDisappear {
            particleTimer?.invalidate()
        }
    }

    // MARK: - Waste Indicator
    func wasteIndicator(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FF6B6B").opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FF6B6B"))
            }

            Text(text)
                .font(.custom("ProductSans-Regular", size: 13))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(width: 120)
    }

    // MARK: - Animations
    private func startAnimations() {
        // Content fades in
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            contentBlur = 0
            contentOpacity = 1
        }

        // Pills collide animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.4)) {
                leftPillX = -15
                rightPillX = 15
            }
        }

        // Collision impact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Heavy impact haptic
            let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
            heavyImpact.impactOccurred()

            showCollisionEffect = true

            // Shake effect
            withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
                shakeOffset = 5
            }

            // Scale bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                collisionScale = 1.1
            }

            // Collision burst
            withAnimation(.easeOut(duration: 0.3)) {
                collisionOpacity = 1
            }

            // X mark appears
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                blockedTextScale = 1.0
                blockedTextOpacity = 1.0
            }

            // Warning haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                notificationFeedback.notificationOccurred(.error)
            }
        }

        // Settle collision
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                collisionScale = 1.0
                shakeOffset = 0
            }

            // Fade out burst
            withAnimation(.easeOut(duration: 0.5)) {
                collisionOpacity = 0
            }

            // Start waste particles
            startWasteParticles()
        }

        // Button fades in
        withAnimation(.easeOut(duration: 0.6).delay(1.5)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    private func startWasteParticles() {
        // Create initial particles falling from collision point
        let centerY = screenHeight * 0.3

        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                let particle = WasteParticle(
                    x: screenWidth / 2 + CGFloat.random(in: -30...30),
                    y: centerY,
                    size: CGFloat.random(in: 6...12),
                    speed: CGFloat.random(in: 2...4),
                    opacity: Double.random(in: 0.3...0.6)
                )
                wasteParticles.append(particle)

                // Soft haptic for each particle
                let soft = UIImpactFeedbackGenerator(style: .soft)
                soft.impactOccurred(intensity: 0.3)
            }
        }

        // Animate particles falling
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            for i in wasteParticles.indices {
                withAnimation(.linear(duration: 0.03)) {
                    wasteParticles[i].y += wasteParticles[i].speed
                    wasteParticles[i].x += CGFloat.random(in: -0.5...0.5)
                    wasteParticles[i].opacity *= 0.99
                }
            }
            wasteParticles.removeAll { $0.y > screenHeight || $0.opacity < 0.1 }
        }
    }
}

// MARK: - Waste Particle
struct WasteParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var opacity: Double
}

#Preview {
    NavigationStack {
        AbsorptionWarningView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
