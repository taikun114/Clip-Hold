import SwiftUI
import AppKit
import Quartz

struct HistoryContentList: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @Environment(\.dismiss) var dismiss

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
    @Binding var previousClipboardHistoryCount: Int

    // 各行のアイコンのNSView参照を保存するためのState
    @State private var rowIconViews: [UUID: NSView] = [:]

    let showLineNumbersInHistoryWindow: Bool
    let preventWindowCloseOnDoubleClick: Bool
    let scrollToTopOnUpdate: Bool
    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat
    let searchText: String

    var onCopyAction: (ClipboardItem) -> Void


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

    var body: some View {
        ZStack {
            if filteredHistory.isEmpty && !isLoading {
                VStack {
                    Spacer()
                    Text("履歴はありません")
                        .foregroundColor(.secondary)
                        .font(.title2)
                        .padding(.bottom, 20)
                    Spacer()
                }
            } else {
                ScrollViewReader { scrollViewProxy in
                    Table(filteredHistory, selection: $selectedItemID) {
                        TableColumn("") { item in
                            HistoryItemRow(
                                item: item,
                                index: filteredHistory.firstIndex(where: { $0.id == item.id }) ?? 0,
                                showLineNumber: showLineNumbersInHistoryWindow,
                                itemToDelete: $itemToDelete,
                                showingDeleteConfirmation: $showingDeleteConfirmation,
                                selectedItemID: $selectedItemID,
                                dismissAction: { dismiss() },
                                showCopyConfirmation: $showCopyConfirmation,
                                showQRCodeSheet: $showQRCodeSheet,
                                selectedItemForQRCode: $selectedItemForQRCode,
                                itemForNewPhrase: $itemForNewPhrase,
                                lineNumberTextWidth: lineNumberTextWidth,
                                trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                                rowIconViews: $rowIconViews // アイコンビュー辞書へのBindingを渡す
                            )
                            .tag(item.id)
                        }
                    }
                    .tableColumnHeaders(.hidden)
                    .tableStyle(.inset)
                    .alternatingRowBackgrounds(.disabled)
                    .animation(.default, value: filteredHistory)
                    .onKeyPress(.space) {
                        guard let selectedID = selectedItemID,
                              let selectedItem = filteredHistory.first(where: { $0.id == selectedID }),
                              let filePath = selectedItem.filePath else {
                            // ファイルが選択されていないか、ファイルパスがない場合は何もしない
                            return .ignored
                        }
                        
                        // 保存しておいたアイコンのビューをアニメーションの開始点として指定する
                        if let controller = NSApp.keyWindow?.windowController as? ClipHoldWindowController,
                           let sourceView = rowIconViews[selectedID] {
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
                           let sourceView = rowIconViews[newID] {
                            controller.showQuickLook(for: filePath as QLPreviewItem, from: sourceView)
                        } else {
                            controller.hideQuickLook()
                        }
                    }
                    .accessibilityLabel("履歴リスト")
                    .scrollContentBackground(.hidden)
                    .blur(radius: isLoading ? 5 : 0)
                    .animation(.easeOut(duration: 0.1), value: isLoading)
                    .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIDs in
                        if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                            Button {
                                // 内部コピーフラグをtrueに設定
                                clipboardManager.isPerformingInternalCopy = true
                                onCopyAction(currentItem)
                                showCopyConfirmation = true
                                currentCopyConfirmationTask?.cancel()
                                currentCopyConfirmationTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                    guard !Task.isCancelled else { return }
                                    withAnimation {
                                        showCopyConfirmation = false
                                    }
                                }
                            } label: {
                                Label("コピー", systemImage: "document.on.document")
                            }
                            if currentItem.isURL, let url = URL(string: currentItem.text) {
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Label("リンクを開く...", systemImage: "paperclip")
                                }
                            }
                            if let qrContent = currentItem.qrCodeContent {
                                Button {
                                    let newItemToCopy = ClipboardItem(text: qrContent) // 新しいClipboardItemを作成
                                    // 内部コピーフラグをtrueに設定
                                    clipboardManager.isPerformingInternalCopy = true
                                    onCopyAction(newItemToCopy)
                                    showCopyConfirmation = true
                                    currentCopyConfirmationTask?.cancel()
                                    currentCopyConfirmationTask = Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                        guard !Task.isCancelled else { return }
                                        withAnimation {
                                            showCopyConfirmation = false
                                        }
                                    }
                                } label: {
                                    Label("QRコードの内容をコピー", systemImage: "qrcode.viewfinder")
                                }
                            }
                            Divider()
                            if let filePath = currentItem.filePath {
                                Button {
                                    // コンテキストメニューからも正しいアイコンビューを指定する
                                    if let controller = NSApp.keyWindow?.windowController as? ClipHoldWindowController,
                                       let sourceView = rowIconViews[id] {
                                        controller.showQuickLook(for: filePath as QLPreviewItem, from: sourceView)
                                    }
                                } label: {
                                    Label("クイックルック", systemImage: "eye")
                                }
                            }
                            Button {
                                itemForNewPhrase = currentItem
                            } label: {
                                Label("項目から定型文を作成...", systemImage: "pencil")
                            }
                            if currentItem.filePath == nil {
                                Button {
                                    showQRCodeSheet = true
                                    selectedItemForQRCode = currentItem
                                } label: {
                                    Label("QRコードを表示...", systemImage: "qrcode")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                itemToDelete = currentItem
                                showingDeleteConfirmation = true
                            } label: {
                                Label("削除...", systemImage: "trash")
                            }
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
                                withAnimation {
                                    showCopyConfirmation = false
                                }
                            }
                            if !preventWindowCloseOnDoubleClick {
                                dismiss()
                            }
                        }
                    })
                    .onDrop(of: [.image], isTargeted: nil) { providers in
                        guard let itemProvider = providers.first else { return false }
                        let manager = clipboardManager
                        itemProvider.loadObject(ofClass: NSImage.self) { (image, error) in
                            DispatchQueue.main.async {
                                if let nsImage = image as? NSImage {
                                    if let qrCodeContent = manager.decodeQRCode(from: nsImage) {
                                        manager.addTextItem(text: qrCodeContent)
                                        let newItemToCopy = ClipboardItem(text: qrCodeContent) // 新しいClipboardItemを作成
                                        // 内部コピーフラグをtrueに設定
                                        manager.isPerformingInternalCopy = true
                                        onCopyAction(newItemToCopy)
                                        
                                        showCopyConfirmation = true
                                    } else {
                                        print("QRコードが見つかりませんでした。")
                                    }
                                } else if let error = error {
                                    print("画像のロードに失敗しました: \(error.localizedDescription)")
                                }
                            }
                        }
                        return true
                    }
                    .onChange(of: filteredHistory) { _, newValue in
                        // filteredHistory が更新され、かつscrollToTopOnUpdateがtrue、かつ検索中でない場合
                        // さらに、元の履歴の数が変わった場合のみに限定する
                        if scrollToTopOnUpdate && searchText.isEmpty && !newValue.isEmpty && newValue.count > previousClipboardHistoryCount {
                            if let firstId = newValue.first?.id {
                                withAnimation {
                                    scrollViewProxy.scrollTo(firstId, anchor: .top)
                                }
                            }
                        }
                        previousClipboardHistoryCount = newValue.count // 現在の履歴数を保存
                    }
                } // ScrollViewReaderの終わり
            }
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
            }
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
