//
//  TimerWidgetLiveActivity.swift
//  TimerWidget
//
//  Created by Martin Mihle Nygaard on 04/06/2024.
//

import ActivityKit
import WidgetKit
import SwiftUI

// TimerWidgetAttributes is defined in Tracker/Core/Models/TimerWidgetAttributes.swift
// and compiled into both targets so the app can start activities and the widget can render them.

struct TimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Spacer()
                Text(context.state.eventName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if context.state.isRunning {
                    // Text(timerInterval:) renders a live-updating countdown/countup
                    // entirely on the system side — no app updates needed for the clock.
                    Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                        .font(.title)
                        .monospaced()
                        .multilineTextAlignment(.center)
                } else {
                    // Show static time when paused
                    Text("\(formatTime(context.state.elapsedTime))")
                        .font(.title)
                        .monospaced()
                        .multilineTextAlignment(.center)
                }
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
                    VStack() {
                        Spacer()
                        HStack() {
                            Spacer()
                            Image(systemName: "stop.circle.fill")
                                .font(.largeTitle)
                                .padding()
                                .monospaced()
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                }
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    VStack() {
                        Spacer()
                        HStack() {
                            if context.state.isRunning {
                                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                                    .font(.largeTitle).monospaced()
                                    .padding(.bottom)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                
                            } else {
                                Text("\(formatTime(context.state.elapsedTime))")
                                    .font(.largeTitle).monospaced()
                                    .padding(.bottom)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
            } compactLeading: {
                Image(systemName: "stopwatch.fill")
                    .frame(idealWidth: 20, maxWidth: 20, alignment: .center)
            } compactTrailing: {
                if context.state.isRunning {
                    Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                        .monospaced()
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, 5)
                        .frame(idealWidth: 80, maxWidth: 80, alignment: .center)
                } else {
                    Text("\(formatTime(context.state.elapsedTime))")
                        .monospaced()
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, 5)
                        .frame(idealWidth: 80, maxWidth: 80, alignment: .center)
                    
                }
            } minimal: {
                Image(systemName: (context.state.isRunning ? "stopwatch.fill" : "stopwatch"))
            }
            .widgetURL(URL(string: "timerapp://"))
            .keylineTint(Color.black)
            //            .contentMargins(.center, 10, for: .expanded)  // More space for trailing region
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        return interval > 60
        ? String(format: "%02d:%02d:--", hours, minutes)
        : String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
            startDate: Date().addingTimeInterval(-600),
            isRunning: true
        )
    }
    
    fileprivate static var paused: TimerWidgetAttributes.ContentState {
        TimerWidgetAttributes.ContentState(
            eventName: "Sample Event",
            eventNotes: "These are some notes about the event.",
            startDate: Date().addingTimeInterval(-1800),
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
