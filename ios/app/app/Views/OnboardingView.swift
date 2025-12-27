//
//  OnboardingView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentImageIndex = 0
    @State private var isSignInModalVisible = false
    @State private var isGoogleLoading = false
    @State private var navigateToSignUp = false
    @State private var isSignedIn = false
    
    // Animation states
    @State private var mainTextOpacity: Double = 0
    @State private var mainTextOffset: CGFloat = 30
    @State private var subTextOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    // Image names - must match Assets.xcassets names
    let images = ["Group6", "iPhone14"]
    let screenWidth = UIScreen.main.bounds.width
    
    var body: some View {
        NavigationStack {
        ZStack {
            backgroundView
            mainContentView
            bottomSectionView
        }
        .onAppear {
            startAnimations()
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
            .navigationDestination(isPresented: $navigateToSignUp) {
                SignUpSexView(coordinator: SignUpFlowCoordinator())
            }
            // Navigation to HomeView is now handled by AppState in RootView
            // When isSignedIn becomes true, AppState.isAuthenticated is set to true
            // and RootView will automatically show HomeView
        }
    }
    
    // MARK: - Background
    var backgroundView: some View {
        AppColors.background(themeManager.colorScheme)
            .ignoresSafeArea()
    }
    
    // MARK: - Main Content
    var mainContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                imageSliderView
                    .padding(.top, 60)
                    .padding(.bottom, 32)
                
                    Spacer()
                        .frame(height: 250)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
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
            Text("Understand your blood.\nTake control of your health.")
                .font(.custom("ProductSans-Regular", size: 30))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .opacity(mainTextOpacity)
                .offset(y: mainTextOffset)
            
            Text("Create an account and join thousands of\npeople who are already using our app.")
                .font(.custom("ProductSans-Regular", size: 16))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(subTextOpacity)
        }
        .padding(.bottom, 32)
    }
    
    var getStartedButton: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            // Navigate to sign-up flow
            DispatchQueue.main.async {
                navigateToSignUp = true
            }
        }) {
            HStack {
                Spacer()
                Text("Get Started")
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
    
    // MARK: - Image Slider
    var imageSliderView: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                TabView(selection: $currentImageIndex) {
                    ForEach(0..<images.count, id: \.self) { index in
                        Image(images[index])
                            .resizable()
                            .aspectRatio(contentMode: index == 0 ? .fill : .fit)
                            .frame(width: screenWidth - 60, height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: screenWidth - 60, height: 260)
                
                // Bottom gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.background(themeManager.colorScheme), Color.clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(width: screenWidth - 60, height: 150)
                .allowsHitTesting(false)
            }
            .frame(width: screenWidth - 60, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Pagination Dots
            HStack(spacing: 8) {
                ForEach(0..<images.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == currentImageIndex ? Color(hex: "#B01328") : Color.white.opacity(0.3))
                        .frame(width: index == currentImageIndex ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentImageIndex)
                }
            }
        }
    }
    
    // MARK: - Animations
    func startAnimations() {
        // Main text animation
        withAnimation(.easeOut(duration: 0.8)) {
            mainTextOpacity = 1
            mainTextOffset = 0
        }
        
        // Sub text animation
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            subTextOpacity = 1
        }
        
        // Button animation
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            buttonOpacity = 1
        }
    }
    
    // MARK: - Google Sign In Handler
    private func handleGoogleSignIn() {
        isGoogleLoading = true
        
        // Close the modal first - ASWebAuthenticationSession can't present over a sheet
        isSignInModalVisible = false
        
        // Wait for the modal to fully dismiss before starting OAuth
        Task {
            // Wait a bit for the modal to dismiss
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Now start the OAuth flow
            let response = await AuthService.shared.signInWithGoogle()
            
            await MainActor.run {
                isGoogleLoading = false
                
                if let error = response.error {
                    // Only show error if not cancelled by user
                    if error.message != "Sign in cancelled" {
                        print("Google sign-in error: \(error.message)")
                    }
                } else if let user = response.user {
                    // Handle successful sign-in
                    print("✅ Google sign-in successful! User ID: \(user.id), Email: \(user.email ?? "N/A")")
                    isSignedIn = true
                }
            }
    }
}
}

// MARK: - Preview
#Preview {
        OnboardingView()
            .environmentObject(ThemeManager.shared)
}
