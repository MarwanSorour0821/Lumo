//
//  SupplementWidget.swift
//  LumoWidget
//
//  Created by Karim Mohamed on 18/01/2026.
//

import WidgetKit
import SwiftUI

// MARK: - App Group Configuration

/// App Group identifier - must match in both app and widget entitlements
private let appGroupIdentifier = "group.com.lumoblood.app"

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
    
    /// Count of pending items
    var pendingCount: Int {
        pendingSupplements.count
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
            isTakenToday: false,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "1", timeIndex: 0, time: "09:00:00", isTaken: false)
            ]
        ),
        WidgetSupplement(
            id: "2",
            name: "Omega-3",
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
            name: "Magnesium",
            type: "supplement",
            reminderTimes: ["21:00:00"],
            isTakenToday: false,
            doseStatuses: [
                WidgetDoseStatus(supplementId: "3", timeIndex: 0, time: "21:00:00", isTaken: false)
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

// MARK: - Widget Views

/// Small widget view - shows count and up to 2 items
struct SupplementWidgetSmallView: View {
    let entry: SupplementEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "pills.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if entry.pendingCount == 0 {
                // All done state
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("All done!")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Show pending count
                Text("\(entry.pendingCount)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(entry.pendingCount == 1 ? "supplement left" : "supplements left")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show first pending item
                if let first = entry.pendingSupplements.first {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(first.color)
                            .frame(width: 8, height: 8)
                        
                        Text(first.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
    }
}

/// Medium widget view - shows list of pending supplements
struct SupplementWidgetMediumView: View {
    let entry: SupplementEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - summary
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("Today's Supplements")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if entry.pendingCount == 0 {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text("All done!")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Spacer()
                } else {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("remaining")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side - list of pending items
            if entry.pendingCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.pendingSupplements.prefix(4)) { supplement in
                        SupplementRowView(supplement: supplement)
                    }
                    
                    if entry.pendingSupplements.count > 4 {
                        Text("+\(entry.pendingSupplements.count - 4) more")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}

/// Large widget view - detailed list with dose times
struct SupplementWidgetLargeView: View {
    let entry: SupplementEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "pills.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Today's Supplements")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount) remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All done!")
                            .foregroundColor(.green)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
            }
            
            Divider()
            
            if entry.pendingCount == 0 {
                // All done state
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
                // List of supplements
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.pendingSupplements.prefix(6)) { supplement in
                        SupplementDetailRowView(supplement: supplement)
                        
                        if supplement.id != entry.pendingSupplements.prefix(6).last?.id {
                            Divider()
                                .padding(.leading, 32)
                        }
                    }
                    
                    if entry.pendingSupplements.count > 6 {
                        HStack {
                            Spacer()
                            Text("+\(entry.pendingSupplements.count - 6) more supplements")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
    }
}

/// Simple row view for medium widget
struct SupplementRowView: View {
    let supplement: WidgetSupplement
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: supplement.iconName)
                .font(.system(size: 12))
                .foregroundColor(supplement.color)
                .frame(width: 16)
            
            Text(supplement.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            
            Spacer()
            
            if let nextDose = supplement.nextPendingDose {
                Text(nextDose.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Detailed row view for large widget
struct SupplementDetailRowView: View {
    let supplement: WidgetSupplement
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(supplement.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: supplement.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(supplement.color)
            }
            
            // Name and doses
            VStack(alignment: .leading, spacing: 2) {
                Text(supplement.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                // Show pending dose times
                if !supplement.pendingDoses.isEmpty {
                    Text(supplement.pendingDoses.map { $0.formattedTime }.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Pending doses count
            if supplement.pendingDoses.count > 1 {
                Text("\(supplement.pendingDoses.count) doses")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(supplement.color)
                    .clipShape(Capsule())
            }
        }
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
        VStack(spacing: 8) {
            Image(systemName: "person.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("Log in to Lumo")
                .font(.system(size: 14, weight: .semibold))
            
            Text("to see your supplements")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
