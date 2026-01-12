//
//  NotificationPermissionView.swift
//  app
//
//  A view to prompt users to enable notifications
//

import SwiftUI

struct NotificationPermissionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool

    // Whether this is shown after account creation (vs. on app launch)
    var isPostSignUp: Bool = false

    // Callback when user enables notifications
    var onEnableNotifications: (() -> Void)? = nil

    @State private var isRequestingPermission = false

    var body: some View {
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Bell icon with animation
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(AppColors.primary)
                }
                .padding(.bottom, 32)

                // Title
                Text(isPostSignUp ? "Never Miss a Dose" : "Enable Notifications")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Description
                Text(isPostSignUp
                    ? "We'd like to send you notifications to remind you when it's time to take your medication. This helps you stay consistent and healthy."
                    : "Notifications are currently disabled. We'd like to send you reminders about your medication to help you stay on track.")
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    NotificationFeatureRow(
                        icon: "alarm.fill",
                        title: "Medication Reminders",
                        description: "Get notified when it's time to take your medication",
                        colorScheme: themeManager.colorScheme
                    )

                    NotificationFeatureRow(
                        icon: "clock.badge.checkmark.fill",
                        title: "Follow-up Alerts",
                        description: "Reminder if you haven't marked a dose as taken",
                        colorScheme: themeManager.colorScheme
                    )

                    NotificationFeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Health Insights",
                        description: "Updates about your health analysis results",
                        colorScheme: themeManager.colorScheme
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()
                Spacer()

                // Enable button
                Button(action: handleEnableNotifications) {
                    HStack {
                        if isRequestingPermission {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isPostSignUp ? "Enable Notifications" : "Open Settings")
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
                .padding(.horizontal, 24)

                // Skip/Later button
                Button(action: {
                    isPresented = false
                }) {
                    Text(isPostSignUp ? "Maybe Later" : "Not Now")
                        .font(.custom("ProductSans-Regular", size: 16))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
    }

    private func handleEnableNotifications() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        if isPostSignUp {
            // Request permission directly
            isRequestingPermission = true
            Task {
                let granted = await NotificationManager.shared.requestPermissions()
                await MainActor.run {
                    isRequestingPermission = false
                    if granted {
                        onEnableNotifications?()
                    }
                    isPresented = false
                }
            }
        } else {
            // Open settings
            NotificationManager.shared.openNotificationSettings()
            isPresented = false
        }
    }
}

// MARK: - Feature Row
struct NotificationFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let colorScheme: ColorScheme?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppColors.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("ProductSans-Bold", size: 15))
                    .foregroundColor(AppColors.text(colorScheme))

                Text(description)
                    .font(.custom("ProductSans-Regular", size: 13))
                    .foregroundColor(AppColors.textSecondary(colorScheme))
            }
        }
    }
}

#Preview {
    NotificationPermissionView(isPresented: .constant(true), isPostSignUp: true)
        .environmentObject(ThemeManager.shared)
}
