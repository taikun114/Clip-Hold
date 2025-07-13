import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers

private let itemDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

private func copyToClipboard(_ item: ClipboardItem) {
    let clipboardManager = ClipboardManager.shared

    clipboardManager.isPerformingInternalCopy = true
    print("DEBUG: copyToClipboard: isPerformingInternalCopy = true")

    NSPasteboard.general.clearContents()

    var success = false

    if let filePath = item.filePath {
        // ファイルパスが存在する場合、ファイルとしてクリップボードにコピーを試みる
        // Option 1: NSURLオブジェクトを書き込む（既存の方法）
        let nsURL = filePath as NSURL
        if NSPasteboard.general.writeObjects([nsURL]) {
            print("クリップボードにファイルがコピーされました (NSURL): \(filePath.lastPathComponent)")
            success = true
        } else {
            print("クリップボードにファイル (NSURL) をコピーできませんでした: \(filePath.lastPathComponent)")
            
            // Option 2: ファイルURLの文字列 (.fileURL タイプ) を書き込む
            // こちらの方が明示的でうまくいく場合があります
            if NSPasteboard.general.setString(filePath.absoluteString, forType: .fileURL) {
                print("クリップボードにファイルURL文字列がコピーされました (.fileURL): \(filePath.lastPathComponent)")
                success = true
            } else {
                print("クリップボードにファイルURL文字列 (.fileURL) をコピーできませんでした: \(filePath.lastPathComponent)")
            }
        }
    }

    // ファイルコピーが失敗した場合、またはファイルパスがそもそも存在しない場合、テキストをコピーする
    if !success {
        if let string = item.text.data(using: .utf8) {
            NSPasteboard.general.setData(string, forType: .string)
            print("クリップボードにテキストがコピーされました: \(item.text.prefix(20))...")
        }
    }

    clipboardManager.isPerformingInternalCopy = false
    print("DEBUG: copyToClipboard: isPerformingInternalCopy = false")
}

// 文字列を安全に切り詰めるヘルパー関数
private func truncateString(_ text: String?, maxLength: Int) -> String {
    guard let text = text else { return "" }
    if text.count > maxLength {
        return String(text.prefix(maxLength)) + "..."
    }
    return text
}

struct HistoryItemRow: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    let item: ClipboardItem
    let index: Int
    let showLineNumber: Bool
    @Binding var itemToDelete: ClipboardItem?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var selectedItemID: UUID?
    var dismissAction: () -> Void
    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    @Environment(\.colorScheme) var colorScheme

    @Binding var showCopyConfirmation: Bool
    @Binding var showQRCodeSheet: Bool
    @Binding var selectedItemForQRCode: ClipboardItem?
    
    @Binding var itemForNewPhrase: ClipboardItem?

    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat

    @State private var iconImage: NSImage?
    @State private var iconLoadTask: Task<Void, Never>?

    init(item: ClipboardItem,
         index: Int,
         showLineNumber: Bool,
         itemToDelete: Binding<ClipboardItem?>,
         showingDeleteConfirmation: Binding<Bool>,
         selectedItemID: Binding<UUID?>,
         dismissAction: @escaping () -> Void, // クロージャは@escapingをつける
         showCopyConfirmation: Binding<Bool>,
         showQRCodeSheet: Binding<Bool>,
         selectedItemForQRCode: Binding<ClipboardItem?>,
         itemForNewPhrase: Binding<ClipboardItem?>,
         lineNumberTextWidth: CGFloat?,
         trailingPaddingForLineNumber: CGFloat) {
            
        self.item = item
        self.index = index
        self.showLineNumber = showLineNumber
        _itemToDelete = itemToDelete
        _showingDeleteConfirmation = showingDeleteConfirmation
        _selectedItemID = selectedItemID
        self.dismissAction = dismissAction
        _showCopyConfirmation = showCopyConfirmation
        _showQRCodeSheet = showQRCodeSheet
        _selectedItemForQRCode = selectedItemForQRCode
        _itemForNewPhrase = itemForNewPhrase
        self.lineNumberTextWidth = lineNumberTextWidth
        self.trailingPaddingForLineNumber = trailingPaddingForLineNumber
    }

    private var actionMenuItems: some View {
        Group {
            Button("コピー") {
                copyToClipboard(item)
                showCopyConfirmation = true
            }
            Button("項目から定型文を作成...") {
                itemForNewPhrase = item // ここでClipboardItemをセット
            }
            Button("QRコードを表示...") {
                showQRCodeSheet = true
                selectedItemForQRCode = item
            }
            Divider()
            Button("削除...", role: .destructive) {
                itemToDelete = item
                showingDeleteConfirmation = true
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) { // アイコンとの間に少しスペースを空ける
            if showLineNumber {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: lineNumberTextWidth, alignment: .trailing)
                    .padding(.trailing, trailingPaddingForLineNumber)
            }
            
            // アイコンを表示するロジック
            if let icon = iconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "text.page")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading) {
                Text(item.text)
                    .lineLimit(1)
                    .font(.body)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                Text(item.date, formatter: itemDateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                actionMenuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundColor(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.leading, 5)
        .contentShape(Rectangle())
        .help(item.text)
        .onAppear {
            if let filePath = item.filePath {
                // 既存のタスクをキャンセルして新しいタスクを開始
                iconLoadTask?.cancel()
                iconLoadTask = Task.detached {
                    let nsImage = NSWorkspace.shared.icon(forFile: filePath.path)
                    // メインスレッドでUIを更新
                    await MainActor.run {
                        self.iconImage = nsImage
                    }
                }
            } else {
                // ファイルでない場合はアイコンをnilにリセット
                iconImage = nil
            }
        }
        .onDisappear {
            // ビューが非表示になったらタスクをキャンセルしてメモリを解放
            iconLoadTask?.cancel()
        }
    }
}

