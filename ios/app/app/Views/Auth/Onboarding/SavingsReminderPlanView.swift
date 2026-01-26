//
//  SavingsReminderPlanView.swift
//  app
//
//  Screen showing savings potential and reminder plan explanation
//

import SwiftUI

struct SavingsReminderPlanView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared
    
    // Navigation
    @State private var navigateToNotifications = false
    @State private var navigateToSignUp = false
    
    // Selected medications from previous step
    let selectedMedications: [String]
    
    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var savingsOpacity: Double = 0
    @State private var savingsScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Haptic generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    private var isDarkMode: Bool {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark
    }
    
    private var savingsAmount: Int {
        Int(onboardingData.potentialSavingsPerYear)
    }
    
    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()
            
            // Gradient effect
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(isDarkMode ? 0.2 : 0.1),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.6
            )
            .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Savings amount display
                VStack(spacing: 12) {
                    Text("Lumo can help you make sure")
                        .font(.custom("ProductSans-Regular", size: 26))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("you get back your")
                            .font(.custom("ProductSans-Regular", size: 26))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text("$\(savingsAmount)")
                            .font(.custom("ProductSans-Bold", size: 48))
                            .foregroundColor(AppColors.primary)
                    }
                    .opacity(savingsOpacity)
                    .scaleEffect(savingsScale)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 40)
                
                // Explanation text
                VStack(spacing: 16) {
                    Text("We will configure a supplement reminder plan that ensures none of your supplements go to waste.")
                        .font(.custom("ProductSans-Regular", size: 18))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(textOpacity)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    impactFeedback.impactOccurred()
                    navigateToNotifications = true
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
                            .fill(AppColors.primary)
                    )
                    .shadow(color: AppColors.primary.opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden(false)
        .fullScreenCover(isPresented: $navigateToNotifications) {
            NotificationPermissionView(
                isPresented: $navigateToNotifications,
                isPostSignUp: false,
                onEnableNotifications: { level in
                    print("✅ Notifications enabled with level: \(level.displayName)")
                }
            )
            .environmentObject(themeManager)
            .onDisappear {
                // After notification prompt is dismissed, navigate to sign up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToSignUp = true
                }
            }
        }
        .navigationDestination(isPresented: $navigateToSignUp) {
            SignUpOnboardingView(selectedMedications: selectedMedications)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animations
    private func startAnimations() {
        // Text appears
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            textOpacity = 1
        }
        
        // Savings amount animates in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
            savingsOpacity = 1
            savingsScale = 1.0
        }
        
        // Button appears
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonOpacity = 1
        }
    }
}

#Preview {
    NavigationStack {
        SavingsReminderPlanView(selectedMedications: ["Vitamin D", "Magnesium"])
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
