import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let scheduler = NotificationScheduler()
    private let refreshWorker = BackgroundRefreshWorker()

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
        AlarmHapticsManager.shared.stop()
        BackgroundRefreshScheduler.shared.schedule()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { await scheduler.clearDeliveredAlarmNotifications() }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        AlarmHapticsManager.shared.start()
        Task { await scheduler.clearDeliveredAlarmNotifications() }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let title = response.notification.request.content.title
        if response.actionIdentifier == NotificationConstants.stopActionId {
            AlarmHapticsManager.shared.stop()
            scheduler.clearSnoozeState()
            Task {
                await scheduler.clearPersistentAlarms()
                await scheduler.clearDeliveredAlarmNotifications()
            }
        } else if response.actionIdentifier == NotificationConstants.snoozeActionId {
            AlarmHapticsManager.shared.stop()
            Task { await scheduler.scheduleSnooze(title: title) }
        } else if response.actionIdentifier == UNNotificationDismissActionIdentifier
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            AlarmHapticsManager.shared.stop()
            scheduler.clearSnoozeState()
            Task {
                await scheduler.clearPersistentAlarms()
                await scheduler.clearDeliveredAlarmNotifications()
            }
        }
        completionHandler()
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
}
