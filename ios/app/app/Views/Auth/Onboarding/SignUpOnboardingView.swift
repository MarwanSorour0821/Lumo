//
//  SignUpOnboardingView.swift
//  app
//
//  Sign up view shown at the end of onboarding
//

import SwiftUI
import UIKit
import SafariServices

struct SignUpOnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState

    // Selected medications from previous step
    let selectedMedications: [String]

    // Form state
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var isGoogleLoading: Bool = false
    @State private var isAppleLoading: Bool = false
    @State private var isCreatingMedications: Bool = false
    @State private var errorAlert: ErrorAlert?
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showNotificationPrompt: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showNoRemindersAlert: Bool = false
    @State private var pendingAuthCompletion: Bool = false
    @State private var didSubscribe: Bool = false

    @FocusState private var focusedField: Field?

    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var starsOpacity: Double = 0
    @State private var stars: [StarParticle] = []

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    private var isDarkMode: Bool {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark
    }

    struct ErrorAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            // Adaptive background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // Radial gradient "light" effect from top
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(isDarkMode ? 0.3 : 0.15),
                    AppColors.primary.opacity(isDarkMode ? 0.1 : 0.05),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.7
            )
            .ignoresSafeArea()

            // Animated star particles (only in dark mode)
            if isDarkMode {
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x, y: star.y)
                        .opacity(star.opacity * starsOpacity)
                }
            }

            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // Title
                    Text("Create your account")
                        .font(.custom("ProductSans-Bold", size: 28))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                    // Subtitle
                    Text("Start tracking your health today")
                        .font(.custom("ProductSans-Regular", size: 15))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)

                    // Form fields
                    VStack(spacing: 16) {
                        // Email field
                        OnboardingInputField(
                            placeholder: "Email address",
                            text: $email,
                            icon: "envelope",
                            keyboardType: .emailAddress,
                            colorScheme: themeManager.colorScheme
                        )
                        .focused($focusedField, equals: .email)

                        // Password field
                        OnboardingInputField(
                            placeholder: "Password",
                            text: $password,
                            icon: "lock",
                            isSecure: true,
                            colorScheme: themeManager.colorScheme
                        )
                        .focused($focusedField, equals: .password)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                    // Create account button
                    Button(action: handleCreateAccount) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account")
                                    .font(.custom("ProductSans-Bold", size: 17))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(AppColors.primary)
                        )
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 16, x: 0, y: 8)
                    }
                    .disabled(isLoading || isCreatingMedications)
                    .opacity(isLoading || isCreatingMedications ? 0.7 : 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(AppColors.border(themeManager.colorScheme))
                            .frame(height: 1)
                        Text("or")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .padding(.horizontal, 16)
                        Rectangle()
                            .fill(AppColors.border(themeManager.colorScheme))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)

                    // Social sign-in buttons
                    VStack(spacing: 12) {
                        // Google Sign In
                        Button(action: handleGoogleSignIn) {
                            HStack(spacing: 12) {
                                Image("GoogleICon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text(isGoogleLoading ? "Signing in..." : "Continue with Google")
                                    .font(.custom("ProductSans-Bold", size: 16))
                            }
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                            )
                        }
                        .disabled(isGoogleLoading || isCreatingMedications)

                        // Apple Sign In
                        Button(action: handleAppleSignIn) {
                            HStack(spacing: 12) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18))
                                Text(isAppleLoading ? "Signing in..." : "Continue with Apple")
                                    .font(.custom("ProductSans-Bold", size: 16))
                            }
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                            )
                        }
                        .disabled(isAppleLoading || isCreatingMedications)
                    }
                    .padding(.horizontal, 24)

                    // Terms disclaimer
                    VStack(spacing: 4) {
                        Text("By continuing, you agree to the")
                            .font(.custom("ProductSans-Regular", size: 13))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                        HStack(spacing: 4) {
                            Button(action: { showTerms = true }) {
                                Text("Terms of Use")
                                    .font(.custom("ProductSans-Bold", size: 13))
                                    .foregroundColor(AppColors.primary)
                            }

                            Text("and")
                                .font(.custom("ProductSans-Regular", size: 13))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                            Button(action: { showPrivacy = true }) {
                                Text("Privacy Policy")
                                    .font(.custom("ProductSans-Bold", size: 13))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .opacity(contentOpacity)
            
            // Loading overlay for medication creation
            if isCreatingMedications {
                ZStack {
                    (isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.text(themeManager.colorScheme)))
                            .scaleEffect(1.5)

                        Text("Setting up your medications...")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(false)
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
        .fullScreenCover(isPresented: $showNotificationPrompt) {
            NotificationPermissionView(
                isPresented: $showNotificationPrompt,
                isPostSignUp: true,
                onEnableNotifications: { level in
                    print("✅ Notifications enabled after sign up with level: \(level.displayName)")
                }
            )
            .environmentObject(themeManager)
            .onDisappear {
                // After notification prompt, show paywall
                if pendingAuthCompletion {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall) {
                // User subscribed successfully
                didSubscribe = true
            }
            .environmentObject(themeManager)
            .onDisappear {
                // After paywall is dismissed
                if pendingAuthCompletion {
                    pendingAuthCompletion = false
                    
                    if !didSubscribe {
                        // User closed paywall without subscribing - show alert
                        showNoRemindersAlert = true
                    } else {
                        // User subscribed - complete auth
                        appState.isAuthenticated = true
                        Task {
                            await UserDataViewModel.shared.loadAllUserData()
                            LoggingViewModel.shared.reset()
                            await LoggingViewModel.shared.refreshData()
                            await LoggingViewModel.shared.rescheduleAllReminders()
                        }
                    }
                }
            }
        }
        .alert("Reminders Disabled", isPresented: $showNoRemindersAlert) {
            Button("OK") {
                // Complete auth after alert is dismissed
                appState.isAuthenticated = true
                Task {
                    await UserDataViewModel.shared.loadAllUserData()
                    LoggingViewModel.shared.reset()
                    await LoggingViewModel.shared.refreshData()
                    await LoggingViewModel.shared.rescheduleAllReminders()
                }
            }
        } message: {
            Text("Without a subscription, you won't receive medication reminders. You can upgrade anytime in Settings.")
        }
        .onAppear {
            initializeStars()
            startAnimations()
            startStarAnimation()
        }
    }

    // MARK: - Star Animation
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
        withAnimation(.easeOut(duration: 0.8)) {
            starsOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            contentOpacity = 1
        }
    }

    private func startStarAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
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

    // MARK: - Actions
    private func handleCreateAccount() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)

        if trimmedEmail.isEmpty {
            errorAlert = ErrorAlert(title: "Error", message: "Please enter your email address")
            return
        }

        if trimmedPassword.isEmpty {
            errorAlert = ErrorAlert(title: "Error", message: "Please enter a password")
            return
        }

        if trimmedPassword.count < 6 {
            errorAlert = ErrorAlert(title: "Error", message: "Password must be at least 6 characters")
            return
        }

        isLoading = true

        Task {
            let response = await AuthService.shared.signUpWithEmail(email: trimmedEmail, password: trimmedPassword)

            await MainActor.run {
                isLoading = false

                if let error = response.error {
                    errorAlert = ErrorAlert(title: "Sign Up Error", message: error.localizedDescription)
                } else if response.user != nil {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)

                    // Create medications and complete onboarding
                    isCreatingMedications = true
                    Task {
                        await completeSignUpFlow()
                    }
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        isGoogleLoading = true

        Task {
            let response = await AuthService.shared.signInWithGoogle()

            await MainActor.run {
                isGoogleLoading = false

                if let error = response.error {
                    if error.message != "Sign in cancelled by user" && error.message != "Sign in cancelled" {
                        errorAlert = ErrorAlert(title: "Sign In Error", message: error.localizedDescription)
                    }
                } else if response.user != nil {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)

                    isCreatingMedications = true
                    Task {
                        await completeSignUpFlow()
                    }
                }
            }
        }
    }

    private func handleAppleSignIn() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        isAppleLoading = true

        Task {
            let response = await AuthService.shared.signInWithApple()

            await MainActor.run {
                isAppleLoading = false

                if let error = response.error {
                    if error.message != "Sign in cancelled" {
                        errorAlert = ErrorAlert(title: "Sign In Error", message: error.localizedDescription)
                    }
                } else if response.user != nil {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)

                    isCreatingMedications = true
                    Task {
                        await completeSignUpFlow()
                    }
                }
            }
        }
    }

    /// Complete the sign-up flow: create medications, check notifications, show paywall, and finish auth
    private func completeSignUpFlow() async {
        // Create medications first
        await createSelectedMedications()

        // Check notification permissions
        let notificationsEnabled = await NotificationManager.shared.areNotificationsEnabled()

        await MainActor.run {
            isCreatingMedications = false
            pendingAuthCompletion = true

            if notificationsEnabled {
                // Notifications already enabled, go straight to paywall
                showPaywall = true
            } else {
                // Show notification prompt first, then paywall
                showNotificationPrompt = true
            }
        }
    }

    private func createSelectedMedications() async {
        guard !selectedMedications.isEmpty else { return }
        
        // Wait a moment to ensure the session is fully established
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify we have an access token
        do {
            _ = try await AuthService.shared.getAccessToken()
            print("✅ Access token available, creating medications...")
        } catch {
            print("❌ No access token available: \(error.localizedDescription)")
            return
        }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate

        for medication in selectedMedications {
            do {
                let newItem = try await LoggingService.shared.createItem(
                    name: medication,
                    type: .medication,
                    description: nil,
                    frequency: .daily,
                    timesPerWeek: 7,
                    startDate: startDate,
                    endDate: endDate
                )

                // Set reminder at 9:00 AM
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let timeString = "09:00:00"

                _ = try await LoggingService.shared.updateReminder(
                    itemId: newItem.id,
                    enabled: true,
                    times: [timeString],
                    days: [0, 1, 2, 3, 4, 5, 6]
                )

                // Schedule local notification
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 9
                components.minute = 0
                let reminderTime = Calendar.current.date(from: components) ?? Date()

                for day in 0..<7 {
                    let weekday = day + 1
                    await NotificationManager.shared.scheduleReminder(
                        itemId: newItem.id,
                        itemName: newItem.name,
                        itemType: "medication",
                        hour: 9,
                        minute: 0,
                        weekday: weekday,
                        timeIndex: 0,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            } catch {
                print("❌ Failed to create medication \(medication): \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Error domain: \(nsError.domain), code: \(nsError.code)")
                    if let userInfo = nsError.userInfo as? [String: Any] {
                        print("   User info: \(userInfo)")
                    }
                }
            }
        }

        // Refresh data
        await LoggingViewModel.shared.refreshData()
    }
}

// MARK: - Onboarding Input Field (Adaptive theme)
struct OnboardingInputField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var colorScheme: ColorScheme? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppColors.textSecondary(colorScheme))
                .frame(width: 20, height: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(colorScheme))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(colorScheme))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(AppColors.inputBackground(colorScheme))
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(AppColors.border(colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        SignUpOnboardingView(selectedMedications: ["Vitamin D", "Magnesium"])
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
