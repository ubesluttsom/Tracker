import UIKit
import BackgroundTasks

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "no.Mihle.Tracker.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "no.Mihle.Tracker.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
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
    
    func cancelAppRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "no.Mihle.Tracker.refresh")
    }
}

class RefreshAppContentsOperation: Operation {
    override func main() {
        if isCancelled { return }
        ContentViewModel.shared.updateLiveActivityInBackground()
    }
}
