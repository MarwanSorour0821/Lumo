//
//  LumoWidgetBundle.swift
//  LumoWidget
//
//  Created by Karim Mohamed on 18/01/2026.
//

import WidgetKit
import SwiftUI

@main
struct SupplementWidget: Widget {
    let kind: String = "SupplementWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SupplementProvider()) { entry in
            SupplementWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Supplements")
        .description("Track your remaining supplements and medications for today.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
