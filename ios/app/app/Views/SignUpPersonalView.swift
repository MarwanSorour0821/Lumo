//
//  SignUpPersonalView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

// Custom enum for autocapitalization to bridge SwiftUI and UIKit
enum TextInputAutocapitalization: Equatable {
    case never
    case words
    case sentences
    case allCharacters
    
    var uiTextAutocapitalizationType: UITextAutocapitalizationType {
        switch self {
        case .never: return .none
        case .words: return .words
        case .sentences: return .sentences
        case .allCharacters: return .allCharacters
        }
    }
}


struct SignUpPersonalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var firstNameError: String?
    @State private var isGoogleLoading = false
    @State private var isAppleLoading = false
    @State private var navigateToCredentials = false
    
    @State private var headingOpacity: Double = 0
    @State private var inputsOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Heading
                        Text("What should we call you?")
                            .font(.custom("ProductSans-Regular", size: 40))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(headingOpacity)
                            .padding(.top, 32)
                            .padding(.bottom, 40)
                        
                        // Inputs
                        VStack(spacing: 20) {
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.7))
                                
                                ZStack(alignment: .leading) {
                                    TextField("", text: $firstName)
                                        .font(.custom("ProductSans-Regular", size: 17))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        .autocapitalization(.words)
                                        .autocorrectionDisabled()
                                        .textContentType(.givenName)
                                        .padding()
                                        .overlay(
                                            Group {
                                                if firstName.isEmpty {
                                                    HStack {
                                                        Text("John")
                                                            .font(.custom("ProductSans-Regular", size: 17))
                                                            .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.4))
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .allowsHitTesting(false)
                                                }
                                            },
                                            alignment: .leading
                                        )
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.surface(themeManager.colorScheme).opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(firstNameError != nil ? Color.red : Color.clear, lineWidth: 1)
                                )
                                
                                if let error = firstNameError {
                                    Text(error)
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name (Optional)")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.7))
                                
                                ZStack(alignment: .leading) {
                                    TextField("", text: $lastName)
                                        .font(.custom("ProductSans-Regular", size: 17))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        .autocapitalization(.words)
                                        .autocorrectionDisabled()
                                        .textContentType(.familyName)
                                        .padding()
                                        .overlay(
                                            Group {
                                                if lastName.isEmpty {
                                                    HStack {
                                                        Text("Doe")
                                                            .font(.custom("ProductSans-Regular", size: 17))
                                                            .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.4))
                                                        Spacer()
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .allowsHitTesting(false)
                                                }
                                            },
                                            alignment: .leading
                                        )
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.surface(themeManager.colorScheme).opacity(0.1))
                                )
                            }
                        }
                        .opacity(inputsOpacity)
                        .padding(.bottom, 32)
                        
                        // Google Sign In Button
                        GoogleSignInButton(
                            onPress: {
                                handleGoogleSignIn()
                            },
                            loading: isGoogleLoading
                        )
                        .opacity(buttonOpacity)
                        .padding(.bottom, 10)
                        
                        // Apple Sign In Button
                        AppleSignInButton(
                            onPress: {
                                handleAppleSignIn()
                            },
                            loading: isAppleLoading
                        )
                        .opacity(buttonOpacity)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100) // Extra padding for bottom buttons
                }
            }
            
            // Bottom Navigation Buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 16) {
                        // Back Button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(AppColors.surface(themeManager.colorScheme))
                                )
                        }
                        .applyGlassButtonStyle()
                        .clipShape(Circle())
                        
                        // Next Button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            handleContinue()
                        }) {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 24)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color(hex: "#B01328"))
                            )
                            .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .navigationBarBackButtonHidden(true) // Hide top back button, use bottom button
        .toolbar {
            ToolbarItem(placement: .principal) {
                ProgressBar(currentStep: 5, totalSteps: 7)
            }
        }
        .onAppear {
            startAnimations()
        }
        .navigationDestination(isPresented: $navigateToCredentials) {
            SignUpCredentialsView(coordinator: coordinator)
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            headingOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            inputsOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            buttonOpacity = 1
        }
    }
    
    private func validateForm() -> Bool {
        firstNameError = nil
        
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            firstNameError = "First name is required"
            return false
        }
        
        return true
    }
    
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if validateForm() {
            coordinator.updateFirstName(firstName.trimmingCharacters(in: .whitespaces))
            coordinator.updateLastName(lastName.trimmingCharacters(in: .whitespaces))
            coordinator.nextStep()
            navigateToCredentials = true
        }
    }
    
    private func handleGoogleSignIn() {
        // Save the name data first
        if !firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            coordinator.updateFirstName(firstName.trimmingCharacters(in: .whitespaces))
        }
        if !lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            coordinator.updateLastName(lastName.trimmingCharacters(in: .whitespaces))
        }
        
        isGoogleLoading = true
        
        Task {
            let response = await AuthService.shared.signInWithGoogle()
            
            await MainActor.run {
                isGoogleLoading = false
                
                if let error = response.error {
                    if error.message != "Sign in cancelled" {
                        print("Google sign-in error: \(error.message)")
                    }
                } else if let user = response.user {
                    print("✅ Google sign-in successful: \(user.id)")
                    
                    // Store OAuth user info
                    coordinator.signUpData.userId = user.id
                    coordinator.signUpData.email = user.email
                    coordinator.signUpData.isOAuthSignIn = true
                    
                    // Use OAuth name if user didn't provide one
                    if coordinator.signUpData.firstName == nil && user.firstName != nil {
                        coordinator.updateFirstName(user.firstName!)
                    }
                    if coordinator.signUpData.lastName == nil && user.lastName != nil {
                        coordinator.updateLastName(user.lastName!)
                    }
                    
                    // Now create the profile with collected signup data
                    createOAuthProfile(userId: user.id, email: user.email)
                }
            }
        }
    }
    
    private func handleAppleSignIn() {
        // Save the name data first
        if !firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            coordinator.updateFirstName(firstName.trimmingCharacters(in: .whitespaces))
        }
        if !lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            coordinator.updateLastName(lastName.trimmingCharacters(in: .whitespaces))
        }
        
        isAppleLoading = true
        
        Task {
            let response = await AuthService.shared.signInWithApple()
            
            await MainActor.run {
                isAppleLoading = false
                
                if let error = response.error {
                    if error.message != "Sign in cancelled" {
                        print("Apple sign-in error: \(error.message)")
                    }
                } else if let user = response.user {
                    print("✅ Apple sign-in successful: \(user.id)")
                    
                    // Store OAuth user info
                    coordinator.signUpData.userId = user.id
                    coordinator.signUpData.email = user.email
                    coordinator.signUpData.isOAuthSignIn = true
                    
                    // Use OAuth name if user didn't provide one
                    if coordinator.signUpData.firstName == nil && user.firstName != nil {
                        coordinator.updateFirstName(user.firstName!)
                    }
                    if coordinator.signUpData.lastName == nil && user.lastName != nil {
                        coordinator.updateLastName(user.lastName!)
                    }
                    
                    // Now create the profile with collected signup data
                    createOAuthProfile(userId: user.id, email: user.email)
                }
            }
        }
    }
    
    private func createOAuthProfile(userId: String, email: String?) {
        Task {
            // Check if we have all required data
            guard let sex = coordinator.signUpData.sex,
                  let ageString = coordinator.signUpData.age,
                  let age = Int(ageString),
                  let heightString = coordinator.signUpData.height,
                  let height = Double(heightString),
                  let weightString = coordinator.signUpData.weight,
                  let weight = Double(weightString) else {
                print("❌ Missing required signup data for OAuth profile")
                return
            }
            
            // Calculate date of birth from age
            let calendar = Calendar.current
            let today = Date()
            let birthYear = calendar.component(.year, from: today) - age
            let dateOfBirth = calendar.date(from: DateComponents(year: birthYear, month: calendar.component(.month, from: today), day: calendar.component(.day, from: today))) ?? today
            
            let heightCm = height
            
            // Convert weight to kg if needed
            var weightKg = weight
            if coordinator.signUpData.weightUnit == "lbs" {
                weightKg = weightKg * 0.453592
            }
            
            print("🔵 Creating OAuth user profile...")
            let profileResponse = await AuthService.shared.createUserProfile(
                userId: userId,
                biologicalSex: sex.rawValue,
                dateOfBirth: dateOfBirth,
                heightCm: heightCm,
                weightKg: weightKg,
                firstName: coordinator.signUpData.firstName,
                lastName: coordinator.signUpData.lastName,
                email: email,
                healthConditions: coordinator.signUpData.healthConditions
            )
            
            await MainActor.run {
                if let error = profileResponse.error {
                    print("❌ OAuth profile creation failed: \(error.message)")
                } else {
                    print("✅ OAuth profile created successfully!")
                    // Update app state to reflect authentication
                    appState.isAuthenticated = true
                }
            }
            
            // Load user data after profile creation
            if profileResponse.error == nil {
                await UserDataViewModel.shared.loadAllUserData()
            }
        }
    }
}

// MARK: - Underline Input Field
struct UnderlineInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var error: String?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var isSecure: Bool = false
    
    private var uiAutocapitalization: UITextAutocapitalizationType {
        autocapitalization.uiTextAutocapitalizationType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(.white)
                        .keyboardType(keyboardType)
                        .autocapitalization(uiAutocapitalization)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: $text)
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(.white)
                        .keyboardType(keyboardType)
                        .autocapitalization(uiAutocapitalization)
                        .autocorrectionDisabled()
                }
            }
            .padding(.vertical, 12)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(error != nil ? Color.red : Color.white.opacity(0.3))
                    .offset(y: 20),
                alignment: .bottom
            )
            
            if let error = error {
                Text(error)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }
}

// Compatibility helper for the iOS 26 `.glass` button style
extension View {
    @ViewBuilder
    func applyGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(PlainButtonStyle())
        }
    }
}

