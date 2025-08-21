import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var clipboardManager: ClipboardManager

    @State private var selectedSection: String = "general"

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
                Label("プライバシー", systemImage: "hand.raised.fill")
                    .tag("privacy")
                Label("情報", systemImage: "info.circle.fill")
                    .tag("info")
            }
            .frame(minWidth: 200, idealWidth: 200, maxWidth: .infinity)
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedSection {
                case "general":
                    GeneralSettingsView()
                        .frame(minWidth: 450, maxWidth: .infinity)
                case "standardPhrases":
                    StandardPhraseSettingsView()
                        .environmentObject(standardPhraseManager)
                        .frame(minWidth: 450, maxWidth: .infinity)
                case "copyHistory":
                    CopyHistorySettingsView()
                        .frame(minWidth: 450, maxWidth: .infinity)
                case "shortcuts":
                    ShortcutsSettingsView()
                        .frame(minWidth: 450, maxWidth: .infinity)
                case "privacy":
                    PrivacySettingsView()
                        .environmentObject(clipboardManager)
                        .frame(minWidth: 450, maxWidth: .infinity)
                case "info":
                    InfoSettingsView()
                        .frame(minWidth: 450, maxWidth: .infinity)
                default:
                    GeneralSettingsView()
                        .frame(minWidth: 450, maxWidth: .infinity)
                }
            }
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}
