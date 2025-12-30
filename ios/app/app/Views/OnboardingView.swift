//
//  OnboardingView.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import UIKit

// MARK: - Particle Model
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var speed: CGFloat
    var opacity: Double
}

// MARK: - Biomarker Burst Data
struct BiomarkerBurst: Identifiable {
    let id = UUID()
    let text: String
    let x: CGFloat
    let y: CGFloat
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isSignInModalVisible = false
    @State private var isGoogleLoading = false
    @State private var navigateToOpeningMoment = false
    @StateObject private var signUpCoordinator = SignUpFlowCoordinator()
    @State private var isSignedIn = false
    
    // Animation states
    @State private var mainTextOpacity: Double = 0
    @State private var mainTextOffset: CGFloat = 30
    @State private var buttonOpacity: Double = 0
    
    // Particle animation states
    @State private var particles: [Particle] = []
    @State private var currentBurst: BiomarkerBurst? = nil
    @State private var burstOpacity: Double = 0
    @State private var particleTimer: Timer? = nil
    @State private var burstTimer: Timer? = nil
    
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    // Biomarker texts for bursts
    let biomarkers = [
        "ApoB — Elevated ↑",
        "HbA1c — Normal",
        "LDL — High ↑",
        "Vitamin D — Low ↓",
        "CRP — Elevated ↑",
        "TSH — Normal",
        "Ferritin — Low ↓",
        "Triglycerides — High ↑"
    ]
    
    var body: some View {
        NavigationStack {
        ZStack {
            backgroundView
            particleView
            bottomSectionView
        }
        .onAppear {
            startAnimations()
            initializeParticles()
            startParticleAnimation()
            startBurstAnimation()
        }
        .onDisappear {
            particleTimer?.invalidate()
            burstTimer?.invalidate()
        }
        .sheet(isPresented: $isSignInModalVisible) {
                SignInModalView(
                    isPresented: $isSignInModalVisible,
                    onGoogleSignIn: {
                        handleGoogleSignIn()
                    },
                    isGoogleLoading: isGoogleLoading,
                    onSignInSuccess: { userId, email in
                        print("✅ Sign-in successful! User ID: \(userId), Email: \(email ?? "N/A")")
                        isSignedIn = true
                        // Update app state to reflect authentication
                        appState.isAuthenticated = true
                    }
                )
                .environmentObject(themeManager)
            }
            .navigationDestination(isPresented: $navigateToOpeningMoment) {
                OpeningMomentView(coordinator: signUpCoordinator)
            }
        }
    }
    
    // MARK: - Background
    var backgroundView: some View {
        AppColors.background(themeManager.colorScheme)
            .ignoresSafeArea()
    }
    
    // MARK: - Particle View
    var particleView: some View {
        ZStack {
            // Floating particles
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
            }
            
            // Biomarker burst text
            if let burst = currentBurst {
                Text(burst.text)
                    .font(.custom("ProductSans-Bold", size: 14))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.surface(themeManager.colorScheme))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .position(x: burst.x, y: burst.y)
                    .opacity(burstOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    // MARK: - Bottom Section
    var bottomSectionView: some View {
        VStack {
            Spacer()
            bottomContent
        }
    }
    
    var bottomContent: some View {
        VStack(spacing: 0) {
            textContent
            getStartedButton
                .padding(.bottom, 16)
                .opacity(buttonOpacity)
            signInLink
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    var textContent: some View {
        VStack(spacing: 24) {
            Text("Get actionable insights to improve your biomarkers.")
                .font(.custom("ProductSans-Regular", size: 30))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .opacity(mainTextOpacity)
                .offset(y: mainTextOffset)
        }
        .padding(.bottom, 32)
    }
    
    var getStartedButton: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            DispatchQueue.main.async {
                navigateToOpeningMoment = true
            }
        }) {
            HStack {
                Spacer()
                Text("Start here")
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(.white)
                Spacer()
            }
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(AppColors.primary)
            )
            .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
        }
    }
    
