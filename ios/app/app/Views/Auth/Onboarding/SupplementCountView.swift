//
//  SupplementCountView.swift
//  app
//
//  Interactive onboarding screen: "How many supplements do you take?"
//

import SwiftUI
import UIKit

struct SupplementCountView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var onboardingData = OnboardingDataCoordinator.shared

    // Navigation
    @State private var navigateToNext = false

    // Selection state
    @State private var selectedCount: Int = 3
    @State private var isDragging = false

    // Animation states
    @State private var contentBlur: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var buttonBlur: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var pillsOpacity: Double = 0
    @State private var pillScales: [CGFloat] = Array(repeating: 0, count: 10)

    // Floating pills animation
    @State private var floatingOffsets: [CGFloat] = Array(repeating: 0, count: 10)
    @State private var floatingTimer: Timer?

    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    private var isDarkMode: Bool {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark
    }

    // Count options
    let countOptions = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10+"]

    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            // Radial gradient effect
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.primary.opacity(isDarkMode ? 0.25 : 0.12),
                    AppColors.primary.opacity(isDarkMode ? 0.08 : 0.03),
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

                // Question text
                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("How many")
                            .font(.custom("ProductSans-Regular", size: 32))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text("supplements")
                            .font(.custom("InstrumentSerif-Italic", size: 38))
                            .foregroundColor(AppColors.primary)
                    }

                    Text("do you take?")
                        .font(.custom("ProductSans-Regular", size: 32))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                .multilineTextAlignment(.center)
                .blur(radius: contentBlur)
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 50)

                // Interactive pill visualization
                pillVisualization
                    .opacity(pillsOpacity)

                Spacer()
                    .frame(height: 40)

                // Horizontal scroll selector
                countSelector
                    .blur(radius: contentBlur * 0.5)
                    .opacity(contentOpacity)
                    .padding(.vertical, 20) // Extra padding to prevent cutoff when numbers get bigger

                Spacer()

                // Continue button
                continueButton
                    .blur(radius: buttonBlur)
                    .opacity(buttonOpacity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationDestination(isPresented: $navigateToNext) {
            ForgetFrequencyView()
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            selectionFeedback.prepare()
            startAnimations()
            startFloatingAnimation()
        }
        .onDisappear {
            floatingTimer?.invalidate()
        }
    }

    // MARK: - Pill Visualization
    var pillVisualization: some View {
        let pillSize: CGFloat = 44
        let spacing: CGFloat = 12
        let rows = selectedCount > 5 ? 2 : 1

        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<(row == 0 ? min(selectedCount, 5) : selectedCount - 5), id: \.self) { col in
                        let index = row * 5 + col
                        if index < selectedCount {
                            pillShape(index: index, size: pillSize)
                        }
                    }
                }
            }
        }
        .frame(height: 140)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedCount)
    }

    func pillShape(index: Int, size: CGFloat) -> some View {
        let colors: [Color] = [
            AppColors.primary,
            AppColors.primary.opacity(0.85),
            Color(hex: "#FF6B6B"),
            Color(hex: "#4ECDC4"),
            Color(hex: "#45B7D1"),
            Color(hex: "#96CEB4"),
            Color(hex: "#FFEAA7"),
            Color(hex: "#DDA0DD"),
            Color(hex: "#98D8C8"),
            Color(hex: "#F7DC6F")
        ]

        return Capsule()
            .fill(
                LinearGradient(
                    colors: [colors[index % colors.count], colors[index % colors.count].opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.5, height: size)
            .shadow(color: colors[index % colors.count].opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(pillScales[safe: index] ?? 1.0)
            .offset(y: floatingOffsets[safe: index] ?? 0)
            .rotationEffect(.degrees(Double(index) * 8 - 20))
    }

    // MARK: - Count Selector
    var countSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(countOptions.enumerated()), id: \.offset) { index, option in
                        countOption(option, index: index + 1, isSelected: selectedCount == index + 1)
                            .id(index + 1)
                    }
                }
                .padding(.horizontal, (screenWidth - 80) / 2)
                .padding(.vertical, 10) // Extra vertical padding to prevent cutoff
            }
            .frame(height: 100) // Fixed height to ensure enough space for scaled numbers
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        proxy.scrollTo(selectedCount, anchor: .center)
                    }
                }
            }
        }
    }

    func countOption(_ text: String, index: Int, isSelected: Bool) -> some View {
        Button(action: {
            if selectedCount != index {
                // Haptic feedback
                selectionFeedback.selectionChanged()

                // Animate pill changes
                let previousCount = selectedCount
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    selectedCount = index
                }

                // Animate new pills appearing
                if index > previousCount {
                    for i in previousCount..<index {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - previousCount) * 0.05) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if i < pillScales.count {
                                    pillScales[i] = 1.0
                                }
                            }
                            // Light haptic for each new pill
                            let lightImpact = UIImpactFeedbackGenerator(style: .soft)
                            lightImpact.impactOccurred(intensity: 0.5)
                        }
                    }
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
                    .frame(width: 64, height: 64)
                    .shadow(color: isSelected ? AppColors.primary.opacity(0.4) : Color.clear, radius: 12, x: 0, y: 4)

                Text(text)
                    .font(.custom("ProductSans-Bold", size: isSelected ? 22 : 18))
                    .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Continue Button
    var continueButton: some View {
        Button(action: {
            impactFeedback.impactOccurred()
            onboardingData.supplementCount = selectedCount
            navigateToNext = true
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
    }

    // MARK: - Animations
    private func startAnimations() {
        // Content fades in
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            contentBlur = 0
            contentOpacity = 1
        }

        // Pills fade in with stagger
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            pillsOpacity = 1
        }

        // Animate initial pills appearing
        for i in 0..<selectedCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    if i < pillScales.count {
                        pillScales[i] = 1.0
                    }
                }
            }
        }

        // Button fades in
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonBlur = 0
            buttonOpacity = 1
        }
    }

    private func startFloatingAnimation() {
        floatingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let time = Date().timeIntervalSince1970
            for i in 0..<10 {
                withAnimation(.linear(duration: 0.05)) {
                    floatingOffsets[i] = CGFloat(sin(time * 2 + Double(i) * 0.5)) * 4
                }
            }
        }
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        SupplementCountView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppState())
    }
}
