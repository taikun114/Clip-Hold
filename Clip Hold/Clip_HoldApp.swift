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

    @StateObject var standardPhraseManager = StandardPhraseManager.shared
    @StateObject var clipboardManager = ClipboardManager.shared

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
        
    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 500, height: 500)
                .environmentObject(clipboardManager)
                .environmentObject(standardPhraseManager)
        }

        MenuBarExtra(
            "Clip Hold", // <- titleKey
            image: isClipboardMonitoringPaused ? "Menubar Icon Dimmed" : "Menubar Icon",
            isInserted: menuBarExtraInsertionBinding
        ) {
            // --- 定型文セクション ---
            Label("よく使う定型文", systemImage: "star")
                .font(.headline)
                .padding(.bottom, 5)
            
            if standardPhraseManager.standardPhrases.isEmpty {
                Text("定型文はありません")
            } else {
                let displayLimit = min(standardPhraseManager.standardPhrases.count, maxPhrasesInMenu)
                ForEach(standardPhraseManager.standardPhrases.prefix(displayLimit)) { phrase in
                    let displayText: String = {
                        let displayContent = phrase.title.replacingOccurrences(of: "\n", with: " ")
                        if displayContent.count > 40 {
                            return String(displayContent.prefix(40)) + "..."
                        }
                        return displayContent
                    }()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(phrase.content, forType: .string)
                        
                        // quickPaste がオンの場合、定型文は常にテキストなのでそのままペースト
                        if quickPaste {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                ClipHoldApp.performPaste()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.secondary)
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
                let displayLimit = min(clipboardManager.clipboardHistory.count, maxHistoryInMenu)
                ForEach(clipboardManager.clipboardHistory.prefix(displayLimit)) { item in
                    
                    let itemDateFormatter: DateFormatter = {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        formatter.timeStyle = .short
                        return formatter
                    }()
                     
                    let displayText: String = {
                        var displayContent = item.text.replacingOccurrences(of: "\n", with: " ")
                        let dateString = itemDateFormatter.string(from: item.date)
                                                 
                        if displayContent.count > 40 {
                            displayContent = String(displayContent.prefix(40)) + "..."
                        }
                                                 
                        return "\(displayContent) (\(dateString))"
                    }()
                    
                    Button {
                        // 内部コピーフラグをtrueに設定
                        clipboardManager.isPerformingInternalCopy = true
                        clipboardManager.copyItemToClipboard(item)
                        
                        // quickPaste がオンの場合、かつ textOnlyQuickPaste がオンの場合は文字列のみペースト
                        if quickPaste {
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
                            if item.isURL { // URLの場合
                                Image(systemName: "paperclip")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(4)
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.secondary)
                            } else if let cachedImage = item.cachedThumbnailImage {
                                Image(nsImage: cachedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            } else if let filePath = item.filePath {
                                // キャッシュがない場合は、従来のファイルアイコンを表示
                                let nsImage = NSWorkspace.shared.icon(forFile: filePath.path)
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            } else {
                                // ファイルパスもキャッシュもなければテキストアイコン
                                // macOS 15 以降では text.page、それ以前では doc.plaintext を使用
                                if #available(macOS 15.0, *) {
                                    Image(systemName: "text.page")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(4)
                                        .frame(width: 16, height: 16) // メニューバーのアイコンサイズに合わせる
                                        .foregroundColor(.secondary)
                                } else {
                                    Image(systemName: "doc.plaintext")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(4)
                                        .frame(width: 16, height: 16) // メニューバーのアイコンサイズに合わせる
                                        .foregroundColor(.secondary)
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
            
            SettingsLink {
                Label("設定...", systemImage: "gear")
            }
            .buttonStyle(.preAction {
                NSApp.activate(ignoringOtherApps: true)
            })
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .environmentObject(clipboardManager)
        .environmentObject(standardPhraseManager)
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
                // StandardPhraseManager はシングルトンなので、static context からも .shared でアクセス可能
                let standardPhraseManager = StandardPhraseManager.shared

                if standardPhraseManager.standardPhrases.indices.contains(i) {
                    let phrase = standardPhraseManager.standardPhrases[i]
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(phrase.content, forType: .string)
                    print("定型文「\(phrase.title)」がショートカットでコピーされました。")

                    // quickPaste の最新の値を取得
                    let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
                    
                    // quickPaste がオンの場合、定型文は常にテキストなのでそのままペースト
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

                if clipboardManager.clipboardHistory.indices.contains(i) {
                    let historyItem = clipboardManager.clipboardHistory[i]
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
                    print("履歴ショートカット \(i+1) が押されましたが、対応する履歴は存在しません。")
                }
            }
        }
    }
}
