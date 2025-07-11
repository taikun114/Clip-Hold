import SwiftUI

struct HistorySearchBar: View {
    @Binding var searchText: String
    @Binding var isLoading: Bool
    @FocusState var isSearchFieldFocused: Bool
    var performSearchAction: (String) -> Void
    var clipboardHistoryCount: Int

    @State private var searchTask: Task<Void, Never>? = nil

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
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 5)
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            
            searchTask = Task { @MainActor in
                let initialDelayNanoseconds: UInt64 = 150_000_000
                try? await Task.sleep(nanoseconds: initialDelayNanoseconds)

                guard !Task.isCancelled else {
                    return
                }
                
                isLoading = true

                let remainingDebounceNanoseconds: UInt64 = 150_000_000
                try? await Task.sleep(nanoseconds: remainingDebounceNanoseconds)

                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                performSearchAction(newValue)
                isLoading = false
            }
        }
        .onChange(of: clipboardHistoryCount) { _, _ in
            performSearchAction(searchText) // 履歴が変更されたら、検索結果を更新
        }
    }
}
