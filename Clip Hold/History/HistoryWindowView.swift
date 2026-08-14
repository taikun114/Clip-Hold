import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers
import Quartz
import QuickLookThumbnailing

// MARK: - HistoryWindowView
struct HistoryWindowView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var frontmostAppMonitor: FrontmostAppMonitor
    @EnvironmentObject var dateReloader: DateReloader
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText: String = ""
    @State private var filteredHistory: [ClipboardItem] = []
    
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: ClipboardItem?
    @State private var deleteOnlyThisItem: Bool = false
    @State private var selectedItemID: UUID?
    @State private var isLoading: Bool = false
    @State private var isPaginating: Bool = false
    @State private var showCopyConfirmation: Bool = false
    @State private var currentCopyConfirmationTask: Task<Void, Never>?
    
    @State private var copyConfirmationTask: Task<Void, Never>? = nil
    @State private var historyUpdateTask: Task<Void, Never>? = nil
    
    @State private var selectedItemForQRCode: ClipboardItem? = nil
    
    @State private var itemForNewPhrase: ClipboardItem? = nil
    
    @State private var isChildSheetPresented: Bool = false
    
    @State private var displayLimit: Int = 100
    
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    
    @State private var searchTrigger: UUID = UUID()
    
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isListFocused: Bool
    
    @AppStorage("hideNumbersInHistoryWindow") var hideNumbersInHistoryWindow: Bool = false
    @AppStorage("closeWindowOnDoubleClickInHistoryWindow") var closeWindowOnDoubleClickInHistoryWindow: Bool = false
    @AppStorage("scrollToTopOnUpdate") var scrollToTopOnUpdate: Bool = true
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = false
    @AppStorage("dateDisplayFormatInHistoryWindow") var dateDisplayFormatInHistoryWindow: String = "absolute"
    
    private var lineNumberTextWidth: CGFloat? {
        guard !hideNumbersInHistoryWindow, !(clipboardManager.filteredHistoryForShortcuts ?? []).isEmpty else { return nil }
        
        let maxIndex = (clipboardManager.filteredHistoryForShortcuts ?? []).count
        let numDigits = String(maxIndex).count
        
        let digitWidth: CGFloat = 7.0
        let periodWidth: CGFloat = 3.0
        let buffer: CGFloat = 1.0
        
        return CGFloat(numDigits) * digitWidth + periodWidth + buffer
    }
    
    private let trailingPaddingForLineNumber: CGFloat = 5
    
    // 文字列を安全に切り詰めるヘルパー関数
    private func truncateString(_ text: String?, maxLength: Int) -> String {
        guard let text = text else { return "" }
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }
    
    private func performUpdate(isPagination: Bool = false, isBackground: Bool = false) {
        if isPagination {
            isPaginating = true
        } else if isBackground {
            // バックグラウンドでの更新のためスピナーを表示しない
        } else {
            isLoading = true
            isPaginating = false
            displayLimit = 100 // 新しい検索やフィルタの時は100件にリセット
            self.filteredHistory = []
            clipboardManager.filteredHistoryForShortcuts = []
        }
        
        let historyCopy = clipboardManager.clipboardHistory
        let currentFilter = clipboardManager.historySelectedFilter
        let currentSort = clipboardManager.historySelectedSort
        let currentApp = clipboardManager.historySelectedApp
        let currentSearchText = searchText
        let currentDisplayLimit = displayLimit
        let currentPinnedID = clipboardManager.pinnedItemID
        let frontmostID = frontmostAppMonitor.frontmostAppBundleIdentifier
        let isReduceMotion = reduceMotion
        
        Task.detached(priority: .userInitiated) {
            let isMatch: (ClipboardItem) -> Bool = { item in
                // App filter
                let matchesApp: Bool
                if currentApp == "auto_filter_mode" {
                    if let frontmostID = frontmostID {
                        if let path = item.sourceAppPath, let itemBundle = Bundle(path: path) {
                            matchesApp = itemBundle.bundleIdentifier == frontmostID
                        } else {
                            matchesApp = false
                        }
                    } else {
                        matchesApp = false
                    }
                } else if currentApp == nil {
                    matchesApp = true
                } else {
                    matchesApp = item.sourceAppPath == currentApp
                }
                
                // Search text filter
                let matchesSearchText = currentSearchText.isEmpty || item.text.localizedCaseInsensitiveContains(currentSearchText)
                
                // Item type filter
                let matchesFilter: Bool
                switch currentFilter {
                case .all:
                    matchesFilter = true
                case .textAll:
                    matchesFilter = item.filePath == nil
                case .textRich:
                    matchesFilter = item.filePath == nil && item.richText != nil
                case .textPlain:
                    matchesFilter = item.filePath == nil && item.richText == nil
                case .linkOnly:
                    matchesFilter = item.isURL
                case .fileOnly:
                    matchesFilter = item.filePath != nil
                case .folderOnly:
                    matchesFilter = item.filePath != nil && item.isFolder
                case .imageOnly:
                    matchesFilter = item.isImage
                case .videoOnly:
                    matchesFilter = item.isVideo
                case .otherFiles:
                    matchesFilter = item.filePath != nil && !item.isImage && !item.isVideo && !item.isPDF && !item.isFolder
                case .pdfOnly:
                    matchesFilter = item.isPDF
                case .colorCodeOnly:
                    matchesFilter = item.filePath == nil && ColorCodeParser.parseColor(from: item.text) != nil
                }
                
                return matchesApp && matchesSearchText && matchesFilter
            }
            
            let finalHistoryToApply: [ClipboardItem]
            
            // 全件フィルタリング後にソートを実行する元の実装に戻す（配列内の順序が保証されていないため）
            let filtered = historyCopy.filter(isMatch)
            let sorted = filtered.sorted { item1, item2 in
                switch currentSort {
                case .newest:
                    return item1.date > item2.date
                case .oldest:
                    return item1.date < item2.date
                case .largestFileSize:
                    return (item1.fileSize ?? 0) > (item2.fileSize ?? 0)
                case .smallestFileSize:
                    return (item1.fileSize ?? 0) < (item2.fileSize ?? 0)
                }
            }
            
            var finalHistory = Array(sorted.prefix(currentDisplayLimit))
            if let pinnedID = currentPinnedID,
               let pinnedItem = sorted.first(where: { $0.id == pinnedID }) {
                finalHistory.insert(pinnedItem.createPinnedDuplicate(), at: 0) // 先頭に追加
            }
            finalHistoryToApply = finalHistory
            
            await MainActor.run {
                if isReduceMotion {
                    self.filteredHistory = finalHistoryToApply
                } else {
                    withAnimation {
                        self.filteredHistory = finalHistoryToApply
                    }
                }
                self.clipboardManager.filteredHistoryForShortcuts = finalHistoryToApply
                
                if self.selectedItemID == nil || !finalHistoryToApply.contains(where: { $0.id == self.selectedItemID }) {
                    self.selectedItemID = finalHistoryToApply.first?.id
                }
                
                // 明示的にリストへフォーカスを移す（検索中でない場合）
                if !self.isSearchFieldFocused {
                    self.isListFocused = true
                }
                
                self.isLoading = false
                self.isPaginating = false
                
                if !isPagination && !isBackground {
                    self.searchTrigger = UUID()
                }
            }
        }
    }
    
    private func handleSearchSubmit() {
        isListFocused = true
    }
    
    var body: some View {
        ZStack {
            SharedWindowBackground()
            
            ZStack {
                VStack(spacing: 0) {
                    HistorySearchBar(
                        searchText: $searchText,
                        isLoading: $isLoading,
                        isSearchFieldFocused: _isSearchFieldFocused,
                        clipboardHistoryCount: clipboardManager.clipboardHistory.count,
                        selectedFilter: $clipboardManager.historySelectedFilter,
                        selectedSort: $clipboardManager.historySelectedSort,
                        selectedApp: $clipboardManager.historySelectedApp
                    )
                    .onSubmit(of: .text) {
                        handleSearchSubmit()
                    }
                    
                    Spacer(minLength: 0)
                    
                    HistoryContentList(
                        filteredHistory: $filteredHistory,
                        isLoading: $isLoading,
                        isPaginating: $isPaginating,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        itemToDelete: $itemToDelete,
                        deleteOnlyThisItem: $deleteOnlyThisItem,
                        selectedItemID: $selectedItemID,
                        showCopyConfirmation: $showCopyConfirmation,
                        currentCopyConfirmationTask: $currentCopyConfirmationTask,
                        selectedItemForQRCode: $selectedItemForQRCode,
                        itemForNewPhrase: $itemForNewPhrase,
                        isChildSheetPresented: $isChildSheetPresented,
                        hideNumbersInHistoryWindow: hideNumbersInHistoryWindow,
                        closeWindowOnDoubleClickInHistoryWindow: closeWindowOnDoubleClickInHistoryWindow,
                        scrollToTopOnUpdate: scrollToTopOnUpdate,
                        showCharacterCount: showCharacterCount,
                        lineNumberTextWidth: lineNumberTextWidth,
                        trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                        searchText: searchText,
                        searchTrigger: searchTrigger,
                        onCopyAction: { item in
                            if item.isCopying { return }
                            // 内部コピーフラグをtrueに設定
                            clipboardManager.isPerformingInternalCopy = true
                            ClipboardManager.shared.copyItemToClipboard(item)
                        },
                        onLoadMore: {
                            if displayLimit < clipboardManager.clipboardHistory.count {
                                displayLimit += 100
                                performUpdate(isPagination: true)
                            }
                        }
                    )
                    .focused($isListFocused)
                    .defaultFocus($isListFocused, true)
                }
            }
            
            // コピー完了アニメーション
            SharedCopyConfirmationView(showCopyConfirmation: showCopyConfirmation)
                .onDisappear {
                    currentCopyConfirmationTask?.cancel()
                }
        }
        .onKeyPress { press in
            // シートが開かれている（または開こうとしている）間は検索欄への入力を無視する
            if isChildSheetPresented || showingDeleteConfirmation || selectedItemForQRCode != nil || itemToDelete != nil || itemForNewPhrase != nil {
                #if DEBUG
                print("Keyboard blocked by state flag in History. child:\(isChildSheetPresented), delConf:\(showingDeleteConfirmation), qr:\(selectedItemForQRCode != nil), itemDel:\(itemToDelete != nil), newPhrase:\(itemForNewPhrase != nil)")
                #endif
                return .ignored
            }
            if let window = NSApp.keyWindow, window.attachedSheet != nil {
                #if DEBUG
                print("Keyboard blocked by attachedSheet in History.")
                #endif
                return .ignored
            }
            
            guard press.modifiers.isEmpty || press.modifiers == .shift else { return .ignored }
            
            // バックスペースキーの処理
            if press.key == .delete || press.key == .deleteForward || press.characters == "\u{7F}" || press.characters == "\u{08}" {
                if !isSearchFieldFocused {
                    if !searchText.isEmpty {
                        searchText.removeLast()
                        isSearchFieldFocused = true
                        
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            if let window = NSApp.keyWindow,
                               let textView = window.firstResponder as? NSTextView {
                                let length = textView.string.count
                                textView.setSelectedRange(NSRange(location: length, length: 0))
                            }
                        }
                        return .handled
                    }
                }
                return .ignored
            }
            
            if press.key == .escape {
                if !searchText.isEmpty {
                    searchText = ""
                    return .handled
                } else {
                    return .ignored
                }
            }
            
            let ignoredKeys: Set<KeyEquivalent> = [.return, .tab, .space, .upArrow, .downArrow, .leftArrow, .rightArrow, .home, .end, .pageUp, .pageDown, .clear]
            if ignoredKeys.contains(press.key) {
                return .ignored
            }
            guard let char = press.characters.first, !press.characters.isEmpty else { return .ignored }
            
            // 制御文字の入力を無視
            if let scalar = char.unicodeScalars.first, CharacterSet.controlCharacters.contains(scalar) {
                return .ignored
            }
            
            if !isSearchFieldFocused {
                searchText.append(char)
                isSearchFieldFocused = true
                
                // 検索欄にフォーカスが移った後、文字が全選択されるのを防ぐためカーソルを末尾に移動させる
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    if let window = NSApp.keyWindow,
                       let textView = window.firstResponder as? NSTextView {
                        let length = textView.string.count
                        textView.setSelectedRange(NSRange(location: length, length: 0))
                    }
                }
                
                return .handled
            }
            return .ignored
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            // ウィンドウが閉じられたときに表示上限をリセットしてメモリを解放
            // 右クリックメニューなどが閉じられた時にも発火してしまうため、識別子を確認する
            if let window = notification.object as? NSWindow, window.identifier?.rawValue == "HistoryWindow" {
                displayLimit = 100
                performUpdate(isBackground: true)
            }
        }
        .frame(minWidth: 300, idealWidth: 375, maxWidth: 900, minHeight: 300, idealHeight: 400, maxHeight: .infinity)
        .onChange(of: searchText) { _, _ in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                performUpdate()
            }
        }
        .onChange(of: clipboardManager.historySelectedFilter) { _, _ in performUpdate() }
        .onChange(of: clipboardManager.historySelectedSort) { _, _ in performUpdate() }
        .onChange(of: clipboardManager.historySelectedApp) { _, _ in performUpdate() }
        .onChange(of: clipboardManager.pinnedItemID) { _, _ in performUpdate(isBackground: true) }
        .onChange(of: frontmostAppMonitor.frontmostAppBundleIdentifier) { _, _ in
            if clipboardManager.historySelectedApp == "auto_filter_mode" {
                performUpdate()
            }
        }
        .onChange(of: clipboardManager.clipboardHistory) { _, _ in performUpdate(isBackground: true) }
        .onAppear {
            clipboardManager.filteredHistoryForShortcuts = []
            
            if clipboardManager.isHistoryLoaded {
                performUpdate()
            } else {
                isLoading = true
            }
            
            // ウインドウ表示時は必ずリストにフォーカスを当てる
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                isListFocused = true
            }
        }
        .onChange(of: clipboardManager.isHistoryLoaded) { _, loaded in
            if loaded {
                performUpdate()
            }
        }
        .onDisappear {
            clipboardManager.filteredHistoryForShortcuts = nil
            
            // コピー確認のタスクをキャンセル
            currentCopyConfirmationTask?.cancel()
            
            // ウインドウが閉じる際に実行中のタスクをキャンセルしてメモリを解放
            searchDebounceTask?.cancel()
            searchDebounceTask = nil // タスクの参照をnilに設定
            
            historyUpdateTask?.cancel()
            historyUpdateTask = nil // タスクの参照をnilに設定
        }
        .alert("履歴の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let item = itemToDelete {
                    clipboardManager.deleteItem(id: item.id, deleteOnlyThisItem: deleteOnlyThisItem)
#if DEBUG
                    print("DEBUG: Item deleted.")
#endif
                    itemToDelete = nil
                    selectedItemID = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete, let filePath = item.filePath {
                // ファイルパスがある場合
                if deleteOnlyThisItem {
                    let hasOtherItems = clipboardManager.clipboardHistory.contains(where: { $0.filePath == filePath && $0.id != item.id })
                    if hasOtherItems {
                        Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？履歴からファイルは削除されず、このファイルに関連する他の履歴は影響を受けません。")
                    } else {
                        Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？他に関連する履歴がないため、履歴からこのファイルが削除されます。")
                    }
                } else {
                    Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？履歴からファイルが削除され、このファイルに関連する他の履歴も削除されます。")
                }
            } else {
                // ファイルパスがない場合（テキストなど）
                Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？")
            }
        }
        .sheet(item: $selectedItemForQRCode) { item in
            QRCodeView(text: item.text)
        }
        .sheet(item: $itemForNewPhrase) { item in
            AddEditPhraseView(mode: .add, initialContent: item.text, presetManager: presetManager, isSheet: true)
                .environmentObject(standardPhraseManager)
                .environmentObject(presetManager)
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(StandardPhrasePresetManager.shared)
        .environmentObject(DateReloader.shared)
}

