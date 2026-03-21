import Foundation
import SwiftData

/// A single time-tracking session. This is the app's core data model,
/// persisted via SwiftData and optionally mirrored to the system calendar.
///
/// All properties have default values so the model is CloudKit-compatible
/// (required for future cross-device sync with Apple Watch).
@Model
class Session {
    var id: UUID = UUID()
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var notes: String = ""
    var tags: [String] = []

    /// Links this session to a calendar event, if calendar sync is enabled.
    /// Stores the EKEvent's `eventIdentifier`.
    var calendarEventID: String?

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        tags: [String] = [],
        calendarEventID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.tags = tags
        self.calendarEventID = calendarEventID
    }
}
