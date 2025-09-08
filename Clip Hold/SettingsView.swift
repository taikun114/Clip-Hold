import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var clipboardManager: ClipboardManager

    @State private var selectedSection: String = "general"
    @State private var navigationHistory: [String] = ["general"]
    @State private var historyIndex: Int = 0
    @State private var isProgrammaticSelection: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isWindowFocused: Bool = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("一般", systemImage: "gear")
                    .tag("general")
                Label("定型文", systemImage: "list.bullet")
                    .tag("standardPhrases")
                Label("コピー履歴", systemImage: "list.clipboard")
                    .tag("copyHistory")
                Label("ショートカット", systemImage: "command")
                    .tag("shortcuts")
                Label("プライバシー", systemImage: "hand.raised")
                    .tag("privacy")
                Label("開発者向け機能", systemImage: "hammer")
                    .tag("developer")
            }
            .safeAreaInset(edge: .bottom) {
                if #available(macOS 26, *) {
                    Button(action: {
                        selectedSection = "info"
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(selectedSection == "info" ? (isWindowFocused ? .white : .primary) : .primary)
                            Text("情報")
                                .foregroundStyle(selectedSection == "info" ? (isWindowFocused ? .white : .secondary.opacity(0.5)) : (isWindowFocused ? .primary : .secondary.opacity(0.5)))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedSection == "info" ? (isWindowFocused ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.3)) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(10)
                } else {
                    Button(action: {
                        selectedSection = "info"
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(selectedSection == "info" ? (isWindowFocused ? .white : .accentColor.opacity(0.8)) : .accentColor.opacity(0.8))
                            Text("情報")
                                .foregroundStyle(selectedSection == "info" ? (isWindowFocused ? .white : .secondary.opacity(0.5)) : (isWindowFocused ? .primary : .secondary.opacity(0.5)))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(selectedSection == "info" ? (isWindowFocused ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.3)) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(10)
                }
            }
            .frame(minWidth: 150, idealWidth: 200, maxWidth: 250)
            .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 250)
        } detail: {
            Group {
                switch selectedSection {
                case "general":
                    GeneralSettingsView()
                        .navigationTitle("一般")
                case "standardPhrases":
                    StandardPhraseSettingsView()
                        .environmentObject(standardPhraseManager)
                        .navigationTitle("定型文")
                case "copyHistory":
                    CopyHistorySettingsView()
                        .navigationTitle("コピー履歴")
                case "shortcuts":
                    ShortcutsSettingsView()
                        .navigationTitle("ショートカット")
                case "privacy":
                    PrivacySettingsView()
                        .environmentObject(clipboardManager)
                        .navigationTitle("プライバシー")
                case "developer":
                    DeveloperSettingsView()
                        .navigationTitle("開発者向け機能")
                case "info":
                    InfoSettingsView()
                        .navigationTitle("情報")
                default:
                    GeneralSettingsView()
                        .navigationTitle("一般")
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 0) {
                        Group {
                            Button(action: goBack) {
                                Image(systemName: "chevron.left")
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .disabled(!canGoBack)
                            if #available(macOS 26, *) {
                                Capsule().fill(Color.secondary).opacity(0.1).frame(width: 1, height: 20)
                            }
                            Button(action: goForward) {
                                Image(systemName: "chevron.right")
                                    .frame(width: 20, height: 20)
                                    .contentShape(Rectangle())
                            }
                            .disabled(!canGoForward)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedSection) { _, newSection in
            if !isProgrammaticSelection {
                // ユーザーの操作による変更の場合のみ履歴を更新
                if historyIndex < navigationHistory.count - 1 {
                    // 履歴の途中で新しい項目を選択した場合、それ以降の履歴を削除
                    navigationHistory.removeSubrange((historyIndex + 1)...)
                }
                navigationHistory.append(newSection)
                historyIndex = navigationHistory.count - 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { notification in
            if let window = notification.object as? NSWindow, window.identifier == NSUserInterfaceItemIdentifier("SettingsWindow") {
                isWindowFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignMainNotification)) { notification in
            if let window = notification.object as? NSWindow, window.identifier == NSUserInterfaceItemIdentifier("SettingsWindow") {
                isWindowFocused = false
            }
        }
    }

    private var canGoBack: Bool {
        historyIndex > 0
    }

    private var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1
    }

    private func goBack() {
        if canGoBack {
            historyIndex -= 1
            isProgrammaticSelection = true
            selectedSection = navigationHistory[historyIndex]
            // フラグをリセット
            DispatchQueue.main.async {
                isProgrammaticSelection = false
            }
        }
    }

    private func goForward() {
        if canGoForward {
            historyIndex += 1
            isProgrammaticSelection = true
            selectedSection = navigationHistory[historyIndex]
            // フラグをリセット
            DispatchQueue.main.async {
                isProgrammaticSelection = false
            }
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}
