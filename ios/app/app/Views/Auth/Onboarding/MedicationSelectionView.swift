//
//  MedicationSelectionView.swift
//  app
//
//  A view for selecting common medications during onboarding
//

import SwiftUI
import UIKit

// MARK: - Medication Item for Selection
struct SelectableMedication: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var isSelected: Bool = false
}

struct MedicationSelectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Navigation
    @State private var navigateToMedicationOnboarding = false

    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var starsOpacity: Double = 0

    // Star particles for background
    @State private var stars: [StarParticle] = []

    // Medications list with selection state
    @State private var medications: [SelectableMedication] = [
        SelectableMedication(name: "Vitamin D", icon: "sun.max.fill"),
        SelectableMedication(name: "Multivitamin", icon: "pill.fill"),
        SelectableMedication(name: "Fish Oil / Omega-3", icon: "drop.fill"),
        SelectableMedication(name: "Magnesium", icon: "sparkles"),
        SelectableMedication(name: "Vitamin B12", icon: "bolt.fill"),
        SelectableMedication(name: "Probiotics", icon: "leaf.fill"),
        SelectableMedication(name: "Iron", icon: "circle.fill"),
        SelectableMedication(name: "Melatonin", icon: "moon.fill"),
        SelectableMedication(name: "Calcium", icon: "cube.fill"),
        SelectableMedication(name: "Zinc", icon: "shield.fill")
    ]

    private var hasSelection: Bool {
        medications.contains(where: { $0.isSelected })
    }

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            // Radial gradient "light" effect from top
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(0.3),
                    AppColors.primary.opacity(0.1),
                    Color.clear
                ]),
                center: .top,
                startRadius: 0,
                endRadius: screenHeight * 0.7
            )
            .ignoresSafeArea()

            // Star particles
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
                    .opacity(star.opacity * starsOpacity)
            }

            // Main content - everything scrolls together
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Title - scrolls with content
                        Text("Which medications do you take?")
                            .font(.custom("ProductSans-Bold", size: 28))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                            .padding(.horizontal, 24)

                        // Subtitle
                        Text("Select all that apply, you can add more later.")
                            .font(.custom("ProductSans-Regular", size: 15))
                            .foregroundColor(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal, 24)

                        // Medications list
                        VStack(spacing: 12) {
                            ForEach($medications) { $medication in
                                MedicationRow(medication: $medication) {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    medication.isSelected.toggle()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 160) // Space for bottom button
                    }
                }
                .opacity(contentOpacity)
            }

            // Bottom footer with gradual blur
            VStack {
                Spacer()

                ZStack(alignment: .bottom) {
                    // Gradual blur background
                    GradualBlurView()
                        .frame(height: 160)
                        .allowsHitTesting(false)

                    // Button content
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        if !hasSelection {
                            for index in medications.indices {
                                medications[index].isSelected = false
                            }
                        }
                        navigateToMedicationOnboarding = true
                    }) {
                        Text(hasSelection ? "Continue" : "None of these")
                            .font(.custom("ProductSans-Bold", size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(hasSelection ? AppColors.primary : Color(hex: "#2A2A2A"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: hasSelection ? AppColors.primary.opacity(0.4) : Color.clear, radius: 16, x: 0, y: 8)
                    }
                    .animation(.easeInOut(duration: 0.2), value: hasSelection)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .opacity(contentOpacity)
        }
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    navigateToMedicationOnboarding = true
                }) {
                    Text("Skip")
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
        }
        .navigationDestination(isPresented: $navigateToMedicationOnboarding) {
            MedicationOnboardingView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            initializeStars()
            startAnimations()
        }
    }

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
}

// MARK: - Gradual Blur View
struct GradualBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = true

        // Create blur effect view
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let blurView = uiView.subviews.first as? UIVisualEffectView else { return }

            // Create gradient mask - clear at top, opaque at bottom
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = uiView.bounds
            gradientLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.5).cgColor,
                UIColor.black.cgColor
            ]
            gradientLayer.locations = [0.0, 0.4, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

            blurView.layer.mask = gradientLayer
        }
    }
}

// MARK: - Medication Row
struct MedicationRow: View {
    @Binding var medication: SelectableMedication
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Selection circle
                Circle()
                    .strokeBorder(
                        medication.isSelected ? AppColors.primary : Color.white.opacity(0.3),
                        lineWidth: 2
                    )
                    .background(
                        Circle()
                            .fill(medication.isSelected ? AppColors.primary : Color.clear)
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(medication.isSelected ? 1 : 0)
                    )

                // Icon
                Image(systemName: medication.icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 32, height: 32)

                // Name
                Text(medication.name)
                    .font(.custom("ProductSans-Regular", size: 17))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1A1A1A"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        medication.isSelected ? AppColors.primary.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .animation(.easeInOut(duration: 0.15), value: medication.isSelected)
    }
}

#Preview {
    NavigationStack {
        MedicationSelectionView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
