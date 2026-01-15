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

    // Whether this is shown after account creation (vs. on app launch)
    var isPostSignUp: Bool = false

    // Callback when user enables notifications
    var onEnableNotifications: ((NotificationLevel) -> Void)? = nil

    @State private var selectedLevel: NotificationLevel = .timeSensitive
    @State private var isRequestingPermission = false

    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // Bell icon
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                                .frame(width: 100, height: 100)

                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(AppColors.primary)
                        }
                        .padding(.top, 40)

                        // Title
                        Text(isPostSignUp ? "Never Miss a Dose" : "Notification Settings")
                            .font(.custom("ProductSans-Bold", size: 28))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .multilineTextAlignment(.center)

                        // Description
                        Text("Choose how you want to be reminded about your medications.")
                            .font(.custom("ProductSans-Regular", size: 16))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)

                    // Notification Level Options
                    VStack(spacing: 12) {
                        ForEach(NotificationLevel.allCases) { level in
                            NotificationLevelCard(
                                level: level,
                                isSelected: selectedLevel == level,
                                colorScheme: themeManager.colorScheme
                            ) {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedLevel = level
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 100)
                }
            }

            // Bottom buttons (fixed)
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    // Enable button
                    Button(action: handleEnableNotifications) {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Enable Notifications")
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
                    .disabled(isRequestingPermission)

                    // Skip/Later button
                    if isPostSignUp {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Maybe Later")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.background(themeManager.colorScheme).opacity(0),
                            AppColors.background(themeManager.colorScheme),
                            AppColors.background(themeManager.colorScheme)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .allowsHitTesting(false)
                )
            }
        }
    }

    private func handleEnableNotifications() {
        let impact = UIImpactFeedbackGenerator(style: .light)
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

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.primary : AppColors.primary.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: level.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : AppColors.primary)
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(level.displayName)
                            .font(.custom("ProductSans-Bold", size: 17))
                            .foregroundColor(AppColors.text(colorScheme))

                        if level == .timeSensitive {
                            Text("Recommended")
                                .font(.custom("ProductSans-Bold", size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(AppColors.primary)
                                )
                        }

                        Spacer()
                    }

                    Text(level.description)
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.textSecondary(colorScheme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Interruption level indicator
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(index < interruptionIndicatorCount(for: level)
                                      ? indicatorColor(for: level)
                                      : AppColors.border(colorScheme))
                                .frame(width: 8, height: 8)
                        }
                        Text(interruptionLevelText(for: level))
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(AppColors.textSecondary(colorScheme))
                    }
                    .padding(.top, 4)
                }

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.primary : AppColors.border(colorScheme), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.primary : AppColors.border(colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func interruptionIndicatorCount(for level: NotificationLevel) -> Int {
        switch level {
        case .standard: return 1
        case .timeSensitive: return 2
        case .critical: return 3
        }
    }

    private func indicatorColor(for level: NotificationLevel) -> Color {
        switch level {
        case .standard: return .gray
        case .timeSensitive: return .orange
        case .critical: return .red
        }
    }

    private func interruptionLevelText(for level: NotificationLevel) -> String {
        switch level {
        case .standard: return "Normal priority"
        case .timeSensitive: return "High priority"
        case .critical: return "Maximum priority"
        }
    }
}

#Preview {
    NotificationPermissionView(isPresented: .constant(true), isPostSignUp: true)
        .environmentObject(ThemeManager.shared)
}
