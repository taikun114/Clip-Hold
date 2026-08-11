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
        // デフォルト設定を登録
        UserDefaults.standard.register(defaults: [
            "historyQuickOverlayModifiers": Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue),
            "standardPhraseQuickOverlayModifiers": Int(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.command.rawValue)
        ])
        
        frontmostAppMonitor.startMonitoring()
        print("AppDelegate: finished launching.")
        
        // Spotlightインデックスの初期化（既存のアイテムをすべてインデックス化）
        SpotlightManager.shared.indexAllExistingItems()
        
        // App Intents (Shortcuts) の登録更新
        if #available(macOS 14.0, *) {
            ClipHoldAppShortcuts.updateAppShortcutParameters()
        }
        
        NSApp.setActivationPolicy(.accessory)
        NSApp.delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission request error: \(error.localizedDescription)")
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
        
        let resumeMonitoringAction = UNNotificationAction(identifier: resumeMonitoringActionID, title: String(localized: "再開"), options: [.foreground])
        let category = UNNotificationCategory(identifier: clipboardPausedNotificationCategory, actions: [resumeMonitoringAction], intentIdentifiers: [], options: [])
        
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
        
        // 複数のカテゴリを一度に登録
        UNUserNotificationCenter.current().setNotificationCategories([category, migrationFailureCategory])
        print("Registered notification category '\(clipboardPausedNotificationCategory)' and action '\(resumeMonitoringActionID)'.")
        print("Registered category for migration failure notification.")
        
        if UserDefaults.standard.bool(forKey: "isClipboardMonitoringPaused") {
            NotificationManager.shared.scheduleClipboardPausedNotification()
            print("AppDelegate: Clipboard monitoring was paused at launch. Scheduled notification.")
        }
        
        // Initialize Quick Overlay Singletons
        _ = QuickOverlayManager.shared
        _ = QuickOverlayWindowController.shared
        _ = QuickOverlayTooltipWindowController.shared
        
        historyWindowAlwaysOnTopObserver = UserDefaults.standard.observe(\.historyWindowAlwaysOnTop, options: [.new]) { [weak self] defaults, change in
            Task { @MainActor in
                guard let self = self, let alwaysOnTop = change.newValue else { return }
                if let historyWindow = self.historyWindowController?.window {
                    historyWindow.level = alwaysOnTop ? .floating : .normal
                }
            }
        }
        
        standardPhraseWindowAlwaysOnTopObserver = UserDefaults.standard.observe(\.standardPhraseWindowAlwaysOnTop, options: [.new]) { [weak self] defaults, change in
            Task { @MainActor in
                guard let self = self, let alwaysOnTop = change.newValue else { return }
                if let standardPhraseWindow = self.standardPhraseWindowController?.window {
                    standardPhraseWindow.level = alwaysOnTop ? .floating : .normal
                }
            }
        }
        
        historyWindowOverlayTransparencyObserver = UserDefaults.standard.observe(\.historyWindowOverlayTransparency, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.historyWindowController?.updateOverlay()
            }
        }
        
        standardPhraseWindowOverlayTransparencyObserver = UserDefaults.standard.observe(\.standardPhraseWindowOverlayTransparency, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.standardPhraseWindowController?.updateOverlay()
            }
        }
        
        historyWindowIsOverlayObserver = UserDefaults.standard.observe(\.historyWindowIsOverlay, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.historyWindowController?.updateOverlay()
            }
        }
        
        standardPhraseWindowIsOverlayObserver = UserDefaults.standard.observe(\.standardPhraseWindowIsOverlay, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
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
                .environmentObject(DateReloader.shared)
            
            let hostingController = NSHostingController(rootView: contentView)
            
            let window = CancellableWindow(
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
            Task { @MainActor in
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
            
            let window = CancellableWindow(
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
            Task { @MainActor in
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
            Task { @MainActor [weak self] in
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
    func showChangeItemAndCopyWindow(withContent content: String) {
        let windowType: WindowType = .changeItemAndCopy
        let title = String(localized: "項目を変更してコピー")
        
        // 既存のウィンドウコントローラーがあればそれを最前面に表示
        if let existingController = windowControllers[windowType] {
            existingController.showWindowAndCenter(false)
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Reusing existing \(windowType) window.")
            return
        }
        
        let editView = ChangeItemAndCopyView(content: content, onCopy: { editedContent in
            // コピー処理を実装
            let clipboardManager = ClipboardManager.shared
            clipboardManager.isPerformingInternalCopy = true
            clipboardManager.copyItemToClipboard(ClipboardItem(text: editedContent))
            
            // クイックペーストの処理
            let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
            let currentQuickPasteToPreviousApp = UserDefaults.standard.bool(forKey: "quickPasteToPreviousApp")
            
            if currentQuickPaste && currentQuickPasteToPreviousApp {
                if ModifierKeyMonitor.shared.currentOptionKeyPressed {
                    return
                }
                ClipHoldApp.performPasteToPreviousApp()
            }
        }, isSheet: false)
        
        // 新しいウィンドウコントローラーを作成
        let windowController = ClipHoldStandardWindowController(rootView: editView, title: title, windowType: windowType)
        windowControllers[windowType] = windowController
        
        // ウィンドウを表示し、アプリをアクティブにする
        windowController.showWindowAndCenter(true)
        NSApp.activate(ignoringOtherApps: true)
        
        print("AppDelegate: \(windowType) window created with ClipHoldStandardWindowController.")
    }
    
    @MainActor
    func showNewCopyWindow() {
        let windowType: WindowType = .newCopy
        let title = String(localized: "テキストを入力して新規コピー")
        
        // 既存のウィンドウコントローラーがあればそれを最前面に表示
        if let existingController = windowControllers[windowType] {
            existingController.showWindowAndCenter(false)
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Reusing existing \(windowType) window.")
            return
        }
        
        let editView = ChangeItemAndCopyView(content: "", title: title, onCopy: { editedContent in
            // コピー処理を実装
            let clipboardManager = ClipboardManager.shared
            clipboardManager.isPerformingInternalCopy = true
            clipboardManager.copyItemToClipboard(ClipboardItem(text: editedContent))
            
            // クイックペーストの処理
            let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
            let currentQuickPasteToPreviousApp = UserDefaults.standard.bool(forKey: "quickPasteToPreviousApp")
            
            if currentQuickPaste && currentQuickPasteToPreviousApp {
                if ModifierKeyMonitor.shared.currentOptionKeyPressed {
                    return
                }
                ClipHoldApp.performPasteToPreviousApp()
            }
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
        print("AppDelegate: Set hideMenuBarExtra to false. Menu bar icon will be displayed.")
        
        NSApp.activate(ignoringOtherApps: true)
        
        return true
    }
    
    // MARK: - CoreSpotlight Handling
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == "com.apple.corespotlightitem" {
            if let identifier = userActivity.userInfo?["kCSSearchableItemActivityIdentifier"] as? String {
                if identifier.hasPrefix("phrase_") {
                    let idString = identifier.replacingOccurrences(of: "phrase_", with: "")
                    if let id = UUID(uuidString: idString) {
                        Task { @MainActor in
                            let presetManager = StandardPhrasePresetManager.shared
                            var foundPhrase: StandardPhrase? = nil
                            for preset in presetManager.presets {
                                if let phrase = preset.phrases.first(where: { $0.id == id }) {
                                    foundPhrase = phrase
                                    break
                                }
                            }
                            if let phrase = foundPhrase {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(phrase.content, forType: .string)
                                NotificationManager.shared.sendStandardNotification(title: "コピーしました", subtitle: phrase.title)
                            }
                        }
                    }
                } else if identifier.hasPrefix("history_") {
                    let idString = identifier.replacingOccurrences(of: "history_", with: "")
                    if let id = UUID(uuidString: idString) {
                        Task {
                            let history = await ChunkedHistoryManager.shared.loadHistory()
                            if let item = history.first(where: { $0.id == id }) {
                                await MainActor.run {
                                    ClipboardManager.shared.copyItemToClipboard(item)
                                    NotificationManager.shared.sendStandardNotification(title: "コピーしました", subtitle: item.text.prefix(20) + "...")
                                }
                            }
                        }
                    }
                }
            }
            return true
        }
        return false
    }
    
    // MARK: - UNUserNotificationCenterDelegate (通知アクションのハンドリング)
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        let notificationCategory = response.notification.request.content.categoryIdentifier
        
        if actionID == resumeMonitoringActionID {
            print("Notification action: 'Resume' was selected.")
            // NotificationManager を介して再開ロジックを実行
            NotificationManager.shared.resumeClipboardMonitoringAndSendNotification()
            
            // アプリをフォアグラウンドに表示
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
            }
        } else if actionID == "OPEN_DOCUMENTATION_ACTION" && notificationCategory == "MIGRATION_FAILURE_CATEGORY" {
            print("Notification action: 'Show Documentation...' was selected.")
            
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
            Task { @MainActor in
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
    
    // Quick Overlay Settings
    @objc dynamic var isQuickOverlayEnabled: Bool {
        get { bool(forKey: "isQuickOverlayEnabled") }
        set { set(newValue, forKey: "isQuickOverlayEnabled") }
    }
    @objc dynamic var quickOverlayDelay: Double {
        get { 
            if object(forKey: "quickOverlayDelay") == nil {
                return 0.0 // Default to 0.0s if not set
            }
            return double(forKey: "quickOverlayDelay")
        }
        set { set(newValue, forKey: "quickOverlayDelay") }
    }
    @objc dynamic var quickOverlayPosition: String {
        get { 
            let val = string(forKey: "quickOverlayPosition")
            return val ?? "cursor"
        }
        set { set(newValue, forKey: "quickOverlayPosition") }
    }
    @objc dynamic var historyQuickOverlayModifiers: Int {
        get { integer(forKey: "historyQuickOverlayModifiers") }
        set { set(newValue, forKey: "historyQuickOverlayModifiers") }
    }
    @objc dynamic var standardPhraseQuickOverlayModifiers: Int {
        get { integer(forKey: "standardPhraseQuickOverlayModifiers") }
        set { set(newValue, forKey: "standardPhraseQuickOverlayModifiers") }
    }
}
