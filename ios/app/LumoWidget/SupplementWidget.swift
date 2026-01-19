//
//  SupplementWidget.swift
//  LumoWidget
//
//  Created by Karim Mohamed on 18/01/2026.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Group Configuration

/// App Group identifier - must match in both app and widget entitlements
private let appGroupIdentifier = "group.com.lumoblood.app"

// MARK: - Lumo Colors

/// Lumo brand colors
enum LumoColors {
    static let primary = Color(hex: "#C7002B")  // Lumo red
    static let primaryDark = Color(hex: "#8E0F20")
    static let primaryLight = Color(hex: "#D4283D")
}

/// Color hex extension for widget
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Keys for shared UserDefaults
private enum WidgetDataKeys {
    static let supplements = "widget_supplements"
    static let lastUpdated = "widget_last_updated"
    static let isLoggedIn = "widget_is_logged_in"
}

// MARK: - Data Models

/// Represents a single dose time and its taken status
struct WidgetDoseStatus: Codable, Identifiable {
    var id: String { "\(supplementId)-\(timeIndex)" }
    let supplementId: String
    let timeIndex: Int
    let time: String  // e.g., "09:00:00"
    let isTaken: Bool
    
    /// Formatted time for display (e.g., "9:00 AM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        // Fallback: try HH:mm format
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return time
    }
}

/// Represents a supplement/medication item for the widget
struct WidgetSupplement: Codable, Identifiable {
    let id: String
    let name: String
    let type: String  // "supplement", "medication", "food"
    let reminderTimes: [String]
    let isTakenToday: Bool
    let doseStatuses: [WidgetDoseStatus]
    
    /// Icon name based on type
    var iconName: String {
        switch type {
        case "medication":
            return "cross.case.fill"
        case "food":
            return "leaf.fill"
        default:
            return "pills.fill"
        }
    }
    
    /// Color based on type
    var color: Color {
        switch type {
        case "medication":
            return .blue
        case "food":
            return .green
        default:
            return .orange
        }
    }
    
    /// Check if all doses are taken
    var allDosesTaken: Bool {
        if doseStatuses.isEmpty {
            return isTakenToday
        }
        return doseStatuses.allSatisfy { $0.isTaken }
    }
    
    /// Get pending (untaken) doses
    var pendingDoses: [WidgetDoseStatus] {
        doseStatuses.filter { !$0.isTaken }
    }
    
    /// Next pending dose time
    var nextPendingDose: WidgetDoseStatus? {
        pendingDoses.first
    }
}

// MARK: - Timeline Entry

struct SupplementEntry: TimelineEntry {
    let date: Date
    let supplements: [WidgetSupplement]
    let isLoggedIn: Bool
    
    /// Supplements that haven't been fully taken today
    var pendingSupplements: [WidgetSupplement] {
        supplements.filter { !$0.allDosesTaken }
    }
    
    /// Supplements that have been fully taken today
    var completedSupplements: [WidgetSupplement] {
        supplements.filter { $0.allDosesTaken }
    }
    
    /// Count of pending items
    var pendingCount: Int {
        pendingSupplements.count
    }
    
    /// Count of completed items
    var completedCount: Int {
        completedSupplements.count
    }
    
    /// Total supplements count
    var totalCount: Int {
        supplements.count
    }
    
    /// Completion progress (0.0 to 1.0)
    var completionProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    /// Formatted date string (e.g., "January 18")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        return formatter.string(from: date)
    }
    
    /// Total pending doses across all supplements
    var totalPendingDoses: Int {
        supplements.reduce(0) { total, supplement in
            if supplement.doseStatuses.isEmpty {
                return total + (supplement.isTakenToday ? 0 : 1)
            }
            return total + supplement.pendingDoses.count
        }
    }
}

// MARK: - Timeline Provider

struct SupplementProvider: TimelineProvider {
    
    // MARK: - Sample Data (for previews and placeholder)
    
