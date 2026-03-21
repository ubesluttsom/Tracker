import UIKit
import BackgroundTasks

// BGTaskScheduler lets the system wake the app periodically while backgrounded.
// We use this to push Live Activity updates (Dynamic Island / Lock Screen timer)
// even when the user isn't actively in the app.
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register the background refresh task. The identifier must match the
        // BGTaskSchedulerPermittedIdentifiers entry in Info.plist.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "no.mihle.Tracker.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "no.mihle.Tracker.refresh")
        // The system decides the actual wake time; this is the earliest it may happen.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        // Immediately schedule the next refresh so updates keep coming.
        scheduleAppRefresh()
        let operationQueue = OperationQueue()
        let operation = RefreshAppContentsOperation()
        task.expirationHandler = {
            operation.cancel()
        }
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        operationQueue.addOperation(operation)
    }

    static func cancelAppRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "no.mihle.Tracker.refresh")
    }
}

class RefreshAppContentsOperation: Operation {
    override func main() {
        if isCancelled { return }
        ContentViewModel.shared.updateLiveActivityInBackground()
    }
}