struct HistoryWindowView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @Environment(\.dismiss) var dismiss

    @State private var searchText: String = ""
    @State private var filteredHistory: [ClipboardItem] = []
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: ClipboardItem?
    @State private var selectedItemID: UUID?
    @State private var isLoading: Bool = false
    @State private var showCopyConfirmation: Bool = false
    @State private var currentCopyConfirmationTask: Task<Void, Never>?
    
    @State private var showQRCodeSheet: Bool = false
    @State private var selectedItemForQRCode: ClipboardItem?

    @State private var itemForNewPhrase: ClipboardItem? = nil

    @State private var previousClipboardHistoryCount: Int = 0

    @FocusState private var isSearchFieldFocused: Bool

    @AppStorage("showLineNumbersInHistoryWindow") var showLineNumbersInHistoryWindow: Bool = false
    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false
    @AppStorage("scrollToTopOnUpdate") var scrollToTopOnUpdate: Bool = false

    private var lineNumberTextWidth: CGFloat? {
        guard showLineNumbersInHistoryWindow, !filteredHistory.isEmpty else { return nil }
        
        let maxIndex = filteredHistory.count
        let numDigits = String(maxIndex).count

        let digitWidth: CGFloat = 7.0
        let periodWidth: CGFloat = 3.0
        let buffer: CGFloat = 1.0

        return CGFloat(numDigits) * digitWidth + periodWidth + buffer
    }

    private let trailingPaddingForLineNumber: CGFloat = 5

    private func performSearch(searchTerm: String) {
        let newFilteredHistory: [ClipboardItem]
        if searchTerm.isEmpty {
            newFilteredHistory = clipboardManager.clipboardHistory
        } else {
            newFilteredHistory = clipboardManager.clipboardHistory.filter { item in
                item.text.localizedCaseInsensitiveContains(searchTerm)
            }
        }
        self.filteredHistory = newFilteredHistory
    }

    var body: some View {
        ZStack {
            HistoryWindowBackground()

            ZStack { // メインコンテンツを囲むZStack
                VStack(spacing: 0) {
                    HistorySearchBar(
                        searchText: $searchText,
                        isLoading: $isLoading,
                        isSearchFieldFocused: _isSearchFieldFocused,
                        performSearchAction: performSearch,
                        clipboardHistoryCount: clipboardManager.clipboardHistory.count
                    )

                    Spacer(minLength: 10)

                    HistoryContentList(
                        filteredHistory: $filteredHistory,
                        isLoading: $isLoading,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        itemToDelete: $itemToDelete,
                        selectedItemID: $selectedItemID,
                        showCopyConfirmation: $showCopyConfirmation,
                        currentCopyConfirmationTask: $currentCopyConfirmationTask,
                        showQRCodeSheet: $showQRCodeSheet,
                        selectedItemForQRCode: $selectedItemForQRCode,
                        itemForNewPhrase: $itemForNewPhrase,
                        previousClipboardHistoryCount: $previousClipboardHistoryCount,
                        showLineNumbersInHistoryWindow: showLineNumbersInHistoryWindow,
                        preventWindowCloseOnDoubleClick: preventWindowCloseOnDoubleClick,
                        scrollToTopOnUpdate: scrollToTopOnUpdate,
                        lineNumberTextWidth: lineNumberTextWidth,
                        trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                        searchText: searchText, // searchTextを渡す
                        onCopyAction: { itemToCopy in
                            copyToClipboard(itemToCopy)
                        }
                    )
                }
            } // メインコンテンツを囲むZStackの終わり
            
            HistoryCopyConfirmation(showCopyConfirmation: $showCopyConfirmation)
                .onAppear {
                    // onAppearからはタイマー設定ロジックを削除。
                    // ここは単にビューの出現アニメーションに使用
                }
                .onDisappear {
                    // ビューが非表示になる際にタスクをキャンセル (念のため)
                    currentCopyConfirmationTask?.cancel()
                }
        }
        .onExitCommand {
            dismiss()
        }
        .frame(minWidth: 300, idealWidth: 375, maxWidth: 900, minHeight: 300, idealHeight: 400, maxHeight: .infinity)
        .onAppear {
            performSearch(searchTerm: searchText)
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.contentViewController is NSHostingController<HistoryWindowView> }) {
                    print("HistoryWindowView onAppear: Found historyWindow via NSHostingController: \(window.identifier?.rawValue == "unknown")")
                    print("HistoryWindowView onAppear: Window delegate: \(window.delegate.debugDescription)")
                    
                    if let controller = window.windowController as? ClipHoldWindowController {
                        print("HistoryWindowView onAppear: Found managed controller. Re-applying customizations.")
                        controller.applyWindowCustomizations(window: window)
                    }
                } else {
                    print("HistoryWindowView onAppear: History window not found among NSApp.windows via NSHostingController.")
                }
            }
        }
        .alert("履歴の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let item = itemToDelete {
                    clipboardManager.deleteItem(id: item.id)
                    itemToDelete = nil
                    selectedItemID = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？")
        }
        .sheet(isPresented: $showQRCodeSheet) {
            if let item = selectedItemForQRCode {
                QRCodeView(text: item.text)
            }
        }
        .sheet(item: $itemForNewPhrase) { item in
            AddEditPhraseView(mode: .add, initialContent: item.text)
                .environmentObject(standardPhraseManager)
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
