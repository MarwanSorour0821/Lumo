//
//  OnboardingView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentImageIndex = 0
    @State private var isSignInModalVisible = false
    @State private var isGoogleLoading = false
    @State private var navigateToSignUp = false
    
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
                    isGoogleLoading: isGoogleLoading
                )
            }
            .navigationDestination(isPresented: $navigateToSignUp) {
                SignUpSexView(coordinator: SignUpFlowCoordinator())
            }
        }
    }
    
    // MARK: - Background
    var backgroundView: some View {
        Theme.colors.background
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
            Text("Top-class premium\nanalysis on your\nblood tests at your\nfinger tips.")
                .font(.custom("ProductSans-Regular", size: 40))
                .foregroundColor(Theme.colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .opacity(mainTextOpacity)
                .offset(y: mainTextOffset)
            
            Text("Create an account and join thousands of\npeople who are already using our app.")
                .font(.custom("ProductSans-Regular", size: 16))
                .foregroundColor(Theme.colors.secondaryText)
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
                    .foregroundColor(Theme.colors.buttonText)
                Spacer()
            }
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Theme.colors.button)
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
                    .foregroundColor(Theme.colors.secondaryText)
                Text("Sign in")
                    .font(.custom("ProductSans-Bold", size: 14))
                    .foregroundColor(.white)
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
                    gradient: Gradient(colors: [Theme.colors.background, Color.clear]),
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
                    print("Google sign-in successful: \(user.id)")
                    // TODO: Navigate to home or check if profile is complete
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
        .preferredColorScheme(.dark)
}
