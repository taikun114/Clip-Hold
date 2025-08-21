import SwiftUI
import UniformTypeIdentifiers
import SwiftUIIntrospect

struct SettingsView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var clipboardManager: ClipboardManager

    @State private var selectedSection: String = "general"
    @Environment(\.colorScheme) var colorScheme

    private var accentColor: Color {
        switch colorScheme {
        case .dark:
            return Color.accentColor.adjustedSaturation(-0.215)
        case .light:
            return Color.accentColor.adjustedBrightness(-0.07).adjustedSaturation(-0.03)
        @unknown default:
            return .accentColor
        }
    }
    
    private var sidebarButtonBackgroundColor: Color {
        switch colorScheme {
        case .dark:
            return Color.accentColor.adjustedBrightness(-0.305).adjustedSaturation(-0.105)
        case .light:
            return Color.accentColor.adjustedBrightness(-0.22).adjustedSaturation(-0.04)
        @unknown default:
            return Color.accentColor.opacity(0.2)
        }
    }

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
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    selectedSection = "info"
                }) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(selectedSection == "info" ? .white : accentColor)
                        Text("情報")
                            .foregroundColor(selectedSection == "info" ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(selectedSection == "info" ? sidebarButtonBackgroundColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(10)
            }
            .frame(minWidth: 150, idealWidth: 200, maxWidth: 250)
            .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 250)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedSection {
                case "general":
                    GeneralSettingsView()
                case "standardPhrases":
                    StandardPhraseSettingsView()
                        .environmentObject(standardPhraseManager)
                case "copyHistory":
                    CopyHistorySettingsView()
                case "shortcuts":
                    ShortcutsSettingsView()
                case "privacy":
                    PrivacySettingsView()
                        .environmentObject(clipboardManager)
                case "info":
                    InfoSettingsView()
                default:
                    GeneralSettingsView()
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)
        }
        .introspect(.navigationSplitView, on: .macOS(.v14, .v15)) { splitview in
            if let delegate = splitview.delegate as? NSSplitViewController {
                delegate.splitViewItems.first?.canCollapse = false
                delegate.splitViewItems.first?.canCollapseFromWindowResize = false
            }
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}