    var signInLink: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            isSignInModalVisible = true
        }) {
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                Text("Sign in")
                    .font(.custom("ProductSans-Bold", size: 14))
                    .foregroundColor(AppColors.primary)
            }
        }
        .opacity(buttonOpacity)
    }
    
    // MARK: - Particle Initialization
    private func initializeParticles() {
        // Use only the app primary color (red) for all particles, with slight opacity variations
        let base = AppColors.primary
        let particleColors: [Color] = [
            base,
            base.opacity(0.9),
            base.opacity(0.8),
            base.opacity(0.7),
            base.opacity(0.6)
        ]

        particles = (0..<25).map { _ in
            Particle(
                x: CGFloat.random(in: 20...(screenWidth - 20)),
                y: CGFloat.random(in: 100...(screenHeight - 300)),
                size: CGFloat.random(in: 4...10),
                color: particleColors.randomElement() ?? base,
                speed: CGFloat.random(in: 0.3...0.8),
                opacity: Double.random(in: 0.4...0.8)
            )
        }
    }
    
    // MARK: - Particle Animation
    private func startParticleAnimation() {
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                for i in particles.indices {
                    // Move particles upward slowly
                    particles[i].y -= particles[i].speed
                    
                    // Add slight horizontal drift
                    particles[i].x += CGFloat.random(in: -0.3...0.3)
                    
                    // Wrap around when particle goes off top
                    if particles[i].y < 50 {
                        particles[i].y = screenHeight - 250
                        particles[i].x = CGFloat.random(in: 20...(screenWidth - 20))
                    }
                    
                    // Keep within horizontal bounds
                    particles[i].x = max(20, min(screenWidth - 20, particles[i].x))
                }
            }
        }
    }
    
    // MARK: - Burst Animation
    private func startBurstAnimation() {
        // Initial delay before first burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            triggerBurst()
        }
        
        // Repeat burst every 2.5-3.5 seconds
        burstTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            triggerBurst()
        }
    }
    
    private func triggerBurst() {
        // Pick a random particle to "burst"
        guard let randomIndex = particles.indices.randomElement() else { return }
        let particle = particles[randomIndex]
        
        // Create burst at particle position (slightly above)
        let burst = BiomarkerBurst(
            text: biomarkers.randomElement() ?? "ApoB — Elevated ↑",
            x: min(max(particle.x, 80), screenWidth - 80), // Keep within bounds
            y: particle.y - 30
        )
        
        // Provide soft haptic feedback when the burst is shown
        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.prepare()
        
        // Show burst
        currentBurst = burst
        withAnimation(.easeOut(duration: 0.3)) {
            burstOpacity = 1.0
        }
        // Trigger the haptic after the animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            impactFeedback.impactOccurred()
        }
        
        // Pulse the particle
        withAnimation(.easeInOut(duration: 0.15)) {
            particles[randomIndex].opacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if randomIndex < particles.count {
                    particles[randomIndex].opacity = Double.random(in: 0.3...0.7)
                }
            }
        }
        
        // Fade out burst after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                burstOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentBurst = nil
            }
        }
    }
    
    // MARK: - Animations
    func startAnimations() {
        // Main headline fades in quickly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                mainTextOpacity = 1
                mainTextOffset = 0
            }
        }
        
        // Button fades in after headline
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                buttonOpacity = 1
            }
        }
    }
    
    // MARK: - Google Sign In Handler
    private func handleGoogleSignIn() {
        isGoogleLoading = true
        isSignInModalVisible = false
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            let response = await AuthService.shared.signInWithGoogle()
            
            await MainActor.run {
                isGoogleLoading = false
                
                if let error = response.error {
                    if error.message != "Sign in cancelled" {
                        print("Google sign-in error: \(error.message)")
                    }
                } else if let user = response.user {
                    print("✅ Google sign-in successful! User ID: \(user.id), Email: \(user.email ?? "N/A")")
                    isSignedIn = true
                    // Update app state to reflect authentication
                    appState.isAuthenticated = true
                }
            }
        }
    }
}

