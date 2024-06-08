//
//  TimerWidget.swift
//  TimerWidget
//
//  Created by Martin Mihle Nygaard on 04/06/2024.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), elapsedTime: 0, isRunning: false, configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), elapsedTime: 3600, isRunning: true, configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for minuteOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset * 10, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, elapsedTime: Double(minuteOffset * 600), isRunning: true, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let elapsedTime: TimeInterval
    let isRunning: Bool
    let configuration: ConfigurationAppIntent
}

struct TimerWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Spacer()
            Text("\(entry.configuration.eventName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(formatTime(entry.elapsedTime))")
                .font(.title)
                .monospaced()
            Spacer()
        }
        .padding()
        .activityBackgroundTint(nil)
        .activitySystemActionForegroundColor(Color.primary)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct TimerWidget: Widget {
    let kind: String = "TimerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TimerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var example: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.eventName = "Sample Event"
        return intent
    }
}

#Preview(as: .systemSmall) {
    TimerWidget()
} timeline: {
    SimpleEntry(date: .now, elapsedTime: 3600, isRunning: true, configuration: .example)
    SimpleEntry(date: .now, elapsedTime: 1800, isRunning: false, configuration: .example)
}
