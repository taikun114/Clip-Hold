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
    @EnvironmentObject var frontmostAppMonitor: FrontmostAppMonitor
    @Environment(\.dismiss) var dismiss

    @State private var searchText: String = ""
    @State private var filteredHistory: [ClipboardItem] = []
    
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: ClipboardItem?
    @State private var selectedItemID: UUID?
    @State private var isLoading: Bool = false
    @State private var showCopyConfirmation: Bool = false
    @State private var currentCopyConfirmationTask: Task<Void, Never>?
    
    @State private var copyConfirmationTask: Task<Void, Never>? = nil
    @State private var historyUpdateTask: Task<Void, Never>? = nil

    @State private var showQRCodeSheet: Bool = false
    @State private var selectedItemForQRCode: ClipboardItem?

    @State private var itemForNewPhrase: ClipboardItem? = nil

    @State private var previousClipboardHistoryCount: Int = 0

    

    @State private var searchDebounceTask: Task<Void, Never>? = nil

    @FocusState private var isSearchFieldFocused: Bool

    @AppStorage("hideNumbersInHistoryWindow") var hideNumbersInHistoryWindow: Bool = false
    @AppStorage("closeWindowOnDoubleClickInHistoryWindow") var closeWindowOnDoubleClickInHistoryWindow: Bool = false
    @AppStorage("scrollToTopOnUpdate") var scrollToTopOnUpdate: Bool = false
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = false

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

    // 検索、フィルタリング、並び替えを統合したタスク実行関数
    private func performUpdate(isIncrementalUpdate: Bool = false) {
        if !isIncrementalUpdate {
            isLoading = true
            self.filteredHistory = []
            clipboardManager.filteredHistoryForShortcuts = []
        }
        
        historyUpdateTask?.cancel()

        historyUpdateTask = Task { @MainActor in
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            let historyCopy = clipboardManager.clipboardHistory
            
            let filtered = historyCopy.filter { item in
                // App filter
                let matchesApp: Bool
                if clipboardManager.historySelectedApp == "auto_filter_mode" {
                    if let frontmostID = frontmostAppMonitor.frontmostAppBundleIdentifier {
                        if let path = item.sourceAppPath, let itemBundle = Bundle(path: path) {
                            matchesApp = itemBundle.bundleIdentifier == frontmostID
                        } else {
                            matchesApp = false
                        }
                    } else {
                        matchesApp = false
                    }
                } else if clipboardManager.historySelectedApp == nil {
                    matchesApp = true
                } else {
                    matchesApp = item.sourceAppPath == clipboardManager.historySelectedApp
                }
                
                // Search text filter
                let matchesSearchText = searchText.isEmpty || item.text.localizedCaseInsensitiveContains(searchText)

                // Item type filter
                let matchesFilter: Bool
                switch clipboardManager.historySelectedFilter {
                case .all:
                    matchesFilter = true
                case .textOnly:
                    matchesFilter = item.filePath == nil
                case .linkOnly:
                    matchesFilter = item.isURL
                case .fileOnly:
                    matchesFilter = item.filePath != nil
                case .imageOnly:
                    matchesFilter = item.isImage
                case .colorCodeOnly:
                    matchesFilter = item.filePath == nil && ColorCodeParser.parseColor(from: item.text) != nil
                }

                return matchesApp && matchesSearchText && matchesFilter
            }

            let sorted = filtered.sorted { item1, item2 in
                switch clipboardManager.historySelectedSort {
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

            self.filteredHistory = sorted
            clipboardManager.filteredHistoryForShortcuts = sorted
            isLoading = false
        }
    }

    var body: some View {
        ZStack {
            HistoryWindowBackground()

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

                    Spacer(minLength: 0)

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
                            hideNumbersInHistoryWindow: hideNumbersInHistoryWindow,
                            closeWindowOnDoubleClickInHistoryWindow: closeWindowOnDoubleClickInHistoryWindow,
                            scrollToTopOnUpdate: scrollToTopOnUpdate,
                            showCharacterCount: showCharacterCount,
                            lineNumberTextWidth: lineNumberTextWidth,
                            trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                            searchText: searchText,
                            onCopyAction: { item in
                                // 内部コピーフラグをtrueに設定
                                clipboardManager.isPerformingInternalCopy = true
                                ClipboardManager.shared.copyItemToClipboard(item)
                            }
                        )
                }
            }
            
            HistoryCopyConfirmation(showCopyConfirmation: $showCopyConfirmation)
                .onAppear {
                    currentCopyConfirmationTask?.cancel()
                }
                .onDisappear {
                    currentCopyConfirmationTask?.cancel()
                }
        }
        .onExitCommand {
            dismiss()
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
        .onChange(of: frontmostAppMonitor.frontmostAppBundleIdentifier) { _, _ in
            if clipboardManager.historySelectedApp == "auto_filter_mode" {
                performUpdate()
            }
        }
        .onChange(of: clipboardManager.clipboardHistory) { _, _ in performUpdate(isIncrementalUpdate: true) }
        .onChange(of: clipboardManager.filteredHistoryForShortcuts) { _, newValue in
            withAnimation {
                filteredHistory = newValue ?? []
            }
        }
        .onAppear {
            clipboardManager.filteredHistoryForShortcuts = []
            performUpdate()
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
        .onDisappear {
            clipboardManager.filteredHistoryForShortcuts = nil
            
            
            
            // ウインドウが閉じる際に実行中のタスクをキャンセルしてメモリを解放
            searchDebounceTask?.cancel()
            searchDebounceTask = nil // タスクの参照をnilに設定
            
            historyUpdateTask?.cancel()
            historyUpdateTask = nil // タスクの参照をnilに設定
        }
        .alert("履歴の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let item = itemToDelete {
                    clipboardManager.deleteItem(id: item.id)
                    print("DEBUG: Item deleted.")
                    itemToDelete = nil
                    selectedItemID = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete, item.filePath != nil {
                // ファイルパスがある場合
                Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？履歴からファイルが削除され、このファイルに関連する他の履歴も削除されます。")
            } else {
                // ファイルパスがない場合（テキストなど）
                Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？")
            }
        }
        .sheet(isPresented: $showQRCodeSheet) {
            if let item = selectedItemForQRCode {
                QRCodeView(text: item.text)
            }
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
}