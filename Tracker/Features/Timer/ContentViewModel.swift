import SwiftUI
import EventKit
import ActivityKit

// Uses iOS 17's @Observable macro instead of ObservableObject + @Published.
// SwiftUI automatically tracks property access in view bodies — no wrappers needed.
@Observable class ContentViewModel {
    // Singleton so all views share one timer/event state and the AppDelegate
    // can update the Live Activity from a background task.
    static let shared = ContentViewModel()

    var startTime: Date?
    var timerString: String = "--:--:--"
    var timerRunning = false
    var eventName: String = ""
    var eventNotes: String = ""
    var showTextField: Bool = true
    var showAll = false
    var events: [EKEvent] = []
    var selectedEvent: EKEvent?
    var showEventDetail = false

    private var timer: Timer?
    private var liveActivity: Activity<TimerWidgetAttributes>?

    private init() {} // Private initializer to prevent additional instances

    func startTimer() {
        if startTime == nil {
            startTime = Date()
        }
        timerRunning = true
        saveTimerState()
        startLiveActivity()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTimerString()
            self.updateLiveActivity()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timerRunning = false
        saveTimerState()
        AppDelegate().cancelAppRefresh() // Cancel the background task
        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start)
            CalendarHelper.logTimeToCalendar(startTime: start, duration: elapsed, eventName: eventName, eventNotes: eventNotes)
        }
        endLiveActivity()
        startTime = nil
    }

    func toggleTimer() {
        if timerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func adjustStartTime(by seconds: TimeInterval) {
        guard let currentStartTime = startTime else {
            startTime = Date().addingTimeInterval(seconds)
            updateTimerString()
            return
        }
        startTime = currentStartTime.addingTimeInterval(seconds)
        if timerRunning {
            startTime = Date().addingTimeInterval(-Date().timeIntervalSince(startTime!))
        }
        updateTimerString()
    }

    func updateTimerString() {
        guard let start = startTime else {
            timerString = "--:--:--"
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        timerString = formatTime(elapsed)
    }

    func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        }
    }

    func fetchEvents() {
        CalendarHelper.fetchEvents { fetchedEvents in
            DispatchQueue.main.async {
                self.events = Array(fetchedEvents)
            }
        }
    }

    func deleteEvent(at offsets: IndexSet) {
        offsets.forEach { index in
            let event = events[index]
            CalendarHelper.deleteEvent(event: event) { success in
                if success {
                    DispatchQueue.main.async {
                        self.events.remove(at: index)
                        self.fetchEvents()
                    }
                }
            }
        }
    }

    func deleteEventFromDetail(event: EKEvent) {
        if let index = events.firstIndex(where: { $0.eventIdentifier == event.eventIdentifier }) {
            CalendarHelper.deleteEvent(event: event) { success in
                if success {
                    DispatchQueue.main.async {
                        self.events.remove(at: index)
                        self.fetchEvents()
                    }
                }
            }
        }
    }

    private func startLiveActivity() {
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = TimerWidgetAttributes()
            let initialState = TimerWidgetAttributes.ContentState(
                eventName: eventName,
                eventNotes: eventNotes,
                startDate: startTime ?? Date(),
                isRunning: true
            )
            do {
                liveActivity = try Activity.request(attributes: attributes, content: .init(state: initialState, staleDate: Date.now + 15))
            } catch {
                print("Error starting live activity: \(error)")
            }
        }
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let updatedState = TimerWidgetAttributes.ContentState(
            eventName: eventName,
            eventNotes: eventNotes,
            startDate: startTime ?? Date(),
            isRunning: timerRunning
        )
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: Date.now + 15))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let finalState = TimerWidgetAttributes.ContentState(
            eventName: eventName,
            eventNotes: eventNotes,
            startDate: startTime ?? Date(),
            isRunning: false
        )
        Task {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            
        }
    }

    func updateLiveActivityInBackground() {
        updateLiveActivity()
    }
    
    // Persist timer state to UserDefaults so a running timer survives app
    // termination (e.g. system kill while backgrounded). loadTimerState()
    // restores it on next launch.
    private func saveTimerState() {
        UserDefaults.standard.set(startTime, forKey: "startTime")
        UserDefaults.standard.set(timerRunning, forKey: "timerRunning")
        UserDefaults.standard.set(eventName, forKey: "eventName")
        UserDefaults.standard.set(eventNotes, forKey: "eventNotes")
    }

    func loadTimerState() {
        if UserDefaults.standard.bool(forKey: "timerRunning") {
            startTime = UserDefaults.standard.object(forKey: "startTime") as? Date
            timerRunning = true
            eventName = UserDefaults.standard.string(forKey: "eventName") ?? ""
            eventNotes = UserDefaults.standard.string(forKey: "eventNotes") ?? ""
            // Restart the timer
            startLiveActivity()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.updateTimerString()
                self.updateLiveActivity()
            }
        } else {
            timerRunning = false
            startTime = nil
            eventName = ""
            eventNotes = ""
        }
    }
}
