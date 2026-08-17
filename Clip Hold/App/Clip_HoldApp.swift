import SwiftUI
import AppKit
import Carbon
import UserNotifications
import KeyboardShortcuts

// PreAction機能を持つPrimitiveButtonStyle
struct PreActionButtonStyle: PrimitiveButtonStyle {
    var preAction: () -> Void
    
    init(preAction: @escaping () -> Void) {
        self.preAction = preAction
    }
    
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            preAction()
            configuration.trigger()
        } label: {
            configuration.label
        }
    }
}

extension PrimitiveButtonStyle where Self == PreActionButtonStyle {
    static func preAction(perform action: @escaping () -> Void) -> PreActionButtonStyle {
        PreActionButtonStyle(preAction: action)
    }
}

extension NSImage {
    func createNotificationAttachment(identifier: String) -> UNNotificationAttachment? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImageRep = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmapImageRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = UUID().uuidString + ".png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL)
            let attachment = try UNNotificationAttachment(identifier: identifier, url: fileURL, options: nil)
            return attachment
        } catch {
            print("Error creating notification attachment: \(error)")
            return nil
        }
    }
}

@main
struct ClipHoldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("dateDisplayFormatInMenu") var dateDisplayFormatInMenu: String = "absolute"
    @AppStorage("maxHistoryInMenu") var maxHistoryInMenu: Int = 10
    @AppStorage("maxPhrasesInMenu") var maxPhrasesInMenu: Int = 5
    @AppStorage("quickPaste") var quickPaste: Bool = false
    @AppStorage("textOnlyQuickPaste") var textOnlyQuickPaste: Bool = false
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = false
    
    @StateObject var standardPhraseManager = StandardPhraseManager.shared
    @StateObject var clipboardManager = ClipboardManager.shared
    @StateObject var presetManager = StandardPhrasePresetManager.shared
    @StateObject var frontmostAppMonitor = FrontmostAppMonitor.shared
    @StateObject var iconGenerator = PresetIconGenerator.shared
    let dateReloader = DateReloader.shared
    
    @AppStorage("isClipboardMonitoringPaused") var isClipboardMonitoringPaused: Bool = false
    @AppStorage("showCurrentPresetIcon") private var showCurrentPresetIcon = false
    @AppStorage("hideMenuBarExtra") private var hideMenuBarExtra = false
    
    private var defaultMenubarIcon: NSImage {
        let name = isClipboardMonitoringPaused ? "Menubar Icon Dimmed" : "Menubar Icon"
        let icon = NSImage(named: name) ?? NSImage()
        icon.isTemplate = true
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }
    
    init() {
        print("ClipHoldApp: Initializing with ClipboardManager and StandardPhraseManager.")
        
        ClipHoldApp.setupGlobalShortcuts()
    }
    
    static func toggleClipboardMonitoring() {
        guard !ClipboardManager.shared.isExporting else { return }
        let defaults = UserDefaults.standard
        let currentIsPaused = defaults.bool(forKey: "isClipboardMonitoringPaused")
        
        defaults.set(!currentIsPaused, forKey: "isClipboardMonitoringPaused")
        NotificationManager.shared.sendMonitoringStatusNotification(isPaused: !currentIsPaused)
        
#if DEBUG
        print("Toggled isClipboardMonitoringPaused from \(currentIsPaused) to \(!currentIsPaused).")
#endif
    }
    
    // MARK: - キーボード操作をシミュレートする関数
    static func performPaste() {
        guard !ClipboardManager.shared.isExporting else { return }
        Task.detached(priority: .userInitiated) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else {
                print("Failed to create event source")
                return
            }
            
            guard let commandDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true),
                  let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
                  let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false),
                  let commandUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false) else {
                print("Failed to create CGEvent for paste")
                return
            }
            
            commandDown.flags = .maskCommand
            commandDown.post(tap: .cgSessionEventTap)
            try? await Task.sleep(for: .milliseconds(10))
            
            vDown.flags = .maskCommand
            vDown.post(tap: .cgSessionEventTap)
            try? await Task.sleep(for: .milliseconds(10))
            
            vUp.flags = .maskCommand
            vUp.post(tap: .cgSessionEventTap)
            try? await Task.sleep(for: .milliseconds(10))
            
            commandUp.flags = []
            commandUp.post(tap: .cgSessionEventTap)
        }
    }
    
    static func performPasteToPreviousApp() {
        guard !ClipboardManager.shared.isExporting else { return }
        if let bundleIdentifier = FrontmostAppMonitor.shared.lastNonClipHoldAppBundleIdentifier {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000) // ウィンドウが閉じることによるシステムフォーカス移動を待つ
                
                let runningApps = NSWorkspace.shared.runningApplications
                if let targetApp = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                    if #available(macOS 14.0, *) {
                        NSApp.yieldActivation(to: targetApp)
                    }
                    targetApp.activate()
                    
                    try? await Task.sleep(nanoseconds: 150_000_000) // 対象アプリがアクティブになるのを待機
                    ClipHoldApp.performPaste()
                } else {
                    ClipHoldApp.performPaste()
                }
            }
        } else {
            ClipHoldApp.performPaste()
        }
    }
    
    private var menuBarExtraInsertionBinding: Binding<Bool> {
        Binding<Bool>(
            get: { !self.hideMenuBarExtra }, // hideMenuBarExtra が true なら非表示 (false)
            set: { self.hideMenuBarExtra = !$0 } // isInserted の変更で hideMenuBarExtra を反転させる
        )
    }
    
    var body: some Scene {
        MenuBarExtra(isInserted: menuBarExtraInsertionBinding) {
            // --- 定型文セクション ---
            Label("よく使う定型文", systemImage: "star")
                .font(.headline)
                .labelStyle(.titleAndIcon)
            
            let phrasesToShow = presetManager.selectedPreset?.phrases ?? []
            if phrasesToShow.isEmpty {
                Text("定型文はありません")
            } else {
                let displayLimit = min(phrasesToShow.count, maxPhrasesInMenu)
                let phrasesWithIndex: [(phrase: StandardPhrase, shortcutName: KeyboardShortcuts.Name?)] = {
                    var result: [(phrase: StandardPhrase, shortcutName: KeyboardShortcuts.Name?)] = []
                    for (index, phrase) in phrasesToShow.prefix(displayLimit).enumerated() {
                        let shortcut: KeyboardShortcuts.Name? = (index < KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts.count) ? KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts[index] : nil
                        result.append((phrase, shortcut))
                    }
                    return result
                }()
                
                ForEach(phrasesWithIndex, id: \.phrase.id) { element in
                    let phrase = element.phrase
                    let shortcutName = element.shortcutName
                    
                    let displayText: String = {
                        let displayContent = phrase.title.replacingOccurrences(of: "\n", with: " ")
                        if displayContent.count > 40 {
                            return String(displayContent.prefix(40)) + "..."
                        }
                        return displayContent
                    }()
                    
                    Button {
                        clipboardManager.isCopyingStandardPhrase = true
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(phrase.content, forType: .string)
                        
                        // オプションキーが押されていない場合、かつエクスポート・インポート中でない場合のみクイックペーストを実行
                        if quickPaste && !ModifierKeyMonitor.shared.currentOptionKeyPressed && !clipboardManager.isExporting {
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 50_000_000)
                                ClipHoldApp.performPaste()
                            }
                        }
                    } label: {
                        Label {
                            Text(displayText)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } icon: {
                            // カラーコードアイコンの表示条件をチェック
                            if showColorCodeIcon, let color = ColorCodeParser.parseColor(from: phrase.content) {
                                Image(nsImage: clipboardManager.createColorIcon(color: color, size: CGSize(width: 16, height: 16)))
                            } else {
                                // 定型文がURLかどうかを判定
                                let isURL: Bool = {
                                    guard !phrase.content.isEmpty,
                                          let url = URL(string: phrase.content) else {
                                        return false
                                    }
                                    // URLスキームがhttpまたはhttpsであることを確認
                                    return url.scheme == "http" || url.scheme == "https"
                                }()
                                
                                Image(systemName: isURL ? "paperclip" : "list.bullet.rectangle.portrait")
                            }
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .applyKeyboardShortcut(for: shortcutName)
                    .disabled(clipboardManager.isExporting)
                }
            }
            
            Divider()
            
            // プリセット選択メニュー
            Menu {
                SharedPresetMenuContent(
                    title: "プリセット",
                    selectedPresetId: Binding(
                        get: { presetManager.selectedPresetId },
                        set: { newValue in
                            if let newValue = newValue {
                                presetManager.selectedPresetId = newValue
                            }
                        }
                    ),
                    onNewPresetAction: {
                        if !clipboardManager.isExporting {
                            if let delegate = NSApp.delegate as? AppDelegate {
                                delegate.showAddPresetWindow()
                            }
                        }
                    },
                    isExporting: clipboardManager.isExporting
                )
            } label: {
                Label {
                    Text("プリセット: \(presetManager.selectedPreset?.truncatedDisplayName(maxLength: 43) ?? String(localized: "なし"))")
                } icon: {
                    if let selectedPreset = presetManager.selectedPreset,
                       let icon = iconGenerator.iconCache[selectedPreset.id] {
                        Image(nsImage: icon)
                    } else {
                        Image(systemName: "star.square")
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            Button {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showStandardPhraseWindow()
                }
            } label: {
                Label("すべての定型文を表示...", systemImage: "pencil.and.list.clipboard")
            }
            .applyKeyboardShortcut(for: .showAllStandardPhrases)
            Divider()
            
            // --- コピー履歴セクション ---
            Label("コピー履歴", systemImage: "clock")
                .font(.headline)
                .labelStyle(.titleAndIcon)
            if clipboardManager.clipboardHistory.isEmpty {
                Text("履歴はありません")
            } else {
                let sortedHistory: [ClipboardItem] = {
                    var items = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
                    if let pinnedID = clipboardManager.pinnedItemID,
                       let pinnedItem = items.first(where: { $0.id == pinnedID }) {
                        items.insert(pinnedItem.createPinnedDuplicate(), at: 0)
                    }
                    return items
                }()
                
                let hasPinnedItem = clipboardManager.pinnedItemID != nil && sortedHistory.first?.originalPinnedItemID != nil
                let effectiveMaxHistory = maxHistoryInMenu + (hasPinnedItem ? 1 : 0)
                let displayLimit = min(sortedHistory.count, effectiveMaxHistory)
                
                let historyItemsWithIndex: [(item: ClipboardItem, shortcutName: KeyboardShortcuts.Name?)] = {
                    var result: [(item: ClipboardItem, shortcutName: KeyboardShortcuts.Name?)] = []
                    var normalIndex = 0
                    for item in sortedHistory.prefix(displayLimit) {
                        var shortcut: KeyboardShortcuts.Name? = nil
                        if item.originalPinnedItemID != nil {
                            shortcut = .copyPinnedHistoryItem
                        } else {
                            if normalIndex < KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts.count {
                                shortcut = KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts[normalIndex]
                            }
                            normalIndex += 1
                        }
                        result.append((item, shortcut))
                    }
                    return result
                }()
                
                ForEach(historyItemsWithIndex, id: \.item.id) { element in
                    let item = element.item
                    let shortcutName = element.shortcutName
                    
                    let displayText: String = {
                        let content = item.displayTitle
                        
                        var displayContent = content.replacingOccurrences(of: "\n", with: " ")
                        let dateString = item.date.formatted(for: dateDisplayFormatInMenu, currentDate: dateReloader.now)
                        
                        let characterCountText = showCharacterCount ? String(localized:" - \(item.text.count)文字") : ""
                        
                        if displayContent.count > 40 {
                            displayContent = String(displayContent.prefix(40)) + "..."
                        }
                        
                        return "\(displayContent) (\(dateString)\(characterCountText))"
                    }()
                    
                    Button {
                        // 内部コピーフラグをtrueに設定
                        clipboardManager.isPerformingInternalCopy = true
                        clipboardManager.copyItemToClipboard(item)
                        
                        // オプションキーが押されていない場合、かつエクスポート・インポート中でない場合のみクイックペーストを実行
                        if quickPaste && !ModifierKeyMonitor.shared.currentOptionKeyPressed && !clipboardManager.isExporting {
                            let textOnlyQuickPaste = UserDefaults.standard.bool(forKey: "textOnlyQuickPaste") // ここで最新の値を取得
                            if textOnlyQuickPaste {
                                // ファイルパスがなく、かつ画像でもない場合にのみペーストを実行
                                if item.filePath == nil && !item.isImage {
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 50_000_000)
                                        ClipHoldApp.performPaste()
                                    }
                                } else {
#if DEBUG
                                    print("textOnlyQuickPaste is on, so non-text content will not be pasted.")
#endif
                                }
                            } else {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 50_000_000)
                                    ClipHoldApp.performPaste()
                                }
                            }
                        }
                    } label: {
                        Label {
                            Text(displayText)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } icon: {
                            if item.originalPinnedItemID != nil {
                                Image(systemName: "pin.fill")
                            } else if showColorCodeIcon, item.filePath == nil, let color = ColorCodeParser.parseColor(from: item.text) {
                                Image(nsImage: clipboardManager.createColorIcon(color: color, size: CGSize(width: 16, height: 16)))
                            } else if item.isURL { // URLの場合
                                Image(systemName: "paperclip")
                            } else if let cachedImage = item.cachedThumbnailImage {
                                Image(nsImage: cachedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .clipped()
                            } else if let filePath = item.filePath {
                                // キャッシュがない場合は、従来のファイルアイコンを表示
                                let nsImage = NSWorkspace.shared.icon(forFile: filePath.path)
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            } else {
                                // ファイルパスもキャッシュもなければテキストアイコン
                                // リッチテキストかどうかでアイコンを分岐
                                if item.richText != nil {
                                    // リッチテキストの場合、richtext.pageアイコンを使用 (macOSバージョンによる分岐)
                                    if #available(macOS 15.0, *) {
                                        Image(systemName: "richtext.page")
                                    } else {
                                        Image(systemName: "doc.richtext")
                                    }
                                } else {
                                    // 標準テキストの場合、text.pageアイコンを使用 (macOSバージョンによる分岐)
                                    if #available(macOS 15.0, *) {
                                        Image(systemName: "text.page")
                                    } else {
                                        Image(systemName: "doc.plaintext")
                                    }
                                }
                            }
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .applyKeyboardShortcut(for: shortcutName)
                    .disabled(item.isCopying || clipboardManager.isExporting)
                }
            }
            
            Divider()
            
            Button {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showHistoryWindow()
                }
            } label: {
                Label("すべてのコピー履歴を表示...", systemImage: "list.clipboard")
            }
            .applyKeyboardShortcut(for: .showAllCopyHistory)
            
            Divider()
            
            if isClipboardMonitoringPaused {
                Label("クリップボード監視: 一時停止中", systemImage: "pause.fill")
                    .labelStyle(.titleAndIcon)
                
                Button {
                    ClipHoldApp.toggleClipboardMonitoring()
                } label: {
                    Label("クリップボード監視を再開", systemImage: "play")
                        .labelStyle(.titleAndIcon)
                }
                .applyKeyboardShortcut(for: .toggleClipboardMonitoring)
                .disabled(clipboardManager.isExporting)
            } else {
                Label("クリップボード監視: 動作中", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                
                Button {
                    ClipHoldApp.toggleClipboardMonitoring()
                } label: {
                    Label("クリップボード監視を一時停止", systemImage: "pause")
                        .labelStyle(.titleAndIcon)
                }
                .applyKeyboardShortcut(for: .toggleClipboardMonitoring)
                .disabled(clipboardManager.isExporting)
            }
            
            Divider()
            
            Button(action: {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showSettingsWindow()
                }
            }) {
                Label("設定...", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("終了", systemImage: "xmark")
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            if showCurrentPresetIcon,
               !presetManager.presets.isEmpty,
               let preset = presetManager.selectedPreset,
               let iconImage = isClipboardMonitoringPaused ? iconGenerator.dimmedMiniIconCache[preset.id] : iconGenerator.miniIconCache[preset.id] {
                Image(nsImage: iconImage)
            } else {
                Image(nsImage: defaultMenubarIcon)
            }
        }
        .environmentObject(clipboardManager)
        .environmentObject(standardPhraseManager)
        .environmentObject(presetManager)
        .environmentObject(frontmostAppMonitor)
        .environmentObject(dateReloader)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("設定...") {
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.showSettingsWindow()
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    static func setupGlobalShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .showAllStandardPhrases) {
#if DEBUG
            print("Show All Standard Phrases shortcut pressed!")
#endif
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showStandardPhraseWindow()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .showAllCopyHistory) {
#if DEBUG
            print("Show All Clipboard History shortcut pressed!")
#endif
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showHistoryWindow()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .toggleClipboardMonitoring) {
            guard !ClipboardManager.shared.isExporting else { return }
#if DEBUG
            print("Toggle Clipboard Monitoring shortcut pressed!")
#endif
            ClipHoldApp.toggleClipboardMonitoring()
        }
        
        // 新しい定型文の追加ショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .addSNewtandardPhrase) {
            guard !ClipboardManager.shared.isExporting else { return }
#if DEBUG
            print("Add New Standard Phrase shortcut pressed!")
#endif
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showAddPhraseWindow(withContent: "")
            }
        }
        
        // 新しいプリセットの追加ショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .addNewPreset) {
            guard !ClipboardManager.shared.isExporting else { return }
