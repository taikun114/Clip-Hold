import SwiftUI

struct HistorySearchBar: View {
    @Binding var searchText: String
    @Binding var isLoading: Bool
    @FocusState var isSearchFieldFocused: Bool
    var clipboardHistoryCount: Int

    @State private var searchTask: Task<Void, Never>? = nil

    @Binding var selectedFilter: ItemFilter
    @Binding var selectedSort: ItemSort

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
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                        .offset(y: -1.0)
                    Spacer()
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.trailing, 8)
                    }
                }
            )
            // フィルターボタン
            Menu {
                ForEach(ItemFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack {
                            // 選択されている場合にのみチェックマークを表示
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                            Text(filter.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    // フィルターがデフォルト以外の場合はアクセントカラーを適用
                    .tint(selectedFilter != .all ? .accentColor : .secondary)
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
        .padding(.horizontal, 8)
        .padding(.bottom, 5)
    }
}
