import SwiftUI

struct HistorySearchBar: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var searchText: String
    @Binding var isLoading: Bool
    @FocusState var isSearchFieldFocused: Bool
    var clipboardHistoryCount: Int

    @State private var searchTask: Task<Void, Never>? = nil

    @Binding var selectedFilter: ItemFilter
    @Binding var selectedSort: ItemSort
    @Binding var selectedApp: String?
    
    // カラーコードフィルタリング設定のバインディング
    @AppStorage("enableColorCodeFilter") var enableColorCodeFilter: Bool = false

    private func resizedAppIcon(for path: String) -> NSImage {
        let originalIcon = NSWorkspace.shared.icon(forFile: path)
        let resizedIcon = NSImage(size: CGSize(width: 16, height: 16))
        resizedIcon.lockFocus()
        originalIcon.draw(in: NSRect(origin: .zero, size: CGSize(width: 16, height: 16)),
                           from: NSRect(origin: .zero, size: originalIcon.size),
                           operation: .sourceOver,
                           fraction: 1.0)
        resizedIcon.unlockFocus()
        return resizedIcon
    }

    var body: some View {
        HStack {
            TextField(
                "履歴を検索",
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .padding(.vertical, 8)
            .padding(.leading, 30)
            .padding(.trailing, 10)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(10)
            .controlSize(.large)
            .focused($isSearchFieldFocused)
            .overlay(
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                        .offset(y: -1.0)
                    Spacer()
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.trailing, 8)
                    }
                }
            )
            // フィルターボタン
            Menu {
                Picker("フィルター", selection: $selectedFilter) {
                    // 「すべての項目」を最初に表示
                    Text(ItemFilter.all.displayName).tag(ItemFilter.all)
                    
                    // テキストピッカーを「すべての項目」の下、「リンクのみ」の上に配置
                    Picker("テキストのみ", selection: $selectedFilter) {
                        Text(ItemFilter.textAll.displayName).tag(ItemFilter.textAll)
                        Divider()
                        Text(ItemFilter.textPlain.displayName).tag(ItemFilter.textPlain)
                        Text(ItemFilter.textRich.displayName).tag(ItemFilter.textRich)
                    }
                    .pickerStyle(.menu)

                    // テキスト関連と「すべての項目」を除く他のフィルターオプションを表示
                    ForEach(ItemFilter.allCases.filter {
                        // テキスト関連と「すべての項目」、colorCodeOnly以外の項目を表示
                        ($0 != .textAll && $0 != .textPlain && $0 != .textRich && $0 != .all && $0 != .colorCodeOnly) || 
                        // colorCodeOnlyは設定がオンの場合のみ表示
                        ($0 == .colorCodeOnly && enableColorCodeFilter)
                    }) { filter in
                        Text(filter.displayName).tag(filter)
                    }

                    if !clipboardManager.appUsageHistory.isEmpty {
                        Divider()
                        Picker(selection: $selectedApp) {
                            Label("すべてのアプリ", systemImage: "app").tag(nil as String?)
                            Label("自動", systemImage: "app.badge.checkmark").tag("auto_filter_mode" as String?)
                            Divider()
                            ForEach(clipboardManager.appUsageHistory.sorted(by: { $0.value < $1.value }), id: \.key) { path, localizedName in
                                Label {
                                    Text(localizedName)
                                } icon: {
                                    if FileManager.default.fileExists(atPath: path) {
                                        Image(nsImage: resizedAppIcon(for: path))
                                    } else {
                                        Image(systemName: "questionmark.app")
                                    }
                                }
                                .tag(path as String?)
                            }
                        } label: {
                            Text("アプリ")
                        }
                        .labelStyle(.titleAndIcon)
                        .pickerStyle(.menu)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .tint(selectedFilter != .all || selectedApp != nil ? .accentColor : .secondary)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .padding(.horizontal, 4)

            // 並び替えボタン
            Menu {
                Picker("並び替え", selection: $selectedSort) {
                    ForEach(ItemSort.allCases, id: \.self) { sort in
                        Text(sort.displayName).tag(sort)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    // 並び替えがデフォルト以外の場合はアクセントカラーを適用
                    .tint(selectedSort != .newest ? .accentColor : .secondary)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            .padding(.horizontal, 4)

        }
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
