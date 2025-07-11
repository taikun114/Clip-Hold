import SwiftUI
import AppKit
import UserNotifications
import KeyboardShortcuts

// アプリケーションのデリゲートクラス
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {

    var historyWindowController: ClipHoldWindowController?
    var standardPhraseWindowController: ClipHoldWindowController?

    private var addPhraseWindowController: ClipHoldWindowController?

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

            window.identifier = NSUserInterfaceItemIdentifier("HistoryWindow")

            window.contentViewController = hostingController
            
            historyWindowController = ClipHoldWindowController(wrappingWindow: window, applyTransparentBackground: true, windowFrameAutosaveKey: "HistoryWindowFrame")
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

            window.identifier = NSUserInterfaceItemIdentifier("StandardPhraseWindow")

            window.contentViewController = hostingController
            
            standardPhraseWindowController = ClipHoldWindowController(wrappingWindow: window, applyTransparentBackground: true, windowFrameAutosaveKey: "StandardPhraseWindowFrame")
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
            window.level = UserDefaults.standard.bool(forKey: "standardPhraseWindowAlwaysOnTop") ? .floating : .normal
        }
    }

    func showAddPhraseWindow(withContent content: String) {
        if addPhraseWindowController == nil || addPhraseWindowController?.window == nil {
            let contentView = AddEditPhraseView(mode: .add, initialContent: content)
                .environmentObject(StandardPhraseManager.shared)

            let hostingController = NSHostingController(rootView: AnyView(contentView))

            var windowRect = NSRect(x: 0, y: 0, width: 400, height: 350) // ウィンドウの固定サイズを設定
            
            if let screenFrame = NSScreen.main?.visibleFrame {
                // スクリーンの中央に配置するためのX座標とY座標を計算
                let x = screenFrame.minX + (screenFrame.width - windowRect.width) / 2
                let y = screenFrame.minY + (screenFrame.height - windowRect.height) / 2
                windowRect.origin = NSPoint(x: x, y: y) // 計算した座標をウィンドウの原点に設定
                print("AppDelegate: Calculated window origin: (\(x), \(y)) for screen frame: \(screenFrame)")
            } else {
                print("AppDelegate: Could not get main screen frame, falling back to default window position.")
                // スクリーン情報が取得できない場合のフォールバック（このままでもデフォルトで左上から表示される）
            }

            let window = NSWindow(
                contentRect: windowRect,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)

            window.contentViewController = hostingController
            window.identifier = NSUserInterfaceItemIdentifier("AddPhraseWindow")

            // ClipHoldWindowController でウィンドウをラップ
            addPhraseWindowController = ClipHoldWindowController(wrappingWindow: window, applyTransparentBackground: false)

            // ウィンドウのデリゲートを設定 (AppDelegateが最終的なデリゲートになる)
            addPhraseWindowController?.window?.delegate = self

            print("AppDelegate: Add Phrase window created.")

        } else {
            // 既存のウィンドウがある場合は、コンテンツを更新して前面に表示
            print("AppDelegate: Add Phrase window already exists. Updating content and bringing to front.")
            if let window = addPhraseWindowController?.window { // Controller 経由でウィンドウにアクセス
                // newContentView を、if/else ブロックの外側に移動し、両方からアクセス可能にする
                let newContentView = AddEditPhraseView(mode: .add, initialContent: content)
                    .environmentObject(StandardPhraseManager.shared)

                // 既存の NSHostingController の rootView を AnyView としてキャストし、新しい AnyView で更新
                if let existingHostingController = window.contentViewController as? NSHostingController<AnyView> {
                    existingHostingController.rootView = AnyView(newContentView)
                } else {
                    // もし contentViewController が期待する型でない場合は、新しいものに置き換える
                    window.contentViewController = NSHostingController(rootView: AnyView(newContentView))
                }
            }
        }
        // ウィンドウを表示し、アプリをアクティブにする
        addPhraseWindowController?.showWindow(nil) // Controller 経由で表示
        addPhraseWindowController?.window?.makeKeyAndOrderFront(nil) // 最前面に表示
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow, closedWindow == addPhraseWindowController?.window {
            print("AppDelegate: Add Phrase window will close. Setting addPhraseWindowController to nil (async).")
            // ここで参照をnilにするのを遅延させ、システムがウィンドウのクローズ処理を完了する時間を確保する
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.addPhraseWindowController = nil
                print("AppDelegate: addPhraseWindowController set to nil asynchronously.")
            }
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
