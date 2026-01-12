//
//  MedicationOnboardingView.swift
//  app
//
//  A medication-first onboarding experience
//

import SwiftUI
import UserNotifications

struct MedicationOnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @StateObject private var coordinator = MedicationOnboardingCoordinator()
    @StateObject private var signUpCoordinator = SignUpFlowCoordinator()

    // Navigation states
    @State private var navigateToOriginalOnboarding = false
    @State private var navigateToBloodTest = false

    var body: some View {
        ZStack {
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // Page content based on current step
            Group {
                switch coordinator.currentStep {
                case .welcome:
                    WelcomePage(coordinator: coordinator)
                case .permissionFraming:
                    PermissionFramingPage(coordinator: coordinator)
                case .actionFraming:
                    ActionFramingPage(coordinator: coordinator)
                case .medicationName:
                    MedicationNamePage(coordinator: coordinator)
                case .dosage:
                    DosagePage(coordinator: coordinator)
                case .frequency:
                    FrequencyPage(coordinator: coordinator)
                case .timeSelection:
                    TimeSelectionPage(coordinator: coordinator)
                case .review:
                    ReviewPage(coordinator: coordinator)
                case .success:
                    SuccessPage(coordinator: coordinator)
                case .expansion:
                    ExpansionPage(
                        coordinator: coordinator,
                        onExploreLater: {
                            navigateToOriginalOnboarding = true
                        },
                        onUploadBloodTest: {
                            navigateToBloodTest = true
                        }
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: coordinator.currentStep)
        }
        .navigationDestination(isPresented: $navigateToOriginalOnboarding) {
            // Go to original onboarding flow (profile setup)
            OpeningMomentView(coordinator: signUpCoordinator)
        }
        .navigationDestination(isPresented: $navigateToBloodTest) {
            // Go to blood test upload
            HomeView()
        }
    }
}

// MARK: - Page 1: Welcome
struct WelcomePage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var headlineOpacity: Double = 0
    @State private var subtextOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var headlineOffset: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Visual element - subtle health icon
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(headlineOpacity)
                .padding(.bottom, 32)

            // Headline
            Text("Create a health you can rely on.")
                .font(.custom("ProductSans-Bold", size: 32))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(headlineOpacity)
                .offset(y: headlineOffset)
                .padding(.horizontal, 32)

            // Subtext
            VStack(spacing: 8) {
                Text("Medication works best with consistency.")
                    .font(.custom("ProductSans-Regular", size: 17))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                Text("Lumo helps you stay on track.")
                    .font(.custom("ProductSans-Regular", size: 17))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .multilineTextAlignment(.center)
            .opacity(subtextOpacity)
            .padding(.top, 16)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // Get Started button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation {
                    coordinator.nextStep()
                }
            }) {
                Text("Get started")
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
            .opacity(buttonOpacity)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headlineOpacity = 1
            headlineOffset = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            subtextOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
            buttonOpacity = 1
        }
    }
}

// MARK: - Page 2: Permission Framing
struct PermissionFramingPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var contentOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Notification bell icon
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.primary)
            }
            .scaleEffect(iconScale)
            .opacity(contentOpacity)
            .padding(.bottom, 32)

            // Headline
            Text("Lumo reminds you — gently.")
                .font(.custom("ProductSans-Bold", size: 28))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
                .padding(.horizontal, 32)

            // Subtext
            Text("We'll notify you when it's time to take your medication.")
                .font(.custom("ProductSans-Regular", size: 17))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // Continue button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                requestNotificationPermission()
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
            .opacity(contentOpacity)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            contentOpacity = 1
            iconScale = 1.0
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationManager.shared.requestPermissions()
            coordinator.setNotificationsEnabled(granted)

            await MainActor.run {
                withAnimation {
                    coordinator.nextStep()
                }
            }
        }
    }
}

// MARK: - Page 3: Action Framing
struct ActionFramingPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var contentOpacity: Double = 0
    @State private var iconOffset: CGFloat = -10

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Pill icon with subtle animation
            Image(systemName: "pills.fill")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: iconOffset)
                .opacity(contentOpacity)
                .padding(.bottom, 32)

            // Headline
            Text("Let's set up your first medication.")
                .font(.custom("ProductSans-Bold", size: 28))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
                .padding(.horizontal, 32)

            // Subtext
            Text("This takes less than a minute.")
                .font(.custom("ProductSans-Regular", size: 17))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // Add medication button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation {
                    coordinator.nextStep()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                    Text("Add medication")
                        .font(.custom("ProductSans-Bold", size: 17))
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
            .opacity(contentOpacity)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            contentOpacity = 1
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3)) {
            iconOffset = 5
        }
    }
}

