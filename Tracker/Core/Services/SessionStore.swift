import Foundation
import SwiftData

/// CRUD operations for Session objects, backed by SwiftData.
/// This replaces CalendarHelper as the primary data service.
/// CalendarHelper is still called as a write-through to keep
/// sessions visible in Calendar.app.
class SessionStore {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ session: Session) {
        modelContext.insert(session)
        try? modelContext.save()

        // Write-through: mirror to the system calendar
        CalendarHelper.logTimeToCalendar(
            startTime: session.startDate,
            duration: session.duration,
            eventName: session.title,
            eventNotes: session.notes
        )
    }

    func fetchAll() -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func delete(_ session: Session) {
        // Also remove from calendar if synced
        if let eventID = session.calendarEventID {
            CalendarHelper.deleteEventByID(eventID)
        }
        modelContext.delete(session)
        try? modelContext.save()
    }
}
