//
//  SignUpCredentialsView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SignUpCredentialsView: View {
    @Environment(\.dismiss) private var dismiss
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
            Theme.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Heading
                        Text("Create your account")
                            .font(.custom("ProductSans-Regular", size: 40))
                            .foregroundColor(.white)
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
                                    .foregroundColor(.white.opacity(0.7))
                                
                                TextField("i.e. johndoe@gmail.com", text: $email)
                                    .font(.custom("ProductSans-Regular", size: 17))
                                    .foregroundColor(.white)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .textContentType(.emailAddress)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
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
                                    .foregroundColor(.white.opacity(0.7))
                                
                                SecureField("Enter your password", text: $password)
                                    .font(.custom("ProductSans-Regular", size: 17))
                                    .foregroundColor(.white)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
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
                                    .foregroundColor(.white.opacity(0.7))
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .font(.custom("ProductSans-Regular", size: 17))
                                    .foregroundColor(.white)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .textContentType(.newPassword)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
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
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .clipShape(Circle())
                        
                        // Next Button
                        Button(action: handleContinue) {
                            HStack(spacing: 8) {
                                if isCreatingAccount {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Next")
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
        }
        .preferredColorScheme(.dark)
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
            
            // TODO: Create account and profile with Supabase
            // For now, just print the data
            print("Sign up complete with data: \(coordinator.signUpData)")
            
            isCreatingAccount = true
            
            // TODO: Implement actual sign-up logic
            Task {
                // Simulate account creation
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                await MainActor.run {
                    isCreatingAccount = false
                    // Navigate to home screen or dismiss
                    dismiss()
                }
            }
        }
    }
}


