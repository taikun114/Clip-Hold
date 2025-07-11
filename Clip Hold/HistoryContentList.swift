//
//  HistoryContentList.swift
//  Clip Hold
//
//  Created by 今浦大雅 on 2025/07/11.
//


import SwiftUI
import AppKit

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

    let showLineNumbersInHistoryWindow: Bool
    let preventWindowCloseOnDoubleClick: Bool
    let scrollToTopOnUpdate: Bool
    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat
    let searchText: String // searchTextを追加

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

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
        ZStack { // Listまたはメッセージが表示されるZStack
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
                ScrollViewReader { scrollViewProxy in // ここにScrollViewReaderを追加
                    List(filteredHistory, selection: $selectedItemID) { item in
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
                            trailingPaddingForLineNumber: trailingPaddingForLineNumber
                        )
                        .tag(item.id)
                        .listRowBackground(Color.clear)
                    }
                    .accessibilityLabel("履歴リスト")
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .blur(radius: isLoading ? 5 : 0)
                    .animation(.easeOut(duration: 0.2), value: isLoading)
                    .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIDs in
                        if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                            Button("コピー") {
                                copyToClipboard(currentItem.text)
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
                            Button("項目から定型文を作成...") {
                                itemForNewPhrase = currentItem // ここでClipboardItemをセット
                            }
                            Button("QRコードを表示...") {
                                showQRCodeSheet = true
                                selectedItemForQRCode = currentItem
                            }
                            Divider()
                            Button("削除...", role: .destructive) {
                                itemToDelete = currentItem
                                showingDeleteConfirmation = true
                            }
                        }
                    }, primaryAction: { selectedIDs in
                        if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                            copyToClipboard(currentItem.text)
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
                                    if let qrCodeContent = parseQRCode(from: nsImage) {
                                        // 修正後の行: キャプチャしたmanagerを使用
                                        manager.addHistoryItem(text: qrCodeContent)
                                        copyToClipboard(qrCodeContent)
                                    } else {
                                        // QRコードが見つからなかった場合の処理
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
