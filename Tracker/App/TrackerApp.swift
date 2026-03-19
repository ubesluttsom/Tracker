import SwiftUI

@main
struct TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    ContentViewModel.shared.loadTimerState()
                }
        }
    }
}
