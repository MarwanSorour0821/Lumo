//
//  StatisticsOnboardingView.swift
//  app
//
//  A simple statistics page shown after the user taps "Get Started"
//

import SwiftUI
import UIKit

// MARK: - Star Particle for Background
struct StarParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

struct StatisticsOnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState

    // Navigation
    @State private var navigateToMedicationSelection = false

    // Animation states
    @State private var contentBlur: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var starsOpacity: Double = 0

    // Star particles for background
    @State private var stars: [StarParticle] = []
    @State private var starAnimationTimer: Timer?

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            // Radial gradient "light" effect from top
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(0.3),
                    AppColors.primary.opacity(0.1),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.7
            )
            .ignoresSafeArea()

            // Star particles
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
                    .opacity(star.opacity * starsOpacity)
            }

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Statistics text - bigger font
                VStack(spacing: 8) {
                    (Text("On average, ")
                        .foregroundColor(.white) +
                     Text("40-50%")
                        .foregroundColor(AppColors.primary) +
                     Text(" of people forget to take their ")
                        .foregroundColor(.white) +
                     Text("medication")
                        .foregroundColor(AppColors.primary))
                        .font(.custom("ProductSans-Bold", size: 34))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 28)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)

                // Icon/mascot - pill icon
                Image(systemName: "pills.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 48)
                    .blur(radius: contentBlur)
                    .opacity(contentOpacity)

                Spacer()
                Spacer()

                // Source citation
                Text("Source: National Institutes of Health (NIH)")
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(Color.white.opacity(0.5))
                    .blur(radius: buttonBlur)
                    .opacity(buttonOpacity)
                    .padding(.bottom, 24)

                // Continue button with app primary color
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    navigateToMedicationSelection = true
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
        .navigationDestination(isPresented: $navigateToMedicationSelection) {
            MedicationSelectionView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            initializeStars()
            startAnimations()
            startStarAnimation()
        }
        .onDisappear {
            starAnimationTimer?.invalidate()
        }
    }

    private func initializeStars() {
        stars = (0..<50).map { _ in
            StarParticle(
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.2...0.8)
            )
        }
    }

    private func startAnimations() {
        // Stars fade in first
        withAnimation(.easeOut(duration: 0.8)) {
            starsOpacity = 1
        }

        // Main content blurs in
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            contentBlur = 0
            contentOpacity = 1
        }

        // Button blurs in
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    private func startStarAnimation() {
        starAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in stars.indices {
                withAnimation(.linear(duration: 0.05)) {
                    stars[i].y -= stars[i].opacity * 0.3
                    stars[i].x += CGFloat.random(in: -0.2...0.2)

                    if stars[i].y < 0 {
                        stars[i].y = screenHeight
                        stars[i].x = CGFloat.random(in: 0...screenWidth)
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
