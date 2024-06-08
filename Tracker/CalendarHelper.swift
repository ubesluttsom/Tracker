import EventKit

class CalendarHelper {
    static let eventStore = EKEventStore()

    static func logTimeToCalendar(startTime: Date?, duration: TimeInterval, eventName: String, eventNotes: String) {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                let calendars = eventStore.calendars(for: .event)
                let calendar = calendars.first { $0.title == "Tracker" } ?? createCustomCalendar(eventStore: eventStore)
                
                guard let customCalendar = calendar else {
                    print("Failed to create or find custom calendar.")
                    return
                }
                
                let event = EKEvent(eventStore: eventStore)
                event.title = eventName.isEmpty ? "Tracked Time" : eventName
                event.startDate = startTime
                event.endDate = startTime?.addingTimeInterval(duration)
                event.calendar = customCalendar
                event.notes = eventNotes
                do {
                    try eventStore.save(event, span: .thisEvent)
                } catch let error {
                    print("Failed to save event with error: \(error)")
                }
            } else {
                print("Failed to access calendar with error: \(String(describing: error)) or access not granted")
            }
        }
    }

    private static func createCustomCalendar(eventStore: EKEventStore) -> EKCalendar? {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "Tracker"

        let sourcesInEventStore = eventStore.sources
        calendar.source = sourcesInEventStore.first { $0.sourceType == .local } ?? eventStore.defaultCalendarForNewEvents?.source

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch let error {
            print("Failed to save calendar with error: \(error)")
            return nil
        }
    }

    static func fetchEvents(completion: @escaping ([EKEvent]) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                let calendars = eventStore.calendars(for: .event)
                let calendar = calendars.first { $0.title == "Tracker" }

                guard let customCalendar = calendar else {
                    print("Failed to find custom calendar.")
                    completion([])
                    return
                }

                let oneYearAgo = Date().addingTimeInterval(-365*24*60*60)
                let oneYearFromNow = Date().addingTimeInterval(365*24*60*60)
                let predicate = eventStore.predicateForEvents(withStart: oneYearAgo, end: oneYearFromNow, calendars: [customCalendar])

                let events = eventStore.events(matching: predicate)
                completion(events.sorted(by: { $0.startDate > $1.startDate }))
            } else {
                print("Failed to access calendar with error: \(String(describing: error)) or access not granted")
                completion([])
            }
        }
    }
    
    static func duration(event: EKEvent) -> TimeInterval {
        return event.endDate.timeIntervalSince(event.startDate)
    }
    
    static func formatDuration(event: EKEvent) -> String {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    static func deleteEvent(event: EKEvent, completion: @escaping (Bool) -> Void) {
        do {
            try eventStore.remove(event, span: .thisEvent)
            completion(true)
        } catch {
            print("Failed to delete event with error: \(error)")
            completion(false)
        }
    }
}
