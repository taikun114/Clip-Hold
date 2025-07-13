import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var clipboardManager: ClipboardManager

    @State private var selectedTab: String = "general"

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
                .tag("general")

            StandardPhraseSettingsView()
                .environmentObject(standardPhraseManager) // 環境オブジェクトを渡す
                .tabItem {
                    Label("定型文", systemImage: "list.bullet")
                }
                .tag("standardPhrases")

            CopyHistorySettingsView()
                .tabItem {
                    Label("コピー履歴", systemImage: "list.clipboard")
                }
                .tag("copyHistory")

            ShortcutsSettingsView()
                .tabItem {
                    Label("ショートカット", systemImage: "command")
                }
                .tag("shortcuts") // ユニークなタグを設定

            PrivacySettingsView()
                .environmentObject(clipboardManager) // 環境オブジェクトを渡す
                .tabItem {
                    Label("プライバシー", systemImage: "hand.raised.fill")
                }
                .tag("privacy")

            InfoSettingsView()
                .tabItem {
                    Label("情報", systemImage: "info.circle.fill")
                }
                .tag("info")
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}
