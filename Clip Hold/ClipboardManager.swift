// ClipboardManager.swift
import Foundation
import AppKit
import SwiftUI
import CoreImage // QRコード解析用

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var clipboardHistory: [ClipboardItem] = []

    private var saveTask: Task<Void, Never>?

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

    @AppStorage("maxHistoryToSave") private var maxHistoryToSave: Int = 0 // 無制限を0で表す (GeneralSettingsViewとキーを合わせる)

    @AppStorage("scanQRCodeImage") private var scanQRCodeImage = false

    @Published var excludedAppIdentifiers: [String] = []

    private var pasteboardMonitorTimer: Timer?
    private var lastChangeCount: Int = 0
    private let historyFileName = "clipboardHistory.json"
    private let filesDirectoryName = "ClipboardFiles" // ファイル保存用のサブディレクトリ名

    @Published var isMonitoring: Bool = false
    @Published var isPerformingInternalCopy: Bool = false // <--- 新しく追加するプロパティ

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
    private func createClipboardItemForFileURL(_ fileURL: URL) -> ClipboardItem? {
        let filesDirectory = createClipboardFilesDirectoryIfNeeded()
        let filesDirectoryPath = filesDirectory?.path ?? ""
        
        if fileURL.path.hasPrefix(filesDirectoryPath) {
            // 内部ファイルの場合（履歴から再コピーされたケースなど）
            print("ClipboardManager: Detected file from our sandbox: \(fileURL.lastPathComponent)")
            let displayName = extractOriginalFileName(from: fileURL.lastPathComponent)
            return ClipboardItem(text: displayName, date: Date(), filePath: fileURL)
        } else {
            // 外部ファイルの場合（Finderなどからコピーされたケース）
            print("ClipboardManager: External file detected: \(fileURL.lastPathComponent)")
            
            let externalFileAttributes = getFileAttributes(fileURL) // 外部ファイルの属性を取得
            
            // サンドボックス内の既存ファイルを走査し、重複をチェック
            if let filesDirectory = filesDirectory { // filesDirectory が nil でないことを確認
                do {
                    let sandboxedFileContents = try FileManager.default.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    
                    for sandboxedFileURL in sandboxedFileContents {
                        let sandboxedFileAttributes = getFileAttributes(sandboxedFileURL)
                        
                        // ファイルサイズと最終変更日時が一致する場合、重複とみなす
                        if let externalSize = externalFileAttributes.fileSize,
                           let externalModDate = externalFileAttributes.modificationDate,
                           let sandboxedSize = sandboxedFileAttributes.fileSize,
                           let sandboxedModDate = sandboxedFileAttributes.modificationDate,
                           externalSize == sandboxedSize && externalModDate == sandboxedModDate {
                            
                            print("ClipboardManager: Found potential duplicate in sandbox based on size/date: \(sandboxedFileURL.lastPathComponent)")
                            // 重複が見つかった場合、既存のサンドボックスファイルを参照する新しいアイテムを返す
                            let displayName = extractOriginalFileName(from: fileURL.lastPathComponent) // 表示名はFinderからコピーされた元のファイル名を使用
                            return ClipboardItem(text: displayName, date: Date(), filePath: sandboxedFileURL)
                        }
                    }
                } catch {
                    print("ClipboardManager: Error getting contents of sandbox directory for duplicate check: \(error.localizedDescription)")
                }
            }
            
            // 重複ファイルが見つからなかった場合、ファイルをサンドボックスにコピーして新しいアイテムを返す
            if let copiedFileURL = copyFileToAppSandbox(from: fileURL) {
                let displayName = extractOriginalFileName(from: fileURL.lastPathComponent)
                return ClipboardItem(text: displayName, date: Date(), filePath: copiedFileURL)
            } else {
                print("ClipboardManager: Failed to copy external file to sandbox: \(fileURL.lastPathComponent).")
                return nil
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
            print("DEBUG: stopMonitoringPasteboard: Timer invalidated and nilled.")
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

            var newItemToConsider: ClipboardItem? = nil
            
            // 1. ファイルURLを読み込もうとする
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
               let firstFileURL = fileURLs.first {
                newItemToConsider = createClipboardItemForFileURL(firstFileURL)
            } else if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue]),
                      let stringURL = pasteboard.string(forType: .fileURL),
                      let url = URL(string: stringURL) {
                newItemToConsider = createClipboardItemForFileURL(url)
            }
            
            // 2. ファイルでなかった場合、文字列として処理を試みる
            if newItemToConsider == nil, let newString = pasteboard.string(forType: .string) {
                newItemToConsider = ClipboardItem(text: newString, date: Date(), filePath: nil)
            }
            
            // 3. ファイルも文字列もなかった場合、QRコードスキャンが有効なら画像として処理
            if newItemToConsider == nil, scanQRCodeImage, let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                print("ClipboardManager: Image detected on pasteboard. Attempting QR code decoding...")
                if let decodedText = decodeQRCode(from: image) {
                    newItemToConsider = ClipboardItem(text: decodedText, date: Date(), filePath: nil)
                    print("ClipboardManager: QR code successfully decoded: \(decodedText.prefix(50))...")
                } else {
                    print("ClipboardManager: Image detected but no QR code found or decoding failed.")
                }
            }

            // --- 統合された重複チェックと履歴への追加 ---
            if let newItem = newItemToConsider {
                if let lastItem = clipboardHistory.first {
                    var isDuplicate = false
                    
                    // 両方がファイルアイテムの場合
                    if let newFilePath = newItem.filePath, let lastFilePath = lastItem.filePath {
                        if newFilePath == lastFilePath {
                            isDuplicate = true
                            print("ClipboardManager: Duplicate file item detected (same path), skipping history addition.")
                        }
                    }
                    // 両方がテキストアイテムの場合 (filePathがnil)
                    else if newItem.filePath == nil && lastItem.filePath == nil {
                        if newItem.text == lastItem.text {
                            isDuplicate = true
                            print("ClipboardManager: Duplicate text item detected, skipping history addition.")
                        }
                    }
                    // 上記以外の場合（例：一方がファイルで他方がテキスト、または内容が異なる）は重複とみなさない
                    
                    if !isDuplicate {
                        self.objectWillChange.send() // UI更新を促す
                        clipboardHistory.insert(newItem, at: 0) // 先頭に追加
                        print("ClipboardManager: New item added to history: \(newItem.text.prefix(50))...")
                    }
                } else {
                    // 履歴が空の場合、最初の項目として常に追加
                    self.objectWillChange.send() // UI更新を促す
                    clipboardHistory.insert(newItem, at: 0) // 先頭に追加
                    print("ClipboardManager: First item added to history: \(newItem.text.prefix(50))...")
                }
            } else {
                print("ClipboardManager: No supported item type found on pasteboard or failed to process.")
            }

            // 最大履歴数を超過した場合の処理を適用
            enforceMaxHistoryCount()
            
            if newItemToConsider != nil {
                scheduleSaveClipboardHistory()
            }
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
        }
    }
    
    // MARK: - History Import/Export (ClipboardHistoryImporterExporterが使うメソッドを定義)
    func importHistory(from items: [ClipboardItem]) {
        // バックグラウンドで処理することでUIのブロックを防ぐ
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // インポートされたアイテムのファイルパスを検証し、存在しないファイルを削除
            let validItems = items.filter { item in
                if let filePath = item.filePath {
                    return FileManager.default.fileExists(atPath: filePath.path)
                }
                return true // ファイルパスがない場合は常に有効とみなす
            }

            // 1. 重複を避けて新しいアイテムを結合
            // テキスト内容とファイルパスの両方が重複するアイテムは追加しない
            let existingItemsSet = Set(self.clipboardHistory.map { "\($0.text)-\($0.filePath?.lastPathComponent ?? "nil")" })
            let newItems = validItems.filter { item in
                !existingItemsSet.contains("\(item.text)-\(item.filePath?.lastPathComponent ?? "nil")")
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
    private func loadClipboardHistory() {
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
            // JSONDecoder には dateDecodingStrategy を使用します。
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
            print("ClipboardManager: Clipboard history loaded from file. Count: \(clipboardHistory.count), Size: \(data.count) bytes.")
        } catch {
            print("ClipboardManager: Error loading clipboard history from file: \(error.localizedDescription)")
        }
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
        let newItem = ClipboardItem(text: text, date: Date(), filePath: nil) // ファイルパスはnil
        clipboardHistory.insert(newItem, at: 0) // 先頭に追加
        print("ClipboardManager: New text item added via addTextItem. Total history: \(clipboardHistory.count)")

        // 最大履歴数を超過した場合の処理を適用
        enforceMaxHistoryCount()
        
        scheduleSaveClipboardHistory()
    }
}
