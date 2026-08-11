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
    
    // 以前の copyFileToAppSandbox は非同期チャンクコピーに置き換えるため削除しました。
    
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
        // UUIDプレフィックスを削除する正規表現パターン
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-"
        
        // ファイル名がUUIDプレフィックスで始まるかチェック
        if let range = fileName.range(of: uuidPattern, options: .regularExpression) {
            // UUIDプレフィックスを削除して元のファイル名を返す
            return String(fileName[range.upperBound...])
        } else {
            // UUIDプレフィックスがない場合は、ファイル名をそのまま返す
            return fileName
        }
    }
    
    // ヘルパー関数: 複数のファイルURLを処理
    func handleMultipleFilesChange(fileURLs: [URL], sourceAppPath: String?, originalItem: ClipboardItem? = nil) async {
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
        if let newItems = await self.createClipboardItemsForMultipleFileURLs(itemsWithQRCode, sourceAppPath: sourceAppPath, originalItem: originalItem) {
            await MainActor.run {
                for newItem in newItems {
                    self.addAndSaveItem(newItem)
                }
            }
        }
    }
    
    // ヘルパー関数: 複数のファイルURLからClipboardItemの配列を作成
    func createClipboardItemsForMultipleFileURLs(_ itemsWithQRCode: [(fileURL: URL, qrCodeContent: String?)], sourceAppPath: String?, originalItem: ClipboardItem? = nil) async -> [ClipboardItem]? {
        // 内部コピーの場合はアラートをスキップ
        if isPerformingInternalCopy {
            print("DEBUG: createClipboardItemsForMultipleFileURLs - isPerformingInternalCopy is true, skipping alert and proceeding to save.")
            var savedItems: [ClipboardItem] = []
            for item in itemsWithQRCode {
                if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: true, originalItem: originalItem) {
                    savedItems.append(newItem)
                }
            }
            return savedItems.isEmpty ? nil : savedItems
        }
        
        var totalFileSize: UInt64 = 0
        var isTimeout = false
        var createdItems: [ClipboardItem] = []
        
        // 1. 即座にUIに追加するための仮アイテムを作成
        for item in itemsWithQRCode {
            if let newItem = await self.createClipboardItemForFileURL(item.fileURL, qrCodeContent: item.qrCodeContent, sourceAppPath: sourceAppPath, isFromAlertConfirmation: false, originalItem: originalItem, isPendingOnly: true) {
                createdItems.append(newItem)
                await MainActor.run {
                    self.addAndSaveItem(newItem) // 履歴に表示させる（isCopying = true, copyProgress = -1.0）
                }
            }
        }
        
        let threshold = UInt64(self.largeFileAlertThreshold)
        let maxLimit = UInt64(self.maxFileSizeToSave)
        let timeout = self.folderCalculationTimeout
        
        // 2. 非同期でサイズを計算
        for item in createdItems {
            guard let url = item.sourceFileURL else { continue }
            let sizeResult = await self.calculateSizeAsync(url: url, timeout: timeout)
            
            // 計算された正確なサイズ（フォルダの場合は中身の合計）でアイテムのサイズを更新
            await MainActor.run {
                item.fileSize = sizeResult.size
                item.isPartialSize = sizeResult.isTimeout
                item.isSizeCalculated = true
            }
            
            totalFileSize += sizeResult.size
            if sizeResult.isTimeout {
                isTimeout = true
                break
            }
            // maxLimit を超えたらそれ以上計算しなくて良い
            if maxLimit > 0 && totalFileSize > maxLimit {
                break
            }
        }
        
        print("DEBUG: createClipboardItemsForMultipleFileURLs - Total calculated size: \(totalFileSize) bytes. isTimeout: \(isTimeout)")
        
        // 3. サイズ判定とアラート
        if maxLimit > 0 && totalFileSize > maxLimit {
            // サイズ超過で保存しない場合、UIから削除
            print("ClipboardManager: Multiple files not saved due to total size limit. Total size: \(totalFileSize) bytes. Limit: \(maxLimit) bytes.")
            let itemsToDelete = createdItems
            await MainActor.run {
                for item in itemsToDelete {
                    self.deleteItem(id: item.id)
                }
            }
            return nil
        }
        
        if isTimeout || (threshold > 0 && totalFileSize > threshold) {
            // アラート表示
            let timeoutOccurred = isTimeout
            let pendingItems = createdItems
            await MainActor.run {
                self.pendingLargeFileIsTimeout = timeoutOccurred
                self.pendingLargeFileItemsSourceAppPath = sourceAppPath
                self.pendingLargeFileItemsWithSize = pendingItems
                self.showingLargeFileAlert = true
            }
            return nil
        }
        
        // 4. アラート不要の場合、直ちに実際のコピー処理を開始
        for item in createdItems {
            self.startFileProcessing(for: item, externalFileAttributes: self.getFileAttributes(item.sourceFileURL!), originalItem: originalItem)
        }
        
        return nil // addAndSaveItem は既に呼ばれているので nil を返す
    }
    
    // ヘルパー関数: フォルダのサイズを非同期で計算（タイムアウト付き）
    func calculateSizeAsync(url: URL, timeout: Double) async -> (size: UInt64, isTimeout: Bool) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return (0, false)
        }
        
        if !isDirectory.boolValue {
            let size = getFileAttributes(url).fileSize ?? 0
            return (size, false)
        }
        
        // バックグラウンドスレッドでディレクトリを探索
        return await Task.detached(priority: .userInitiated) {
            let startTime = Date()
            var folderSize: UInt64 = 0
            
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
                return (0, false)
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Date().timeIntervalSince(startTime) > timeout {
                    return (folderSize, true)
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    folderSize += UInt64(resourceValues.fileSize ?? 0)
                } catch {
                    // Ignore errors (e.g. permission denied)
                }
            }
            return (folderSize, false)
        }.value
    }
    
    func createClipboardItemForFileURL(_ fileURL: URL, qrCodeContent: String? = nil, sourceAppPath: String? = nil, isFromAlertConfirmation: Bool = false, originalItem: ClipboardItem? = nil, isPendingOnly: Bool = false) async -> ClipboardItem? { // private から internal に変更
        _ = createClipboardFilesDirectoryIfNeeded()
        
        // 外部ファイルの属性を取得
        let externalFileAttributes = getFileAttributes(fileURL)
        
        print("DEBUG: createClipboardItemForFileURL - isPerformingInternalCopy: \(isPerformingInternalCopy), isFromAlertConfirmation: \(isFromAlertConfirmation)")
        
        // ファイルサイズチェックは createClipboardItemsForMultipleFileURLs 側で行うため、ここでは省略
        
        // ファイル保存用ディレクトリの取得
        guard let filesDirectory = createClipboardFilesDirectoryIfNeeded() else { return nil }
        let fileName = fileURL.lastPathComponent
        let uniqueFileName = "\(UUID().uuidString)-\(fileName)"
        let destinationURL = filesDirectory.appendingPathComponent(uniqueFileName)
        
        // プレースホルダーとなるClipboardItemを即座に作成
        let newItem = ClipboardItem(text: fileName, date: Date(), filePath: destinationURL, fileSize: externalFileAttributes.fileSize, fileHash: originalItem?.fileHash, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath)
        newItem.sourceFileURL = fileURL
        
        // 即座にソースファイルから基本のアイコンを設定しておく（UIでのデフォルトアイコンへのフォールバックを防ぐため）
        if let originalThumb = originalItem?.cachedThumbnailImage {
            newItem.cachedThumbnailImage = originalThumb
        } else {
            newItem.cachedThumbnailImage = NSWorkspace.shared.icon(forFile: fileURL.path)
        }
        
        // originalItemが提供された場合（履歴からのコピーの場合）はファイル操作をスキップし、即座に重複として扱う
        if let originalItem = originalItem {
            // originalItem の情報をそのまま使用し、ファイルコピーやハッシュ計算を行わない
            newItem.filePath = originalItem.filePath // Sandbox上の既存ファイルパスを使用
            newItem.fileSize = originalItem.fileSize
            newItem.isCopying = false
            newItem.copyProgress = 1.0
            print("DEBUG: createClipboardItemForFileURL - Copied from history. Treated as duplicate immediately.")
            return newItem
        }
        
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
        let isDir = isDirectory.boolValue
        
        await MainActor.run {
            newItem.isCopying = true
            newItem.isProgressBarVisible = isDir // フォルダの場合は最初から表示する
            newItem.copyProgress = -1.0
        }
        
        if !isDir {
            // ファイルの場合、1.0秒経過しても計算中・アラート表示中・コピー中のままならプログレスバーを表示する
            Task { [weak newItem] in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0秒
                if let item = newItem {
                    await MainActor.run {
                        if item.isCopying {
                            item.isProgressBarVisible = true
                        }
                    }
                }
            }
        }
        
        if isPendingOnly {
            return newItem
        }
        
        // 非同期チャンクコピーを開始するタスク
        self.startFileProcessing(for: newItem, externalFileAttributes: externalFileAttributes, originalItem: originalItem)
        
        return newItem
    }
    
    func startFileProcessing(for item: ClipboardItem, externalFileAttributes: (fileSize: UInt64?, modificationDate: Date?), originalItem: ClipboardItem?) {
        guard let fileURL = item.sourceFileURL else { return }
        guard let destinationURL = item.filePath else { return }
        let fileName = item.text
        
        let copyTask = Task.detached(priority: .background) { [weak item, weak self] in
            guard let item = item else { return }
            let startTime = Date()
            let totalSize = externalFileAttributes.fileSize ?? 1
            
            // サムネイルを高解像度で再生成（ソースURLから並行して行う）
            Task {
                let thumbnailSize = CGSize(width: 60, height: 60)
                let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: thumbnailSize, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
                
                var retryCount = 0
                let maxRetries = 3
                
                while retryCount < maxRetries {
                    if item.isCopyCancelled { break }
                    do {
                        let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                        
                        // サムネイルではなくただのアイコンが返された場合は、まだ生成が終わっていない可能性があるためリトライする
                        if thumbnail.type == .icon && retryCount < maxRetries - 1 {
                            retryCount += 1
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                            continue
                        }
                        
                        if !item.isCopyCancelled {
                            await MainActor.run {
                                item.objectWillChange.send()
                                item.cachedThumbnailImage = thumbnail.nsImage
                            }
                        }
                        break // 成功したのでループを抜ける
                    } catch {
                        retryCount += 1
                        if retryCount >= maxRetries {
                            // エラー時は初期設定された基本アイコンのままとする
                            break
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
            
            // タスク内で外部ファイルのハッシュを計算（UIをブロックしない）
            let externalFileHash = HashCalculator.calculateFileHash(at: fileURL, fileSize: Int64(totalSize)) { [weak item] progress in
                let mappedProgress = progress * 0.5 // ハッシュ計算は進捗の0%〜50%に割り当てる
                Task { @MainActor [weak item] in
                    item?.copyProgress = mappedProgress
                }
            } isCancelled: { [weak item] in
                return item?.isCopyCancelled ?? true
            }
            
            if item.isCopyCancelled { return }
            
            // キャッシュ（履歴全体のハッシュ情報）から重複をチェック
            var foundDuplicateURL: URL? = nil
            if let externalHash = externalFileHash {
                foundDuplicateURL = await ClipboardManager.shared.getFileURL(forHash: externalHash)
                
                if let duplicateURL = foundDuplicateURL, FileManager.default.fileExists(atPath: duplicateURL.path) {
                    print("ClipboardManager: Found duplicate in sandbox based on file hash cache: \(duplicateURL.lastPathComponent)")
                    let displayName = self?.extractOriginalFileName(from: duplicateURL.lastPathComponent) ?? duplicateURL.lastPathComponent
                    let sandboxedFileAttributes = self?.getFileAttributes(duplicateURL)
                    let sourceURL = fileURL
                    
                    await MainActor.run {
                        let itemsToUpdate = [item] + ClipboardManager.shared.clipboardHistory.filter { $0.isCopying && $0.sourceFileURL == sourceURL && $0.id != item.id }
                        for targetItem in itemsToUpdate {
                            targetItem.text = displayName
                            targetItem.filePath = duplicateURL
                            targetItem.fileSize = sandboxedFileAttributes?.fileSize ?? externalFileAttributes.fileSize
                            targetItem.fileHash = externalHash
                            targetItem.copyProgress = 1.0
                        }
                    }
                    
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    if elapsedTime > 1.0 {
                        // 1秒待機
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    
                    // 重複ファイル（正しいアイコンを持つSandbox上のファイル）から最終的なアイコンを取得する
                    let finalIconRequest = QLThumbnailGenerator.Request(fileAt: duplicateURL, size: CGSize(width: 60, height: 60), scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
                    let finalDestinationURL = duplicateURL
                    let finalHash = externalHash
                    
                    let finalThumbnailImage: NSImage?
                    if let finalThumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: finalIconRequest) {
                        finalThumbnailImage = finalThumbnail.nsImage
                    } else {
                        finalThumbnailImage = NSWorkspace.shared.icon(forFile: finalDestinationURL.path)
                    }
                    
                    await MainActor.run {
                        // 自分自身と、同じsourceFileURLを持つコピー中のプレースホルダーアイテムをすべて取得
                        let itemsToUpdate = [item] + ClipboardManager.shared.clipboardHistory.filter { $0.isCopying && $0.sourceFileURL == sourceURL && $0.id != item.id }
                        let itemIDsToUpdate = Set(itemsToUpdate.map { $0.id })
                        
                        // 今回のアイテムを除外した履歴の中で、一番新しいアイテム（直前の履歴）を取得
                        let otherItems = ClipboardManager.shared.clipboardHistory.filter { !itemIDsToUpdate.contains($0.id) }
                        if let lastRealItem = otherItems.max(by: { $0.date < $1.date }) {
                            // 直前の履歴と全く同じファイル（パスとサイズが一致）であれば、今回追加されたアイテムは不要なので削除する
                            let isSameAsLast = lastRealItem.filePath == finalDestinationURL && lastRealItem.fileSize == (sandboxedFileAttributes?.fileSize ?? externalFileAttributes.fileSize)
                            
                            if isSameAsLast {
                                // UI更新用に通知
                                ClipboardManager.shared.objectWillChange.send()
                                // メモリ上の履歴から自身とプレースホルダーを削除
                                ClipboardManager.shared.clipboardHistory.removeAll { itemIDsToUpdate.contains($0.id) }
                                
                                // 非同期でチャンク（保存データ）からも削除
                                for targetItem in itemsToUpdate {
                                    Task {
                                        await ChunkedHistoryManager.shared.deleteHistoryItem(id: targetItem.id)
                                    }
                                }
                                return
                            }
                        }
                        
                        // 直前の履歴と異なる場合は、通常通り更新する
                        for targetItem in itemsToUpdate {
                            targetItem.objectWillChange.send()
                            if let img = finalThumbnailImage {
                                targetItem.cachedThumbnailImage = img
                            }
                            targetItem.filePath = finalDestinationURL
                            targetItem.fileHash = finalHash
                            targetItem.copyProgress = 1.0
                            withAnimation(.easeInOut(duration: 0.3)) {
                                targetItem.isCopying = false
                            }
                            Task {
                                await ChunkedHistoryManager.shared.updateHistoryItem(targetItem)
                            }
                        }
                    }
                    
                    return
                }
            }
            
            // 重複ファイルが見つからなかった場合、コピーを開始
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
            let isDirectory = isDir.boolValue
            
            await MainActor.run {
                item.fileHash = externalFileHash
                // フォルダの場合は引き続き不確定(indeterminate)、ファイルの場合はハッシュ計算完了の0.5とする
                item.copyProgress = isDirectory ? -1.0 : 0.5
            }
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                if isDirectory {
                    let fm = FileManager()
                    let delegate = DirectoryCopyDelegate(item: item)
                    fm.delegate = delegate
                    
                    do {
                        try fm.copyItem(at: fileURL, to: destinationURL)
                    } catch {
                        print("ClipboardManager: Error copying directory: \(error)")
                    }
                    
                    if item.isCopyCancelled {
                        print("ClipboardManager: Copy cancelled for \(fileName) (Directory)")
                        try? FileManager.default.removeItem(at: destinationURL)
                        
                        let sourceURL = fileURL
                        await MainActor.run {
                            let itemsToDelete = [item] + ClipboardManager.shared.clipboardHistory.filter { $0.isCopying && $0.sourceFileURL == sourceURL && $0.id != item.id }
                            for targetItem in itemsToDelete {
                                ClipboardManager.shared.deleteItem(id: targetItem.id)
                            }
                        }
                        return
                    }
                    
                    await MainActor.run {
                        item.copyProgress = 1.0
                    }
                } else {
                    let bufferSize = 1024 * 1024 * 4 // 4MBチャンク
                    let fileHandleReader = try FileHandle(forReadingFrom: fileURL)
                    FileManager.default.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
                    let fileHandleWriter = try FileHandle(forWritingTo: destinationURL)
                    
                    defer {
                        try? fileHandleReader.close()
                        try? fileHandleWriter.close()
                    }
                    
                    let totalSize = externalFileAttributes.fileSize ?? 1
                    var copiedSize: UInt64 = 0
                    
                    while true {
                        if item.isCopyCancelled {
                            print("ClipboardManager: Copy cancelled for \(fileName)")
                            try? FileManager.default.removeItem(at: destinationURL)
                            
                            let sourceURL = fileURL
                            await MainActor.run {
                                let itemsToDelete = [item] + ClipboardManager.shared.clipboardHistory.filter { $0.isCopying && $0.sourceFileURL == sourceURL && $0.id != item.id }
                                for targetItem in itemsToDelete {
                                    ClipboardManager.shared.deleteItem(id: targetItem.id)
                                }
                            }
                            return
                        }
                        
                        if let data = try fileHandleReader.read(upToCount: bufferSize) {
                            try fileHandleWriter.write(contentsOf: data)
                            copiedSize += UInt64(data.count)
                            
                            let copyRatio = Double(copiedSize) / Double(max(totalSize, 1))
                            let progress = 0.5 + (copyRatio * 0.5) // コピーは進捗の50%〜100%に割り当てる
                            await MainActor.run {
                                item.copyProgress = progress
                            }
                        } else {
                            break // EOF
                        }
                    }
                }
                
                let finalDestinationURL = destinationURL
                let finalHash = externalFileHash
                let sourceURL = fileURL
                
                if let externalHash = finalHash {
                    await ClipboardManager.shared.updateFileHashCache(url: finalDestinationURL, hash: externalHash)
                }
                print("ClipboardManager: Async copied file to sandbox as \(finalDestinationURL.lastPathComponent)")
                
                // コピー完了後に、Sandboxに保存されたファイルから確実に正しいアイコンを再取得する
                let finalIconRequest = QLThumbnailGenerator.Request(fileAt: finalDestinationURL, size: CGSize(width: 60, height: 60), scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
                let finalThumbnailImage: NSImage?
                if let finalThumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: finalIconRequest) {
                    finalThumbnailImage = finalThumbnail.nsImage
                } else {
                    finalThumbnailImage = NSWorkspace.shared.icon(forFile: finalDestinationURL.path)
                }
                
                await MainActor.run {
                    // 自分自身と、同じsourceFileURLを持つコピー中のプレースホルダーアイテムをすべて更新
                    let itemsToUpdate = [item] + ClipboardManager.shared.clipboardHistory.filter { $0.isCopying && $0.sourceFileURL == sourceURL && $0.id != item.id }
                    
                    for targetItem in itemsToUpdate {
                        targetItem.copyProgress = 1.0
                        targetItem.objectWillChange.send()
                        if let img = finalThumbnailImage {
                            targetItem.cachedThumbnailImage = img
                        }
                        targetItem.filePath = finalDestinationURL
                        targetItem.fileHash = finalHash
                        withAnimation(.easeInOut(duration: 0.3)) {
                            targetItem.isCopying = false
                        }
                        Task {
                            await ChunkedHistoryManager.shared.updateHistoryItem(targetItem)
                        }
                    }
                }
                
            } catch {
                print("ClipboardManager: Error async copying file to sandbox: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: destinationURL)
                let sourceURL = fileURL
                await MainActor.run {
                    let itemsToDelete = [item] + ClipboardManager.shared.clipboardHistory.filter { $0.isCopying && $0.sourceFileURL == sourceURL && $0.id != item.id }
                    for targetItem in itemsToDelete {
                        ClipboardManager.shared.deleteItem(id: targetItem.id)
                    }
                }
            }
        }
        
        // キャンセル用にタスクを保持
        item.copyTask = copyTask
    }
    
    // MARK: - New Helper function for image duplication check and saving
    func createClipboardItemFromImageData(_ imageData: Data, qrCodeContent: String?, sourceAppPath: String? = nil, isFromAlertConfirmation: Bool = false) async -> ClipboardItem? { // private から internal に変更
        guard let filesDirectory = createClipboardFilesDirectoryIfNeeded() else { return nil }
        
        let newImageSize = UInt64(imageData.count)
        // 画像データのハッシュを計算
        let newImageHash = HashCalculator.calculateImageDataHash(imageData)
        
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
                        self.pendingLargeFileItemsSourceAppPath = sourceAppPath
                        self.showingLargeFileAlert = true // didSetがNSAlertをトリガーする
                        print("DEBUG: createClipboardItemFromImageData - Setting showingLargeFileAlert to true for image data (size: \(newImageSize))")
                    }
                    return nil // まだ保存せず、ユーザーのアラート確認を待つ
                }
            }
        }
        // ここに到達した場合は、アラート表示が不要（内部コピー、またはアラート確認済み、またはサイズ制限内）なので、
        // そのまま保存ロジックに進む
        
        // キャッシュから重複をチェック（ファイルシステム全走査を廃止）
        let duplicateURL = await MainActor.run {
            return self.getFileURL(forHash: newImageHash)
        }
        
        if let duplicateURL = duplicateURL, FileManager.default.fileExists(atPath: duplicateURL.path) {
            print("ClipboardManager: Found duplicate image in sandbox based on file hash cache: \(duplicateURL.lastPathComponent)")
            let sandboxedFileAttributes = getFileAttributes(duplicateURL)
            return ClipboardItem(text: "Image File", date: Date(), filePath: duplicateURL, fileSize: sandboxedFileAttributes.fileSize, fileHash: newImageHash, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath)
        }
        
        // 重複が見つからなかった場合、新しい画像を保存
        let uniqueFileName = "\(UUID().uuidString)-image.png"
        let destinationURL = filesDirectory.appendingPathComponent(uniqueFileName)
        
        do {
            try imageData.write(to: destinationURL)
            print("ClipboardManager: New image saved to sandbox as \(destinationURL.lastPathComponent)")
            
            // 新しく保存された画像のハッシュをキャッシュに登録する
            await MainActor.run {
                self.updateFileHashCache(url: destinationURL, hash: newImageHash)
            }
            
            // ファイルサイズとハッシュもセット
            return ClipboardItem(text: "Image File", date: Date(), filePath: destinationURL, fileSize: newImageSize, fileHash: newImageHash, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath)
        } catch {
            print("ClipboardManager: Error saving new image to sandbox: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - New Helper function for PDF duplication check and saving
    func createClipboardItemFromPDFData(_ pdfData: Data, sourceAppPath: String? = nil, isFromAlertConfirmation: Bool = false) async -> ClipboardItem? {
        guard let filesDirectory = createClipboardFilesDirectoryIfNeeded() else { return nil }
        
        let newPDFSize = UInt64(pdfData.count)
        // PDFデータのハッシュを計算
        let newPDFHash = HashCalculator.calculateImageDataHash(pdfData)
        
        print("DEBUG: createClipboardItemFromPDFData - isPerformingInternalCopy: \(isPerformingInternalCopy), isFromAlertConfirmation: \(isFromAlertConfirmation)")
        
        // MARK: - PDFサイズチェックを追加 (内部コピーでない場合、かつアラート確認からでない場合のみアラートを表示)
        if !isPerformingInternalCopy {
            if !isFromAlertConfirmation {
                if maxFileSizeToSave > 0 && newPDFSize > maxFileSizeToSave {
                    print("ClipboardManager: PDF not saved due to size limit. PDF size: \(newPDFSize) bytes. Limit: \(maxFileSizeToSave) bytes.")
                    return nil
                } else if largeFileAlertThreshold > 0 && newPDFSize > largeFileAlertThreshold {
                    await MainActor.run {
                        // PDFはpendingLargeImageDataを再利用する（タイプを区別する必要があれば新しいプロパティを追加）
                        self.pendingLargeImageData = (pdfData, nil)
                        self.pendingLargeFileItemsSourceAppPath = sourceAppPath
                        self.showingLargeFileAlert = true
                        print("DEBUG: createClipboardItemFromPDFData - Setting showingLargeFileAlert to true for PDF data (size: \(newPDFSize))")
                    }
                    return nil
                }
            }
        }
        
        // キャッシュから重複をチェック（ファイルシステム全走査を廃止）
        let duplicateURL = await MainActor.run {
            return self.getFileURL(forHash: newPDFHash)
        }
        
        if let duplicateURL = duplicateURL, FileManager.default.fileExists(atPath: duplicateURL.path) {
            print("ClipboardManager: Found duplicate PDF in sandbox based on file hash cache: \(duplicateURL.lastPathComponent)")
            let attributes = getFileAttributes(duplicateURL)
            return ClipboardItem(text: "PDF File", date: Date(), filePath: duplicateURL, fileSize: attributes.fileSize, fileHash: newPDFHash, sourceAppPath: sourceAppPath)
        }
        
        // 重複が見つからなかった場合、新しいPDFを保存
        let uniqueFileName = "\(UUID().uuidString)-file.pdf"
        let destinationURL = filesDirectory.appendingPathComponent(uniqueFileName)
        
        do {
            try pdfData.write(to: destinationURL)
            print("ClipboardManager: New PDF saved to sandbox as \(destinationURL.lastPathComponent)")
            
            // 新しく保存されたPDFのハッシュをキャッシュに登録する
            await MainActor.run {
                self.updateFileHashCache(url: destinationURL, hash: newPDFHash)
            }
            
            return ClipboardItem(text: "PDF File", date: Date(), filePath: destinationURL, fileSize: newPDFSize, fileHash: newPDFHash, sourceAppPath: sourceAppPath)
        } catch {
            print("ClipboardManager: Error saving new PDF to sandbox: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Helper function for duplication check
    func isDuplicate(_ newItem: ClipboardItem, of existingItem: ClipboardItem) -> Bool { // private から internal に変更
        // ファイルアイテムの場合、ファイルハッシュで重複を判定（ハッシュが利用可能な場合）
        if let newFilePath = newItem.filePath, let existingFilePath = existingItem.filePath {
            // ファイルハッシュが両方存在する場合、ハッシュで比較
            if let newFileHash = newItem.fileHash, let existingFileHash = existingItem.fileHash {
                return newFileHash == existingFileHash
            }
            // どちらかのハッシュが存在しない場合、ファイルパスとサイズで比較（従来の方法）
            else {
                // ファイルパスとサイズが一致する場合、重複と判定
                // ファイル名（textプロパティ）は表示用なので比較対象に含めない
                return newFilePath == existingFilePath && newItem.fileSize == existingItem.fileSize
            }
        }
        // テキストアイテムの場合、リッチテキストと標準テキストを区別して重複を判定
        else if newItem.filePath == nil && existingItem.filePath == nil {
            // 両方ともリッチテキストの場合、リッチテキストの内容で比較
            if let newRichText = newItem.richText, let existingRichText = existingItem.richText {
                if newRichText.utf8.count != existingRichText.utf8.count { return false }
                return newRichText == existingRichText
            }
            // 片方だけがリッチテキストの場合、重複ではない
            else if (newItem.richText != nil) != (existingItem.richText != nil) {
                return false
            }
            // 両方ともリッチテキストでない（標準テキスト）場合、標準テキストの内容で比較
            else {
                if newItem.text.utf8.count != existingItem.text.utf8.count { return false }
                return newItem.text == existingItem.text
            }
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
        
        // 専用の一時ディレクトリを作成
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClipHoldTemp", isDirectory: true)
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("ClipboardManager: Error creating ClipHoldTemp directory: \(error.localizedDescription)")
            }
        }
        
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
        let tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent("ClipHoldTemp", isDirectory: true)
        print("ClipboardManager: Attempting to clean up temporary files in \(tempDirectoryURL.path)")
        
        do {
            if fileManager.fileExists(atPath: tempDirectoryURL.path) {
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
            }
        } catch {
            print("ClipboardManager: Error getting contents of temporary directory: \(error.localizedDescription)")
        }
        // temporaryFileUrls セットもクリアする
        temporaryFileUrls.removeAll()
    }
}

// フォルダコピー時のキャンセル判定・進捗報告用デリゲート
private class DirectoryCopyDelegate: NSObject, FileManagerDelegate {
    weak var item: ClipboardItem?
    private let totalSize: UInt64
    private var copiedSize: UInt64 = 0
    private var lastReportTime: Date = Date()
    private var lastReportedProgress: Double = 0.0
    
    init(item: ClipboardItem) {
        self.item = item
        self.totalSize = max(item.fileSize ?? 1, 1) // 0除算を防ぐため最低1とする
    }
    
    func fileManager(_ fileManager: FileManager, shouldCopyItemAt srcURL: URL, to dstURL: URL) -> Bool {
        // キャンセルされている場合はfalseを返してコピーをスキップさせる
        if item?.isCopyCancelled == true {
            return false
        }
        
        // 擬似的な進捗報告（ファイル単位）
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: srcURL.path, isDirectory: &isDir) && !isDir.boolValue {
            // ファイルのサイズを取得して足し込む
            if let size = (try? srcURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                copiedSize += UInt64(size)
                
                let currentProgress = Double(copiedSize) / Double(totalSize)
                let now = Date()
                
                // 進捗が一定量(1%)進んだか、前回の報告から一定時間(0.1秒)経過した場合のみUIを更新する（負荷軽減）
                if (currentProgress - lastReportedProgress) > 0.01 || now.timeIntervalSince(lastReportTime) > 0.1 {
                    lastReportTime = now
                    lastReportedProgress = currentProgress
                    
                    // フォルダの場合は -1.0 ではなく、0.0〜1.0の進捗をセットしてプログレスバーを表示させる
                    Task { @MainActor [weak item] in
                        // もし1.0を超えていたら0.99で止める（1.0はコピー完了時にセットされるため）
                        item?.copyProgress = min(currentProgress, 0.99)
                    }
                }
            }
        }
        
        return true
    }
}
