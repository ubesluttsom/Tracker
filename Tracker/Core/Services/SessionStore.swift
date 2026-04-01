import Foundation
import SwiftData
import os

/// CRUD operations for Session objects, backed by SwiftData.
/// This replaces CalendarHelper as the primary data service.
/// CalendarHelper is still called as a write-through to keep
/// sessions visible in Calendar.app.
class SessionStore {
    private let logger = Logger(subsystem: "no.mihle.Tracker", category: "SessionStore")
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ session: Session) {
        modelContext.insert(session)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
        }

        // Write-through: mirror to the system calendar
        CalendarHelper.logTimeToCalendar(
            startTime: session.startDate,
            duration: session.duration,
            eventName: session.title,
            eventNotes: session.notes
        )
    }

    func update(_ session: Session) {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to update session: \(error.localizedDescription)")
        }

        // Write-through: update the calendar event if one exists
        if let eventID = session.calendarEventID {
            CalendarHelper.updateEventByID(
                eventID,
                title: session.title,
                startDate: session.startDate,
                endDate: session.endDate,
                notes: session.notes
            )
        }
    }

    func fetchAll() -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch sessions: \(error.localizedDescription)")
            return []
        }
    }

    func delete(_ session: Session) {
        // Also remove from calendar if synced
        if let eventID = session.calendarEventID {
            CalendarHelper.deleteEventByID(eventID)
        }
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to delete session: \(error.localizedDescription)")
        }
    }
}
