//
//  PillReminderWidgetBundle.swift
//  PillReminderWidget
//
//  Widget Bundle for Pill Reminder Live Activity
//

import WidgetKit
import SwiftUI

@main
struct PillReminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity widget
        if #available(iOS 16.2, *) {
            PillReminderLiveActivity()
        }
    }
}
