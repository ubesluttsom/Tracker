import SwiftData
import SwiftUI

@main
struct TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer

    init() {
        // Store the SwiftData database in the App Group's shared directory
        // so both the main app and the widget extension can access it.
        let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.no.mihle.Tracker")!
            .appendingPathComponent("Tracker.store")

        let config = ModelConfiguration(url: groupURL)

        container = try! ModelContainer(for: Session.self, configurations: config)

        // Inject the SessionStore into the shared view model.
        // container.mainContext is a ModelContext on the main thread,
        // appropriate for UI-driven reads and writes.
        ContentViewModel.shared.sessionStore = SessionStore(
            modelContext: container.mainContext
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    ContentViewModel.shared.loadTimerState()
                }
        }
        .modelContainer(container)
    }
}
