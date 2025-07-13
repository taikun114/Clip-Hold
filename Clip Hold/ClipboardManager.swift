import Foundation
import AppKit
import SwiftUI
import CoreImage // QRコード解析用
import UniformTypeIdentifiers // UTTypeのチェック用
import QuickLookThumbnailing

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var clipboardHistory: [ClipboardItem] = []

    private var saveTask: Task<Void, Never>?
    
    private var temporaryFileUrls: Set<URL> = []
    
    private func scheduleSaveClipboardHistory() {
        // 既存のタスクをキャンセル
        saveTask?.cancel()
        
        // 1秒後に保存を実行する新しいタスクをスケジュール
        saveTask = Task {
            do {
                try await Task.sleep(for: .seconds(1))
                // Taskがキャンセルされていたら実行しない
                guard !Task.isCancelled else { return }
                
                // メインアクターで保存を実行
                await MainActor.run {
                    self.saveClipboardHistory()
                }
            } catch {
                // キャンセルされた場合、エラーは無視する
            }
        }
    }
    
    @AppStorage("maxHistoryToSave") private var maxHistoryToSave: Int = 0
    @AppStorage("maxFileSizeToSave") private var maxFileSizeToSave: Int = 1_000_000_000
    
    @Published var excludedAppIdentifiers: [String] = []
    
    private var pasteboardMonitorTimer: Timer?
    private var lastChangeCount: Int = 0
    private let historyFileName = "clipboardHistory.json"
    private let filesDirectoryName = "ClipboardFiles" // ファイル保存用のサブディレクトリ名
    
    @Published var isMonitoring: Bool = false
    @Published var isPerformingInternalCopy: Bool = false
    
    private var isClipboardMonitoringPausedObserver: NSKeyValueObservation?
    
    
    // MARK: - Initialization
    private init() {
        // ファイル保存ディレクトリの準備
        _ = createClipboardFilesDirectoryIfNeeded()
        
        loadClipboardHistory()
        
        print("ClipboardManager: Initialized with history count: \(clipboardHistory.count)")
        
        // 既存の除外アプリ識別子をロード（UserDefaultsから）
        if let data = UserDefaults.standard.data(forKey: "excludedAppIdentifiersData"),
           let identifiers = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedAppIdentifiers = identifiers
        }
        
        isClipboardMonitoringPausedObserver = UserDefaults.standard.observe(\.isClipboardMonitoringPaused, options: [.initial, .new]) { [weak self] defaults, change in
            guard let self = self else { return }
            let isPaused = defaults.isClipboardMonitoringPaused
            
            // @Published isMonitoring の状態を更新
            self.isMonitoring = !isPaused // isPausedがtrueならisMonitoringはfalse
            
            // 監視状態に応じてタイマーを制御
            if isPaused {
                self.stopMonitoringPasteboard() // UserDefaultsが停止状態ならタイマーを停止
            } else {
                self.startMonitoringPasteboard() // UserDefaultsが再開状態ならタイマーを開始
            }
            print("DEBUG: ClipboardManager: UserDefaults.isClipboardMonitoringPaused changed to \(isPaused). isMonitoring set to \(self.isMonitoring).")
        }
    }
    
    // オブジェクト破棄時に監視を停止する
    deinit {
        isClipboardMonitoringPausedObserver?.invalidate()
        print("DEBUG: ClipboardManager: isClipboardMonitoringPausedObserver invalidated.")
    }
    
    // MARK: - File Management Helpers
    private func getAppSpecificDirectory() -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ClipboardManager: Could not find Application Support directory.")
            return nil
        }
        return directory.appendingPathComponent("ClipHold")
    }
    
    private func createClipboardFilesDirectoryIfNeeded() -> URL? {
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
    
    private func copyFileToAppSandbox(from sourceURL: URL) -> URL? {
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
    
    private func deleteFileFromSandbox(at fileURL: URL) {
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
    private func getFileAttributes(_ url: URL) -> (fileSize: UInt64?, modificationDate: Date?) {
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
    private func extractOriginalFileName(from fileName: String) -> String {
        if let range = fileName.range(of: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-", options: .regularExpression) {
            return String(fileName[range.upperBound...])
        } else {
            return fileName
        }
    }
    
    // ヘルパー関数: ファイルURLからClipboardItemを作成（物理的な重複コピー防止ロジックを含む）
    private func createClipboardItemForFileURL(_ fileURL: URL, qrCodeContent: String? = nil) -> ClipboardItem? {
        let filesDirectory = createClipboardFilesDirectoryIfNeeded()
        
        // 外部ファイルの属性を取得
        let externalFileAttributes = getFileAttributes(fileURL)
        
        // MARK: - ファイルサイズチェックを追加
        if let fileSize = externalFileAttributes.fileSize, maxFileSizeToSave > 0 && fileSize > maxFileSizeToSave {
            print("ClipboardManager: File not saved due to size limit. File size: \(fileSize) bytes. Limit: \(maxFileSizeToSave) bytes.")
            return nil // サイズ制限を超えているためnilを返す
        }
        
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
                        return ClipboardItem(text: displayName, date: Date(), filePath: sandboxedFileURL, fileSize: sandboxedSize, qrCodeContent: qrCodeContent) // 新しいアイテムにもファイルサイズをセット
                    }
                }
            } catch {
                print("ClipboardManager: Error getting contents of sandbox directory for duplicate check: \(error.localizedDescription)")
            }
        }
        
        // 重複ファイルが見つからなかった場合、ファイルをサンドボックスにコピーして新しいアイテムを返す
        if let copiedFileURL = copyFileToAppSandbox(from: fileURL) {
            let displayName = fileURL.lastPathComponent
            return ClipboardItem(text: displayName, date: Date(), filePath: copiedFileURL, fileSize: externalFileAttributes.fileSize, qrCodeContent: qrCodeContent) // 新しいアイテムにもファイルサイズをセット
        }
        
        print("ClipboardManager: Failed to copy external item to sandbox: \(fileURL.lastPathComponent).")
        return nil
    }
    
    // MARK: - New Helper function for image duplication check and saving
    private func createClipboardItemFromImageData(_ imageData: Data, qrCodeContent: String?) -> ClipboardItem? {
        guard let filesDirectory = createClipboardFilesDirectoryIfNeeded() else { return nil }
        
        let newImageSize = UInt64(imageData.count)
        
        // MARK: - 画像サイズチェックを追加
        if maxFileSizeToSave > 0 && newImageSize > maxFileSizeToSave {
            print("ClipboardManager: Image not saved due to size limit. Image size: \(newImageSize) bytes. Limit: \(maxFileSizeToSave) bytes.")
            return nil // サイズ制限を超えているためnilを返す
        }
        
        do {
            let sandboxedFileContents = try FileManager.default.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles)
            
            for sandboxedFileURL in sandboxedFileContents {
                if sandboxedFileURL.lastPathComponent.hasSuffix("-image.png") {
                    let sandboxedFileAttributes = getFileAttributes(sandboxedFileURL)
                    if let sandboxedSize = sandboxedFileAttributes.fileSize, sandboxedSize == newImageSize {
                        print("ClipboardManager: Found duplicate image in sandbox based on file size: \(sandboxedFileURL.lastPathComponent)")
                        return ClipboardItem(text: String(localized: "Image File"), date: Date(), filePath: sandboxedFileURL, fileSize: sandboxedSize, qrCodeContent: qrCodeContent)
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
            return ClipboardItem(text: String(localized: "Image File"), date: Date(), filePath: destinationURL, fileSize: newImageSize, qrCodeContent: qrCodeContent)
        } catch {
            print("ClipboardManager: Error saving new image to sandbox: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Helper function for duplication check
    private func isDuplicate(_ newItem: ClipboardItem, of existingItem: ClipboardItem) -> Bool {
        // ファイルアイテムの場合、ファイルサイズで重複を判定
        if newItem.filePath != nil && existingItem.filePath != nil && newItem.fileSize != nil && newItem.fileSize == existingItem.fileSize {
            return true
        }
        // テキストアイテムの場合、テキスト内容で重複を判定
        if newItem.filePath == nil && existingItem.filePath == nil && newItem.text == existingItem.text {
            return true
        }
        return false
    }
    
    // MARK: - Helper function to add and save a new item
    private func addAndSaveItem(_ newItem: ClipboardItem) {
        // 先頭の項目と重複している場合はスキップ
        if let firstItem = clipboardHistory.first, isDuplicate(newItem, of: firstItem) {
            print("ClipboardManager: Item is a duplicate of the first item, skipping addition.")
            return
        }
        
        self.objectWillChange.send()
        clipboardHistory.insert(newItem, at: 0)
        print("ClipboardManager: New item added to history: \(newItem.text.prefix(50))...")
        
        if let filePath = newItem.filePath {
            generateThumbnail(for: newItem, at: filePath)
        }

        // 最大履歴数を超過した場合の処理を適用
        enforceMaxHistoryCount()
        
        // 履歴を保存
        scheduleSaveClipboardHistory()
    }
    
    // MARK: - Thumbnail Generation
    private func generateThumbnail(for item: ClipboardItem, at fileURL: URL) {
        let thumbnailSize = CGSize(width: 40, height: 40) // メニューバーの表示サイズに合わせる
        let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: thumbnailSize, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
        
        Task.detached {
            do {
                let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                await MainActor.run {
                    item.cachedThumbnailImage = thumbnail.nsImage
                    // MenuBarExtraを更新するため、マネージャー全体を更新通知
                    self.objectWillChange.send()
                }
            } catch {
                print("Failed to generate thumbnail for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Clipboard Monitoring
    func startMonitoringPasteboard() {
        // 新しいタイマーを起動する前に、確実に既存のタイマーを無効化しnilにする
        if let timer = pasteboardMonitorTimer {
            timer.invalidate()
            self.pasteboardMonitorTimer = nil
            print("DEBUG: startMonitoringPasteboard: Invalidated old timer before starting new.")
        }
        
        lastChangeCount = NSPasteboard.general.changeCount
        print("ClipboardManager: Monitoring started. Initial pasteboard change count: \(lastChangeCount)")
        
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else {
                print("DEBUG: Timer fired, but self is nil. Timer will invalidate itself.")
                // selfがnilの場合、タイマーのターゲットがなくなったため、念のためタイマーを無効化
                self?.pasteboardMonitorTimer?.invalidate()
                return
            }
            // isMonitoring が true の場合にのみ checkPasteboard() を実行
            guard self.isMonitoring else {
                print("DEBUG: Timer fired, but isMonitoring is false. Skipping check.")
                return
            }
            self.checkPasteboard()
        }
        RunLoop.main.add(newTimer, forMode: .common) // メインRunLoopに明示的に追加
        self.pasteboardMonitorTimer = newTimer // 新しいタイマーをプロパティに保持
        isMonitoring = true
        print("ClipboardManager: クリップボード監視を開始しました。isMonitoring: \(isMonitoring)")
    }
    
    func stopMonitoringPasteboard() {
        if let timer = pasteboardMonitorTimer {
            timer.invalidate()
            self.pasteboardMonitorTimer = nil
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
        } else {
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
        }
        isMonitoring = false
        print("ClipboardManager: Monitoring stopped. isMonitoring: \(self.isMonitoring)")
    }
    
    private func checkPasteboard() {
        guard isMonitoring else {
            print("DEBUG: checkPasteboard: isMonitoring is false, returning.")
            return
        }
        guard !isPerformingInternalCopy else {
            print("DEBUG: checkPasteboard: isPerformingInternalCopy is true, skipping monitoring.")
            return
        }
        
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            if let activeAppBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                guard !excludedAppIdentifiers.contains(activeAppBundleIdentifier) else {
                    return // 除外アプリからのコピーは無視
                }
            }
            
            // 1. ファイルURLを読み込もうとする（最優先）
            // readObjectsがNSURLを返す場合と、stringがfileURLを返す場合を両方チェック
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
               let firstFileURL = fileURLs.first {
                
                var qrCodeContent: String? = nil
                
                // コピーされたファイルが画像であるかチェック
                if let fileUTI = try? firstFileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
                   fileUTI.conforms(to: .image) {
                    if let image = NSImage(contentsOf: firstFileURL) {
                        qrCodeContent = decodeQRCode(from: image)
                    }
                }
                
                if let newItem = createClipboardItemForFileURL(firstFileURL, qrCodeContent: qrCodeContent) {
                    addAndSaveItem(newItem)
                }
                return // ファイルの有無に関わらず、ファイルパスのチェックが完了したので終了
            } else if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue]),
                      let stringURL = pasteboard.string(forType: .fileURL),
                      let url = URL(string: stringURL) {
                
                var qrCodeContent: String? = nil
                
                if let fileUTI = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                   fileUTI.conforms(to: .image) {
                    if let image = NSImage(contentsOf: url) {
                        qrCodeContent = decodeQRCode(from: image)
                    }
                }
                
                if let newItem = createClipboardItemForFileURL(url, qrCodeContent: qrCodeContent) {
                    addAndSaveItem(newItem)
                }
                return // ファイルの有無に関わらず、ファイルパスのチェックが完了したので終了
            }
            
            // 2. ファイルURLがなければ、画像データを直接読み込もうとする
            var imageDataFromPasteboard: Data?
            var imageFromPasteboard: NSImage?
            
            // ネイティブな画像データを優先して読み込む
            if let tiffData = pasteboard.data(forType: .tiff) {
                imageDataFromPasteboard = tiffData
                imageFromPasteboard = NSImage(data: tiffData)
                print("ClipboardManager: Image data detected on pasteboard (TIFF).")
            } else if let pngData = pasteboard.data(forType: .png) {
                imageDataFromPasteboard = pngData
                imageFromPasteboard = NSImage(data: pngData)
                print("ClipboardManager: Image data detected on pasteboard (PNG).")
            } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                // どちらも見つからない場合、一般的なNSImageオブジェクトのTIFF表現を試みる
                imageDataFromPasteboard = image.tiffRepresentation
                imageFromPasteboard = image
                if imageDataFromPasteboard != nil {
                    print("ClipboardManager: Image data detected on pasteboard (from generic NSImage).")
                }
            }
            
            if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                let qrCodeContent = decodeQRCode(from: image)
                
                if let newItem = createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent) {
                    addAndSaveItem(newItem)
                }
                return // 画像の有無に関わらず、画像データのチェックが完了したので終了
            }
            
            // 3. ファイルも画像もなかった場合、文字列として処理を試みる
            if let newString = pasteboard.string(forType: .string) {
                let newItem = ClipboardItem(text: newString, date: Date(), filePath: nil, fileSize: nil)
                addAndSaveItem(newItem)
                return
            }
            
            print("ClipboardManager: No supported item type found on pasteboard.")
        }
    }
    
    
    // MARK: - QR Code Decoding
    public func decodeQRCode(from image: NSImage) -> String? {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
            print("Failed to convert NSImage to CIImage.")
            return nil
        }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage)
        
        if let qrFeature = features?.first as? CIQRCodeFeature {
            return qrFeature.messageString
        }
        return nil
    }
    
    // MARK: - History Management
    func clearAllHistory() {
        // 関連するファイルをすべて削除
        for item in clipboardHistory {
            if let filePath = item.filePath {
                deleteFileFromSandbox(at: filePath)
            }
        }
        // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
        self.objectWillChange.send()
        clipboardHistory = []
        print("ClipboardManager: All history cleared.")
    }
    
    func deleteItem(id: UUID) {
        if let index = clipboardHistory.firstIndex(where: { $0.id == id }) {
            let itemToDelete = clipboardHistory[index]
            if let filePath = itemToDelete.filePath {
                deleteFileFromSandbox(at: filePath)
            }
            // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
            self.objectWillChange.send()
            clipboardHistory.remove(at: index)
            print("ClipboardManager: Item deleted. Total history: \(clipboardHistory.count)")

            scheduleSaveClipboardHistory()
            
            cleanUpTemporaryFiles()
        }
    }
    
    
    // MARK: - History Import/Export (ClipboardHistoryImporterExporterが使うメソッドを定義)
    func importHistory(from items: [ClipboardItem]) {
        // バックグラウンドで処理することでUIのブロックを防ぐ
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // インポートされたアイテムのファイルパスが指すファイルが実際に存在するかを確認し、存在しない場合は削除
            let validItems = items.filter { item in
                if let filePath = item.filePath {
                    return FileManager.default.fileExists(atPath: filePath.path)
                }
                return true // ファイルパスがない場合は常に有効とみなす
            }
            
            // 1. 重複を避けて新しいアイテムを結合
            let existingItemsSet = Set(self.clipboardHistory.map {
                let pathComponent = $0.filePath?.lastPathComponent ?? "nil"
                return "\($0.text)-\(pathComponent)"
            })
            
            let newItems = validItems.filter { item in
                let pathComponent = item.filePath?.lastPathComponent ?? "nil"
                return !existingItemsSet.contains("\(item.text)-\(pathComponent)")
            }
            
            // 2. 既存の履歴に新しいアイテムを追加 (メインスレッドでPublishedプロパティを更新)
            DispatchQueue.main.async {
                // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
                self.objectWillChange.send()
                self.clipboardHistory.append(contentsOf: newItems)
                
                // 3. 全体を日付（date）の降順でソート
                self.clipboardHistory.sort { $0.date > $1.date }
                
                // 4. 最大履歴数を超過した場合の処理
                self.enforceMaxHistoryCount()
                
                for item in self.clipboardHistory where item.filePath != nil {
                    self.generateThumbnail(for: item, at: item.filePath!)
                }

                print("ClipboardManager: 履歴をインポートしました。追加された項目数: \(newItems.count), 総履歴数: \(self.clipboardHistory.count)")
                
                self.scheduleSaveClipboardHistory()
            }
        }
    }
    
    
    // MARK: - Max History Count Enforcement
    func enforceMaxHistoryCount() {
        print("DEBUG: enforceMaxHistoryCount() - maxHistoryToSave: \(self.maxHistoryToSave), 現在の履歴数: \(self.clipboardHistory.count)")
        if self.maxHistoryToSave > 0 && self.clipboardHistory.count > self.maxHistoryToSave {
            // 削除されるアイテムから関連するファイルも削除
            let itemsToRemove = self.clipboardHistory.suffix(self.clipboardHistory.count - self.maxHistoryToSave)
            for item in itemsToRemove {
                if let filePath = item.filePath {
                    deleteFileFromSandbox(at: filePath)
                }
            }
            // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
            self.objectWillChange.send()
            self.clipboardHistory.removeLast(self.clipboardHistory.count - self.maxHistoryToSave)
            print("DEBUG: enforceMaxHistoryCount() - 履歴を \(self.maxHistoryToSave) に調整しました。現在の履歴数: \(self.clipboardHistory.count)")
        } else if self.maxHistoryToSave == 0 { // 無制限の場合
            print("DEBUG: enforceMaxHistoryCount() - 無制限設定のため調整なし。")
        }
    }
    
    // MARK: - Excluded App Management
    func updateExcludedAppIdentifiers(_ identifiers: [String]) {
        // 現在のリストと新しいリストが同じでなければ更新する
        if self.excludedAppIdentifiers != identifiers {
            // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
            self.objectWillChange.send()
            self.excludedAppIdentifiers = identifiers
            print("ClipboardManager: Excluded app identifiers updated. Count: \(identifiers.count)")
        }
    }
    
    // MARK: - History Persistence (ファイルシステムに保存)
    private func saveClipboardHistory() {
        guard let appSpecificDirectory = getAppSpecificDirectory() else {
            print("ClipboardManager: Could not get app-specific directory for saving.")
            return
        }
        
        let fileURL = appSpecificDirectory.appendingPathComponent(historyFileName)
        
        do {
            // ディレクトリが存在しない場合は作成 (getAppSpecificDirectoryとcreateClipboardFilesDirectoryIfNeededで既に作成されるはずだが念のため)
            if !FileManager.default.fileExists(atPath: appSpecificDirectory.path) {
                try FileManager.default.createDirectory(at: appSpecificDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            let encoder = JSONEncoder()
            // JSONEncoder には dateEncodingStrategy を使用します。
            encoder.dateEncodingStrategy = .iso8601 // 日付のエンコード形式を合わせる (ClipboardHistoryDocumentと一致させる)
            encoder.outputFormatting = .prettyPrinted // 可読性のために整形 (Optional)
            
            let data = try encoder.encode(clipboardHistory)
            try data.write(to: fileURL)
            print("ClipboardManager: Clipboard history saved to file: \(fileURL.path)")
        } catch {
            print("ClipboardManager: Error saving clipboard history to file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - History Loading (ファイルシステムからロード)
    public func loadClipboardHistory() {
        guard let appSpecificDirectory = getAppSpecificDirectory() else {
            print("ClipboardManager: Could not get app-specific directory for loading.")
            return
        }
        
        let fileURL = appSpecificDirectory.appendingPathComponent(historyFileName)
        
        // ファイルが存在しない場合は早期リターン
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ClipboardManager: Clipboard history file not found, starting with empty history.")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            // JSONDecoder には dateEncodingStrategy を使用します。
            decoder.dateDecodingStrategy = .iso8601 // 日付のデコード形式を合わせる (ClipboardHistoryDocumentと一致させる)
            
            var loadedHistory = try decoder.decode([ClipboardItem].self, from: data)
            
            // ロードした履歴アイテムのfilePathが指すファイルが実際に存在するかを確認し、存在しない場合は削除
            loadedHistory.removeAll { item in
                if let filePath = item.filePath {
                    if !FileManager.default.fileExists(atPath: filePath.path) {
                        print("ClipboardManager: Missing file for history item: \(filePath.lastPathComponent). Removing item from history.")
                        return true // 履歴から削除
                    }
                }
                return false // 履歴に残す
            }
            
            self.clipboardHistory = loadedHistory
            
            for item in self.clipboardHistory where item.filePath != nil {
                generateThumbnail(for: item, at: item.filePath!)
            }

            print("ClipboardManager: Clipboard history loaded from file. Count: \(clipboardHistory.count), Size: \(data.count) bytes.")
        } catch {
            print("ClipboardManager: Error loading clipboard history from file: \(error.localizedDescription)")
        }
    }
    
    func copyItemToClipboard(_ item: ClipboardItem) {
        // 古い一時ファイルをすべて削除する
        cleanUpTemporaryFiles()

        isPerformingInternalCopy = true
        print("DEBUG: copyItemToClipboard: isPerformingInternalCopy = true")
        
        NSPasteboard.general.clearContents()
        var success = false
        
        if let filePath = item.filePath {
            // ファイルパスが存在する場合
            if let tempURL = createTemporaryCopy(for: item) {
                // 一時的なファイルリンクのURLをクリップボードに書き込む
                if NSPasteboard.general.writeObjects([tempURL as NSURL]) {
                    print("クリップボードにファイルがコピーされました (元のファイル名): \(tempURL.lastPathComponent)")
                    success = true
                } else {
                    print("クリップボードに一時ファイル (NSURL) をコピーできませんでした。")
                    // フォールバックとして、元のサンドボックスURLをコピー
                    if NSPasteboard.general.writeObjects([filePath as NSURL]) {
                        print("フォールバック: サンドボックス内のファイルがコピーされました。")
                        success = true
                    }
                }
            }
        }
        
        if !success {
            // ファイルコピーが失敗した場合、またはファイルパスがない場合、テキストをコピー
            // item.text は非オプショナルなので、直接使用する
            if NSPasteboard.general.setString(item.text, forType: .string) {
                print("クリップボードにテキストがコピーされました: \(item.text.prefix(20))...")
                success = true
            }
        }
        
        isPerformingInternalCopy = false
        print("DEBUG: copyItemToClipboard: isPerformingInternalCopy = false")
    }

    // MARK: - ファイルコピーのためのヘルパー
    // 元のファイル名で一時的なファイルを作成する
    private func createTemporaryCopy(for item: ClipboardItem) -> URL? {
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
            temporaryFileUrls.insert(tempFileURL)
            
            return tempFileURL
        } catch {
            print("ClipboardManager: Error creating temporary file copy: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 一時ファイルクリーンアップ
    private func cleanUpTemporaryFiles() {
        print("ClipboardManager: Cleaning up \(temporaryFileUrls.count) temporary files.")
        for fileURL in temporaryFileUrls {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("ClipboardManager: Removed temporary file: \(fileURL.lastPathComponent)")
            } catch {
                print("ClipboardManager: Error removing temporary file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        temporaryFileUrls.removeAll()
    }
}

extension ClipboardManager {
    // 履歴にテキストアイテムを明示的に追加するメソッド
    // クリップボード監視以外からの入力 (例: ドラッグ&ドロップ) に使用
    func addTextItem(text: String) {
        // 同じ内容のものが連続して追加された場合はスキップ (ファイルパスがないテキストアイテムとしてのみチェック)
        if let lastItem = clipboardHistory.first, lastItem.text == text, lastItem.filePath == nil {
            print("ClipboardManager: Duplicate text item detected via addTextItem, skipping. Text: \(text.prefix(50))...\n")
            return
        }

        self.objectWillChange.send() // UI更新を促す
        let newItem = ClipboardItem(text: text, date: Date(), filePath: nil, fileSize: nil) // ファイルパスとサイズはnil
        clipboardHistory.insert(newItem, at: 0) // 先頭に追加
        print("ClipboardManager: New text item added via addTextItem. Total history: \(clipboardHistory.count)")

        // 最大履歴数を超過した場合の処理を適用
        enforceMaxHistoryCount()

        scheduleSaveClipboardHistory()
    }
}
