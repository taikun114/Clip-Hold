import SwiftUI
import AppKit
import UserNotifications
import KeyboardShortcuts

// アプリケーションのデリゲートクラス
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {

    var historyWindowController: ClipHoldWindowController?
    var standardPhraseWindowController: ClipHoldWindowController?
    var settingsWindowController: SettingsWindowController?

    // ウィンドウの種類ごとにウィンドウコントローラーを管理する
    private var windowControllers: [WindowType: ClipHoldStandardWindowController] = [:]

    let resumeMonitoringActionID = "RESUME_MONITORING_ACTION"
    let clipboardPausedNotificationCategory = "CLIPBOARD_PAUSED_CATEGORY"

    private var historyWindowAlwaysOnTopObserver: NSKeyValueObservation?
    private var standardPhraseWindowAlwaysOnTopObserver: NSKeyValueObservation?
    private var historyWindowOverlayTransparencyObserver: NSKeyValueObservation?
    private var standardPhraseWindowOverlayTransparencyObserver: NSKeyValueObservation?
    private var historyWindowIsOverlayObserver: NSKeyValueObservation?
    private var standardPhraseWindowIsOverlayObserver: NSKeyValueObservation?
    private let frontmostAppMonitor = FrontmostAppMonitor.shared

    // MARK: - Application Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        frontmostAppMonitor.startMonitoring()
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
        
        // マイグレーション失敗通知のカテゴリを登録
        let openDocumentationAction = UNNotificationAction(
            identifier: "OPEN_DOCUMENTATION_ACTION",
            title: String(localized: "ドキュメントを表示…"),
            options: [.foreground]
        )
        let migrationFailureCategory = UNNotificationCategory(
            identifier: "MIGRATION_FAILURE_CATEGORY",
            actions: [openDocumentationAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([migrationFailureCategory])
        print("マイグレーション失敗通知のカテゴリを登録しました。")

        if UserDefaults.standard.bool(forKey: "isClipboardMonitoringPaused") {
            NotificationManager.shared.scheduleClipboardPausedNotification()
            print("AppDelegate: アプリ起動時、クリップボード監視は一時停止状態です。通知をスケジュールしました。")
        }

                historyWindowAlwaysOnTopObserver = UserDefaults.standard.observe(\.historyWindowAlwaysOnTop, options: [.new]) { [weak self] defaults, change in
            DispatchQueue.main.async {
                guard let self = self, let alwaysOnTop = change.newValue else { return }
                if let historyWindow = self.historyWindowController?.window {
                    historyWindow.level = alwaysOnTop ? .floating : .normal
                }
            }
        }

        standardPhraseWindowAlwaysOnTopObserver = UserDefaults.standard.observe(\.standardPhraseWindowAlwaysOnTop, options: [.new]) { [weak self] defaults, change in
            DispatchQueue.main.async {
                guard let self = self, let alwaysOnTop = change.newValue else { return }
                if let standardPhraseWindow = self.standardPhraseWindowController?.window {
                    standardPhraseWindow.level = alwaysOnTop ? .floating : .normal
                }
            }
        }

        historyWindowOverlayTransparencyObserver = UserDefaults.standard.observe(\.historyWindowOverlayTransparency, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.historyWindowController?.updateOverlay()
            }
        }

        standardPhraseWindowOverlayTransparencyObserver = UserDefaults.standard.observe(\.standardPhraseWindowOverlayTransparency, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.standardPhraseWindowController?.updateOverlay()
            }
        }

        historyWindowIsOverlayObserver = UserDefaults.standard.observe(\.historyWindowIsOverlay, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.historyWindowController?.updateOverlay()
            }
        }

        standardPhraseWindowIsOverlayObserver = UserDefaults.standard.observe(\.standardPhraseWindowIsOverlay, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.standardPhraseWindowController?.updateOverlay()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("AppDelegate: will terminate.")
        historyWindowAlwaysOnTopObserver?.invalidate()
        standardPhraseWindowAlwaysOnTopObserver?.invalidate()
        historyWindowOverlayTransparencyObserver?.invalidate()
        standardPhraseWindowOverlayTransparencyObserver?.invalidate()
        historyWindowIsOverlayObserver?.invalidate()
        standardPhraseWindowIsOverlayObserver?.invalidate()
    }
    
    // MARK: - Window Management

    func showSettingsWindow() {
        if settingsWindowController == nil || settingsWindowController?.window == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.showWindow(nil)
            
            NSApp.activate(ignoringOtherApps: true)
        } else {
            settingsWindowController?.showWindow(nil)
            settingsWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    func showHistoryWindow() {
        if historyWindowController == nil || historyWindowController?.window == nil {
            let contentView = HistoryWindowView()
                .environmentObject(ClipboardManager.shared)
                .environmentObject(StandardPhraseManager.shared)
                .environmentObject(StandardPhrasePresetManager.shared)
                .environmentObject(frontmostAppMonitor)
            
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.identifier = NSUserInterfaceItemIdentifier("HistoryWindow")

            window.contentViewController = hostingController
            
            
            historyWindowController = ClipHoldWindowController(wrappingWindow: window, windowType: .history, applyTransparentBackground: true, windowFrameAutosaveKey: "HistoryWindowFrame")
            historyWindowController?.onWindowWillClose = { [weak self] in
                ClipboardManager.shared.resetHistoryViewFilters()
                self?.historyWindowController = nil
                print("AppDelegate: History window closed and filters reset.")
            }
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
            // ウィンドウがキー状態になった後にupdateOverlayを呼び出す
            DispatchQueue.main.async {
                self.historyWindowController?.updateOverlay()
            }
        }
    }

    @MainActor
    func showStandardPhraseWindow() {
        if standardPhraseWindowController == nil || standardPhraseWindowController?.window == nil {
            let contentView = StandardPhraseWindowView()
                .environmentObject(ClipboardManager.shared)
                .environmentObject(StandardPhraseManager.shared)
                .environmentObject(StandardPhrasePresetManager.shared)

            let hostingController = NSHostingController(rootView: contentView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 375, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.identifier = NSUserInterfaceItemIdentifier("StandardPhraseWindow")

            window.contentViewController = hostingController
            
            standardPhraseWindowController = ClipHoldWindowController(wrappingWindow: window, windowType: .standardPhrase, applyTransparentBackground: true, windowFrameAutosaveKey: "StandardPhraseWindowFrame")
            standardPhraseWindowController?.onWindowWillClose = { [weak self] in
                self?.standardPhraseWindowController = nil
                print("AppDelegate: Standard Phrase window closed.")
            }
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
            // ウィンドウがキー状態になった後にupdateOverlayを呼び出す
            DispatchQueue.main.async {
                self.standardPhraseWindowController?.updateOverlay()
            }
        }
    }

    @MainActor
    func showAddPhraseWindow(withContent content: String) {
        let windowType: WindowType = .addPhrase
        let title = String(localized: "定型文を追加")
        
        // 既存のウィンドウコントローラーがあればそれを最前面に表示
        if let existingController = windowControllers[windowType] {
            existingController.showWindowAndCenter(false)
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Reusing existing \(windowType) window.")
            return
        }

        let contentView = AddEditPhraseView(mode: .add, initialContent: content, presetManager: StandardPhrasePresetManager.shared, isSheet: false)
            .environmentObject(StandardPhraseManager.shared)
            .environmentObject(StandardPhrasePresetManager.shared)

        // 新しいウィンドウコントローラーを作成
        let windowController = ClipHoldStandardWindowController(rootView: contentView, title: title, windowType: windowType)
        windowControllers[windowType] = windowController

        // ウィンドウを表示し、アプリをアクティブにする
        windowController.showWindowAndCenter(true)
        NSApp.activate(ignoringOtherApps: true)
        
        print("AppDelegate: \(windowType) window created with ClipHoldStandardWindowController.")
    }
    
    @MainActor
    func showAddPresetWindow() {
        let windowType: WindowType = .addPreset
        let title = String(localized: "プリセットを追加")
        
        // 既存のウィンドウコントローラーがあればそれを最前面に表示
        if let existingController = windowControllers[windowType] {
            existingController.showWindowAndCenter(false)
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Reusing existing \(windowType) window.")
            return
        }
        
        let contentView = AddEditPresetView(isSheet: false, onDismiss: { [weak self] in
            // ウィンドウを閉じたときの後処理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let controller = self.windowControllers[windowType] {
                    controller.close()
                }
                self.windowControllers.removeValue(forKey: windowType)
                print("AppDelegate: \(windowType) window removed from windowControllers asynchronously.")
            }
        }, editingPreset: nil)
        .environmentObject(StandardPhrasePresetManager.shared)

        // 新しいウィンドウコントローラーを作成
        let windowController = ClipHoldStandardWindowController(rootView: contentView, title: title, windowType: windowType)
        windowControllers[windowType] = windowController

        // ウィンドウを表示し、アプリをアクティブにする
        windowController.showWindowAndCenter(true)
        NSApp.activate(ignoringOtherApps: true)
        
        print("AppDelegate: \(windowType) window created with ClipHoldStandardWindowController.")
    }
    
    @MainActor
    func showEditHistoryWindow(withContent content: String) {
        let windowType: WindowType = .editHistory
        let title = String(localized: "履歴を変更してコピー")
        
        // 既存のウィンドウコントローラーがあればそれを最前面に表示
        if let existingController = windowControllers[windowType] {
            existingController.showWindowAndCenter(false)
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Reusing existing \(windowType) window.")
            return
        }

        let editView = EditHistoryItemView(content: content, onCopy: { editedContent in
            // コピー処理を実装
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(editedContent, forType: .string)
        }, isSheet: false)

        // 新しいウィンドウコントローラーを作成
        let windowController = ClipHoldStandardWindowController(rootView: editView, title: title, windowType: windowType)
        windowControllers[windowType] = windowController

        // ウィンドウを表示し、アプリをアクティブにする
        windowController.showWindowAndCenter(true)
        NSApp.activate(ignoringOtherApps: true)
        
        print("AppDelegate: \(windowType) window created with ClipHoldStandardWindowController.")
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }

        // ウィンドウの種類ごとにウィンドウコントローラーを管理する
        for (type, controller) in windowControllers {
            if closedWindow == controller.window {
                print("AppDelegate: \(type) window will close. Removing from windowControllers.")
                windowControllers.removeValue(forKey: type)
                print("AppDelegate: \(type) window removed from windowControllers.")
                break
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
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        let notificationCategory = response.notification.request.content.categoryIdentifier
        
        if actionID == resumeMonitoringActionID {
            print("通知アクション: '再開' が選択されました。")
            // NotificationManager を介して再開ロジックを実行
            NotificationManager.shared.resumeClipboardMonitoringAndSendNotification()

            // アプリをフォアグラウンドに表示
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        } else if actionID == "OPEN_DOCUMENTATION_ACTION" && notificationCategory == "MIGRATION_FAILURE_CATEGORY" {
            print("通知アクション: 'ドキュメントを表示…' が選択されました。")
            
            // ドキュメントのURLを決定
            let documentationURL: String
            if Locale.current.language.languageCode?.identifier == "ja" {
                documentationURL = "https://clip-hold.taikun.design/jp/docs/upgrade-history-data"
            } else {
                documentationURL = "https://clip-hold.taikun.design/docs/upgrade-history-data"
            }
            
            // デフォルトブラウザでURLを開く
            if let url = URL(string: documentationURL) {
                NSWorkspace.shared.open(url)
            }
            
            // アプリをフォアグラウンドに表示
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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
    @objc dynamic var historyWindowIsOverlay: Bool {
        get { bool(forKey: "historyWindowIsOverlay") }
        set { set(newValue, forKey: "historyWindowIsOverlay") }
    }
    @objc dynamic var standardPhraseWindowIsOverlay: Bool {
        get { bool(forKey: "standardPhraseWindowIsOverlay") }
        set { set(newValue, forKey: "standardPhraseWindowIsOverlay") }
    }
    @objc dynamic var historyWindowOverlayTransparency: Double {
        get { double(forKey: "historyWindowOverlayTransparency") }
        set { set(newValue, forKey: "historyWindowOverlayTransparency") }
    }
    @objc dynamic var standardPhraseWindowOverlayTransparency: Double {
        get { double(forKey: "standardPhraseWindowOverlayTransparency") }
        set { set(newValue, forKey: "standardPhraseWindowOverlayTransparency") }
    }
}
