//
//  TimerWidgetLiveActivity.swift
//  TimerWidget
//
//  Created by Martin Mihle Nygaard on 04/06/2024.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var eventName: String
        var eventNotes: String
        var elapsedTime: TimeInterval
        var isRunning: Bool
    }

    // Fixed non-changing properties about your activity go here!
    // var myNonChangingProperty: String
}

struct TimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Spacer()
                Text("\(context.state.eventName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(formatTime(context.state.elapsedTime, context.isStale))")
                    .font(.title)
                    .monospaced()
                Spacer()
            }
            .padding()
            .activityBackgroundTint(nil)
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                }
                DynamicIslandExpandedRegion(.trailing) {
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(formatTime(context.state.elapsedTime, context.isStale))")
                                .font(.title).monospaced()
                            Spacer()
                        }
                        Spacer()
                    }
                }
            } compactLeading: {
                HStack {
                    Spacer()
                    Image(systemName: "stopwatch.fill")
                }
            } compactTrailing: {
                VStack {
                    Spacer()
                    HStack {
                        Text("\(formatTime(context.state.elapsedTime, context.isStale))")
                            .monospaced()
                        Spacer()
                    }
                    Spacer()
                }
            } minimal: {
                HStack {
                    Spacer()
                    Image(systemName: (context.state.isRunning ? "stopwatch.fill" : "stopwatch"))
                    Spacer()
                }
            }
            .widgetURL(URL(string: "timerapp://"))
            .keylineTint(Color.black)
        }
    }
    
    private func formatTime(_ interval: TimeInterval, _ stale: Bool) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if Int(interval) > 60 || stale {
            return String(format: "%02d:%02d:--", hours, minutes)
        } else {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

extension TimerWidgetAttributes {
    fileprivate static var preview: TimerWidgetAttributes {
        TimerWidgetAttributes()
    }
}

extension TimerWidgetAttributes.ContentState {
    fileprivate static var running: TimerWidgetAttributes.ContentState {
        TimerWidgetAttributes.ContentState(
            eventName: "Sample Event",
            eventNotes: "These are some notes about the event.",
            elapsedTime: 3600,
            isRunning: true
        )
    }
    
    fileprivate static var paused: TimerWidgetAttributes.ContentState {
        TimerWidgetAttributes.ContentState(
            eventName: "Sample Event",
            eventNotes: "These are some notes about the event.",
            elapsedTime: 1800,
            isRunning: false
        )
    }
}

#Preview("Notification", as: .content, using: TimerWidgetAttributes.preview) {
   TimerWidgetLiveActivity()
} contentStates: {
    TimerWidgetAttributes.ContentState.running
    TimerWidgetAttributes.ContentState.paused
}