// MARK: - Page 4: Medication Name
struct MedicationNamePage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var medicationName: String = ""
    @State private var showSuggestions: Bool = false
    @State private var contentOpacity: Double = 0
    @FocusState private var isInputFocused: Bool

    private var suggestions: [String] {
        coordinator.filteredMedications(for: medicationName)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("What medication do you take?")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text("Start typing the name.")
                    .font(.custom("ProductSans-Regular", size: 15))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .opacity(contentOpacity)

            // Search input
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                    TextField("e.g., Vitamin D, Metformin", text: $medicationName)
                        .font(.custom("ProductSans-Regular", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .focused($isInputFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .onChange(of: medicationName) { _ in
                            showSuggestions = !medicationName.isEmpty && !suggestions.isEmpty
                        }

                    if !medicationName.isEmpty {
                        Button(action: {
                            medicationName = ""
                            showSuggestions = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface(themeManager.colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isInputFocused ? AppColors.primary : AppColors.border(themeManager.colorScheme), lineWidth: isInputFocused ? 2 : 1)
                )

                // Suggestions
                if showSuggestions && !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                medicationName = suggestion
                                showSuggestions = false
                                isInputFocused = false
                            }) {
                                HStack {
                                    Image(systemName: "pill.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.primary)

                                    Text(suggestion)
                                        .font(.custom("ProductSans-Regular", size: 16))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }

                            if suggestion != suggestions.last {
                                Divider()
                                    .background(AppColors.border(themeManager.colorScheme))
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface(themeManager.colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                    )
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .opacity(contentOpacity)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                // Back button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation {
                        coordinator.previousStep()
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                        )
                }

                Spacer()

                // Continue button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    coordinator.updateMedicationName(medicationName)
                    withAnimation {
                        coordinator.nextStep()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 17))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(medicationName.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.primary.opacity(0.5) : AppColors.primary)
                    )
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .disabled(medicationName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(contentOpacity)
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            contentOpacity = 1
        }
    }
}

// MARK: - Page 5: Dosage
struct DosagePage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var dosageAmount: Double = 1
    @State private var selectedUnit: DosageUnit = .pill
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("How much do you take?")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text("You can change this anytime.")
                    .font(.custom("ProductSans-Regular", size: 15))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .opacity(contentOpacity)

            Spacer()

            // Dosage stepper
            VStack(spacing: 32) {
                // Amount display
                HStack(spacing: 16) {
                    // Minus button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        if dosageAmount > 0.5 {
                            dosageAmount -= 0.5
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(dosageAmount <= 0.5 ? AppColors.textSecondary(themeManager.colorScheme).opacity(0.5) : AppColors.text(themeManager.colorScheme))
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                            )
                    }
                    .disabled(dosageAmount <= 0.5)

                    // Amount
                    Text(dosageAmount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dosageAmount) : String(format: "%.1f", dosageAmount))
                        .font(.custom("ProductSans-Bold", size: 56))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .frame(minWidth: 80)

                    // Plus button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dosageAmount += 0.5
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(AppColors.surface(themeManager.colorScheme))
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                            )
                    }
                }

                // Unit selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([DosageUnit.pill, .capsule, .tablet, .mg, .ml, .drop], id: \.self) { unit in
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                selectedUnit = unit
                            }) {
                                Text(unit.displayName)
                                    .font(.custom(selectedUnit == unit ? "ProductSans-Bold" : "ProductSans-Regular", size: 15))
                                    .foregroundColor(selectedUnit == unit ? .white : AppColors.text(themeManager.colorScheme))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedUnit == unit ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selectedUnit == unit ? Color.clear : AppColors.border(themeManager.colorScheme), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .opacity(contentOpacity)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation {
                        coordinator.previousStep()
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                        )
                }

                Spacer()

                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    coordinator.updateDosage(amount: dosageAmount, unit: selectedUnit)
                    withAnimation {
                        coordinator.nextStep()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 17))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(AppColors.primary)
                    )
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(contentOpacity)
        }
        .onAppear {
            dosageAmount = coordinator.data.dosageAmount
            selectedUnit = coordinator.data.dosageUnit
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            contentOpacity = 1
        }
    }
}

