import SwiftUI

@main
struct TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ContentViewModel.shared)
                .onAppear {
                    ContentViewModel.shared.loadTimerState()
                }
        }
    }
}
