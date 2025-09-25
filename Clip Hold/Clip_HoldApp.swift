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

@main
struct ClipHoldApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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

    @AppStorage("isClipboardMonitoringPaused") var isClipboardMonitoringPaused: Bool = false
    @AppStorage("hideMenuBarExtra") private var hideMenuBarExtra = false

    init() {
        print("ClipHoldApp: Initializing with ClipboardManager and StandardPhraseManager.")
        
        ClipHoldApp.setupGlobalShortcuts()
    }
    
    // MARK: - キーボード操作をシミュレートする関数
    static func performPaste() {
        let delay: TimeInterval = 0.01

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("Failed to create event source")
            return
        }

        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)!
        commandDown.flags = .maskCommand
        commandDown.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: delay)

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)!
        vDown.flags = .maskCommand
        vDown.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: delay)

        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)!
        vUp.flags = .maskCommand
        vUp.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: delay)

        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)!
        commandUp.flags = []
        commandUp.post(tap: .cgSessionEventTap)
    }

    private var menuBarExtraInsertionBinding: Binding<Bool> {
        Binding<Bool>(
            get: { !self.hideMenuBarExtra }, // hideMenuBarExtra が true なら非表示 (false)
            set: { self.hideMenuBarExtra = !$0 } // isInserted の変更で hideMenuBarExtra を反転させる
        )
    }
    
    private func displayName(for preset: StandardPhrasePreset?) -> String {
        guard let preset = preset else {
            // 選択されているプリセットがない場合
            return String(localized: "プリセットがありません")
        }
        return displayName(for: preset)
    }

    private func displayName(for preset: StandardPhrasePreset) -> String {
        if preset.id.uuidString == "00000000-0000-0000-0000-000000000000" {
            return String(localized: "Default")
        }
        return preset.name
    }
        
    var body: some Scene {
        MenuBarExtra(
            "Clip Hold", // <- titleKey
            image: isClipboardMonitoringPaused ? "Menubar Icon Dimmed" : "Menubar Icon",
            isInserted: menuBarExtraInsertionBinding
        ) {
            // --- 定型文セクション ---
            HStack {
                Label("よく使う定型文", systemImage: "star")
                    .font(.headline)
            }
            .padding(.bottom, 5)
                        
            let phrasesToShow = presetManager.selectedPreset?.phrases ?? []
            if phrasesToShow.isEmpty {
                Text("定型文はありません")
            } else {
                let displayLimit = min(phrasesToShow.count, maxPhrasesInMenu)
                ForEach(phrasesToShow.prefix(displayLimit)) {
                    phrase in
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
                        
                        // オプションキーが押されていない場合のみクイックペーストを実行
                        if quickPaste && !NSEvent.modifierFlags.contains(.option) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                ClipHoldApp.performPaste()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
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
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.secondary)
                            }
                            Text(displayText)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            }
            
            Divider()

            // プリセット選択メニュー
            Menu {
                Picker("プリセット", selection: Binding(
                    get: {
                        // プリセットが空の場合、特別なUUIDを返す
                        if presetManager.presets.isEmpty {
                            return UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                        }
                        return presetManager.selectedPresetId
                    },
                    set: { newValue in
                        // UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")は「プリセットがありません」のタグ
                        if newValue?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                            // プリセットがない場合は何もしない
                            // 選択を元に戻す
                            if let firstPreset = presetManager.presets.first {
                                presetManager.selectedPresetId = firstPreset.id
                            } else {
                                // まだプリセットがない場合はnilのまま
                                presetManager.selectedPresetId = nil
                            }
                        } else {
                            presetManager.selectedPresetId = newValue
                            presetManager.saveSelectedPresetId()
                        }
                    }
                )) {
                    ForEach(presetManager.presets) { preset in
                        Label {
                            Text(displayName(for: preset))
                        } icon: {
                            if let iconImage = iconGenerator.iconCache[preset.id] {
                                Image(nsImage: iconImage)
                            } else {
                                Image(systemName: "star.fill") // Fallback
                            }
                        }
                        .tag(preset.id as UUID?)
                    }
                    
                    // プリセットがない場合の項目
                    if presetManager.presets.isEmpty {
                        Text("プリセットがありません")
                            .tag(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") as UUID?)
                    }
                }
                .pickerStyle(.inline)
                
                Divider()
                
                Button("新規プリセット...") {
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.showAddPresetWindow()
                    }
                }
            } label: {
                Label {
                    Text("プリセット: \(displayName(for: presetManager.selectedPreset))")
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
            Divider()
            
            // --- コピー履歴セクション ---
            Label("コピー履歴", systemImage: "clock")
                .font(.headline)
            if clipboardManager.clipboardHistory.isEmpty {
                Text("履歴はありません")
            } else {
                // clipboardHistoryを日付の新しい順にソート
                let sortedHistory = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
                let displayLimit = min(sortedHistory.count, maxHistoryInMenu)
                ForEach(sortedHistory.prefix(displayLimit)) {
                    item in
                    
                    let itemDateFormatter: DateFormatter = {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        formatter.timeStyle = .short
                        return formatter
                    }()
                     
                    let displayText: String = {
                        let content: String
                        if item.text == "Image File" {
                            content = String(localized: "Image File")
                        } else if item.text == "PDF File" {
                            content = String(localized: "PDF File")
                        } else {
                            content = item.text
                        }

                        var displayContent = content.replacingOccurrences(of: "\n", with: " ")
                        let dateString = itemDateFormatter.string(from: item.date)
                        
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
                        
                        // オプションキーが押されていない場合のみクイックペーストを実行
                        if quickPaste && !NSEvent.modifierFlags.contains(.option) {
                            let textOnlyQuickPaste = UserDefaults.standard.bool(forKey: "textOnlyQuickPaste") // ここで最新の値を取得
                            if textOnlyQuickPaste {
                                // ファイルパスがなく、かつ画像でもない場合にのみペーストを実行
                                if item.filePath == nil && !item.isImage {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        ClipHoldApp.performPaste()
                                    }
                                } else {
                                    print("textOnlyQuickPasteがオンのため、テキスト以外のコンテンツはペーストされません。")
                                }
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    ClipHoldApp.performPaste()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            // カラーコードアイコンの表示条件をチェック
                            if showColorCodeIcon, item.filePath == nil, let color = ColorCodeParser.parseColor(from: item.text) {
                                Image(nsImage: clipboardManager.createColorIcon(color: color, size: CGSize(width: 16, height: 16)))
                            } else if item.isURL { // URLの場合
                                Image(systemName: "paperclip")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(4)
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.secondary)
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
                                            .resizable()
                                            .scaledToFit()
                                            .padding(4)
                                            .frame(width: 16, height: 16) // メニューバーのアイコンサイズに合わせる
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: "doc.richtext")
                                            .resizable()
                                            .scaledToFit()
                                            .padding(4)
                                            .frame(width: 16, height: 16) // メニューバーのアイコンサイズに合わせる
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    // 標準テキストの場合、text.pageアイコンを使用 (macOSバージョンによる分岐)
                                    if #available(macOS 15.0, *) {
                                        Image(systemName: "text.page")
                                            .resizable()
                                            .scaledToFit()
                                            .padding(4)
                                            .frame(width: 16, height: 16) // メニューバーのアイコンサイズに合わせる
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: "doc.plaintext")
                                            .resizable()
                                            .scaledToFit()
                                            .padding(4)
                                            .frame(width: 16, height: 16) // メニューバーのアイコンサイズに合わせる
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Text(displayText)
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
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
            
            Divider()
            
            Button(action: {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showSettingsWindow()
                }
            }) {
                Label("設定...", systemImage: "gear")
            }
            
            Divider()
            
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .environmentObject(clipboardManager)
        .environmentObject(standardPhraseManager)
        .environmentObject(presetManager)
        .environmentObject(frontmostAppMonitor)
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
            print("「すべての定型文を表示」ショートカットが押されました！")
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showStandardPhraseWindow()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .showAllCopyHistory) {
            print("「すべてのコピー履歴を表示」ショートカットが押されました！")
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showHistoryWindow()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .toggleClipboardMonitoring) {
            print("「クリップボード監視を切り替える」ショートカットが押されました！")
            let defaults = UserDefaults.standard
            let currentIsPaused = defaults.bool(forKey: "isClipboardMonitoringPaused")
            
            // UserDefaultsの値を直接トグルする
            defaults.set(!currentIsPaused, forKey: "isClipboardMonitoringPaused")
            
            // ショートカットで切り替えた際に通知を送信
            NotificationManager.shared.sendMonitoringStatusNotification(isPaused: !currentIsPaused)

            // コンソール出力はUserDefaultsの変更結果に基づいて行う
            print("isClipboardMonitoringPaused の値を \(currentIsPaused) から \(!currentIsPaused) に変更しました。")
        }

        // 新しい定型文の追加ショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .addSNewtandardPhrase) {
            print("「新しい定型文を追加」ショートカットが押されました！")
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showAddPhraseWindow(withContent: "")
            }
        }

        // 新しいプリセットの追加ショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .addNewPreset) {
            print("「新しいプリセットを追加」ショートカットが押されました！")
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.showAddPresetWindow()
            }
        }

        // 次のプリセットに切り替えるショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .nextPreset) {
            print("「次のプリセットに切り替える」ショートカットが押されました！")
            let presetManager = StandardPhrasePresetManager.shared
            if !presetManager.presets.isEmpty {
                let currentIndex = presetManager.presets.firstIndex { $0.id == presetManager.selectedPresetId } ?? -1
                let nextIndex = (currentIndex + 1) % presetManager.presets.count
                let nextPreset = presetManager.presets[nextIndex]
                presetManager.selectedPresetId = nextPreset.id
                presetManager.saveSelectedPresetId()
                
                // 通知設定がオンの場合、通知を送信
                if UserDefaults.standard.bool(forKey: "sendNotificationOnPresetChange") {
                    let notificationCenter = UNUserNotificationCenter.current()
                    let content = UNMutableNotificationContent()
                    content.title = nextPreset.displayName
                    content.body = String(localized: "「\(nextPreset.displayName)」に切り替わりました。")
                    content.sound = nil // 音なし
                    
                    let request = UNNotificationRequest(identifier: "PresetChangeNotification", content: content, trigger: nil)
                    notificationCenter.add(request) { error in
                        if let error = error {
                            print("通知の送信に失敗しました: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        // 前のプリセットに切り替えるショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .previousPreset) {
            print("「前のプリセットに切り替える」ショートカットが押されました！")
            let presetManager = StandardPhrasePresetManager.shared
            if !presetManager.presets.isEmpty {
                let currentIndex = presetManager.presets.firstIndex { $0.id == presetManager.selectedPresetId } ?? -1
                let previousIndex = (currentIndex - 1 + presetManager.presets.count) % presetManager.presets.count
                let previousPreset = presetManager.presets[previousIndex]
                presetManager.selectedPresetId = previousPreset.id
                presetManager.saveSelectedPresetId()
                
                // 通知設定がオンの場合、通知を送信
                if UserDefaults.standard.bool(forKey: "sendNotificationOnPresetChange") {
                    let notificationCenter = UNUserNotificationCenter.current()
                    let content = UNMutableNotificationContent()
                    content.title = previousPreset.displayName
                    content.body = String(localized: "「\(previousPreset.displayName)」に切り替わりました。")
                    content.sound = nil // 音なし
                    
                    let request = UNNotificationRequest(identifier: "PresetChangeNotification", content: content, trigger: nil)
                    notificationCenter.add(request) { error in
                        if let error = error {
                            print("通知の送信に失敗しました: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        // クリップボードから新しい定型文の追加ショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .addStandardPhraseFromClipboard) {
            print("「クリップボードから定型文を追加」ショートカットが押されました！")
            if let delegate = NSApp.delegate as? AppDelegate {
                let clipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
                delegate.showAddPhraseWindow(withContent: clipboardContent)
            }
        }

        // 定型文コピーショートカットの登録
        for i in 0..<KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts.count {
            let shortcutName = KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts[i]
            KeyboardShortcuts.onKeyDown(for: shortcutName) {
                let presetManager = StandardPhrasePresetManager.shared
                if let selectedPreset = presetManager.selectedPreset, selectedPreset.phrases.indices.contains(i) {
                    let phrase = selectedPreset.phrases[i]
                    let clipboardManager = ClipboardManager.shared
                    clipboardManager.isCopyingStandardPhrase = true
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(phrase.content, forType: .string)
                    print("定型文「\(phrase.title)」がショートカットでコピーされました。")

                    let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
                    if currentQuickPaste {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            performPaste() // static メソッドとして呼び出し
                            print("performPaste")
                        }
                    }
                } else {
                    print("定型文ショートカット \(i+1) が押されましたが、対応する定型文は存在しません。")
                }
            }
        }

        // コピー履歴コピーショートカットの登録
        for i in 0..<KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts.count {
            let shortcutName = KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts[i]
            KeyboardShortcuts.onKeyDown(for: shortcutName) {
                // ClipboardManager はシングルトンなので、static context からも .shared でアクセス可能
                let clipboardManager = ClipboardManager.shared
                let useFiltered = UserDefaults.standard.bool(forKey: "useFilteredHistoryForShortcuts")

                let historySource: [ClipboardItem]
                if useFiltered, let filteredList = clipboardManager.filteredHistoryForShortcuts {
                    historySource = filteredList
                } else {
                    historySource = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
                }

                // 並び替えた配列に対してインデックスを適用
                if historySource.indices.contains(i) {
                    let historyItem = historySource[i]
                    NSPasteboard.general.clearContents()

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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    performPaste()
                                    print("performPaste")
                                }
                            } else {
                                print("textOnlyQuickPasteがオンのため、テキスト以外のコンテンツはペーストされません。")
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                performPaste()
                                print("performPaste")
                            }
                        }
                    }
                } else {
                    print("履歴ショートカット \(i+1) が押されましたが、対応する履歴（UI上\(i+1)番目）は存在しません。")
                }
            }
        }
        
        // 最新の履歴を編集してコピーするショートカットの登録
        KeyboardShortcuts.onKeyDown(for: .editAndCopyLatestHistory) {
            let clipboardManager = ClipboardManager.shared
            let useFiltered = UserDefaults.standard.bool(forKey: "useFilteredHistoryForShortcuts")
            
            let historySource: [ClipboardItem]
            if useFiltered, let filteredList = clipboardManager.filteredHistoryForShortcuts {
                historySource = filteredList
            } else {
                historySource = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
            }
            
            // 最新の履歴アイテムを取得
            if let latestItem = historySource.first {
                // ウィンドウとして表示する処理をここに実装
                DispatchQueue.main.async {
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.showEditHistoryWindow(withContent: latestItem.text)
                    }
                }
            }
        }
    }
}