// MARK: - Page 6: Frequency
struct FrequencyPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var selectedFrequency: MedicationFrequency = .onceDaily
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("How often do you take it?")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .opacity(contentOpacity)

            Spacer()

            // Frequency options
            VStack(spacing: 12) {
                ForEach(MedicationFrequency.allCases, id: \.self) { frequency in
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFrequency = frequency
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(frequency.displayName)
                                    .font(.custom("ProductSans-Bold", size: 18))
                                    .foregroundColor(selectedFrequency == frequency ? .white : AppColors.text(themeManager.colorScheme))

                                Text(frequencySubtext(for: frequency))
                                    .font(.custom("ProductSans-Regular", size: 14))
                                    .foregroundColor(selectedFrequency == frequency ? .white.opacity(0.8) : AppColors.textSecondary(themeManager.colorScheme))
                            }

                            Spacer()

                            if selectedFrequency == frequency {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedFrequency == frequency ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedFrequency == frequency ? Color.clear : AppColors.border(themeManager.colorScheme), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .opacity(contentOpacity)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation {
                        coordinator.previousStep()
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                        )
                }

                Spacer()

                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    coordinator.updateFrequency(selectedFrequency)
                    withAnimation {
                        // Skip time selection for "as needed"
                        if selectedFrequency == .asNeeded {
                            coordinator.goToStep(.review)
                        } else {
                            coordinator.nextStep()
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 17))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(AppColors.primary)
                    )
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(contentOpacity)
        }
        .onAppear {
            selectedFrequency = coordinator.data.frequency
            startAnimations()
        }
    }

    private func frequencySubtext(for frequency: MedicationFrequency) -> String {
        switch frequency {
        case .onceDaily: return "Same time every day"
        case .multipleTimes: return "Morning, afternoon, or evening"
        case .asNeeded: return "No regular schedule"
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            contentOpacity = 1
        }
    }
}

// MARK: - Page 7: Time Selection
struct TimeSelectionPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var reminderTimes: [Date] = []
    @State private var showTimePicker: Bool = false
    @State private var editingTimeIndex: Int? = nil
    @State private var tempTime: Date = Date()
    @State private var contentOpacity: Double = 0

    private let presets: [(String, Int, Int)] = [
        ("Morning", 8, 0),
        ("Afternoon", 13, 0),
        ("Evening", 20, 0)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("When should we remind you?")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text(coordinator.data.frequency == .multipleTimes ? "Add multiple reminder times." : "We'll remind you at this time every day.")
                    .font(.custom("ProductSans-Regular", size: 15))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .opacity(contentOpacity)

            // Preset buttons
            if coordinator.data.frequency == .onceDaily {
                HStack(spacing: 12) {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                            components.hour = preset.1
                            components.minute = preset.2
                            if let time = Calendar.current.date(from: components) {
                                reminderTimes = [time]
                            }
                        }) {
                            Text(preset.0)
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(AppColors.surface(themeManager.colorScheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .opacity(contentOpacity)
            }

            Spacer()

            // Time display / picker
            VStack(spacing: 16) {
                ForEach(Array(reminderTimes.enumerated()), id: \.offset) { index, time in
                    Button(action: {
                        editingTimeIndex = index
                        tempTime = time
                        showTimePicker = true
                    }) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.primary)

                            Text(formatTime(time))
                                .font(.custom("ProductSans-Bold", size: 32))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))

                            Spacer()

                            if coordinator.data.frequency == .multipleTimes && reminderTimes.count > 1 {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    reminderTimes.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                        )
                    }
                }

                // Add time button for multiple times
                if coordinator.data.frequency == .multipleTimes && reminderTimes.count < 5 {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        editingTimeIndex = nil
                        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                        components.hour = 12
                        components.minute = 0
                        tempTime = Calendar.current.date(from: components) ?? Date()
                        showTimePicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.primary)

                            Text("Add another time")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(AppColors.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(AppColors.primary, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .opacity(contentOpacity)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation {
                        coordinator.previousStep()
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(AppColors.surface(themeManager.colorScheme))
                        )
                        .overlay(
                            Circle()
                                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                        )
                }

                Spacer()

                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    coordinator.updateReminderTimes(reminderTimes)
                    withAnimation {
                        coordinator.nextStep()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 17))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(AppColors.primary)
                    )
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .opacity(contentOpacity)
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(
                selectedTime: $tempTime,
                onSave: {
                    if let index = editingTimeIndex {
                        reminderTimes[index] = tempTime
                    } else {
                        reminderTimes.append(tempTime)
                        reminderTimes.sort()
                    }
                    showTimePicker = false
                },
                onCancel: {
                    showTimePicker = false
                }
            )
            .presentationDetents([.height(320)])
        }
        .onAppear {
            reminderTimes = coordinator.data.reminderTimes
            if reminderTimes.isEmpty {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 9
                components.minute = 0
                reminderTimes = [Calendar.current.date(from: components) ?? Date()]
            }
            startAnimations()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            contentOpacity = 1
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTime: Date
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .font(.custom("ProductSans-Regular", size: 17))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

                Spacer()

                Text("Set Time")
                    .font(.custom("ProductSans-Bold", size: 17))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Spacer()

                Button("Done") {
                    onSave()
                }
                .font(.custom("ProductSans-Bold", size: 17))
                .foregroundColor(AppColors.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Time picker
            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, 20)

            Spacer()
        }
        .background(AppColors.modalBackground(themeManager.colorScheme))
    }
}

