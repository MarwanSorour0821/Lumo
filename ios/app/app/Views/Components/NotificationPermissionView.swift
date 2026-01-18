//
//  NotificationPermissionView.swift
//  app
//
//  A view to prompt users to enable notifications with level selection
//

import SwiftUI

struct NotificationPermissionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool

    var isPostSignUp: Bool = false
    var onEnableNotifications: ((NotificationLevel) -> Void)? = nil

    @State private var selectedLevel: NotificationLevel = .timeSensitive
    @State private var isRequestingPermission = false
    @State private var appearAnimation = false

    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [
                    AppColors.background(themeManager.colorScheme),
                    AppColors.background(themeManager.colorScheme).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        headerSection
                            .padding(.bottom, 40)

                        // Cards
                        cardsSection
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 140)
                }

                Spacer(minLength: 0)
            }

            // Bottom buttons
            VStack {
                Spacer()
                bottomSection
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 20) {
            // Animated bell icon
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .scaleEffect(appearAnimation ? 1 : 0.8)
                    .opacity(appearAnimation ? 1 : 0)

                // Inner circle
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .scaleEffect(appearAnimation ? 1 : 0.7)
                    .opacity(appearAnimation ? 1 : 0)

                // Icon
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appearAnimation ? 1 : 0.5)
                    .opacity(appearAnimation ? 1 : 0)
            }
            .padding(.top, 48)

            // Title & Description
            VStack(spacing: 12) {
                Text(isPostSignUp ? "Stay on Track" : "Notifications")
                    .font(.custom("ProductSans-Bold", size: 32))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                Text("Choose how you'd like to receive\nreminders for your medications")
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 15)
            }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15), value: appearAnimation)
    }

    // MARK: - Cards Section

    private var cardsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(NotificationLevel.allCases.enumerated()), id: \.element) { index, level in
                NotificationLevelCard(
                    level: level,
                    isSelected: selectedLevel == level,
                    colorScheme: themeManager.colorScheme
                ) {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedLevel = level
                    }
                }
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8).delay(0.2 + Double(index) * 0.08),
                    value: appearAnimation
                )
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [
                    AppColors.background(themeManager.colorScheme).opacity(0),
                    AppColors.background(themeManager.colorScheme)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 50)
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                // Enable button
                Button(action: handleEnableNotifications) {
                    HStack(spacing: 10) {
                        if isRequestingPermission {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Enable Notifications")
                                .font(.custom("ProductSans-Bold", size: 17))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.primary.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: AppColors.primary.opacity(0.35), radius: 16, x: 0, y: 8)
                    )
                }
                .disabled(isRequestingPermission)

                // Skip button
                if isPostSignUp {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        isPresented = false
                    }) {
                        Text("Maybe Later")
                            .font(.custom("ProductSans-Medium", size: 15))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .background(AppColors.background(themeManager.colorScheme))
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)
    }

    private func handleEnableNotifications() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        isRequestingPermission = true
        Task {
            let granted = await NotificationManager.shared.requestPermissions(for: selectedLevel)
            await MainActor.run {
                isRequestingPermission = false
                if granted {
                    onEnableNotifications?(selectedLevel)
                }
                isPresented = false
            }
        }
    }
}

// MARK: - Notification Level Card

struct NotificationLevelCard: View {
    let level: NotificationLevel
    let isSelected: Bool
    let colorScheme: ColorScheme?
    let onTap: () -> Void

    private var levelColor: Color {
        switch level {
        case .standard: return .gray
        case .timeSensitive: return .orange
        case .critical: return .red
        }
    }

    private var priorityText: String {
        switch level {
        case .standard: return "Normal"
        case .timeSensitive: return "High"
        case .critical: return "Urgent"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            isSelected
                                ? levelColor.opacity(0.15)
                                : AppColors.surface(colorScheme)
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected ? levelColor.opacity(0.3) : Color.clear,
                                    lineWidth: 1
                                )
                        )

                    Image(systemName: level.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? levelColor : AppColors.textSecondary(colorScheme))
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(level.displayName)
                            .font(.custom("ProductSans-Bold", size: 17))
                            .foregroundColor(AppColors.text(colorScheme))

                        if level == .timeSensitive {
                            Text("Best")
                                .font(.custom("ProductSans-Bold", size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .orange.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }

                    Text(level.description)
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Priority indicator
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            ForEach(0..<3) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        index < priorityBars
                                            ? levelColor
                                            : AppColors.border(colorScheme)
                                    )
                                    .frame(width: 16, height: 4)
                            }
                        }

                        Text(priorityText + " priority")
                            .font(.custom("ProductSans-Regular", size: 11))
                            .foregroundColor(AppColors.textSecondary(colorScheme))
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? levelColor : AppColors.border(colorScheme),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(levelColor)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppColors.surface(colorScheme))
                    .shadow(
                        color: isSelected ? levelColor.opacity(0.15) : Color.black.opacity(0.03),
                        radius: isSelected ? 12 : 6,
                        x: 0,
                        y: isSelected ? 6 : 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? levelColor.opacity(0.4) : AppColors.border(colorScheme).opacity(0.5),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(NotificationCardButtonStyle())
    }

    private var priorityBars: Int {
        switch level {
        case .standard: return 1
        case .timeSensitive: return 2
        case .critical: return 3
        }
    }
}

// MARK: - Button Style

private struct NotificationCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    NotificationPermissionView(isPresented: .constant(true), isPostSignUp: true)
        .environmentObject(ThemeManager.shared)
}
