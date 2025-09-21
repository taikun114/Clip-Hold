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
                    Label(ItemFilter.all.displayName, systemImage: "list.clipboard").tag(ItemFilter.all)
                    
                    // テキストピッカーを「すべての項目」の下、「リンクのみ」の上に配置
                    Picker(selection: $selectedFilter) {
                        Label(ItemFilter.textAll.displayName, systemImage: "textformat").tag(ItemFilter.textAll)
                        Divider()
                        if #available(macOS 15.0, *) {
                            Label(ItemFilter.textPlain.displayName, systemImage: "text.page").tag(ItemFilter.textPlain)
                        } else {
                            Label(ItemFilter.textPlain.displayName, systemImage: "doc.plaintext").tag(ItemFilter.textPlain)
                        }
                        if #available(macOS 15.0, *) {
                            Label(ItemFilter.textRich.displayName, systemImage: "richtext.page").tag(ItemFilter.textRich)
                        } else {
                            Label(ItemFilter.textRich.displayName, systemImage: "doc.richtext").tag(ItemFilter.textRich)
                        }
                    } label: {
                        Label("テキストのみ", systemImage: "textformat")
                    }
                    .pickerStyle(.menu)

                    // テキスト関連と「すべての項目」を除く他のフィルターオプションを表示
                    ForEach(ItemFilter.allCases.filter {
                        // テキスト関連と「すべての項目」、colorCodeOnly以外の項目を表示
                        ($0 != .textAll && $0 != .textPlain && $0 != .textRich && $0 != .all && $0 != .colorCodeOnly) || 
                        // colorCodeOnlyは設定がオンの場合のみ表示
                        ($0 == .colorCodeOnly && enableColorCodeFilter)
                    }) { filter in
                        switch filter {
                        case .linkOnly:
                            Label(filter.displayName, systemImage: "paperclip").tag(filter)
                        case .fileOnly:
                            if #available(macOS 15.0, *) {
                                Label(filter.displayName, systemImage: "document").tag(filter)
                            } else {
                                Label(filter.displayName, systemImage: "doc").tag(filter)
                            }
                        case .imageOnly:
                            Label(filter.displayName, systemImage: "photo").tag(filter)
                        case .pdfOnly:
                            Label(filter.displayName, systemImage: "text.document").tag(filter)
                        case .colorCodeOnly:
                            Label(filter.displayName, systemImage: "paintpalette").tag(filter)
                        default:
                            Text(filter.displayName).tag(filter)
                        }
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
                            Label("アプリ", systemImage: "app")
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
            .disabled(isLoading) // 読み込み中に無効化

            // 並び替えボタン
            Menu {
                Picker("並び替え", selection: $selectedSort) {
                    ForEach(ItemSort.allCases, id: \.self) { sort in
                        switch sort {
                        case .newest:
                            Label(sort.displayName, systemImage: "clock").tag(sort)
                        case .oldest:
                            Text(sort.displayName).tag(sort)
                        case .largestFileSize:
                            Divider()
                            Label(sort.displayName, systemImage: "folder").tag(sort)
                        case .smallestFileSize:
                            Text(sort.displayName).tag(sort)
                        }
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
            .disabled(isLoading) // 読み込み中に無効化

        }
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
