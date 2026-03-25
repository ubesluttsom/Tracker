import SwiftUI
import ActivityKit

// Uses iOS 17's @Observable macro instead of ObservableObject + @Published.
// SwiftUI automatically tracks property access in view bodies — no wrappers needed.
@Observable class ContentViewModel {
    // Singleton so all views share one timer/event state and the AppDelegate
    // can update the Live Activity from a background task.
    static let shared = ContentViewModel()

    var sessionStore: SessionStore?

    var startTime: Date?
    var timerString: String = "--:--:--"
    var timerRunning = false
    var sessionName: String = ""
    var sessionNotes: String = ""
    var sessionTags: [String] = []
    var showTextField: Bool = true
    var showAll = false
    var showStatistics = false
    var sessions: [Session] = []
    var selectedSession: Session?
    var showDailyTotal: Bool = false
    var dailyTotalFilterTags: [String] = []
    private var currentDate: Date = Date()

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
        AppDelegate.cancelAppRefresh() // Cancel the background task
        if let start = startTime {
            let session = Session(
                title: sessionName.isEmpty ? "Tracked Time" : sessionName,
                startDate: start,
                endDate: Date(),
                notes: sessionNotes,
                tags: sessionTags
            )
            sessionStore?.save(session)
            fetchSessions()
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
        currentDate = Date()
        guard let start = startTime else {
            timerString = "--:--:--"
            return
        }
        let elapsed = currentDate.timeIntervalSince(start)
        timerString = formatTime(elapsed)
    }

    func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        }
    }

    func fetchSessions() {
        sessions = sessionStore?.fetchAll() ?? []
    }

    // MARK: - Daily Total

    var todaySessions: [Session] {
        sessions.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    var todayAvailableTags: [String] {
        let savedTags = Set(todaySessions.flatMap(\.tags))
        let currentTags = Set(sessionTags)
        return savedTags.union(currentTags).sorted()
    }

    var dailyTotalString: String {
        var filtered = todaySessions
        if !dailyTotalFilterTags.isEmpty {
            filtered = filtered.filter { session in
                session.tags.contains(where: dailyTotalFilterTags.contains)
            }
        }
        var total = filtered.reduce(0.0) { $0 + $1.duration }

        // Add current running session if it matches the filter
        if timerRunning, let start = startTime {
            let currentMatches = dailyTotalFilterTags.isEmpty ||
                sessionTags.contains(where: dailyTotalFilterTags.contains)
            if currentMatches {
                total += currentDate.timeIntervalSince(start)
            }
        }

        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    func toggleDailyTotalTag(_ tag: String) {
        if let index = dailyTotalFilterTags.firstIndex(of: tag) {
            dailyTotalFilterTags.remove(at: index)
        } else {
            dailyTotalFilterTags.append(tag)
        }
    }

    func initDailyTotalTags() {
        dailyTotalFilterTags = sessionTags
    }

    // MARK: - Delete & Update

    func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            sessionStore?.delete(sessions[index])
        }
        fetchSessions()
    }

    func deleteSession(_ session: Session) {
        sessionStore?.delete(session)
        fetchSessions()
    }

    func updateSession(_ session: Session) {
        sessionStore?.update(session)
        fetchSessions()
    }

    // MARK: - Merge & Copy

    func canMergeSessions(_ a: Session, _ b: Session) -> Bool {
        a.title == b.title && a.notes == b.notes && a.tags == b.tags
    }

    /// Returns the time gap between two sessions (negative if they overlap).
    func timeGap(between a: Session, _ b: Session) -> TimeInterval {
        let earlier = a.startDate < b.startDate ? a : b
        let later = a.startDate < b.startDate ? b : a
        return later.startDate.timeIntervalSince(earlier.endDate)
    }

    /// Merge two sessions: expand the kept session's time range to cover both, delete the other.
    func mergeSessions(keep: Session, remove: Session) {
        keep.startDate = min(keep.startDate, remove.startDate)
        keep.endDate = max(keep.endDate, remove.endDate)
        updateSession(keep)
        deleteSession(remove)
    }

    /// Copy title, notes, and tags from one session to another.
    func copySessionData(from source: Session, to target: Session) {
        target.title = source.title
        target.notes = source.notes
        target.tags = source.tags
        updateSession(target)
    }

    private func startLiveActivity() {
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = TimerWidgetAttributes()
            let initialState = TimerWidgetAttributes.ContentState(
                eventName: sessionName,
                eventNotes: sessionNotes,
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
            eventName: sessionName,
            eventNotes: sessionNotes,
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
            eventName: sessionName,
            eventNotes: sessionNotes,
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
        UserDefaults.standard.set(sessionName, forKey: "sessionName")
        UserDefaults.standard.set(sessionNotes, forKey: "sessionNotes")
    }

    func loadTimerState() {
        if UserDefaults.standard.bool(forKey: "timerRunning") {
            startTime = UserDefaults.standard.object(forKey: "startTime") as? Date
            timerRunning = true
            sessionName = UserDefaults.standard.string(forKey: "sessionName") ?? ""
            sessionNotes = UserDefaults.standard.string(forKey: "sessionNotes") ?? ""
            // Restart the timer
            startLiveActivity()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.updateTimerString()
                self.updateLiveActivity()
            }
        } else {
            timerRunning = false
            startTime = nil
            sessionName = ""
            sessionNotes = ""
        }
    }
}
