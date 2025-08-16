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
            alert.messageText = NSLocalizedString("大容量ファイルのコピー", comment: "")

            // Format the largeFileAlertThreshold for display
            let formattedThreshold = ByteCountFormatter.string(fromByteCount: Int64(self.largeFileAlertThreshold), countStyle: .file)

            var actualFileSizeString: String?
            if let pendingItem = self.pendingLargeFileItem, let fileSize = self.getFileAttributes(pendingItem.fileURL).fileSize {
                actualFileSizeString = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            } else if let pendingImageData = self.pendingLargeImageData {
                actualFileSizeString = ByteCountFormatter.string(fromByteCount: Int64(pendingImageData.imageData.count), countStyle: .file)
            }

            // Construct the informative text based on whether actual file size is available
            if let actualSize = actualFileSizeString {
                alert.informativeText = String(format: NSLocalizedString("%1$@を超えるファイル（%2$@）がコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold, actualSize)
            } else {
                alert.informativeText = String(format: NSLocalizedString("%@を超えるファイルがコピーされました。履歴に保存してもよろしいですか？", comment: ""), formattedThreshold)
            }

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
                if let pendingItem = self.pendingLargeFileItem {
                    // ユーザーが保存を許可した場合、ファイルをサンドボックスにコピーし、履歴に追加
                    // ここで createClipboardItemForFileURL を呼び出すことで重複検知ロジックが適用される
                    // アラート確認からの呼び出しであることを示すフラグをtrueにする
                    print("DEBUG: handleLargeFileAlertConfirmation - Attempting to add pending file item.")
                    if let newItem = await self.createClipboardItemForFileURL(pendingItem.fileURL, qrCodeContent: pendingItem.qrCodeContent, isFromAlertConfirmation: true) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                } else if let pendingImageData = self.pendingLargeImageData {
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
                    self.pendingLargeImageData = nil
                    // showingLargeFileAlert を false に設定して、didSet が再度NSAlertをトリガーするのを防ぐ
                    if self.showingLargeFileAlert {
                        self.showingLargeFileAlert = false
                        print("DEBUG: handleLargeFileAlertConfirmation - Reset showingLargeFileAlert to false.")
                    }
                }
            }
        } else {
            print("DEBUG: handleLargeFileAlertConfirmation - User chose NOT to save the large file/image.")
            // アラートの状態をリセット
            pendingLargeFileItem = nil
            pendingLargeImageData = nil
            // showingLargeFileAlert を false に設定して、didSet が再度NSAlertをトリガーするのを防ぐ
            if showingLargeFileAlert {
                showingLargeFileAlert = false
                print("DEBUG: handleLargeFileAlertConfirmation - Reset showingLargeFileAlert to false.")
            }
        }
    }
}