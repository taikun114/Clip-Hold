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
                ForEach(ItemFilter.allCases.filter { 
                    // colorCodeOnlyは設定がオンの場合のみ表示
                    $0 != .colorCodeOnly || enableColorCodeFilter
                }) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack {
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                            Text(filter.displayName)
                        }
                    }
                }
                
                if !clipboardManager.appUsageHistory.isEmpty {
                    Divider()
                    Menu {
                        Button {
                            selectedApp = nil
                        } label: {
                            HStack {
                                if selectedApp == nil {
                                    Image(systemName: "checkmark")
                                }
                                Text("すべてのアプリ")
                            }
                        }
                        
                        Divider()
                        
                        ForEach(clipboardManager.appUsageHistory.sorted(by: { $0.value < $1.value }), id: \.key) { nonLocalizedName, localizedName in
                            Button {
                                selectedApp = nonLocalizedName
                            } label: {
                                HStack {
                                    if selectedApp == nonLocalizedName {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(localizedName)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if selectedApp != nil {
                                Image(systemName: "checkmark")
                            }
                            Text("アプリ")
                        }
                    }
                }
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
                ForEach(ItemSort.allCases) { sort in
                    Button {
                        selectedSort = sort
                    } label: {
                        HStack {
                            // 選択されている場合にのみチェックマークを表示
                            if selectedSort == sort {
                                Image(systemName: "checkmark")
                            }
                            Text(sort.displayName)
                        }
                    }
                }
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
