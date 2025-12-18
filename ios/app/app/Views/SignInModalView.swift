//
//  SignInModalView.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import SafariServices

struct SignInModalView: View {
    @Binding var isPresented: Bool
    var onGoogleSignIn: (() -> Void)? = nil
    var isGoogleLoading: Bool = false
    var onSignInSuccess: ((String, String?) -> Void)? = nil
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var errorAlert: ErrorAlert?
    
    @FocusState private var focusedField: Field?
    
    struct ErrorAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Envelope Icon
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color(hex: "#B01328"))
                        .font(.system(size: 30))
                        .padding(.top, 18)
                        .padding(.bottom, 15)
                    
                    // Title
                    Text("Sign In")
                        .font(.custom("ProductSans-Bold", size: 22))
                        .foregroundColor(Color(uiColor: .label))
                        .padding(.bottom, 32)
                    
                    // Email Input
                    InputField(
                        placeholder: "Email address",
                        text: $email,
                        icon: .email,
                        isEnabled: !showPassword
                    )
                    .focused($focusedField, equals: .email)
                    .padding(.bottom, 24)
                    
                    // Password Input
                    if showPassword {
                        InputField(
                            placeholder: "Password",
                            text: $password,
                            icon: .password,
                            isSecure: true
                        )
                        .focused($focusedField, equals: .password)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Google Sign In Button
                    GoogleSignInButton(
                        onPress: {
                            handleGoogleSignIn()
                        },
                        loading: isGoogleLoading
                    )
                    .padding(.bottom, 10)
                    
                    // Continue/Sign In Button
                    continueButton
                        .padding(.bottom, 16)
                    
                    // Terms Disclaimer
                    termsDisclaimer
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(uiColor: .label))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .sheet(isPresented: $showTerms) {
            SafariView(url: URL(string: "https://lumo-blood.com/terms")!)
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: URL(string: "https://lumo-blood.com/privacy")!)
        }
        .alert(item: $errorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: isPresented) { newValue in
            if !newValue {
                resetForm()
            }
        }
    }
    
    // MARK: - Continue Button
    private var continueButton: some View {
        Button(action: handleContinue) {
            HStack(spacing: 8) {
                Text(isLoading ? "Signing in..." : showPassword ? "Sign In" : "Continue")
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(.white)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#B01328"), Color(hex: "#C01328")]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(28)
            .shadow(color: Color(hex: "#B01328").opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
    
    // MARK: - Terms Disclaimer
    private var termsDisclaimer: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to the")
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(Color(uiColor: .secondaryLabel))
            
            HStack(spacing: 4) {
                Button(action: { showTerms = true }) {
                    Text("Terms of Use")
                        .font(.custom("ProductSans-Bold", size: 14))
                        .foregroundColor(.white)
                }
                
                Text("and")
                    .font(.custom("ProductSans-Regular", size: 14))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                
                Button(action: { showPrivacy = true }) {
                    Text("Privacy Policy")
                        .font(.custom("ProductSans-Bold", size: 14))
                        .foregroundColor(.white)
                }
            }
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: - Actions
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        
        if trimmedEmail.isEmpty {
            showErrorAlert(title: "Error", message: "Please enter your email address")
            return
        }
        
        if !showPassword {
            // Show password field
            withAnimation(.spring(response: 0.3)) {
                showPassword = true
            }
            // Focus password field after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .password
            }
            return
        }
        
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)
        if trimmedPassword.isEmpty {
            showErrorAlert(title: "Error", message: "Please enter your password")
            return
        }
        
        // Sign in with email and password
        isLoading = true
        
        Task {
            let response = await AuthService.shared.signInWithEmail(email: trimmedEmail, password: trimmedPassword)
            
            await MainActor.run {
                isLoading = false
                
                if let error = response.error {
                    showErrorAlert(title: "Sign In Error", message: error.localizedDescription)
                } else if let user = response.user {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    if let onSignInSuccess = onSignInSuccess {
                        onSignInSuccess(user.id, user.email)
                    }
                    isPresented = false
                } else {
                    showErrorAlert(title: "Sign In Error", message: "Unable to sign in. Please try again.")
                }
            }
        }
    }
    
    private func showErrorAlert(title: String, message: String) {
        errorAlert = ErrorAlert(title: title, message: message)
    }
    
    private func handleClose() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        isPresented = false
    }
    
    private func handleGoogleSignIn() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if let onGoogleSignIn = onGoogleSignIn {
            onGoogleSignIn()
        } else {
            // Fallback: Use AuthService directly
            Task {
                await MainActor.run {
                    // Don't set isLoading - Google sign-in has its own loading state
                }
                
                let response = await AuthService.shared.signInWithGoogle()
                
                await MainActor.run {
                    // Don't set isLoading - Google sign-in has its own loading state
                    
                    if let error = response.error {
                        // Only show error if not cancelled by user
                        if error.message != "Sign in cancelled by user" {
                            showErrorAlert(title: "Sign In Error", message: error.localizedDescription)
                        }
                    } else if let user = response.user {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                        
                        if let onSignInSuccess = onSignInSuccess {
                            onSignInSuccess(user.id, user.email)
                        }
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func resetForm() {
        email = ""
        password = ""
        showPassword = false
        isLoading = false
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


#Preview {
    SignInModalView(isPresented: .constant(true))
}

