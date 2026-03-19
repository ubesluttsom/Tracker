import ActivityKit
import Foundation

// Shared between the main app (for starting/updating Live Activities)
// and the widget extension (for rendering them).
struct TimerWidgetAttributes: ActivityAttributes {
    // ContentState holds dynamic values that change while the Live Activity
    // is running. Attributes (above) hold fixed values set at launch time —
    // currently empty because the timer needs no immutable metadata.
    public struct ContentState: Codable, Hashable {
        var eventName: String
        var eventNotes: String
        var startDate: Date
        var isRunning: Bool
        var elapsedTime: TimeInterval {
            Date().timeIntervalSince(startDate)
        }
    }
}
