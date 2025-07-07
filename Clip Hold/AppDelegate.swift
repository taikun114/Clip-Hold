import SwiftUI
import AppKit
import UserNotifications
import KeyboardShortcuts

// アプリケーションのデリゲートクラス
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    var historyWindowController: ClipHoldWindowController?
    var standardPhraseWindowController: ClipHoldWindowController?

    let resumeMonitoringActionID = "RESUME_MONITORING_ACTION"
    let clipboardPausedNotificationCategory = "CLIPBOARD_PAUSED_CATEGORY"

    private var historyWindowAlwaysOnTopObserver: NSKeyValueObservation?
    private var standardPhraseWindowAlwaysOnTopObserver: NSKeyValueObservation?

    // MARK: - Application Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: finished launching.")

        NSApp.setActivationPolicy(.accessory)
        NSApp.delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("通知の許可が与えられました。")
            } else if let error = error {
                print("通知許可のリクエストエラー: \(error.localizedDescription)")
            }
        }
        
        UNUserNotificationCenter.current().delegate = self

        let resumeMonitoringAction = UNNotificationAction(identifier: resumeMonitoringActionID, title: String(localized: "再開"), options: [.foreground])
        let category = UNNotificationCategory(identifier: clipboardPausedNotificationCategory, actions: [resumeMonitoringAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        print("通知カテゴリ '\(clipboardPausedNotificationCategory)' とアクション '\(resumeMonitoringActionID)' を登録しました。")

        if UserDefaults.standard.bool(forKey: "isClipboardMonitoringPaused") {
            NotificationManager.shared.scheduleClipboardPausedNotification()
            print("AppDelegate: アプリ起動時、クリップボード監視は一時停止状態です。通知をスケジュールしました。")
        }

        historyWindowAlwaysOnTopObserver = UserDefaults.standard.observe(\.historyWindowAlwaysOnTop, options: [.new]) { [weak self] defaults, change in
            guard let self = self, let alwaysOnTop = change.newValue else { return }
            if let historyWindow = self.historyWindowController?.window {
                historyWindow.level = alwaysOnTop ? .floating : .normal
                print("DEBUG: historyWindowAlwaysOnTop changed. Level set to: \(historyWindow.level.rawValue)")
            } else {
                print("DEBUG: historyWindowAlwaysOnTop changed, but historyWindowController is nil or window is nil.")
            }
        }

        standardPhraseWindowAlwaysOnTopObserver = UserDefaults.standard.observe(\.standardPhraseWindowAlwaysOnTop, options: [.new]) { [weak self] defaults, change in
            guard let self = self, let alwaysOnTop = change.newValue else { return }
            if let standardPhraseWindow = self.standardPhraseWindowController?.window {
                standardPhraseWindow.level = alwaysOnTop ? .floating : .normal
                print("DEBUG: standardPhraseWindowAlwaysOnTop changed. Level set to: \(standardPhraseWindow.level.rawValue)")
            } else {
                print("DEBUG: standardPhraseWindowAlwaysOnTop changed, but standardPhraseWindowController is nil or window is nil.")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("AppDelegate: will terminate.")
        historyWindowAlwaysOnTopObserver?.invalidate()
        standardPhraseWindowAlwaysOnTopObserver?.invalidate()
    }
    
    // MARK: - Window Management

    func showHistoryWindow() {
        if historyWindowController == nil || historyWindowController?.window == nil {
            let contentView = HistoryWindowView()
                .environmentObject(ClipboardManager.shared)
                .environmentObject(StandardPhraseManager.shared)
            
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.setFrameAutosaveName("HistoryWindow")
            window.center()
            window.identifier = NSUserInterfaceItemIdentifier("HistoryWindow")

            window.contentViewController = hostingController
            
            historyWindowController = ClipHoldWindowController(wrappingWindow: window)
            historyWindowController?.showWindow(nil)
            
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: History window created and shown.")
        } else {
            print("AppDelegate: History window already exists. Bringing to front.")
            historyWindowController?.showWindow(nil)
            historyWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        if let window = historyWindowController?.window {
            historyWindowController?.applyWindowCustomizations(window: window)
            window.level = UserDefaults.standard.bool(forKey: "historyWindowAlwaysOnTop") ? .floating : .normal
        }
    }

    func showStandardPhraseWindow() {
        if standardPhraseWindowController == nil || standardPhraseWindowController?.window == nil {
            let contentView = StandardPhraseWindowView()
                .environmentObject(ClipboardManager.shared)
                .environmentObject(StandardPhraseManager.shared)

            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 375, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.setFrameAutosaveName("StandardPhraseWindow")
            window.center()
            window.identifier = NSUserInterfaceItemIdentifier("StandardPhraseWindow")

            window.contentViewController = hostingController
            
            standardPhraseWindowController = ClipHoldWindowController(wrappingWindow: window)
            standardPhraseWindowController?.showWindow(nil)
            
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Static phrase window created and shown.")
        } else {
            print("AppDelegate: Static phrase window already exists. Bringing to front.")
            standardPhraseWindowController?.showWindow(nil)
            standardPhraseWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        if let window = standardPhraseWindowController?.window {
            standardPhraseWindowController?.applyWindowCustomizations(window: window)
            window.level = UserDefaults.standard.bool(forKey: "standardPhraseWindowAlwaysOnTop") ? .floating : .normal
        }
    }

    // MARK: - Application Delegate Methods for Reopening
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        UserDefaults.standard.set(false, forKey: "hideMenuBarExtra")
        print("AppDelegate: hideMenuBarExtra を false に設定しました。メニューバーアイコンが表示されるようになります。")
        
        NSApp.activate(ignoringOtherApps: true)
        
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate (通知アクションのハンドリング)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == resumeMonitoringActionID {
            print("通知アクション: '再開' が選択されました。")
            // NotificationManager を介して再開ロジックを実行
            NotificationManager.shared.resumeClipboardMonitoringAndSendNotification()

            // アプリをフォアグラウンドに表示
            NSApp.activate(ignoringOtherApps: true)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// UserDefaultsのKey-Value Observing (KVO) を使うための拡張
extension UserDefaults {
    @objc dynamic var isClipboardMonitoringPaused: Bool {
        get { bool(forKey: "isClipboardMonitoringPaused") }
        set { set(newValue, forKey: "isClipboardMonitoringPaused") }
    }
    @objc dynamic var historyWindowAlwaysOnTop: Bool {
        get { bool(forKey: "historyWindowAlwaysOnTop") }
        set { set(newValue, forKey: "historyWindowAlwaysOnTop") }
    }
    @objc dynamic var standardPhraseWindowAlwaysOnTop: Bool {
        get { bool(forKey: "standardPhraseWindowAlwaysOnTop") }
        set { set(newValue, forKey: "standardPhraseWindowAlwaysOnTop") }
    }
}
