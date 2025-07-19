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

    @State private var quickLookManager = QuickLookManager()

    let showLineNumbersInHistoryWindow: Bool
    let preventWindowCloseOnDoubleClick: Bool
    let scrollToTopOnUpdate: Bool
    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat
    let searchText: String // searchTextを追加

    var onCopyAction: (ClipboardItem) -> Void // ClipboardItemを受け取り、何も返さないクロージャ


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
        ZStack { // Tableまたはメッセージが表示されるZStack
            if filteredHistory.isEmpty && !isLoading {
                VStack { // VStackで囲み、Spacerで中央に配置
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
                                quickLookManager: quickLookManager,
                                lineNumberTextWidth: lineNumberTextWidth,
                                trailingPaddingForLineNumber: trailingPaddingForLineNumber
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
                        
                        // このビューに関連付けられたNSViewを一時的に取得
                        if let window = NSApp.keyWindow, let contentView = window.contentView {
                            quickLookManager.showQuickLook(for: filePath, sourceView: contentView)
                        }
                        
                        return .handled
                    }
                    .onChange(of: selectedItemID) { oldID, newID in
                        // 新しい項目が選択されていない場合は何もしない
                        guard let newID = newID else {
                            // 選択が解除された場合、Quick Lookパネルを閉じる
                            quickLookManager.hideQuickLook()
                            return
                        }
                        
                        // 選択された新しい項目を取得
                        guard let selectedItem = filteredHistory.first(where: { $0.id == newID }) else {
                            return
                        }

                        // Quick Lookパネルが表示されているか確認
                        guard QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible else {
                            return
                        }

                        // 選択された項目にファイルパスがあるか確認
                        if let filePath = selectedItem.filePath {
                            // ファイルが選択された場合、パネルの内容を更新
                            quickLookManager.quickLookURL = filePath
                            QLPreviewPanel.shared().reloadData()
                        } else {
                            // プレーンテキストが選択された場合、パネルを閉じる
                            quickLookManager.hideQuickLook()
                        }
                    }
                    .accessibilityLabel("履歴リスト")
                    .scrollContentBackground(.hidden)
                    .blur(radius: isLoading ? 5 : 0)
                    .animation(.easeOut(duration: 0.1), value: isLoading)
                    .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIDs in
                        if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                            Button("コピー") {
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
                            }
                            if currentItem.isURL, let url = URL(string: currentItem.text) {
                                Button("リンクを開く...") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            if let qrContent = currentItem.qrCodeContent {
                                Button("QRコードの内容をコピー") {
                                    let newItemToCopy = ClipboardItem(text: qrContent) // 新しいClipboardItemを作成
                                    // 内部コピーフラグをtrueに設定
                                    clipboardManager.isPerformingInternalCopy = true
                                    onCopyAction(newItemToCopy) // onCopyActionを呼び出す
                                    showCopyConfirmation = true
                                    currentCopyConfirmationTask?.cancel()
                                    currentCopyConfirmationTask = Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                        guard !Task.isCancelled else { return }
                                        withAnimation {
                                            showCopyConfirmation = false
                                        }
                                    }
                                }
                            }
                            Divider()
                            if let filePath = currentItem.filePath {
                                Button("クイックルック") {
                                    if let sourceView = NSApp.keyWindow?.contentView {
                                        quickLookManager.showQuickLook(for: filePath, sourceView: sourceView)
                                    }
                                }
                            }
                            Button("項目から定型文を作成...") {
                                itemForNewPhrase = currentItem // ここでClipboardItemをセット
                            }
                            if currentItem.filePath == nil {
                                Button("QRコードを表示...") {
                                    showQRCodeSheet = true
                                    selectedItemForQRCode = currentItem
                                }
                            }
                            Divider()
                            Button("削除...", role: .destructive) {
                                itemToDelete = currentItem
                                showingDeleteConfirmation = true
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

                        // clipboardManager を定数にキャプチャ
                        let manager = clipboardManager // ここでキャプチャします

                        itemProvider.loadObject(ofClass: NSImage.self) { (image, error) in
                            DispatchQueue.main.async {
                                if let nsImage = image as? NSImage {
                                    if let qrCodeContent = manager.decodeQRCode(from: nsImage) {
                                        manager.addTextItem(text: qrCodeContent)
                                        let newItemToCopy = ClipboardItem(text: qrCodeContent) // 新しいClipboardItemを作成
                                        // 内部コピーフラグをtrueに設定
                                        manager.isPerformingInternalCopy = true
                                        onCopyAction(newItemToCopy) // onCopyActionを呼び出す
                                        
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
