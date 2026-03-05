import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let scheduler = NotificationScheduler()
    private let refreshWorker = BackgroundRefreshWorker()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppLog.configureFromDefaults()
        UNUserNotificationCenter.current().delegate = self
        scheduler.registerCategories()
        GeofenceAlarmMonitor.shared.activate()
        registerBackgroundTasks()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        runImmediateBackgroundRefreshIfPossible(application)
        BackgroundRefreshScheduler.shared.schedule()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppLog.app.info("App became active.")
        Task { await scheduler.logDeliveredAlarmSnapshot(context: "app-active") }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let title = notification.request.content.title
        AppLog.app.info("Foreground alarm notification delivered.", metadata: ["title": title])
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let title = response.notification.request.content.title
        let appState = UIApplication.shared.applicationState
        let isAppActive = appState == .active
        AppLog.app.info("Alarm notification action received.", metadata: ["action": response.actionIdentifier, "title": title])
        // Legacy custom dismiss actions — kept for any notifications already delivered
        // before the category was updated to system-dismiss-only.
        if response.actionIdentifier == NotificationConstants.dismissActionId
            || response.actionIdentifier == NotificationConstants.legacyStopActionId {
            scheduler.clearSnoozeState()
            Task {
                await scheduler.clearPersistentAlarms()
                await scheduler.clearDeliveredAlarmNotifications()
                await scheduler.logDeliveredAlarmSnapshot(context: "action-dismiss")
                completionHandler()
            }
        } else if response.actionIdentifier == NotificationConstants.snoozeActionId {
            Task {
                await scheduler.scheduleSnooze(title: title)
                await scheduler.logDeliveredAlarmSnapshot(context: "action-snooze")
                completionHandler()
            }
        } else if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            // In foreground, system banner auto-dismiss can trigger dismiss/default;
            // ignore those to avoid unintentionally cancelling an active barrage.
            if isAppActive {
                completionHandler()
                return
            }
            scheduler.clearSnoozeState()
            Task {
                await scheduler.clearPersistentAlarms()
                await scheduler.clearDeliveredAlarmNotifications()
                await scheduler.logDeliveredAlarmSnapshot(context: "action-dismiss")
                completionHandler()
            }
        } else {
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                AppLog.app.info("Default notification tap received.", metadata: ["title": title, "appActive": "\(isAppActive)"])
            }
            completionHandler()
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundRefreshConstants.taskId,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleAppRefresh(task: task)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        BackgroundRefreshScheduler.shared.schedule()

        let work = Task {
            await refreshWorker.refreshAlarms()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func runImmediateBackgroundRefreshIfPossible(_ application: UIApplication) {
        if backgroundTask != .invalid { return }
        backgroundTask = application.beginBackgroundTask(withName: "NeverLateImmediateRefresh") { [weak self] in
            guard let self else { return }
            if self.backgroundTask != .invalid {
                application.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
        guard backgroundTask != .invalid else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.refreshWorker.refreshAlarms()
            if self.backgroundTask != .invalid {
                application.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
    }
}
