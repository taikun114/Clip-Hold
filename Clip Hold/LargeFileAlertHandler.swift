import Foundation
import AppKit // NSAlert
import SwiftUI // NSLocalizedString

extension ClipboardManager {
    // MARK: - Large File Alert Handling
    // Method to directly display NSAlert
    func presentLargeFileConfirmationAlert() { // private から internal に変更
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = NSAlert()
            
            // 新しいプロパティがセットされている場合はそれを優先
            let isMultipleFilesWithSize = self.pendingLargeFileItemsWithSize != nil && (self.pendingLargeFileItemsWithSize?.count ?? 0) > 1
            // let isSingleFileWithSize = self.pendingLargeFileItemsWithSize != nil && (self.pendingLargeFileItemsWithSize?.count ?? 0) == 1
            
            let alertTitle: String
            if isMultipleFilesWithSize {
                alertTitle = NSLocalizedString("大容量ファイルの複数コピー", comment: "")
            } else {
                // 単一ファイルまたは古いプロパティを使用する場合
                alertTitle = NSLocalizedString("大容量ファイルのコピー", comment: "")
            }
            alert.messageText = alertTitle

            var informativeText: String
            
            // Format the largeFileAlertThreshold for display
            let formattedThreshold = ByteCountFormatter.string(fromByteCount: Int64(self.largeFileAlertThreshold), countStyle: .file)

            // 新しいプロパティ (pendingLargeFileItemsWithSize) を使用
            if let pendingItemsWithSize = self.pendingLargeFileItemsWithSize {
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
            }
            // 古いプロパティ (pendingLargeFileItems) を使用するフォールバック
            else if let pendingItems = self.pendingLargeFileItems, pendingItems.count > 1 {
                // 複数ファイル用のメッセージ (古いプロパティを使用)
                var totalFileSize: UInt64 = 0
                for item in pendingItems {
                    let fileSize = self.getFileAttributes(item.fileURL).fileSize ?? 0
                    totalFileSize += fileSize
                }
                let formattedTotalSize = ByteCountFormatter.string(fromByteCount: Int64(totalFileSize), countStyle: .file)
                let fileCount = pendingItems.count
                informativeText = String(format: NSLocalizedString("%1$@を超える%2$d個のファイル（合計%3$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, fileCount, formattedTotalSize)
            } else if let pendingItem = self.pendingLargeFileItem, let fileSize = self.getFileAttributes(pendingItem.fileURL).fileSize {
                // 単一ファイル用のメッセージ（既存のロジック）
                let actualFileSizeString = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                informativeText = String(format: NSLocalizedString("%1$@を超えるファイル（%2$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, actualFileSizeString)
            } else if let pendingImageData = self.pendingLargeImageData {
                // 画像データ用のメッセージ（既存のロジック）
                let actualFileSizeString = ByteCountFormatter.string(fromByteCount: Int64(pendingImageData.imageData.count), countStyle: .file)
                informativeText = String(format: NSLocalizedString("%1$@を超えるファイル（%2$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, actualFileSizeString)
            } else {
                // ファイルサイズが取得できない場合（既存のロジック）
                informativeText = String(format: NSLocalizedString("%@を超えるファイルがコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold)
            }

            alert.informativeText = informativeText

            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("はい", comment: "")) // NSAlertFirstButtonReturn (1000)
            alert.addButton(withTitle: NSLocalizedString("いいえ", comment: "")) // NSAlertSecondButtonReturn (1001)

            let response = alert.runModal()
            print("DEBUG: presentLargeFileConfirmationAlert - Alert dismissed. Response: \(response.rawValue)")

            // NSAlertFirstButtonReturn corresponds to "Yes", NSAlertSecondButtonReturn to "No"
            let shouldSave = (response == .alertFirstButtonReturn)
            self.handleLargeFileAlertConfirmation(shouldSave: shouldSave)
        }
    }

    func handleLargeFileAlertConfirmation(shouldSave: Bool) {
        print("DEBUG: handleLargeFileAlertConfirmation - shouldSave: \(shouldSave)")
        if shouldSave {
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                // 新しいプロパティ (pendingLargeFileItemsWithSize) を使用
                if let pendingItemsWithSize = self.pendingLargeFileItemsWithSize {
                    let sourceAppPath = self.pendingLargeFileItemsSourceAppPath // ソースアプリパスを取得
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add \(pendingItemsWithSize.count) pending file items (new property).")
                    var addedItems: [ClipboardItem] = []
                    for item in pendingItemsWithSize {
                        // 各ファイルを個別に処理 (ソースアプリパスを渡す)
                        if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true) {
                            addedItems.append(newItem)
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
                }
                // 古いプロパティ (pendingLargeFileItems) を使用するフォールバック
                else if let pendingItems = self.pendingLargeFileItems {
                    let sourceAppPath = self.pendingLargeFileItemsSourceAppPath // ソースアプリパスを取得
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add \(pendingItems.count) pending file items (old property).")
                    var addedItems: [ClipboardItem] = []
                    for item in pendingItems {
                        // 各ファイルを個別に処理 (ソースアプリパスを渡す)
                        if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true) {
                            addedItems.append(newItem)
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
                }
                // 単一ファイルが保留されている場合（後方互換性維持）
                else if let pendingItem = self.pendingLargeFileItem {
                    // ユーザーが保存を許可した場合、ファイルをサンドボックスにコピーし、履歴に追加
                    // ここで createClipboardItemForFileURL を呼び出すことで重複検知ロジックが適用される
                    // アラート確認からの呼び出しであることを示すフラグをtrueにする
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add pending file item.")
                    if let newItem = await self.createClipboardItemForFileURL(pendingItem.fileURL, qrCodeContent: pendingItem.qrCodeContent, isFromAlertConfirmation: true) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                }
                // 画像データが保留されている場合（後方互換性維持）
                else if let pendingImageData = self.pendingLargeImageData {
                    // ユーザーが画像の保存を許可した場合、画像をサンドボックスにコピーし、履歴に追加
                    // ここで createClipboardItemFromImageData を呼び出すことで重複検知ロジックが適用される
                    // アラート確認からの呼び出しであることを示すフラグをtrueにする
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add pending image data.")
                    if let newItem = await self.createClipboardItemFromImageData(pendingImageData.imageData, qrCodeContent: pendingImageData.qrCodeContent, isFromAlertConfirmation: true) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                }
                // アラートの状態をリセット
                await MainActor.run {
                    self.pendingLargeFileItem = nil
                    self.pendingLargeFileItems = nil
                    self.pendingLargeFileItemsWithSize = nil // 新しいプロパティもリセット
                    self.pendingLargeFileItemsSourceAppPath = nil // リセット
                    self.pendingLargeImageData = nil
                    // showingLargeFileAlert を false に設定して、didSet が再度NSAlertをトリガーするのを防ぐ
                    if self.showingLargeFileAlert {
                        self.showingLargeFileAlert = false
                        print("DEBUG: handleLargeFileAlertConfirmation - Reset showingLargeFileAlert to false.")
                    }
                }
            }
        } else {
            print("DEBUG: handleLargeFileAlertConfirmation - User chose NOT to save the large file/image(s).")
            // アラートの状態をリセット
            pendingLargeFileItem = nil
            pendingLargeFileItems = nil
            pendingLargeFileItemsWithSize = nil // 新しいプロパティもリセット
            pendingLargeFileItemsSourceAppPath = nil // リセット
            pendingLargeImageData = nil
            // showingLargeFileAlert を false に設定して、didSet が再度NSAlertをトリガーするのを防ぐ
            if showingLargeFileAlert {
                showingLargeFileAlert = false
                print("DEBUG: handleLargeFileAlertConfirmation - Reset showingLargeFileAlert to false.")
            }
        }
    }
}