    static let sampleSupplements: [WidgetSupplement] = [
        WidgetSupplement(
            id: "1",
            name: "Vitamin D3",
            type: "supplement",
            reminderTimes: ["09:00:00"],
            isTakenToday: true,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "1", timeIndex: 0, time: "09:00:00", isTaken: true)
            ]
        ),
        WidgetSupplement(
            id: "2",
            name: "Omega-3 Fish Oil",
            type: "supplement",
            reminderTimes: ["09:00:00", "21:00:00"],
            isTakenToday: false,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "2", timeIndex: 0, time: "09:00:00", isTaken: true),
                WidgetDoseStatus(supplementId: "2", timeIndex: 1, time: "21:00:00", isTaken: false)
            ]
        ),
        WidgetSupplement(
            id: "3",
            name: "Magnesium Glycinate",
            type: "supplement",
            reminderTimes: ["21:00:00"],
            isTakenToday: false,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "3", timeIndex: 0, time: "21:00:00", isTaken: false)
            ]
        ),
        WidgetSupplement(
            id: "4",
            name: "Probiotics",
            type: "supplement",
            reminderTimes: ["08:00:00"],
            isTakenToday: true,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "4", timeIndex: 0, time: "08:00:00", isTaken: true)
            ]
        ),
        WidgetSupplement(
            id: "5",
            name: "Vitamin C",
            type: "supplement",
            reminderTimes: ["12:00:00"],
            isTakenToday: false,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "5", timeIndex: 0, time: "12:00:00", isTaken: false)
            ]
        )
    ]
    
    func placeholder(in context: Context) -> SupplementEntry {
        SupplementEntry(date: Date(), supplements: Self.sampleSupplements, isLoggedIn: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SupplementEntry) -> Void) {
        // For snapshot (widget gallery), show sample data
        if context.isPreview {
            let entry = SupplementEntry(date: Date(), supplements: Self.sampleSupplements, isLoggedIn: true)
            completion(entry)
            return
        }
        
        // For actual snapshot, try to load real data
        let (supplements, isLoggedIn) = loadSupplementsFromSharedStorage()
        let entry = SupplementEntry(date: Date(), supplements: supplements, isLoggedIn: isLoggedIn)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SupplementEntry>) -> Void) {
        // Load supplements from shared storage
        let (supplements, isLoggedIn) = loadSupplementsFromSharedStorage()
        
        let currentDate = Date()
        let entry = SupplementEntry(date: currentDate, supplements: supplements, isLoggedIn: isLoggedIn)
        
        // Refresh every 15 minutes to keep dose times accurate
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Data Loading
    
    private func loadSupplementsFromSharedStorage() -> (supplements: [WidgetSupplement], isLoggedIn: Bool) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Widget: Failed to access App Group")
            return ([], false)
        }
        
        let isLoggedIn = sharedDefaults.bool(forKey: WidgetDataKeys.isLoggedIn)
        print("🔍 Widget: Read isLoggedIn = \(isLoggedIn) from App Group")
        
        guard let data = sharedDefaults.data(forKey: WidgetDataKeys.supplements) else {
            print("ℹ️ Widget: No supplement data found (isLoggedIn=\(isLoggedIn))")
            return ([], isLoggedIn)
        }
        
        do {
            let supplements = try JSONDecoder().decode([WidgetSupplement].self, from: data)
            print("✅ Widget: Loaded \(supplements.count) supplements")
            return (supplements, isLoggedIn)
        } catch {
            print("❌ Widget: Failed to decode supplements - \(error)")
            return ([], isLoggedIn)
        }
    }
}

// MARK: - Logo Header Component

/// Lumo logo and brand name header
struct LumoHeaderView: View {
    var compact: Bool = false
    
