import SwiftUI
import AppKit
import Quartz

struct HistoryContentList: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    @Binding var filteredHistory: [ClipboardItem]
    @Binding var isLoading: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var itemToDelete: ClipboardItem?
    @Binding var selectedItemID: UUID?
    @Binding var showCopyConfirmation: Bool
    @Binding var currentCopyConfirmationTask: Task<Void, Never>?
    @Binding var showQRCodeSheet: Bool
    @Binding var selectedItemForQRCode: ClipboardItem?
    @Binding var itemForNewPhrase: ClipboardItem?
    
    @State private var previousNewestItemID: UUID?
    @State private var previousPinnedItemID: UUID?
    
    // State variables for the exclude app alert
    @State private var showingExcludeAppAlert = false
    @State private var appToExclude: String?
    
    // State variables for the delete all history from app alert
    @State private var showingDeleteAllFromAppAlert = false
    @State private var appToDeleteFrom: String?
    
    // 各行のアイコンのNSView参照を保存するためのState
    @State private var rowIconStore = RowIconStore()
    
    // State variable for the edit sheet
    @State private var showingEditSheet = false
    @State private var itemToEdit: ClipboardItem?
    
    // ピン留め置き換えアラート用State
    @State private var itemToReplacePin: ClipboardItem? = nil
    @State private var showingReplacePinConfirmation = false
    
    private var pinnedItemToShow: ClipboardItem? {
        guard let pinnedItem = clipboardManager.pinnedItem else { return nil }
        if searchText.isEmpty {
            return pinnedItem
        } else {
            return pinnedItem.text.localizedCaseInsensitiveContains(searchText) ? pinnedItem : nil
        }
    }
    
    private var unpinnedFilteredHistory: [ClipboardItem] {
        if let pinnedID = clipboardManager.pinnedItemID {
            return filteredHistory.filter { $0.id != pinnedID }
        }
        return filteredHistory
    }
    
    let hideNumbersInHistoryWindow: Bool
    let closeWindowOnDoubleClickInHistoryWindow: Bool
    let scrollToTopOnUpdate: Bool
    let showCharacterCount: Bool
    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat
    let searchText: String
    @EnvironmentObject var dateReloader: DateReloader
    @AppStorage("dateDisplayFormatInHistoryWindow") var dateDisplayFormatInHistoryWindow: String = "absolute"

    
    var onCopyAction: (ClipboardItem) -> Void
    var onLoadMore: () -> Void
    
    
    private func parseQRCode(from image: NSImage) -> String? {
        guard let ciImage = CIImage(data: image.tiffRepresentation ?? Data()) else { return nil }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage)
        
        for feature in features ?? [] {
            if let qrCodeFeature = feature as? CIQRCodeFeature {
                return qrCodeFeature.messageString
            }
        }
        return nil
    }
    
    @ViewBuilder
    private func historyMenuItems(for currentItem: ClipboardItem) -> some View {
        SharedCopyMenuItem {
            clipboardManager.isPerformingInternalCopy = true
            onCopyAction(currentItem)
            showCopyConfirmation = true
            currentCopyConfirmationTask?.cancel()
            currentCopyConfirmationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                showCopyConfirmation = false
            }
        }
        
        if currentItem.richText != nil {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(currentItem.text, forType: .string)
                showCopyConfirmation = true
                currentCopyConfirmationTask?.cancel()
                currentCopyConfirmationTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    showCopyConfirmation = false
                }
            } label: {
                Text("標準テキストとしてコピー")
            }
        }
        
        SharedEditAndCopyMenuItem {
            itemToEdit = currentItem
            showingEditSheet = true
        }
        
        if let qrContent = currentItem.qrCodeContent {
            Button {
                let newItemToCopy = ClipboardItem(text: qrContent)
                clipboardManager.isPerformingInternalCopy = true
                onCopyAction(newItemToCopy)
                showCopyConfirmation = true
                currentCopyConfirmationTask?.cancel()
                currentCopyConfirmationTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    showCopyConfirmation = false
                }
            } label: {
                Label("QRコードの内容をコピー", systemImage: "qrcode.viewfinder")
            }
        }
        
        if let filePath = currentItem.filePath {
            Button {
                NSWorkspace.shared.open(filePath)
            } label: {
                Label("開く", systemImage: "arrow.up.forward.app")
            }
        }
        
        if currentItem.isURL {
            SharedOpenLinkMenuItem(urlString: currentItem.text)
        }
        
        Divider()
        
        if let filePath = currentItem.filePath {
            Button {
                if let controller = NSApp.keyWindow?.windowController as? ClipHoldWindowController,
                   let sourceView = rowIconStore.views[currentItem.id] {
                    controller.showQuickLook(for: filePath as QLPreviewItem, from: sourceView)
                }
            } label: {
                Label("クイックルック", systemImage: "eye")
            }
        }
        
        let targetID = currentItem.originalPinnedItemID ?? currentItem.id
        if clipboardManager.pinnedItemID == targetID {
            Button {
                clipboardManager.unpinItem()
            } label: {
                Label("ピン留めを解除", systemImage: "pin.slash").forceIconOnMacOS27()
            }
        } else {
            Button {
                if clipboardManager.pinnedItemID != nil {
                    itemToReplacePin = currentItem
                    showingReplacePinConfirmation = true
                } else {
                    if let originalItem = clipboardManager.clipboardHistory.first(where: { $0.id == targetID }) {
                        clipboardManager.pinItem(originalItem)
                    } else {
                        clipboardManager.pinItem(currentItem)
                    }
                }
            } label: {
                Label("ピン留め", systemImage: "pin").forceIconOnMacOS27()
            }
        }
        
        Button {
            itemForNewPhrase = currentItem
        } label: {
            Label("項目から定型文を作成...", systemImage: "pencil")
        }
        
        if currentItem.filePath == nil {
            SharedShowQRCodeMenuItem {
                showQRCodeSheet = true
                selectedItemForQRCode = currentItem
            }
        }
        
        Divider()
        
        if let sourceAppPath = currentItem.sourceAppPath {
            Button {
                appToExclude = sourceAppPath
                showingExcludeAppAlert = true
            } label: {
                Label("除外するアプリに追加...", systemImage: "hand.raised.circle")
            }
        }
        
        SharedDeleteMenuItem {
            itemToDelete = currentItem
            showingDeleteConfirmation = true
        }
        
        if let sourceAppPath = currentItem.sourceAppPath {
            Button(role: .destructive) {
                showingDeleteAllFromAppAlert = true
                appToDeleteFrom = sourceAppPath
            } label: {
                Text("このアプリからのすべての履歴を削除...")
            }
        }
    }
    
    var body: some View {
        ZStack {
            if filteredHistory.isEmpty && !isLoading {
                SharedEmptyListView(message: "履歴はありません")
            } else {
                ScrollViewReader { scrollViewProxy in
                    Table(filteredHistory, selection: $selectedItemID) {
                        TableColumn("") { item in
                            HistoryItemRow(
                                item: item,
                                index: filteredHistory.firstIndex(where: { $0.id == item.id }) ?? 0,
                                hideNumbers: hideNumbersInHistoryWindow,
                                rowIconStore: rowIconStore,
                                showCharacterCount: showCharacterCount,
                                lineNumberTextWidth: lineNumberTextWidth,
                                trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                                menuItems: {
                                    historyMenuItems(for: item)
                                }
                            )
                            .onAppear {
                                if let index = filteredHistory.firstIndex(where: { $0.id == item.id }), index == filteredHistory.count - 1 {
                                    onLoadMore()
                                }
                            }
                            .environmentObject(clipboardManager)
                            .environmentObject(standardPhraseManager)
                            .environmentObject(presetManager)
                            .environmentObject(dateReloader)
                            .tag(item.id)
                        }
                    }
                    .tableColumnHeaders(.hidden)
                    .tableStyle(.inset)
                    .alternatingRowBackgrounds(.disabled)
                    .animation(reduceMotion ? nil : .default, value: filteredHistory)
                    .onKeyPress(.space) {
                        guard let selectedID = selectedItemID,
                              let selectedItem = filteredHistory.first(where: { $0.id == selectedID }),
                              let filePath = selectedItem.filePath else {
                            // ファイルが選択されていないか、ファイルパスがない場合は何もしない
                            return .ignored
                        }
                        
                        // 保存しておいたアイコンのビューをアニメーションの開始点として指定する
                        if let controller = NSApp.keyWindow?.windowController as? ClipHoldWindowController,
                           let sourceView = rowIconStore.views[selectedID] {
                            controller.showQuickLook(for: filePath as QLPreviewItem, from: sourceView)
                        }
                        
                        return .handled
                    }
                    .onChange(of: selectedItemID) { oldID, newID in
                        guard let controller = NSApp.keyWindow?.windowController as? ClipHoldWindowController else { return }
                        
                        guard let newID = newID else {
                            controller.hideQuickLook()
                            return
                        }
                        
                        guard let selectedItem = filteredHistory.first(where: { $0.id == newID }) else {
                            return
                        }
                        
                        guard QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible else {
                            return
                        }
                        
                        // 選択が変更された場合も、正しいアイコンビューから再表示する
                        if let filePath = selectedItem.filePath,
                           let sourceView = rowIconStore.views[newID] {
                            controller.showQuickLook(for: filePath as QLPreviewItem, from: sourceView)
                        } else {
                            controller.hideQuickLook()
                        }
                    }
                    .accessibilityLabel("履歴リスト")
                    .scrollContentBackground(.hidden)
                    .if(!reduceMotion) { view in
                        view.blur(radius: isLoading ? 5 : 0)
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isLoading)
                    .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIDs in
                        if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                            historyMenuItems(for: currentItem)
                        }
                    }, primaryAction: { selectedIDs in
                        if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                            // 内部コピーフラグをtrueに設定
                            clipboardManager.isPerformingInternalCopy = true
                            onCopyAction(currentItem)
                            showCopyConfirmation = true
                            currentCopyConfirmationTask?.cancel()
                            currentCopyConfirmationTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                guard !Task.isCancelled else { return }
                                showCopyConfirmation = false
                            }
                            if closeWindowOnDoubleClickInHistoryWindow {
                                dismiss()
                            }
                        }
                    })
                    .sheet(item: $itemToEdit) { item in
                        EditHistoryItemView(content: item.text, onCopy: { editedContent in
                            // コピー処理を実装
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(editedContent, forType: .string)
                            
                            // コピー確認を表示
                            showCopyConfirmation = true
                            currentCopyConfirmationTask?.cancel()
                            currentCopyConfirmationTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                guard !Task.isCancelled else { return }
                                showCopyConfirmation = false
                            }
                        }, isSheet: true)
                    }
                    .onDrop(of: [.image], isTargeted: nil) { providers in
                        guard let itemProvider = providers.first else { return false }
                        let manager = clipboardManager
                        itemProvider.loadObject(ofClass: NSImage.self) { (image, error) in
                            Task { @MainActor in
                                if let nsImage = image as? NSImage {
                                    if let qrCodeContent = manager.decodeQRCode(from: nsImage) {
                                        manager.addTextItem(text: qrCodeContent)
                                        let newItemToCopy = ClipboardItem(text: qrCodeContent) // 新しいClipboardItemを作成
                                        // 内部コピーフラグをtrueに設定
                                        manager.isPerformingInternalCopy = true
                                        onCopyAction(newItemToCopy)
                                        
                                        showCopyConfirmation = true
                                        currentCopyConfirmationTask?.cancel() // 既存のタスクがあればキャンセル
                                        currentCopyConfirmationTask = Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒後に非表示
                                            guard !Task.isCancelled else { return }
                                            showCopyConfirmation = false
                                        }
                                    } else {
                                        print("QR code not found.")
                                    }
                                } else if let error = error {
                                    print("Failed to load image: \(error.localizedDescription)")
                                }
                            }
                        }
                        return true
                    }
                    .onChange(of: filteredHistory) { _, newValue in
                        // 不要になったrowIconStore.viewsのエントリをクリーンアップする
                        let currentIDs = Set(clipboardManager.clipboardHistory.map { $0.id })
                        let oldIDs = Set(rowIconStore.views.keys)
                        let idsToRemove = oldIDs.subtracting(currentIDs)
                        for id in idsToRemove {
                            rowIconStore.views.removeValue(forKey: id)
                        }
                        
                        // filteredHistory が更新され、かつscrollToTopOnUpdateがtrue、かつ検索中でない場合
                        // さらに、履歴内で一番新しいアイテムのIDが変わった場合（＝新しくコピーされた場合）、
                        // またはピン留めされたアイテムが変わった場合に限定する
                        let newestItem = clipboardManager.clipboardHistory.max { $0.date < $1.date }
                        let pinnedItemChanged = clipboardManager.pinnedItemID != previousPinnedItemID
                        
                        if scrollToTopOnUpdate && searchText.isEmpty && !newValue.isEmpty && (newestItem?.id != previousNewestItemID || pinnedItemChanged) {
                            if let firstId = newValue.first?.id {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    if reduceMotion {
                                        scrollViewProxy.scrollTo(firstId, anchor: .top)
                                    } else {
                                        withAnimation {
                                            scrollViewProxy.scrollTo(firstId, anchor: .top)
                                        }
                                    }
                                }
                            }
                        }
                        previousNewestItemID = newestItem?.id // 現在の最新アイテムのIDを保存
                        previousPinnedItemID = clipboardManager.pinnedItemID // 現在のピン留めアイテムのIDを保存
                    }
                    .alert(String(localized: "除外するアプリに追加"), isPresented: $showingExcludeAppAlert) {
                        Button("キャンセル", role: .cancel) { }
                        Button("追加") {
                            if let appPath = appToExclude {
                                // Get the bundle identifier from the app path
                                let appURL = URL(fileURLWithPath: appPath)
                                if let appBundle = Bundle(url: appURL),
                                   let bundleIdentifier = appBundle.bundleIdentifier {
                                    // Update the excluded app identifiers in ClipboardManager
                                    var currentExcludedIdentifiers = clipboardManager.excludedAppIdentifiers
                                    if !currentExcludedIdentifiers.contains(bundleIdentifier) {
                                        currentExcludedIdentifiers.append(bundleIdentifier)
                                        clipboardManager.updateExcludedAppIdentifiers(currentExcludedIdentifiers)
                                        
                                        // Also update UserDefaults
                                        if let encoded = try? JSONEncoder().encode(currentExcludedIdentifiers) {
                                            UserDefaults.standard.set(encoded, forKey: "excludedAppIdentifiersData")
                                        }
                                    }
                                }
                            }
                        }
                    } message: {
                        if let appPath = appToExclude {
                            let appName = clipboardManager.getLocalizedName(for: appPath) ?? appPath
                            Text("「\(appName)」を除外するアプリに追加しますか？除外するアプリは「プライバシー」設定から変更することができます。")
                        }
                    }
                    .alert("このアプリの履歴を削除", isPresented: $showingDeleteAllFromAppAlert) {
                        Button("削除", role: .destructive) {
                            if let appPath = appToDeleteFrom {
                                clipboardManager.deleteAllHistoryFromApp(sourceAppPath: appPath)
                            }
                        }
                        Button("キャンセル", role: .cancel) { }
                    } message: {
                        if let appPath = appToDeleteFrom {
                            let appName = clipboardManager.getLocalizedName(for: appPath) ?? appPath
                            let count = clipboardManager.countHistoryFromApp(sourceAppPath: appPath)
                            Text("「\(appName)」からのすべての履歴を削除してもよろしいですか？\(count)個の履歴が削除されます。この操作は元に戻せません。")
                        }
                    }
                    .alert("ピン留めを置き換え", isPresented: $showingReplacePinConfirmation) {
                        Button("置き換え", role: .destructive) {
                            if let itemToPin = itemToReplacePin {
                                clipboardManager.pinItem(itemToPin)
                            }
                            itemToReplacePin = nil
                        }
                        Button("キャンセル", role: .cancel) {
                            itemToReplacePin = nil
                        }
                    } message: {
                        Text("この項目をピン留めすると、現在ピン留めされている項目が置き換えられます。よろしいですか？")
                    }
                } // ScrollViewReaderの終わり
            }
            if isLoading {
                SharedLoadingView()
            }
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
