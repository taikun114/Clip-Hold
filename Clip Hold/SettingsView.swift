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
            if #available(macOS 26, *) {
                return Color.accentColor.adjustedBrightness(-0.2).adjustedSaturation(0.3)
            } else {
                return Color.accentColor.adjustedBrightness(-0.305).adjustedSaturation(-0.105)
            }
        case .light:
            if #available(macOS 26, *) {
                return Color.accentColor.adjustedBrightness(-0.22).adjustedSaturation(-0.04)
            } else {
                return Color.accentColor.adjustedBrightness(-0.22).adjustedSaturation(-0.04)
            }
        @unknown default:
            return Color.accentColor.opacity(0.8)
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
                                .foregroundColor(.primary)
                            Text("情報")
                                .foregroundColor(selectedSection == "info" ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedSection == "info" ? sidebarButtonBackgroundColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(10)
                } else {
                    Button(action: {
                        selectedSection = "info"
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
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
        }
    }
}


#Preview {
    SettingsView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(ClipboardManager.shared)
}