    var body: some View {
        HStack(spacing: compact ? 5 : 6) {
            // Logo image from widget assets
            if let uiImage = UIImage(named: "LumoLogo") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
            } else {
                // Fallback: show a red circle if image not found
                Circle()
                    .fill(LumoColors.primary)
                    .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
            }
            
            Text("Lumo")
                .font(.system(size: compact ? 14 : 16, weight: .bold, design: .default))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Progress Ring Component

/// Semi-circular progress ring showing completion
struct ProgressRingView: View {
    let progress: Double  // 0.0 to 1.0
    let completed: Int
    let total: Int
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background arc
            Circle()
                .trim(from: 0.0, to: 0.75)
                .stroke(
                    Color.gray.opacity(0.25),
                    style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
            
            // Progress arc - solid Lumo red
            Circle()
                .trim(from: 0.0, to: min(progress * 0.75, 0.75))
                .stroke(
                    LumoColors.primary,
                    style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            // Center text
            VStack(spacing: 0) {
                Text("\(completed)/\(total)")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Widget Views

/// Small widget view - compact layout with progress ring
struct SupplementWidgetSmallView: View {
    let entry: SupplementEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header row with logo and progress ring
            HStack(alignment: .center) {
                LumoHeaderView(compact: true)
                
                Spacer()
                
                // Progress ring
                ProgressRingView(
                    progress: entry.completionProgress,
                    completed: entry.completedCount,
                    total: entry.totalCount,
                    size: 44
                )
            }
            
            // Date
            Text(entry.formattedDate)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(LumoColors.primary)
            
            Spacer()
            
            if entry.totalCount == 0 {
                // No supplements
                Text("No supplements")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else if entry.pendingCount == 0 {
                // All done
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All done!")
                        .font(.system(size: 14, weight: .semibold))
                }
            } else {
                // Show only 1 pending item
                if let first = entry.pendingSupplements.first {
                    SupplementItemRow(supplement: first, compact: true)
                }
                
                // Show "+X more" if more than 1
                if entry.pendingCount > 1 {
                    Text("+\(entry.pendingCount - 1) more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(4)
    }
}

/// Medium widget view - shows list of pending supplements
struct SupplementWidgetMediumView: View {
    let entry: SupplementEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with logo and progress ring aligned
            HStack(alignment: .top) {
                // Left side: Logo, subtitle, and date
                VStack(alignment: .leading, spacing: 3) {
                    LumoHeaderView(compact: false)
                    
                    Text("Your supplements")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(entry.formattedDate)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(LumoColors.primary)
                }
                
                Spacer()
                
                // Right side: Progress ring (aligned with top)
                ProgressRingView(
                    progress: entry.completionProgress,
                    completed: entry.completedCount,
                    total: entry.totalCount,
                    size: 58
                )
            }
            
            Spacer(minLength: 4)
            
            if entry.totalCount == 0 {
                // No supplements
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.secondary)
                    Text("Add supplements in the app")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if entry.pendingCount == 0 {
                // All done
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("All done for today!")
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
            } else {
                // Show pending items
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.pendingSupplements.prefix(3)) { supplement in
                        SupplementItemRow(supplement: supplement, compact: false)
                    }
                    
                    if entry.pendingCount > 3 {
                        Text("+\(entry.pendingCount - 3) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
    }
}

/// Large widget view - detailed list with dose times
struct SupplementWidgetLargeView: View {
    let entry: SupplementEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with logo and progress ring aligned
            HStack(alignment: .top) {
                // Left side: Logo, subtitle, and date
                VStack(alignment: .leading, spacing: 4) {
                    LumoHeaderView(compact: false)
                    
                    Text("Your supplements")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(entry.formattedDate)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(LumoColors.primary)
                }
                
                Spacer()
                
                // Right side: Progress ring (aligned with top)
                ProgressRingView(
                    progress: entry.completionProgress,
                    completed: entry.completedCount,
                    total: entry.totalCount,
                    size: 70
                )
            }
            
            Divider()
                .padding(.vertical, 2)
            
            if entry.totalCount == 0 {
                // No supplements
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No supplements yet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add supplements in the Lumo app")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if entry.pendingCount == 0 {
                // All done
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Great job!")
                        .font(.system(size: 18, weight: .semibold))
                    Text("You've taken all your supplements today")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Show pending items
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.pendingSupplements.prefix(6)) { supplement in
                        SupplementItemRow(supplement: supplement, compact: false, showDoseTime: true)
                    }
                }
                
                Spacer(minLength: 4)
                
                if entry.pendingCount > 6 {
                    Text("+\(entry.pendingCount - 6) more")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
    }
}

/// Unified row view for supplement items across all widget sizes
struct SupplementItemRow: View {
    let supplement: WidgetSupplement
    var compact: Bool = false
    var showDoseTime: Bool = false
    
    var body: some View {
        Button(intent: ToggleSupplementIntent(
            supplementId: supplement.id,
            supplementName: supplement.name,
            timeIndex: supplement.nextPendingDose?.timeIndex ?? -1
        )) {
            HStack(spacing: compact ? 8 : 10) {
                // Circle toggle
                Image(systemName: supplement.allDosesTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 18 : 20))
                    .foregroundColor(supplement.allDosesTaken ? .green : .white.opacity(0.6))
                
                // Supplement name
                Text(supplement.name)
                    .font(.system(size: compact ? 13 : 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(supplement.allDosesTaken, color: .secondary)
                    .foregroundColor(supplement.allDosesTaken ? .secondary : .primary)
                
                Spacer()
                
                // Show dose time for large widget
                if showDoseTime, let nextDose = supplement.nextPendingDose {
                    Text(nextDose.formattedTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accessory Widget Views (Lock Screen)

/// Circular accessory widget - shows count
struct SupplementAccessoryCircularView: View {
    let entry: SupplementEntry
    
    var body: some View {
        ZStack {
            if entry.pendingCount == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
            } else {
                VStack(spacing: 0) {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 22, weight: .bold))
                    Text("left")
                        .font(.system(size: 10))
                }
            }
        }
        .widgetAccentable()
    }
}

/// Rectangular accessory widget - shows next pending supplement
struct SupplementAccessoryRectangularView: View {
    let entry: SupplementEntry
    
    var body: some View {
        if entry.pendingCount == 0 {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                VStack(alignment: .leading) {
                    Text("Supplements")
                        .font(.headline)
                    Text("All done for today!")
                        .font(.caption)
                }
            }
            .widgetAccentable()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "pills.fill")
                    Text("\(entry.pendingCount) supplements left")
                        .font(.headline)
                }
                .widgetAccentable()
                
                if let first = entry.pendingSupplements.first {
                    Text("Next: \(first.name)")
                        .font(.caption)
                    
                    if let nextDose = first.nextPendingDose {
                        Text("at \(nextDose.formattedTime)")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

/// Inline accessory widget - single line of text
struct SupplementAccessoryInlineView: View {
    let entry: SupplementEntry
    
    var body: some View {
        if entry.pendingCount == 0 {
            Label("All supplements taken ✓", systemImage: "pills.fill")
        } else {
            Label("\(entry.pendingCount) supplements remaining", systemImage: "pills.fill")
        }
    }
}

// MARK: - Not Logged In Views

/// Not logged in view for home screen widgets
struct NotLoggedInView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Logo header
            LumoHeaderView(compact: false)
            
            // Subtitle
            Text("Your supplements")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Login prompt
            VStack(spacing: 6) {
                Image(systemName: "person.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                
                Text("Log in to Lumo")
                    .font(.system(size: 13, weight: .semibold))
                
                Text("to track your supplements")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding(14)
    }
}

/// Not logged in view for lock screen circular
struct NotLoggedInCircularView: View {
    var body: some View {
        Image(systemName: "person.circle")
            .font(.system(size: 24))
            .widgetAccentable()
    }
}

/// Not logged in view for lock screen rectangular
struct NotLoggedInRectangularView: View {
    var body: some View {
        HStack {
            Image(systemName: "person.circle")
            VStack(alignment: .leading) {
                Text("Supplements")
                    .font(.headline)
                Text("Log in to view")
                    .font(.caption)
            }
        }
        .widgetAccentable()
    }
}

/// Not logged in view for lock screen inline
struct NotLoggedInInlineView: View {
    var body: some View {
        Label("Log in to see supplements", systemImage: "pills.fill")
    }
}

// MARK: - Main Widget Entry View

struct SupplementWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SupplementEntry
    
    var body: some View {
        if !entry.isLoggedIn {
            // Show not logged in state
            switch family {
            case .accessoryCircular:
                NotLoggedInCircularView()
            case .accessoryRectangular:
                NotLoggedInRectangularView()
            case .accessoryInline:
                NotLoggedInInlineView()
            default:
                NotLoggedInView()
            }
        } else {
            // Show normal widget content
            switch family {
            case .systemSmall:
                SupplementWidgetSmallView(entry: entry)
            case .systemMedium:
                SupplementWidgetMediumView(entry: entry)
            case .systemLarge:
                SupplementWidgetLargeView(entry: entry)
            case .accessoryCircular:
                SupplementAccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                SupplementAccessoryRectangularView(entry: entry)
            case .accessoryInline:
                SupplementAccessoryInlineView(entry: entry)
            default:
                SupplementWidgetSmallView(entry: entry)
            }
        }
    }
}

// MARK: - Previews

struct SupplementWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Logged in
            SupplementWidgetEntryView(entry: SupplementEntry(date: .now, supplements: SupplementProvider.sampleSupplements, isLoggedIn: true))
                .containerBackground(.fill.tertiary, for: .widget)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Logged In")
            SupplementWidgetEntryView(entry: SupplementEntry(date: .now, supplements: SupplementProvider.sampleSupplements, isLoggedIn: true))
                .containerBackground(.fill.tertiary, for: .widget)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium - Logged In")
            SupplementWidgetEntryView(entry: SupplementEntry(date: .now, supplements: SupplementProvider.sampleSupplements, isLoggedIn: true))
                .containerBackground(.fill.tertiary, for: .widget)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large - Logged In")

            // Not logged in
            SupplementWidgetEntryView(entry: SupplementEntry(date: .now, supplements: [], isLoggedIn: false))
                .containerBackground(.fill.tertiary, for: .widget)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Not Logged In")
            SupplementWidgetEntryView(entry: SupplementEntry(date: .now, supplements: [], isLoggedIn: false))
                .containerBackground(.fill.tertiary, for: .widget)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium - Not Logged In")
            SupplementWidgetEntryView(entry: SupplementEntry(date: .now, supplements: [], isLoggedIn: false))
                .containerBackground(.fill.tertiary, for: .widget)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large - Not Logged In")
        }
    }
}