#if DEBUG
            print("Add New Preset shortcut pressed!")
#endif
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showAddPresetWindow()
            }
        }
        
        // 次のプリセットに切り替えるショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .nextPreset) {
            guard !ClipboardManager.shared.isExporting else { return }
#if DEBUG
            print("Switch to Next Preset shortcut pressed!")
#endif
            let presetManager = StandardPhrasePresetManager.shared
            if !presetManager.presets.isEmpty {
                let currentIndex = presetManager.presets.firstIndex { $0.id == presetManager.selectedPresetId } ?? -1
                let nextIndex = (currentIndex + 1) % presetManager.presets.count
                let nextPreset = presetManager.presets[nextIndex]
                presetManager.selectedPresetId = nextPreset.id
                
                // 通知設定がオンの場合、通知を送信
                if UserDefaults.standard.bool(forKey: "sendNotificationOnPresetChange") {
                    let notificationCenter = UNUserNotificationCenter.current()
                    let content = UNMutableNotificationContent()
                    content.title = nextPreset.displayName
                    content.body = String(localized: "「\(nextPreset.displayName)」に切り替わりました。")
                    content.sound = nil // 音なし
                    
                    // Add attachment
                    if let bigIcon = PresetIconGenerator.shared.bigIconCache[nextPreset.id],
                       let attachment = bigIcon.createNotificationAttachment(identifier: "presetIcon") {
                        content.attachments = [attachment]
                    }
                    
                    let request = UNNotificationRequest(identifier: "PresetChangeNotification", content: content, trigger: nil)
                    notificationCenter.add(request) { error in
                        if let error = error {
                            print("Failed to send notification: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        // 前のプリセットに切り替えるショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .previousPreset) {
            guard !ClipboardManager.shared.isExporting else { return }
#if DEBUG
            print("Switch to Previous Preset shortcut pressed!")
#endif
            let presetManager = StandardPhrasePresetManager.shared
            if !presetManager.presets.isEmpty {
                let currentIndex = presetManager.presets.firstIndex { $0.id == presetManager.selectedPresetId } ?? -1
                let previousIndex = (currentIndex - 1 + presetManager.presets.count) % presetManager.presets.count
                let previousPreset = presetManager.presets[previousIndex]
                presetManager.selectedPresetId = previousPreset.id
                
                // 通知設定がオンの場合、通知を送信
                if UserDefaults.standard.bool(forKey: "sendNotificationOnPresetChange") {
                    let notificationCenter = UNUserNotificationCenter.current()
                    let content = UNMutableNotificationContent()
                    content.title = previousPreset.displayName
                    content.body = String(localized: "「\(previousPreset.displayName)」に切り替わりました。")
                    content.sound = nil // 音なし
                    
                    // Add attachment
                    if let bigIcon = PresetIconGenerator.shared.bigIconCache[previousPreset.id],
                       let attachment = bigIcon.createNotificationAttachment(identifier: "presetIcon") {
                        content.attachments = [attachment]
                    }
                    
                    let request = UNNotificationRequest(identifier: "PresetChangeNotification", content: content, trigger: nil)
                    notificationCenter.add(request) { error in
                        if let error = error {
                            print("Failed to send notification: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        // クリップボードから新しい定型文の追加ショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .addStandardPhraseFromClipboard) {
            guard !ClipboardManager.shared.isExporting else { return }
#if DEBUG
            print("Add Standard Phrase from Clipboard shortcut pressed!")
#endif
            if let delegate = NSApp.delegate as? AppDelegate {
                let clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
                delegate.showAddPhraseWindow(withContent: clipboardContent)
            }
        }
        
        // 定型文コピーショートカットの登録
        for i in 0..<KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts.count {
            let shortcutName = KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts[i]
            KeyboardShortcuts.onKeyDown(for: shortcutName) {
                guard !ClipboardManager.shared.isExporting else { return }
                let presetManager = StandardPhrasePresetManager.shared
                if let selectedPreset = presetManager.selectedPreset, selectedPreset.phrases.indices.contains(i) {
                    let phrase = selectedPreset.phrases[i]
                    let clipboardManager = ClipboardManager.shared
                    clipboardManager.isCopyingStandardPhrase = true
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(phrase.content, forType: .string)
#if DEBUG
                    print("Standard phrase '\(phrase.title)' copied via shortcut.")
#endif
                    
                    let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
                    if currentQuickPaste {
                        ClipHoldApp.performPasteWithOverlayCheck()
#if DEBUG
                        print("performPasteWithOverlayCheck")
#endif
                    }
                } else {
                    // 通知のタイトルと本文を構築
                    let number = i + 1
                    let ordinalSuffix = number.ordinalSuffixForStandardPhrase
                    let title = String(format: String(localized: "%1$d%2$@定型文は設定されていません"), number, ordinalSuffix)
                    let body = String(format: String(localized: "%1$d%2$@定型文を呼び出すショートカットキーが押されましたが、この定型文は設定されていません。"), number, ordinalSuffix)
                    
                    // 無音通知を送信
                    NotificationManager.shared.sendSilentNotification(
                        title: title,
                        body: body,
                        identifier: "standardPhraseNotSet_\(number)"
                    )
                    
#if DEBUG
                    print("Standard phrase shortcut \(number) was pressed, but no corresponding phrase exists. Silent notification sent.")
#endif
                }
            }
        }
        
        // ピン留め履歴項目のコピーショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .copyPinnedHistoryItem) {
            guard !ClipboardManager.shared.isExporting else { return }
            let clipboardManager = ClipboardManager.shared
            if let pinnedItem = clipboardManager.pinnedItem {
                if pinnedItem.isCopying { return }
                clipboardManager.isPerformingInternalCopy = true
                clipboardManager.copyItemToClipboard(pinnedItem)
                
                let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
                let currentTextOnlyQuickPaste = UserDefaults.standard.bool(forKey: "textOnlyQuickPaste")
                
                if currentQuickPaste {
                    if currentTextOnlyQuickPaste {
                        if pinnedItem.filePath == nil && !pinnedItem.isImage {
                            ClipHoldApp.performPasteWithOverlayCheck()
                        }
                    } else {
                        ClipHoldApp.performPasteWithOverlayCheck()
                    }
                }
            } else {
                let title = String(localized: "履歴はピン留めされていません")
                let body = String(localized: "ピン留めされた履歴をコピーするショートカットキーが押されましたが、現在何もピン留めされていません。")
                
                // 無音通知を送信
                NotificationManager.shared.sendSilentNotification(
                    title: title,
                    body: body,
                    identifier: "pinnedHistoryNotSet"
                )
                
#if DEBUG
                print("Pinned history shortcut pressed, but no item is pinned. Silent notification sent.")
#endif
            }
        }
        
        // コピー履歴コピーショートカットの登録
        for i in 0..<KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts.count {
            let shortcutName = KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts[i]
            KeyboardShortcuts.onKeyDown(for: shortcutName) {
                guard !ClipboardManager.shared.isExporting else { return }
                // ClipboardManager はシングルトンなので、static context からも .shared でアクセス可能
                let clipboardManager = ClipboardManager.shared
                let useFiltered = UserDefaults.standard.bool(forKey: "useFilteredHistoryForShortcuts")
                
                let rawHistorySource: [ClipboardItem]
                if useFiltered, let filteredList = clipboardManager.filteredHistoryForShortcuts {
                    rawHistorySource = filteredList
                } else {
                    rawHistorySource = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
                }
                let historySource = rawHistorySource.filter { $0.originalPinnedItemID == nil }
                
                // 並び替えた配列に対してインデックスを適用
                if historySource.indices.contains(i) {
                    let historyItem = historySource[i]
                    
                    if historyItem.isCopying { return }
                    
                    // 内部コピーフラグをtrueに設定
                    clipboardManager.isPerformingInternalCopy = true
                    clipboardManager.copyItemToClipboard(historyItem)
                    
                    // quickPaste と textOnlyQuickPaste の最新の値を取得
                    let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
                    let currentTextOnlyQuickPaste = UserDefaults.standard.bool(forKey: "textOnlyQuickPaste")
                    
                    // quickPaste がオンの場合、かつ textOnlyQuickPaste がオンの場合は、ファイルパスがなく、かつ画像でもない場合にのみペースト
                    if currentQuickPaste {
                        if currentTextOnlyQuickPaste {
                            if historyItem.filePath == nil && !historyItem.isImage {
                                ClipHoldApp.performPasteWithOverlayCheck()
#if DEBUG
                                print("performPasteWithOverlayCheck")
#endif
                            } else {
#if DEBUG
                                print("textOnlyQuickPaste is on, so non-text content will not be pasted.")
#endif
                            }
                        } else {
                            ClipHoldApp.performPasteWithOverlayCheck()
#if DEBUG
                            print("performPasteWithOverlayCheck")
#endif
                        }
                    }
                } else {
#if DEBUG
                    print("History shortcut \(i+1) was pressed, but no corresponding history item (UI position \(i+1)) exists.")
#endif
                }
            }
        }
        
        // 最新の履歴を変更してコピーするショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .editAndCopyLatestHistory) {
            guard !ClipboardManager.shared.isExporting else { return }
            let clipboardManager = ClipboardManager.shared
            let useFiltered = UserDefaults.standard.bool(forKey: "useFilteredHistoryForShortcuts")
            
            let rawHistorySource: [ClipboardItem]
            if useFiltered, let filteredList = clipboardManager.filteredHistoryForShortcuts {
                rawHistorySource = filteredList
            } else {
                rawHistorySource = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
            }
            
            let historySource = rawHistorySource.filter { $0.originalPinnedItemID == nil }
            
            // 最新の履歴アイテムを取得
            if let latestItem = historySource.first {
                // ウィンドウとして表示する処理をここに実装
                Task { @MainActor in
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.showChangeItemAndCopyWindow(withContent: latestItem.text)
                    }
                }
            }
        }
        
        // テキストを入力してコピーするショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .newCopy) {
            guard !ClipboardManager.shared.isExporting else { return }
            Task { @MainActor in
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showNewCopyWindow()
                }
            }
        }
    }
    
    static func performPasteWithOverlayCheck() {
        guard !ClipboardManager.shared.isExporting else { return }
        Task { @MainActor in
            if QuickOverlayManager.shared.isOverlayVisible {
                QuickOverlayManager.shared.isOverlayVisible = false
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
                try? await Task.sleep(nanoseconds: 150_000_000)
                performPaste()
            } else {
                try? await Task.sleep(nanoseconds: 50_000_000)
                performPaste()
            }
        }
    }
}
