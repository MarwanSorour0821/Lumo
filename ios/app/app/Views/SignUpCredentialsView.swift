//
//  SignUpCredentialsView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SignUpCredentialsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    @State private var isCreatingAccount = false
    @State private var showError: String?
    
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
                        Text("Save your progress")
                            .font(.custom("ProductSans-Regular", size: 40))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(headingOpacity)
                            .padding(.top, 32)
                            .padding(.bottom, 40)
                        
                        // Inputs
                        VStack(spacing: 20) {
                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your email")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.7))
                                
                                ZStack(alignment: .leading) {
                                    TextField("", text: $email)
                                        .font(.custom("ProductSans-Regular", size: 17))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textContentType(.username)
                                        .tint(AppColors.text(themeManager.colorScheme))
                                        .padding()
                                        .overlay(
                                            Group {
                                                if email.isEmpty {
                                                    HStack {
                                                        Text("Your email")
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
                                        .fill(AppColors.background(themeManager.colorScheme).opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(emailError != nil ? Color.red : Color.clear, lineWidth: 1)
                                )
                                
                                if let error = emailError {
                                    Text(error)
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.7))
                                
                                ZStack(alignment: .leading) {
                                    SecureField("", text: $password)
                                        .font(.custom("ProductSans-Regular", size: 17))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .textContentType(.newPassword)
                                        .padding()
                                        .overlay(
                                            Group {
                                                if password.isEmpty {
                                                    HStack {
                                                        Text("Enter your password")
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
                                        .fill(AppColors.background(themeManager.colorScheme).opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(passwordError != nil ? Color.red : Color.clear, lineWidth: 1)
                                )
                                
                                if let error = passwordError {
                                    Text(error)
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme).opacity(0.7))
                                
                                ZStack(alignment: .leading) {
                                    SecureField("", text: $confirmPassword)
                                        .font(.custom("ProductSans-Regular", size: 17))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .textContentType(.none)
                                        .padding()
                                        .overlay(
                                            Group {
                                                if confirmPassword.isEmpty {
                                                    HStack {
                                                        Text("Confirm your password")
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
                                        .fill(AppColors.background(themeManager.colorScheme).opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(confirmPasswordError != nil ? Color.red : Color.clear, lineWidth: 1)
                                )
                                
                                if let error = confirmPasswordError {
                                    Text(error)
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .opacity(inputsOpacity)
                        .padding(.bottom, 100) // Extra padding for bottom buttons
                    }
                    .padding(.horizontal, 24)
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
                                        .fill(AppColors.background(themeManager.colorScheme))
                                )
                        }
                        //.buttonStyle(.glass)
                        .applyGlassButtonStyle()
                        .clipShape(Circle())
                        
                        // Next Button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            handleContinue()
                        }) {
                            HStack(spacing: 8) {
                                if isCreatingAccount {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create")
                                        .font(.custom("ProductSans-Bold", size: 16))
                                        .foregroundColor(.white)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color(hex: "#B01328"))
                            )
                            .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                        }
                        .disabled(isCreatingAccount)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .preferredColorScheme(themeManager.colorScheme)
        .navigationBarBackButtonHidden(true) // Hide top back button, use bottom button
        .toolbar {
            ToolbarItem(placement: .principal) {
                ProgressBar(currentStep: 6, totalSteps: 7)
            }
        }
        .onAppear {
            startAnimations()
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
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
        
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            emailError = "Email is required"
            return false
        } else if !isValidEmail(email) {
            emailError = "Please enter a valid email"
            return false
        }
        
        if password.isEmpty {
            passwordError = "Password is required"
            return false
        } else if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
            return false
        }
        
        if password != confirmPassword {
            confirmPasswordError = "Passwords do not match"
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if validateForm() {
            coordinator.updateEmail(email.trimmingCharacters(in: .whitespaces))
            coordinator.updatePassword(password)
            coordinator.nextStep()
            
            isCreatingAccount = true
            
            Task {
                // Step 1: Sign up with email and password
                print("🔵 Starting account creation process...")
                let signUpResponse = await AuthService.shared.signUpWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                
                guard let user = signUpResponse.user else {
                    let errorMessage = signUpResponse.error?.message ?? "Failed to create account."
                    print("❌ Account creation failed: \(errorMessage)")
                    await MainActor.run {
                        showError = errorMessage
                        isCreatingAccount = false
                    }
                    return
                }
                
                print("✅ Account created. User ID: \(user.id)")
                
                // Step 2: Prepare profile data
                guard let sex = coordinator.signUpData.sex,
                      let ageString = coordinator.signUpData.age,
                      let age = Int(ageString),
                      let heightString = coordinator.signUpData.height,
                      let height = Double(heightString),
                      let weightString = coordinator.signUpData.weight,
                      let weight = Double(weightString) else {
                    await MainActor.run {
                        showError = "Missing required information. Please complete all fields."
                        isCreatingAccount = false
                    }
                    return
                }
                
                // Calculate date of birth from age
                let calendar = Calendar.current
                let today = Date()
                let birthYear = calendar.component(.year, from: today) - age
                let dateOfBirth = calendar.date(from: DateComponents(year: birthYear, month: calendar.component(.month, from: today), day: calendar.component(.day, from: today))) ?? today
                
                // Height is already in cm from the picker
                let heightCm = height
                
                // Convert weight to kg (if needed)
                var weightKg = weight
                if coordinator.signUpData.weightUnit == "lbs" {
                    weightKg = weightKg * 0.453592
                }
                
                // Step 3: Create user profile
                print("🔵 Creating user profile...")
                let profileResponse = await AuthService.shared.createUserProfile(
                    userId: user.id, // user.id is already a String
                    biologicalSex: sex.rawValue,
                    dateOfBirth: dateOfBirth,
                    heightCm: heightCm,
                    weightKg: weightKg,
                    firstName: coordinator.signUpData.firstName,
                    lastName: coordinator.signUpData.lastName,
                    email: user.email,
                    healthConditions: coordinator.signUpData.healthConditions
                )
                
                if let error = profileResponse.error {
                    print("❌ Profile creation failed: \(error.message)")
                    await MainActor.run {
                        showError = "Failed to create profile: \(error.message)"
                        isCreatingAccount = false
                    }
                    return
                }
                
                // Success - update app state to logged in
                print("✅ Account and profile created successfully!")
                await MainActor.run {
                    isCreatingAccount = false
                    // Update app state to reflect authentication
                    appState.isAuthenticated = true
                    // User will automatically be navigated to HomeView
                }
            }
        }
    }
}
