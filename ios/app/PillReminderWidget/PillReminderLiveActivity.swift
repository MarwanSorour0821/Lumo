//
//  PillReminderLiveActivity.swift
//  PillReminderWidget
//
//  Live Activity views for Dynamic Island pill reminders
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

@available(iOS 16.2, *)
struct PillReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PillReminderAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                // Compact leading (pill icon)
                CompactLeadingView()
            } compactTrailing: {
                // Compact trailing (time remaining)
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal view (just icon)
                MinimalView()
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenView: View {
    let context: ActivityViewContext<PillReminderAttributes>

    private var timeRemaining: String {
        let minutes = context.state.minutesRemaining
        if minutes <= 0 {
            return "now"
        } else if minutes < 60 {
            return "in \(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "in \(hours)h \(mins)m"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Pill icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#C7002B").opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "pills.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#C7002B"))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Header
                HStack {
                    Text("Pill reminder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    // Time badge
                    Text(timeRemaining)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7002B"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#C7002B").opacity(0.2))
                        )
                }

                // Previous pill info
                if let previousPill = context.state.previousPillName {
                    Text("Previous pill: \(previousPill)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Next pill info
                HStack {
                    Text("Next pill:")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))

                    Text(context.state.pillName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#C7002B"))

                    Spacer()

                    Text(context.state.formattedTime)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Action buttons
                HStack(spacing: 12) {
                    // Skip button
                    Link(destination: URL(string: "lumo://pill-reminder/skip/\(context.attributes.itemId)")!) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }

                    // Take button
                    Link(destination: URL(string: "lumo://pill-reminder/take/\(context.attributes.itemId)")!) {
                        Text("Take")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#C7002B"))
                            )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.black)
    }
}

// MARK: - Compact Views

@available(iOS 16.2, *)
struct CompactLeadingView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#C7002B").opacity(0.3))
                .frame(width: 28, height: 28)

            Image(systemName: "pills.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#C7002B"))
        }
    }
}

@available(iOS 16.2, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<PillReminderAttributes>

    private var timeText: String {
        let minutes = context.state.minutesRemaining
        if minutes <= 0 {
            return "now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h"
        }
    }

    var body: some View {
        Text(timeText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "#C7002B"))
    }
}

@available(iOS 16.2, *)
struct MinimalView: View {
    var body: some View {
        Image(systemName: "pills.fill")
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "#C7002B"))
    }
}

// MARK: - Expanded Views

@available(iOS 16.2, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<PillReminderAttributes>

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#C7002B").opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "pills.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#C7002B"))
            }

            Text("Pill reminder")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<PillReminderAttributes>

    private var timeRemaining: String {
        let minutes = context.state.minutesRemaining
        if minutes <= 0 {
            return "now"
        } else if minutes < 60 {
            return "in \(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "in \(hours)h"
            }
            return "in \(hours)h \(mins)m"
        }
    }

    var body: some View {
        Text(timeRemaining)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "#C7002B"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: "#C7002B").opacity(0.2))
            )
    }
}

@available(iOS 16.2, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<PillReminderAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let previousPill = context.state.previousPillName {
                Text("Previous pill: \(previousPill)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 6) {
                Text("Next pill:")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))

                Text(context.state.pillName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#C7002B"))

                Spacer()

                Text(context.state.formattedTime)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<PillReminderAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Skip button
            Link(destination: URL(string: "lumo://pill-reminder/skip/\(context.attributes.itemId)")!) {
                HStack {
                    Spacer()
                    Text("Skip")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }

            // Take button
            Link(destination: URL(string: "lumo://pill-reminder/take/\(context.attributes.itemId)")!) {
                HStack {
                    Spacer()
                    Text("Take")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(Color(hex: "#C7002B"))
                )
            }
        }
    }
}

// MARK: - Preview

@available(iOS 16.2, *)
struct PillReminderLiveActivity_Previews: PreviewProvider {
    static var attributes = PillReminderAttributes(
        itemId: "test-id",
        itemType: "medication",
        doseIndex: 0
    )

    static var contentState = PillReminderAttributes.ContentState(
        pillName: "Roaccutane 30 mg",
        scheduledTime: Date().addingTimeInterval(19 * 60), // 19 minutes from now
        previousPillName: "Carsil 20 mg",
        isActive: true
    )

    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")

        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")

        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")

        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Lock Screen")
    }
}
