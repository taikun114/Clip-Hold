import Foundation
import UserNotifications
import AppKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private let monitoringStatusNotificationID = "monitoringStatusNotification"
    private let testNotificationID = "testNotification"
    let clipboardPausedNotificationIdentifier = "clipboardPausedNotification" // 一時停止通知の識別子を定数として定義
    private let migrationSuccessNotificationID = "migrationSuccessNotification"
    private let migrationFailureNotificationID = "migrationFailureNotification"
    
    private init() {}
    
    func getNotificationAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    func scheduleClipboardPausedNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [clipboardPausedNotificationIdentifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [clipboardPausedNotificationIdentifier])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "クリップボード監視は一時停止中です。")
        content.body = String(localized: "クリップボードの履歴を保存できるようにするには、クリップボード監視を再開する必要があります。")
        content.sound = .default
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            content.categoryIdentifier = appDelegate.clipboardPausedNotificationCategory
            print("NotificationManager: Set category identifier '\(appDelegate.clipboardPausedNotificationCategory)' for scheduled notification.")
        } else {
            print("NotificationManager: AppDelegate not found or category identifier could not be retrieved. Scheduling notification without category.")
            // Fallback: カテゴリがない場合でも通知自体は表示されるが、アクションは表示されない
        }
        
        let request = UNNotificationRequest(identifier: clipboardPausedNotificationIdentifier, content: content, trigger: nil) // 定数を使用
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Clipboard paused notification schedule error: \(error.localizedDescription)")
            } else {
                print("Clipboard paused notification scheduled.")
            }
        }
    }
    
    func resumeClipboardMonitoringAndSendNotification() {
        // UserDefaults の状態を更新
        UserDefaults.standard.set(false, forKey: "isClipboardMonitoringPaused")
        print("NotificationManager: Set UserDefaults isClipboardMonitoringPaused to false.")
        
        // クリップボード監視を再開
        ClipboardManager.shared.startMonitoringPasteboard()
        print("NotificationManager: Clipboard monitoring resumed.")
        
        // 配信済みの「一時停止通知」を削除
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [clipboardPausedNotificationIdentifier])
        print("NotificationManager: Delivered pause notifications removed.")
        
        // 「再開されました」通知を送信
        sendMonitoringStatusNotification(isPaused: false)
    }
    
    func removeClipboardPausedNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [clipboardPausedNotificationIdentifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [clipboardPausedNotificationIdentifier])
        print("Clipboard paused notification removed.")
    }
    
    func sendMonitoringStatusNotification(isPaused: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [monitoringStatusNotificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [monitoringStatusNotificationID])
        
        let content = UNMutableNotificationContent()
        content.title = isPaused ? String(localized: "クリップボード監視が一時停止されました。") : String(localized: "クリップボード監視が再開されました。")
        content.body = isPaused ? String(localized: "クリップボードの履歴が追加されなくなります。") : String(localized: "クリップボードの履歴が保存されるようになります。")
        content.sound = nil // こちらの通知ではサウンドを無効に
        
        let request = UNNotificationRequest(identifier: monitoringStatusNotificationID, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Monitoring status change notification send error: \(error.localizedDescription)")
            } else {
                print("Monitoring status change notification sent. Pause status: \(isPaused)")
            }
        }
    }
    
    func sendTestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testNotificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [testNotificationID])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "テスト通知")
        content.body = String(localized: "これはClip Holdからのテスト通知です。")
        content.sound = nil // こちらの通知ではサウンドを無効に
        
        let request = UNNotificationRequest(identifier: testNotificationID, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Test notification send error: \(error.localizedDescription)")
            } else {
                print("Test notification sent.")
            }
        }
    }
    
    // マイグレーション成功通知
    func sendMigrationSuccessNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [migrationSuccessNotificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [migrationSuccessNotificationID])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "履歴ファイルのアップグレードに成功しました")
        content.body = String(localized: "履歴ファイルが最新の形式に正しく変換されました。")
        content.sound = .default // 音を鳴らす
        
        let request = UNNotificationRequest(identifier: migrationSuccessNotificationID, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Migration success notification send error: \(error.localizedDescription)")
            } else {
                print("Migration success notification sent.")
            }
        }
    }
    
    // マイグレーション失敗通知
    func sendMigrationFailureNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [migrationFailureNotificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [migrationFailureNotificationID])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "履歴ファイルのアップグレードに失敗しました")
        content.body = String(localized: "以前の履歴ファイルが使用されています。アップグレード方法はドキュメントをご覧ください。")
        content.sound = .default // 音を鳴らす
        
        // ドキュメントを開くアクションを追加
        let openDocumentationAction = UNNotificationAction(
            identifier: "OPEN_DOCUMENTATION_ACTION",
            title: String(localized: "ドキュメントを表示…"),
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "MIGRATION_FAILURE_CATEGORY",
            actions: [openDocumentationAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "MIGRATION_FAILURE_CATEGORY"
        
        let request = UNNotificationRequest(identifier: migrationFailureNotificationID, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Migration failure notification send error: \(error.localizedDescription)")
            } else {
                print("Migration failure notification sent.")
            }
        }
    }
}
