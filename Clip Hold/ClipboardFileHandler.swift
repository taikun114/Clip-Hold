import Foundation
import AppKit // NSImage
import SwiftUI // @AppStorage
import UniformTypeIdentifiers // UTType
import QuickLookThumbnailing // QLThumbnailGenerator

extension ClipboardManager {
    // MARK: - File Management Helpers
    func getAppSpecificDirectory() -> URL? { // private から internal に変更
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ClipboardManager: Could not find Application Support directory.")
            return nil
        }
        return directory.appendingPathComponent("ClipHold")
    }

    func createClipboardFilesDirectoryIfNeeded() -> URL? { // private から internal に変更
        guard let appSpecificDirectory = getAppSpecificDirectory() else { return nil }
        let filesDirectory = appSpecificDirectory.appendingPathComponent(filesDirectoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: filesDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true, attributes: nil)
                print("ClipboardManager: Created clipboard files directory: \(filesDirectory.path)")
            } catch {
                print("ClipboardManager: Error creating clipboard files directory: \(error.localizedDescription)")
                return nil
            }
        }
        return filesDirectory
    }

    // ファイルをアプリのサンドボックスにコピーする処理を非同期化
    private func copyFileToAppSandbox(from sourceURL: URL) async -> URL? {
        guard let filesDirectory = createClipboardFilesDirectoryIfNeeded() else { return nil }

        let fileName = sourceURL.lastPathComponent
        // 同じファイル名が既に存在する場合に備えて、ユニークな名前を生成
        // ここで UUID を含む名前を生成し、実際のファイル名として使用
        let uniqueFileName = "\(UUID().uuidString)-\(fileName)"
        let destinationURL = filesDirectory.appendingPathComponent(uniqueFileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("ClipboardManager: Copied file from \(sourceURL.lastPathComponent) to sandbox as \(destinationURL.lastPathComponent)")
            return destinationURL
        } catch {
            print("ClipboardManager: Error copying file to sandbox: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteFileFromSandbox(at fileURL: URL) { // private から internal に変更
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("ClipboardManager: Deleted file from sandbox: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("ClipboardManager: Error deleting file from sandbox: \(error.localizedDescription)")
        }
    }

    // ヘルパー関数: ファイルの属性（サイズと変更日時）を取得
    func getFileAttributes(_ url: URL) -> (fileSize: UInt64?, modificationDate: Date?) { // private から internal に変更
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.uint64Value
            let modificationDate = attributes[.modificationDate] as? Date
            return (fileSize, modificationDate)
        } catch {
            print("ClipboardManager: Error getting attributes for \(url.lastPathComponent): \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    // ヘルパー関数: 元のファイル名を抽出
    func extractOriginalFileName(from fileName: String) -> String { // private から internal に変更
        if let range = fileName.range(of: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-", options: .regularExpression) {
            return String(fileName[range.upperBound...])
        } else {
            return fileName
        }
    }

    // ヘルパー関数: 複数のファイルURLを処理
    func handleMultipleFilesChange(fileURLs: [URL], sourceAppPath: String?) async {
        var itemsWithQRCode: [(fileURL: URL, qrCodeContent: String?)] = []
        
        for fileURL in fileURLs {
            var qrCodeContent: String? = nil
            
            // コピーされたファイルが画像であるかチェック
            if let fileUTI = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
               fileUTI.conforms(to: .image) {
                if let image = NSImage(contentsOf: fileURL) {
                    qrCodeContent = self.decodeQRCode(from: image)
                }
            }
            
            itemsWithQRCode.append((fileURL: fileURL, qrCodeContent: qrCodeContent))
        }
        
        // 複数ファイル用の処理関数を呼び出す
        if let newItems = await self.createClipboardItemsForMultipleFileURLs(itemsWithQRCode, sourceAppPath: sourceAppPath) {
            await MainActor.run {
                for newItem in newItems {
                    self.addAndSaveItem(newItem)
                }
            }
        }
    }
    
    // ヘルパー関数: 複数のファイルURLからClipboardItemの配列を作成
    func createClipboardItemsForMultipleFileURLs(_ itemsWithQRCode: [(fileURL: URL, qrCodeContent: String?)], sourceAppPath: String?) async -> [ClipboardItem]? {
        // 内部コピーの場合はアラートをスキップ
        if isPerformingInternalCopy {
            print("DEBUG: createClipboardItemsForMultipleFileURLs - isPerformingInternalCopy is true, skipping alert and proceeding to save.")
            var savedItems: [ClipboardItem] = []
            for item in itemsWithQRCode {
                if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true) {
                    savedItems.append(newItem)
                }
            }
            return savedItems.isEmpty ? nil : savedItems
        }

        var totalFileSize: UInt64 = 0
        var fileItemsWithAttributes: [(fileURL: URL, qrCodeContent: String?, fileSize: UInt64?)] = []
        
        // 各ファイルの属性を取得し、合計サイズを計算
        for item in itemsWithQRCode {
            let fileAttributes = getFileAttributes(item.fileURL)
            totalFileSize += fileAttributes.fileSize ?? 0
            fileItemsWithAttributes.append((fileURL: item.fileURL, qrCodeContent: item.qrCodeContent, fileSize: fileAttributes.fileSize))
        }
        
        print("DEBUG: createClipboardItemsForMultipleFileURLs - Total file size: \(totalFileSize) bytes for \(itemsWithQRCode.count) files.")
        
        // MARK: - ファイルサイズチェック (アラート確認からでない場合のみアラートを表示)
        if largeFileAlertThreshold > 0 && totalFileSize > largeFileAlertThreshold {
            // アラートしきい値を超えている場合、アラート表示を要求
            let fileCount = itemsWithQRCode.count
            let totalSizeForAlert = totalFileSize // ローカルコピーを作成
            await MainActor.run {
                self.pendingLargeFileItems = itemsWithQRCode // 全ファイル情報を保持
                self.pendingLargeFileItemsSourceAppPath = sourceAppPath // ソースアプリパスを保持
                self.showingLargeFileAlert = true // didSetがNSAlertをトリガーする
                print("DEBUG: createClipboardItemsForMultipleFileURLs - Setting showingLargeFileAlert to true for \(fileCount) files with total size \(totalSizeForAlert).")
            }
            return nil // まだ保存せず、ユーザーのアラート確認を待つ
        } else if maxFileSizeToSave > 0 && totalFileSize > maxFileSizeToSave {
            // 合計サイズが最大保存サイズ制限を超えている場合は保存しない
            print("ClipboardManager: Multiple files not saved due to total size limit. Total size: \(totalFileSize) bytes. Limit: \(maxFileSizeToSave) bytes.")
            return nil
        }
        
        // アラート表示が不要な場合、各ファイルを個別に処理して保存
        var savedItems: [ClipboardItem] = []
        for item in fileItemsWithAttributes {
            if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true) {
                savedItems.append(newItem)
            }
        }
        
        return savedItems.isEmpty ? nil : savedItems
    }

    // ヘルパー関数: ファイルURLからClipboardItemを作成（物理的な重複コピー防止ロジックを含む）
    func createClipboardItemForFileURL(_ fileURL: URL, qrCodeContent: String? = nil, sourceAppPath: String? = nil, isFromAlertConfirmation: Bool = false) async -> ClipboardItem? { // private から internal に変更
        let filesDirectory = createClipboardFilesDirectoryIfNeeded()

        // 外部ファイルの属性を取得
        let externalFileAttributes = getFileAttributes(fileURL)

        print("DEBUG: createClipboardItemForFileURL - isPerformingInternalCopy: \(isPerformingInternalCopy), isFromAlertConfirmation: \(isFromAlertConfirmation)")

        // MARK: - ファイルサイズチェックを追加 (内部コピーでない場合、かつアラート確認からでない場合のみアラートを表示)
        // isPerformingInternalCopy が true の場合は、アラート表示を完全にスキップして保存処理に進む
        if !isPerformingInternalCopy { // 内部コピーでない場合のみ、アラート表示の可能性を考慮
            if !isFromAlertConfirmation { // かつ、アラート確認からでない場合のみアラートを表示
                if let fileSize = externalFileAttributes.fileSize {
                    // サイズ制限またはアラートしきい値を超えているかチェック
                    if maxFileSizeToSave > 0 && fileSize > maxFileSizeToSave {
                        print("ClipboardManager: File not saved due to size limit. File size: \(fileSize) bytes. Limit: \(maxFileSizeToSave) bytes.")
                        return nil // サイズ制限を超えている場合はnilを返す
                    } else if largeFileAlertThreshold > 0 && fileSize > largeFileAlertThreshold {
                        // アラートしきい値を超えている場合、アラート表示を要求
                        await MainActor.run {
                            self.pendingLargeFileItem = (fileURL, qrCodeContent)
                            self.showingLargeFileAlert = true // didSetがNSAlertをトリガーする
                            print("DEBUG: createClipboardItemForFileURL - Setting showingLargeFileAlert to true for file: \(fileURL.lastPathComponent)")
                        }
                        return nil // まだ保存せず、ユーザーのアラート確認を待つ
                    }
                }
            }
        }
        // ここに到達した場合は、アラート表示が不要（内部コピー、またはアラート確認済み、またはサイズ制限内）なので、
        // そのまま保存ロジックに進む

        // サンドボックス内の既存ファイルを走査し、重複をチェック
        if let filesDirectory = filesDirectory {
            do {
                let sandboxedFileContents = try FileManager.default.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles)

                for sandboxedFileURL in sandboxedFileContents {
                    let sandboxedFileAttributes = getFileAttributes(sandboxedFileURL)

                    // MARK: - ファイルサイズが完全に一致するかどうかのみを比較
                    if let externalSize = externalFileAttributes.fileSize,
                       let sandboxedSize = sandboxedFileAttributes.fileSize,
                       externalSize == sandboxedSize {
                        print("ClipboardManager: Found potential duplicate in sandbox based on file size: \(sandboxedFileURL.lastPathComponent)")
                        // 重複が見つかった場合、既存のサンドボックスファイルを参照する新しいアイテムを返す
                        let displayName = extractOriginalFileName(from: sandboxedFileURL.lastPathComponent)
                        return ClipboardItem(text: displayName, date: Date(), filePath: sandboxedFileURL, fileSize: sandboxedSize, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) // 新しいアイテムにもファイルサイズをセット
                    }
                }
            } catch {
                print("ClipboardManager: Error getting contents of sandbox directory for duplicate check: \(error.localizedDescription)")
            }
        }

        // 重複ファイルが見つからなかった場合、ファイルをサンドボックスにコピーして新しいアイテムを返す
        if let copiedFileURL = await copyFileToAppSandbox(from: fileURL) {
            let displayName = fileURL.lastPathComponent
            return ClipboardItem(text: displayName, date: Date(), filePath: copiedFileURL, fileSize: externalFileAttributes.fileSize, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) // 新しいアイテムにもファイルサイズをセット
        }

        print("ClipboardManager: Failed to copy external item to sandbox: \(fileURL.lastPathComponent).")
        return nil
    }

    // MARK: - New Helper function for image duplication check and saving
    func createClipboardItemFromImageData(_ imageData: Data, qrCodeContent: String?, sourceAppPath: String? = nil, isFromAlertConfirmation: Bool = false) async -> ClipboardItem? { // private から internal に変更
        guard let filesDirectory = createClipboardFilesDirectoryIfNeeded() else { return nil }

        let newImageSize = UInt64(imageData.count)

        print("DEBUG: createClipboardItemFromImageData - isPerformingInternalCopy: \(isPerformingInternalCopy), isFromAlertConfirmation: \(isFromAlertConfirmation)")

        // MARK: - 画像サイズチェックを追加 (内部コピーでない場合、かつアラート確認からでない場合のみアラートを表示)
        // isPerformingInternalCopy が true の場合は、アラート表示を完全にスキップして保存処理に進む
        if !isPerformingInternalCopy { // 内部コピーでない場合のみ、アラート表示の可能性を考慮
            if !isFromAlertConfirmation { // かつ、アラート確認からでない場合のみアラートを表示
                if maxFileSizeToSave > 0 && newImageSize > maxFileSizeToSave {
                    print("ClipboardManager: Image not saved due to size limit. Image size: \(newImageSize) bytes. Limit: \(maxFileSizeToSave) bytes.")
                    return nil // サイズ制限を超えている場合はnilを返す
                    } else if largeFileAlertThreshold > 0 && newImageSize > largeFileAlertThreshold {
                    // アラートしきい値を超えている場合、アラート表示を要求
                    await MainActor.run {
                        self.pendingLargeImageData = (imageData, qrCodeContent)
                        self.showingLargeFileAlert = true // didSetがNSAlertをトリガーする
                        print("DEBUG: createClipboardItemFromImageData - Setting showingLargeFileAlert to true for image data (size: \(newImageSize))")
                    }
                    return nil // まだ保存せず、ユーザーのアラート確認を待つ
                }
            }
        }
        // ここに到達した場合は、アラート表示が不要（内部コピー、またはアラート確認済み、またはサイズ制限内）なので、
        // そのまま保存ロジックに進む

        do {
            let sandboxedFileContents = try FileManager.default.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles)

            for sandboxedFileURL in sandboxedFileContents {
                if sandboxedFileURL.lastPathComponent.hasSuffix("-image.png") {
                    let sandboxedFileAttributes = getFileAttributes(sandboxedFileURL)
                    if let sandboxedSize = sandboxedFileAttributes.fileSize, sandboxedSize == newImageSize {
                        print("ClipboardManager: Found duplicate image in sandbox based on file size: \(sandboxedFileURL.lastPathComponent)")
                        return ClipboardItem(text: String(localized: "Image File"), date: Date(), filePath: sandboxedFileURL, fileSize: sandboxedSize, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath)
                    }
                }
            }
        } catch {
            print("ClipboardManager: Error getting contents of sandbox directory for image duplicate check: \(error.localizedDescription)")
        }

        // 重複が見つからなかった場合、新しい画像を保存
        let uniqueFileName = "\(UUID().uuidString)-image.png"
        let destinationURL = filesDirectory.appendingPathComponent(uniqueFileName)

        do {
            try imageData.write(to: destinationURL)
            print("ClipboardManager: New image saved to sandbox as \(destinationURL.lastPathComponent)")
            return ClipboardItem(text: String(localized: "Image File"), date: Date(), filePath: destinationURL, fileSize: newImageSize, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath)
        } catch {
            print("ClipboardManager: Error saving new image to sandbox: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helper function for duplication check
    func isDuplicate(_ newItem: ClipboardItem, of existingItem: ClipboardItem) -> Bool { // private から internal に変更
        // ファイルアイテムの場合、ファイルパスとサイズで重複を判定
        if let newFilePath = newItem.filePath, let existingFilePath = existingItem.filePath {
            // ファイルパスとサイズが一致する場合、重複と判定
            // ファイル名（textプロパティ）は表示用なので比較対象に含めない
            return newFilePath == existingFilePath && newItem.fileSize == existingItem.fileSize
        }
        // テキストアイテムの場合、テキスト内容で重複を判定
        else if newItem.filePath == nil && existingItem.filePath == nil {
            return newItem.text == existingItem.text
        }
        // 片方だけがファイルアイテムの場合は重複ではない
        return false
    }

    // MARK: - Thumbnail Generation
    func generateThumbnail(for item: ClipboardItem, at fileURL: URL) { // private から internal に変更
        let thumbnailSize = CGSize(width: 40, height: 40) // メニューバーの表示サイズに合わせる
        let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: thumbnailSize, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)

        Task.detached {
            do {
                let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                // 画像を正方形にパディング（アスペクト比を維持）
                let paddedImage = ClipboardManager.shared.padToSquare(thumbnail.nsImage, size: thumbnailSize)
                
                // NSImageをPNGデータに変換して、Sendableな形式にする
                guard let imageData = paddedImage.imageData else {
                    print("Failed to convert padded image to PNG data")
                    return
                }
                
                await MainActor.run {
                    // PNGデータからNSImageを再作成
                    if let image = NSImage(data: imageData) {
                        item.cachedThumbnailImage = image
                        // MenuBarExtraを更新するため、マネージャー全体を更新通知
                        self.objectWillChange.send()
                    }
                }
            } catch {
                print("Failed to generate thumbnail for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - ファイルコピーのためのヘルパー
    // 元のファイル名で一時的なファイルを作成する
    func createTemporaryCopy(for item: ClipboardItem) async -> URL? { // private から internal に変更
        guard let originalFilePath = item.filePath else {
            return nil
        }

        let originalFileName = extractOriginalFileName(from: originalFilePath.lastPathComponent)

        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectoryURL.appendingPathComponent(originalFileName)

        // 既存のファイルがあれば削除
        if FileManager.default.fileExists(atPath: tempFileURL.path) {
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        do {
            try FileManager.default.copyItem(at: originalFilePath, to: tempFileURL)
            print("ClipboardManager: Temporary file created at \(tempFileURL.path) from original file \(originalFilePath.path)")

            // 追跡リストに追加
            await MainActor.run {
                _ = self.temporaryFileUrls.insert(tempFileURL) // 明示的に結果を無視
            }

            return tempFileURL
        } catch {
            print("ClipboardManager: Error creating temporary file copy: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 一時ファイルクリーンアップ
    func cleanUpTemporaryFiles() { // private から internal に変更
        let fileManager = FileManager.default
        let tempDirectoryURL = fileManager.temporaryDirectory
        print("ClipboardManager: Attempting to clean up temporary files in \(tempDirectoryURL.path)")

        do {
            let tempContents = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            var cleanedCount = 0
            for fileURL in tempContents {
                do {
                    try fileManager.removeItem(at: fileURL)
                    print("ClipboardManager: Removed temporary file: \(fileURL.lastPathComponent)")
                    cleanedCount += 1
                } catch {
                    print("ClipboardManager: Error removing temporary file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
            print("ClipboardManager: Cleaned up \(cleanedCount) temporary files.")
        } catch {
            print("ClipboardManager: Error getting contents of temporary directory: \(error.localizedDescription)")
        }
        // temporaryFileUrls セットもクリアする
        temporaryFileUrls.removeAll()
    }
}