// Updated: Opening Moment screen with radial gradient semicircle at the bottom
struct OpeningMomentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var navigateToSex = false
    @State private var initialTextVisible = false
    @State private var showAdditionalText = false
    @State private var appendedOpacity: Double = 0.0
    @State private var headingBlur: CGFloat = 8

    var body: some View {
        // Removed nested NavigationView to prevent duplicate back buttons when this view
        // is presented inside a parent NavigationStack. Rely on the parent NavigationStack's
        // navigation bar and attach toolbar items directly to this view.
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // background accent removed
            EmptyView()

            // Content stacked above the radial gradient semicircle
            VStack {
                Spacer() // push headline toward vertical center

                HStack {
                    // Headline placed centered vertically but left-aligned horizontally
                    VStack(alignment: .leading, spacing: 0) {
                        let mainText = "You probably feel fine right now. Most people do."
                        let appendedText = " But feeling fine isn’t the same as being healthy. That difference lives in your blood."

                        (Text(mainText)
                            .font(.custom("ProductSans-Bold", size: 36))
                            .foregroundColor(showAdditionalText ? AppColors.textSecondary(themeManager.colorScheme) : AppColors.text(themeManager.colorScheme))
                         + Text(appendedText)
                            .font(.custom("ProductSans-Bold", size: 36))
                            .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(appendedOpacity))
                        )
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        // Fade in initial text (no scale)
                        .blur(radius: headingBlur)
                        .opacity(initialTextVisible ? 1 : 0)
                        .offset(y: initialTextVisible ? (showAdditionalText ? -12 : 0) : 20)
                        .animation(.easeOut(duration: 0.6), value: initialTextVisible)
                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: showAdditionalText)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeOut(duration: 0.6)) {
                                    initialTextVisible = true
                                    headingBlur = 0
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                }

                Spacer()

                NavigationLink(destination: TellHealthView(coordinator: coordinator), isActive: $navigateToSex) { EmptyView() }

                // Begin button (full width) placed at the bottom
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    if (!showAdditionalText) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            showAdditionalText = true
                            appendedOpacity = 1.0
                        }
                    } else {
                        navigateToSex = true
                    }
                }) {
                    HStack {
                        Spacer()
                        Text(showAdditionalText ? "Tell Us Your Health Story" : "Next")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 28).fill(AppColors.primary))
                    .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // Helper to construct attributed headline so the appended copy appears inline and parts can differ in color/opacity
    private func makeHeadlineAttributed(showAdditional: Bool, scheme: ColorScheme?) -> AttributedString {
        let mainText = "Your blood tells a story. We help you read it."
        let appended = " This takes about 60 seconds. Everything you share stays private."

        let font = UIFont(name: "ProductSans-Bold", size: 36) ?? UIFont.boldSystemFont(ofSize: 36)
        let mainColor = UIColor(showAdditional ? AppColors.textSecondary(scheme) : AppColors.text(scheme))
        let appendedColor = UIColor(AppColors.text(scheme))

        let mutable = NSMutableAttributedString()
        let mainAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: mainColor
        ]
        let appendAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: appendedColor.withAlphaComponent(showAdditional ? 1.0 : 0.0)
        ]

        mutable.append(NSAttributedString(string: mainText, attributes: mainAttrs))
        mutable.append(NSAttributedString(string: appended, attributes: appendAttrs))

        return AttributedString(mutable)
    }

    // Gradient colors adapt to light/dark mode
    private func triangleGradientColors(for scheme: ColorScheme?) -> [Color] {
        let isDark = (scheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)) == .dark
        if isDark {
            return [Color.white.opacity(0.14), Color.white.opacity(0.04), Color.clear]
        } else {
            return [Color.black.opacity(0.06), Color.black.opacity(0.03), Color.clear]
        }
    }
}

// Triangle shape with point at top center and base at bottom
struct BottomTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // top center
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // bottom right
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // bottom left
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview {
        OnboardingView()
            .environmentObject(ThemeManager.shared)
}