// MARK: - Page 8: Review
struct ReviewPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var contentOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Summary card
            VStack(spacing: 24) {
                // Checkmark icon
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 72, height: 72)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primary)
                }

                Text("You're all set.")
                    .font(.custom("ProductSans-Bold", size: 24))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                // Details
                VStack(spacing: 16) {
                    DetailRow(icon: "pill.fill", label: "Medication", value: coordinator.data.medicationName)

                    DetailRow(
                        icon: "number",
                        label: "Dosage",
                        value: "\(coordinator.data.dosageAmount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", coordinator.data.dosageAmount) : String(format: "%.1f", coordinator.data.dosageAmount)) \(coordinator.data.dosageUnit.displayName)"
                    )

                    if !coordinator.data.reminderTimes.isEmpty {
                        DetailRow(
                            icon: "clock.fill",
                            label: "Reminder",
                            value: coordinator.data.reminderTimes.map { formatTime($0) }.joined(separator: ", ")
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppColors.surface(themeManager.colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .scaleEffect(cardScale)
            .opacity(contentOpacity)

            Spacer()

            // Confirm button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                saveMedication()
            }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Confirm reminder")
                            .font(.custom("ProductSans-Bold", size: 17))
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
            .disabled(isSaving)
            .opacity(contentOpacity)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Edit link
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation {
                    coordinator.goToStep(.medicationName)
                }
            }) {
                Text("Edit details")
                    .font(.custom("ProductSans-Regular", size: 15))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .opacity(contentOpacity)
            .padding(.bottom, 48)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func saveMedication() {
        isSaving = true
        Task {
            let success = await coordinator.saveMedication()
            await MainActor.run {
                isSaving = false
                if success {
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    withAnimation {
                        coordinator.nextStep()
                    }
                }
            }
        }
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            contentOpacity = 1
            cardScale = 1.0
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.primary)
                .frame(width: 24)

            Text(label)
                .font(.custom("ProductSans-Regular", size: 15))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))

            Spacer()

            Text(value)
                .font(.custom("ProductSans-Bold", size: 15))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Page 9: Success
struct SuccessPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator

    @State private var contentOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var showConfetti: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Success animation
            ZStack {
                // Pulse rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(AppColors.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 120 + CGFloat(index) * 40, height: 120 + CGFloat(index) * 40)
                        .scaleEffect(showConfetti ? 1.2 : 0.8)
                        .opacity(showConfetti ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                            value: showConfetti
                        )
                }

                // Checkmark
                ZStack {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(checkmarkScale)
            }
            .opacity(contentOpacity)

            // Text
            VStack(spacing: 8) {
                Text("Reminder set.")
                    .font(.custom("ProductSans-Bold", size: 32))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))

                Text("Lumo's got your back.")
                    .font(.custom("ProductSans-Regular", size: 17))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .opacity(contentOpacity)
            .padding(.top, 32)

            Spacer()
            Spacer()

            // Continue button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation {
                    coordinator.nextStep()
                }
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
            .opacity(contentOpacity)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            contentOpacity = 1
            checkmarkScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showConfetti = true
        }
    }
}

// MARK: - Page 10: Expansion
struct ExpansionPage: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: MedicationOnboardingCoordinator
    var onExploreLater: () -> Void
    var onUploadBloodTest: () -> Void

    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(contentOpacity)
                .padding(.bottom, 24)

            // Headline
            Text("Want deeper insights?")
                .font(.custom("ProductSans-Bold", size: 28))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)

            // Subtext
            Text("Upload blood tests anytime to understand your health better.")
                .font(.custom("ProductSans-Regular", size: 17))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
                .opacity(contentOpacity)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // Primary button - Explore later
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onExploreLater()
            }) {
                Text("Explore later")
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
            .opacity(contentOpacity)
            .padding(.horizontal, 24)

            // Secondary button - Upload blood test
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onUploadBloodTest()
            }) {
                Text("Upload blood test")
                    .font(.custom("ProductSans-Regular", size: 17))
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
            .opacity(contentOpacity)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            contentOpacity = 1
        }
    }
}

#Preview {
    NavigationStack {
        MedicationOnboardingView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
