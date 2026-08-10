import Foundation
import AppKit // NSAlert
import SwiftUI // NSLocalizedString

extension ClipboardManager {
    // MARK: - Large File Alert Handling
    // Method to directly display NSAlert
    func presentLargeFileConfirmationAlert() { // private から internal に変更
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // 保留中のファイルが何もない場合はアラートを出さない
            guard !self.pendingLargeFileItemsWithSize.isEmpty || self.pendingLargeImageData != nil else { return }
            
            // 新しいプロパティがセットされている場合はそれを優先
            let isMultipleFilesWithSize = self.pendingLargeFileItemsWithSize.count > 1
            // let isSingleFileWithSize = self.pendingLargeFileItemsWithSize.count == 1
            
            let alertTitle: String
            if isMultipleFilesWithSize {
                alertTitle = NSLocalizedString("大容量ファイルの複数コピー", comment: "")
            } else {
                // 単一ファイルまたは古いプロパティを使用する場合
                alertTitle = NSLocalizedString("大容量ファイルのコピー", comment: "")
            }
            
            var informativeText: String
            
            // Format the largeFileAlertThreshold for display
            let formattedThreshold = ByteCountFormatter.string(fromByteCount: Int64(self.largeFileAlertThreshold), countStyle: .file)
            
            // 新しいプロパティ (pendingLargeFileItemsWithSize) を使用
            if !self.pendingLargeFileItemsWithSize.isEmpty {
                let pendingItemsWithSize = self.pendingLargeFileItemsWithSize
                if pendingItemsWithSize.count > 1 {
                    // 複数ファイル用のメッセージ (新しいプロパティを使用)
                    var totalFileSize: UInt64 = 0
                    for item in pendingItemsWithSize {
                        totalFileSize += item.fileSize ?? 0
                    }
                    let formattedTotalSize = ByteCountFormatter.string(fromByteCount: Int64(totalFileSize), countStyle: .file)
                    let fileCount = pendingItemsWithSize.count
                    informativeText = String(format: NSLocalizedString("%1$@を超える%2$d個のファイル（合計%3$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, fileCount, formattedTotalSize)
                } else if let firstItem = pendingItemsWithSize.first, let fileSize = firstItem.fileSize {
                    // 単一ファイル用のメッセージ (新しいプロパティを使用)
                    let actualFileSizeString = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                    informativeText = String(format: NSLocalizedString("%1$@を超えるファイル（%2$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, actualFileSizeString)
                } else {
                    // ファイルサイズが取得できない場合のフォールバック (新しいプロパティを使用)
                    informativeText = String(format: NSLocalizedString("%@を超えるファイルがコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold)
                }
            } else if let pendingImageData = self.pendingLargeImageData {
                // 画像データ用のメッセージ（既存のロジック）
                let actualFileSizeString = ByteCountFormatter.string(fromByteCount: Int64(pendingImageData.imageData.count), countStyle: .file)
                informativeText = String(format: NSLocalizedString("%1$@を超えるファイル（%2$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, actualFileSizeString)
            } else {
                // ファイルサイズが取得できない場合（既存のロジック）
                informativeText = String(format: NSLocalizedString("%@を超えるファイルがコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold)
            }
            
            LargeFileAlertWindowController.shared.showAlert(
                title: alertTitle,
                message: informativeText,
                buttons: [
                    LargeFileAlertButton(
                        title: NSLocalizedString("いいえ", comment: ""),
                        isProminent: false,
                        keyboardShortcut: .cancelAction,
                        action: { [weak self] in
                            LargeFileAlertWindowController.shared.closeWindow()
                            self?.handleLargeFileAlertConfirmation(shouldSave: false)
                        }
                    ),
                    LargeFileAlertButton(
                        title: NSLocalizedString("はい", comment: ""),
                        isProminent: true,
                        keyboardShortcut: .defaultAction,
                        action: { [weak self] in
                            LargeFileAlertWindowController.shared.closeWindow()
                            self?.handleLargeFileAlertConfirmation(shouldSave: true)
                        }
                    )
                ]
            )
        }
    }
    
    func handleLargeFileAlertConfirmation(shouldSave: Bool) {
        print("DEBUG: handleLargeFileAlertConfirmation - shouldSave: \(shouldSave)")
        if shouldSave {
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                // 新しいプロパティ (pendingLargeFileItemsWithSize) を使用
                if !self.pendingLargeFileItemsWithSize.isEmpty {
                    let sourceAppPath = self.pendingLargeFileItemsSourceAppPath // ソースアプリパスを取得
                    let itemsToProcess = self.pendingLargeFileItemsWithSize // ローカルコピー
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add \(itemsToProcess.count) pending file items (new property).")
                    var addedItems: [ClipboardItem] = []
                    var failedItems: [(fileURL: URL, qrCodeContent: String?, fileSize: UInt64?)] = []
                    
                    for item in itemsToProcess {
                        // ファイルの存在チェック
                        if FileManager.default.fileExists(atPath: item.fileURL.path) {
                            // 各ファイルを個別に処理 (ソースアプリパスを渡す)
                            if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true) {
                                addedItems.append(newItem)
                            }
                        } else {
                            failedItems.append(item)
                            print("DEBUG: handleLargeFileAlertConfirmation - File not found: \(item.fileURL.path)")
                        }
                    }
                    
                    // まとめて履歴に追加
                    if !addedItems.isEmpty {
                        let itemsToAdd = addedItems // ローカルコピーを作成
                        await MainActor.run {
                            for newItem in itemsToAdd {
                                self.addAndSaveItem(newItem)
                            }
                        }
                    }
                    
                    // エラーのハンドリング
                    if !failedItems.isEmpty {
                        let isAddedItemsEmpty = addedItems.isEmpty
                        await MainActor.run {
                            let alertTitle: String
                            let alertMessage: String
                            
                            if isAddedItemsEmpty {
                                // 全て失敗
                                alertTitle = NSLocalizedString("ファイルを保存できませんでした", comment: "")
                                alertMessage = NSLocalizedString("ファイルが見つからなかったため、履歴に保存することができませんでした。", comment: "")
                            } else {
                                // 一部失敗
                                alertTitle = NSLocalizedString("一部のファイルを保存できませんでした", comment: "")
                                alertMessage = NSLocalizedString("一部のファイルが見つからなかったため、履歴に保存することができませんでした。", comment: "")
                            }
                            
                            LargeFileAlertWindowController.shared.showAlert(
                                title: alertTitle,
                                message: alertMessage,
                                buttons: [
                                    LargeFileAlertButton(
                                        title: NSLocalizedString("OK", comment: ""),
                                        isProminent: true,
                                        keyboardShortcut: .defaultAction,
                                        action: {
                                            LargeFileAlertWindowController.shared.closeWindow()
                                        }
                                    )
                                ]
                            )
                        }
                    }
                }
                // 画像データが保留されている場合（後方互換性維持）
                else if let pendingImageData = self.pendingLargeImageData {
                    // ユーザーが画像の保存を許可した場合、画像をサンドボックスにコピーし、履歴に追加
                    // ここで createClipboardItemFromImageData を呼び出すことで重複検知ロジックが適用される
                    // アラート確認からの呼び出しであることを示すフラグをtrueにする
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add pending image data.")
                    let sourceAppPath = self.pendingLargeFileItemsSourceAppPath
                    if let newItem = await self.createClipboardItemFromImageData(pendingImageData.imageData, qrCodeContent: pendingImageData.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                }
                // アラートの状態をリセット
                await MainActor.run {
                    // showingLargeFileAlert を false に設定して、didSet が再度NSAlertをトリガーするのを防ぐ
                    if self.showingLargeFileAlert {
                        self.showingLargeFileAlert = false
                        print("DEBUG: handleLargeFileAlertConfirmation - Reset showingLargeFileAlert to false.")
                    }
                    self.pendingLargeFileItemsWithSize.removeAll() // 新しいプロパティもリセット
                    self.pendingLargeFileItemsSourceAppPath = nil // リセット
                    self.pendingLargeImageData = nil
                }
            }
        } else {
            print("DEBUG: handleLargeFileAlertConfirmation - User chose NOT to save the large file/image(s).")
            // showingLargeFileAlert を false に設定して、didSet が再度NSAlertをトリガーするのを防ぐ
            if showingLargeFileAlert {
                showingLargeFileAlert = false
                print("DEBUG: handleLargeFileAlertConfirmation - Reset showingLargeFileAlert to false.")
            }
            // アラートの状態をリセット
            pendingLargeFileItemsWithSize.removeAll() // 新しいプロパティもリセット
            pendingLargeFileItemsSourceAppPath = nil // リセット
            pendingLargeImageData = nil
        }
    }
}
