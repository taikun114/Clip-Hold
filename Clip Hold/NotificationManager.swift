import Foundation
import UserNotifications
import AppKit

class NotificationManager {
    static let shared = NotificationManager()

    private let monitoringStatusNotificationID = "monitoringStatusNotification"
    private let testNotificationID = "testNotification"
    let clipboardPausedNotificationIdentifier = "clipboardPausedNotification" // 一時停止通知の識別子を定数として定義

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
            print("NotificationManager: スケジュールする通知にカテゴリ識別子 '\(appDelegate.clipboardPausedNotificationCategory)' を設定しました。")
        } else {
            print("NotificationManager: AppDelegateが見つからないか、カテゴリ識別子が取得できませんでした。カテゴリなしで通知をスケジュールします。")
            // Fallback: カテゴリがない場合でも通知自体は表示されるが、アクションは表示されない
        }

        let request = UNNotificationRequest(identifier: clipboardPausedNotificationIdentifier, content: content, trigger: nil) // 定数を使用

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("クリップボード一時停止通知のスケジュールエラー: \(error.localizedDescription)")
            } else {
                print("クリップボード一時停止通知をスケジュールしました。")
            }
        }
    }

    func resumeClipboardMonitoringAndSendNotification() {
        // UserDefaults の状態を更新
        UserDefaults.standard.set(false, forKey: "isClipboardMonitoringPaused")
        print("NotificationManager: UserDefaultsのisClipboardMonitoringPausedをfalseに設定。")

        // クリップボード監視を再開
        ClipboardManager.shared.startMonitoringPasteboard()
        print("NotificationManager: クリップボード監視を再開しました。")

        // 配信済みの「一時停止通知」を削除
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [clipboardPausedNotificationIdentifier])
        print("NotificationManager: 配信済みの一時停止通知を削除しました。")

        // 「再開されました」通知を送信
        sendMonitoringStatusNotification(isPaused: false)
    }

    func removeClipboardPausedNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [clipboardPausedNotificationIdentifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [clipboardPausedNotificationIdentifier])
        print("クリップボード一時停止通知を削除しました。")
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
                print("監視状態変更通知の送信エラー: \(error.localizedDescription)")
            } else {
                print("監視状態変更通知を送信しました。一時停止状態: \(isPaused)")
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
                print("テスト通知の送信エラー: \(error.localizedDescription)")
            } else {
                print("テスト通知を送信しました。")
            }
        }
    }
}
