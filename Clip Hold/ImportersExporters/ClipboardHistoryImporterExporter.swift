import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI
import Compression
import System
import AppleArchive

// アラート表示のためのIdentifiableな構造体
struct AlertContent: Identifiable {
    let id = UUID()
    let title: Text
    let message: Text
    let isSuccess: Bool
    var onDismiss: (() -> Void)? = nil
    
    static func success(_ message: Text, onDismiss: (() -> Void)? = nil) -> AlertContent {
        AlertContent(title: Text("成功"), message: message, isSuccess: true, onDismiss: onDismiss)
    }
    
    static func error(title: Text = Text("エラー"), _ message: Text, onDismiss: (() -> Void)? = nil) -> AlertContent {
        AlertContent(title: title, message: message, isSuccess: false, onDismiss: onDismiss)
    }
}

struct ConfirmationAlert: Identifiable {
    let id = UUID()
    let title: Text
    let message: Text
    let primaryButtonTitle: Text
    let primaryAction: () -> Void
    let secondaryButtonTitle: Text
    let secondaryAction: () -> Void
}

struct ExportMetadata: Codable {
    var pinnedItemID: UUID?
    var appVersion: String?
    var totalUncompressedSize: Int64?
}

class ClipboardHistoryImporterExporter: ObservableObject {
    @Published var isShowingExportConfigSheet = false
    @Published var currentAlert: AlertContent?
    @Published var sheetAlert: AlertContent?
    @Published var currentConfirmationAlert: ConfirmationAlert?
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = -1.0 // -1.0 means indeterminate
    @Published var exportStatusText: String = ""
    
    @Published var importProgress: Double = -1.0 // -1.0 means indeterminate
    @Published var importStatusText: String = ""
    
    @Published var isCancelling: Bool = false
    
    private var exportTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var currentProcess: Process?
    
    func cancelExport() {
        Task { @MainActor in
            self.isCancelling = true
            self.exportStatusText = "キャンセル中..."
            self.exportProgress = -1.0
            
            self.currentProcess?.terminate()
            self.exportTask?.cancel()
        }
    }
    
    func cancelImport() {
        Task { @MainActor in
            self.isCancelling = true
            self.importStatusText = "キャンセル中..."
            self.importProgress = -1.0
            
            self.currentProcess?.terminate()
            self.importTask?.cancel()
        }
    }
    
    func handleImportResult(_ result: Result<[URL], Error>, into clipboardManager: ClipboardManager, onComplete: @escaping (UInt64) -> Void) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                Task { @MainActor in
                    self.currentAlert = .error(Text("選択されたファイルがありません。"))
                }
                print("No file selected.")
                return
            }
            
            Task { @MainActor in
                self.isExporting = true
                self.importProgress = -1.0 // 準備中・展開中はIndeterminate
                self.importStatusText = "準備中..."
                clipboardManager.stopMonitoringPasteboard()
                clipboardManager.isExporting = true // インポート中もクリップボード監視を停止するため
            }
            
            importTask = Task.detached {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                        print("DEBUG: Security-scoped resource access stopped for URL: \(url.path)")
                    }
                    
                    Task { @MainActor in
                        if self.isCancelling {
                            self.sheetAlert = .error(Text("インポートがキャンセルされました。"), onDismiss: {
                                self.isExporting = false
                            })
                            self.isCancelling = false
                        }
                        clipboardManager.startMonitoringPasteboard()
                        clipboardManager.isExporting = false
                    }
                }
                
                if !accessed {
                    await MainActor.run {
                        self.sheetAlert = .error(Text("ファイルへのアクセス権限がありません。ファイルパス: \(url.lastPathComponent)"), onDismiss: {
                            self.isExporting = false
                        })
                    }
                    print("DEBUG: Security-scoped resource access failed for URL: \(url.path)")
                    return
                }
                
                do {
                    var importedHistory: [ClipboardItem] = []
                    var importedMetadata: ExportMetadata?
                    let fileExtension = url.pathExtension.lowercased()
                    
                    if fileExtension == "cliphold" {
                        let fileManager = FileManager.default
                        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
                        defer { try? fileManager.removeItem(at: tempDir) }
                        
                        await MainActor.run { self.importStatusText = "ファイルを展開中..." }
                        
                        let filePath = FilePath(url.path)
                        guard let fileStream = ArchiveByteStream.fileStream(path: filePath, mode: .readOnly, options: [], permissions: FilePermissions(rawValue: 0o644)) else {
                            throw NSError(domain: "AppleArchiveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "ファイルを開けませんでした。"])
                        }
                        
                        var archiveExtracted = false
                        
                        let progressTask = Task {
                            let localFileManager = FileManager.default
                            var exactTotalSize: Int64? = nil
                            
                            while !Task.isCancelled {
                                do {
                                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                                    
                                    if exactTotalSize == nil {
                                        let hiddenMetadataURL = tempDir.appendingPathComponent(".metadata.json")
                                        if localFileManager.fileExists(atPath: hiddenMetadataURL.path), let data = try? Data(contentsOf: hiddenMetadataURL) {
                                            if let meta = try? JSONDecoder().decode(ExportMetadata.self, from: data), let actualSize = meta.totalUncompressedSize {
                                                exactTotalSize = actualSize
                                            }
                                        }
                                    }
                                    
                                    let currentTotal = exactTotalSize
                                    let targetProgress: Double
                                    if let totalSize = currentTotal, totalSize > 0 {
                                        let currentSize = self.calculateDirectorySize(url: tempDir, fileManager: localFileManager)
                                        let progress = Double(currentSize) / Double(totalSize)
                                        targetProgress = min(0.40, progress * 0.40)
                                    } else {
                                        targetProgress = -1.0
                                    }
                                    
                                    await MainActor.run {
                                        if !self.isCancelling {
                                            self.importProgress = targetProgress
                                        }
                                    }
                                } catch {
                                }
                            }
                        }
                        
                        do {
                            guard let decompressionStream = ArchiveByteStream.decompressionStream(readingFrom: fileStream) else {
                                throw NSError(domain: "AppleArchiveError", code: 2, userInfo: [NSLocalizedDescriptionKey: "展開ストリームの作成に失敗しました。"])
                            }
                            guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressionStream) else {
                                throw NSError(domain: "AppleArchiveError", code: 3, userInfo: [NSLocalizedDescriptionKey: "デコードストリームの作成に失敗しました。"])
                            }
                            
                            let destPath = FilePath(tempDir.path)
                            guard let extractStream = ArchiveStream.extractStream(extractingTo: destPath, flags: []) else {
                                throw NSError(domain: "AppleArchiveError", code: 4, userInfo: [NSLocalizedDescriptionKey: "出力ストリームの作成に失敗しました。"])
                            }
                            
                            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
                            
                            try extractStream.close()
                            try decodeStream.close()
                            try decompressionStream.close()
                            try fileStream.close()
                            
                            archiveExtracted = true
                        } catch {
                            try? fileStream.close()
                            print("AppleArchive extraction failed: \(error)")
                        }
                        
                        progressTask.cancel()
                        
                        if Task.isCancelled { throw CancellationError() }
                        
                        if archiveExtracted {
                            let jsonURL = tempDir.appendingPathComponent("history.json")
                            var data = try Data(contentsOf: jsonURL)
                            
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            importedHistory = try decoder.decode([ClipboardItem].self, from: data)
                            data = Data() // 早めにメモリを解放
                            
                            await MainActor.run { self.importStatusText = "ファイルとフォルダを復元中..." }
                            
                            // ファイルのコピー
                            if let targetFilesDir = clipboardManager.createClipboardFilesDirectoryIfNeeded() {
                                let sourceFilesDir = tempDir.appendingPathComponent("HistoryFiles")
                                if fileManager.fileExists(atPath: sourceFilesDir.path) {
                                    let files = try fileManager.contentsOfDirectory(atPath: sourceFilesDir.path)
                                    let totalFiles = files.count
                                    var copiedFiles = 0
                                    
                                    for fileName in files {
                                        if Task.isCancelled { return }
                                        
                                        let sourceURL = sourceFilesDir.appendingPathComponent(fileName)
                                        let destURL = targetFilesDir.appendingPathComponent(fileName)
                                        
                                        if !fileManager.fileExists(atPath: destURL.path) {
                                            try? fileManager.copyItem(at: sourceURL, to: destURL)
                                        }
                                        copiedFiles += 1
                                        
                                        if copiedFiles % 100 == 0 || copiedFiles == totalFiles {
                                            let progress = 0.40 + (Double(copiedFiles) / Double(max(1, totalFiles))) * 0.40
                                            await MainActor.run { self.importProgress = progress } // 展開40%〜コピー完了で80%
                                        }
                                    }
                                }
                            }
                            let hiddenMetadataURL = tempDir.appendingPathComponent(".metadata.json")
                            if fileManager.fileExists(atPath: hiddenMetadataURL.path) {
                                if let metadataData = try? Data(contentsOf: hiddenMetadataURL) {
                                    importedMetadata = try? JSONDecoder().decode(ExportMetadata.self, from: metadataData)
                                }
                            }
                        } else {
                            // アーカイブの展開に失敗した場合、単一のJSONファイルである可能性を考慮してフォールバック
                            let data = try Data(contentsOf: url)
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            importedHistory = try decoder.decode([ClipboardItem].self, from: data)
                        }
                    } else {
                        // 従来のJSON
                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        
                        importedHistory = try decoder.decode([ClipboardItem].self, from: data)
                    }
                    
                    // 履歴を古い順に並べ替え
                    importedHistory.sort { $0.date < $1.date }
                    
                    let importedPinnedItem = importedMetadata?.pinnedItemID.flatMap { id in importedHistory.first(where: { $0.id == id }) }
                    let historyToImport = importedHistory
                    
                    await MainActor.run {
                        clipboardManager.importHistory(from: historyToImport)
                        self.importStatusText = "保存フォルダの総容量を計算中..."
                        self.importProgress = 0.80
                    }
                    
                    // APFS等のファイルシステムで大量コピー直後にファイルサイズが正確に取得できない問題を防ぐため、
                    // 「計算中」の表示の裏で意図的に待機する
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    
                    let newTotalSize = await clipboardManager.recalculateAllFolderSizes { progress, _ in
                        if !Task.isCancelled {
                            let scaledProgress = 0.80 + (progress * 0.20)
                            await MainActor.run {
                                if !self.isCancelling {
                                    self.importProgress = scaledProgress
                                }
                            }
                        }
                    }
                    
                    let finalTotalSize = newTotalSize
                    await MainActor.run {
                        self.importProgress = 1.0
                        
                        // ピン留めの処理
                        if let pinnedItem = importedPinnedItem,
                           clipboardManager.clipboardHistory.contains(where: { $0.id == pinnedItem.id }) {
                            
                            let newImportedPinnedID = pinnedItem.id
                            let currentPinnedID = clipboardManager.pinnedItemID
                            if currentPinnedID == nil {
                                clipboardManager.pinnedItemID = newImportedPinnedID
                                self.sheetAlert = .success(Text("クリップボード履歴が正常にインポートされ、ピン留め項目も復元されました。"), onDismiss: { self.isExporting = false })
                            } else if currentPinnedID != newImportedPinnedID {
                                self.currentConfirmationAlert = ConfirmationAlert(
                                    title: Text("ピン留めの競合"),
                                    message: Text("インポートしたファイルにピン留め項目がありましたが、現在このデバイスでは別の項目がピン留めされています。インポートしたピン留め項目に置き換えますか？"),
                                    primaryButtonTitle: Text("置き換える"),
                                    primaryAction: {
                                        clipboardManager.pinnedItemID = newImportedPinnedID
                                        self.sheetAlert = .success(Text("クリップボード履歴が正常にインポートされ、ピン留め項目が置き換えられました。"), onDismiss: { self.isExporting = false })
                                    },
                                    secondaryButtonTitle: Text("そのままにする"),
                                    secondaryAction: {
                                        self.sheetAlert = .success(Text("クリップボード履歴が正常にインポートされました。"), onDismiss: { self.isExporting = false })
                                    }
                                )
                            } else {
                                self.sheetAlert = .success(Text("クリップボード履歴が正常にインポートされました。"), onDismiss: { self.isExporting = false })
                            }
                        } else {
                            self.sheetAlert = .success(Text("クリップボード履歴が正常にインポートされました。"), onDismiss: { self.isExporting = false })
                        }
                        
                        onComplete(finalTotalSize)
                        
                        print("Clipboard history imported successfully: \(url.path)")
                    }
                    
                } catch {
                    if Task.isCancelled { return }
                    
                    await MainActor.run {
                        self.sheetAlert = .error(title: Text("インポートエラー"), Text("インポートしようとしたファイルは壊れているか、読み取れないためインポートできませんでした。"), onDismiss: {
                            self.isExporting = false
                        })
                    }
                    print("History file read or parse error: \(error.localizedDescription)")
                }
            }
        case .failure(let error):
            Task { @MainActor in
                self.currentAlert = .error(Text("ファイルの選択に失敗しました: \(error.localizedDescription)"), onDismiss: {
                    self.isExporting = false
                })
            }
            print("File selection error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Estimated Size Calculation
    func calculateEstimatedExportSize(clipboardManager: ClipboardManager, includeFiles: Bool) async -> (min: Int64, max: Int64) {
        let history = clipboardManager.clipboardHistory
        var totalEstimatedSizeMin: Int64 = 0
        var totalEstimatedSizeMax: Int64 = 0
        
        var jsonSize: Int64 = 0
        autoreleasepool {
            do {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(history) {
                    jsonSize = Int64(data.count)
                }
            }
        }
        
        if includeFiles {
            // history.json はテキストなので 15% 〜 25% 程度に圧縮されると想定
            totalEstimatedSizeMin += Int64(Double(jsonSize) * 0.15)
            totalEstimatedSizeMax += Int64(Double(jsonSize) * 0.25)
        } else {
            // JSONのみの場合はZIP圧縮されずそのまま出力されるため、生のサイズを使用
            totalEstimatedSizeMin += jsonSize
            totalEstimatedSizeMax += jsonSize
        }
        
        if includeFiles {
            let fileManager = FileManager.default
            guard let filesDir = clipboardManager.createClipboardFilesDirectoryIfNeeded() else {
                return (min: totalEstimatedSizeMin, max: totalEstimatedSizeMax)
            }
            
            var usedFileNames: Set<String> = []
            for item in history {
                if let filePath = item.filePath {
                    usedFileNames.insert(filePath.lastPathComponent)
                }
            }
            
            for fileName in usedFileNames {
                let fileURL = filesDir.appendingPathComponent(fileName)
                let sizes = await estimateCompressedSize(for: fileURL, fileManager: fileManager)
                totalEstimatedSizeMin += sizes.min
                totalEstimatedSizeMax += sizes.max
            }
        }
        return (min: totalEstimatedSizeMin, max: totalEstimatedSizeMax)
    }
    
    private func estimateCompressedSize(for fileURL: URL, fileManager: FileManager) async -> (min: Int64, max: Int64) {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else { return (min: 0, max: 0) }
        
        if isDirectory.boolValue {
            // ディレクトリ（アプリバンドル等）の場合は全体のサイズを計算し、45%〜65%の圧縮率を適用
            let totalDirSize = calculateDirectorySize(url: fileURL, fileManager: fileManager)
            return (min: Int64(Double(totalDirSize) * 0.45), max: Int64(Double(totalDirSize) * 0.65))
        } else {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                guard let originalSize = attributes[FileAttributeKey.size] as? UInt64 else { return (min: 0, max: 0) }
                let size = Int64(originalSize)
                
                // 拡張子による固定の係数を廃止し、すべてのファイルに対して実測の圧縮率を算出する
                // これにより、拡張子が .png や .pdf でも内部的に圧縮可能な場合（巨大な単色画像や特殊なデータ）に
                // 正確な推定値が出せるようになる
                return sampleCompressionRatio(for: fileURL, originalSize: size)
                
            } catch {
                return (min: 0, max: 0)
            }
        }
    }
    
    private func calculateDirectorySize(url: URL, fileManager: FileManager) -> Int64 {
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey], options: []) {
            for case let fileURL as URL in enumerator {
                autoreleasepool {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
                        if resourceValues.isSymbolicLink != true && fileURL.lastPathComponent != ".DS_Store" {
                            if let fileSize = resourceValues.fileSize {
                                totalSize += Int64(fileSize)
                            }
                        }
                    } catch {
                        // Ignore errors
                    }
                }
            }
        }
        return totalSize
    }
    
    private func sampleCompressionRatio(for fileURL: URL, originalSize: Int64) -> (min: Int64, max: Int64) {
        // 先頭1MBを読み込んで圧縮率を計算
        let sampleSize = min(originalSize, 1024 * 1024) // 最大1MB
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return (min: Int64(Double(originalSize) * 0.3), max: Int64(Double(originalSize) * 0.7))
        }
        defer { try? fileHandle.close() }
        
        return autoreleasepool {
            guard let data = try? fileHandle.read(upToCount: Int(sampleSize)) else {
                return (min: Int64(Double(originalSize) * 0.3), max: Int64(Double(originalSize) * 0.7))
            }
            
            do {
                let compressedData = try (data as NSData).compressed(using: .zlib)
                let ratio = Double(compressedData.count) / Double(data.count)
                // min: 安全マージンなし (先頭データは高圧縮されやすいため過小評価になりやすい)
                let minRatio = max(0.05, min(1.0, ratio))
                // max: 安全マージン +15% を加算
                let maxRatio = max(0.1, min(1.0, ratio + 0.15))
                
                return (min: Int64(Double(originalSize) * minRatio), max: Int64(Double(originalSize) * maxRatio))
            } catch {
                return (min: Int64(Double(originalSize) * 0.3), max: Int64(Double(originalSize) * 0.7))
            }
        }
    }
    
    // MARK: - エクスポート結果のハンドリング用メソッド
    func handleExportResult(_ result: Result<URL, Error>, from clipboardManager: ClipboardManager, includeFiles: Bool, estimatedFinalSize: Int64? = nil, onComplete: @escaping () -> Void) {
        switch result {
        case .success(let url):
            Task { @MainActor in
                self.isExporting = true
                self.exportProgress = -1.0
                self.exportStatusText = "準備中..."
                clipboardManager.stopMonitoringPasteboard()
                clipboardManager.isExporting = true
            }
            
            exportTask = Task.detached {
                defer {
                    Task { @MainActor in
                        if self.isCancelling {
                            self.sheetAlert = .error(Text("エクスポートがキャンセルされました。"), onDismiss: {
                                self.isExporting = false
                                onComplete()
                            })
                            self.isCancelling = false
                        }
                        clipboardManager.startMonitoringPasteboard()
                        clipboardManager.isExporting = false
                    }
                }
                let historyToExport = clipboardManager.clipboardHistory
                
                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = .prettyPrinted
                    let fileManager = FileManager.default
                    let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    defer { try? fileManager.removeItem(at: tempDir) }
                    
                    let archiveSourceDir = tempDir.appendingPathComponent("ArchiveSource")
                    try fileManager.createDirectory(at: archiveSourceDir, withIntermediateDirectories: true)
                    
                    let jsonURL = archiveSourceDir.appendingPathComponent("history.json")
                    fileManager.createFile(atPath: jsonURL.path, contents: nil, attributes: nil)
                    let fileHandle = try FileHandle(forWritingTo: jsonURL)
                    
                    try fileHandle.write(contentsOf: "[\n".data(using: .utf8)!)
                    let count = historyToExport.count
                    
                    var writeBuffer = Data()
                    writeBuffer.reserveCapacity(1024 * 1024) // 1MB程度の初期キャパシティ
                    
                    for (index, item) in historyToExport.enumerated() {
                        autoreleasepool {
                            if let itemData = try? encoder.encode(item) {
                                writeBuffer.append(itemData)
                                if index < count - 1 {
                                    writeBuffer.append(",\n".data(using: .utf8)!)
                                } else {
                                    writeBuffer.append("\n".data(using: .utf8)!)
                                }
                            }
                        }
                        
                        // 100件ごと、または最後の要素でバッファを書き込んでクリアする
                        if index % 100 == 99 || index == count - 1 {
                            try? fileHandle.write(contentsOf: writeBuffer)
                            writeBuffer.removeAll(keepingCapacity: true)
                        }
                    }
                    try fileHandle.write(contentsOf: "]".data(using: .utf8)!)
                    try fileHandle.close()
                    
                    if includeFiles {
                        let filesDir = archiveSourceDir.appendingPathComponent("HistoryFiles")
                        try fileManager.createDirectory(at: filesDir, withIntermediateDirectories: true)
                        
                        guard let sourceFilesDir = clipboardManager.createClipboardFilesDirectoryIfNeeded() else {
                            throw NSError(domain: "ExportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "ファイルディレクトリが見つかりません。"])
                        }
                        
                        var usedFileNames: Set<String> = []
                        for item in historyToExport {
                            if let filePath = item.filePath {
                                usedFileNames.insert(filePath.lastPathComponent)
                            }
                        }
                        
                        let totalFiles = usedFileNames.count
                        var copiedFiles = 0
                        var totalFilesSize: Int64 = 0
                        
                        await MainActor.run { self.exportStatusText = "関連ファイルをコピー中..." }
                        
                        for fileName in usedFileNames {
                            let sourceURL = sourceFilesDir.appendingPathComponent(fileName)
                            let destURL = filesDir.appendingPathComponent(fileName)
                            if fileManager.fileExists(atPath: sourceURL.path) {
                                try? fileManager.copyItem(at: sourceURL, to: destURL)
                                
                                var isDir: ObjCBool = false
                                if fileManager.fileExists(atPath: destURL.path, isDirectory: &isDir) {
                                    if isDir.boolValue {
                                        totalFilesSize += self.calculateDirectorySize(url: destURL, fileManager: fileManager)
                                    } else {
                                        if let attr = try? fileManager.attributesOfItem(atPath: destURL.path), let size = attr[.size] as? Int64 {
                                            totalFilesSize += size
                                        }
                                    }
                                }
                            }
                            copiedFiles += 1
                            
                            if Task.isCancelled { throw CancellationError() }
                            
                            // 更新頻度を抑える
                            if copiedFiles % 100 == 0 || copiedFiles == totalFiles {
                                let progress = Double(copiedFiles) / Double(max(1, totalFiles))
                                await MainActor.run { self.exportProgress = progress * 0.5 } // コピーフェーズは50%
                            }
                        }
                        
                        if Task.isCancelled { throw CancellationError() }
                        
                        // コピー完了後に全体のサイズが確定するため、ここでメタデータを作成する
                        let historyJSONAttr = try? fileManager.attributesOfItem(atPath: jsonURL.path)
                        let historyJSONSize = (historyJSONAttr?[.size] as? Int64) ?? 0
                        
                        let metadataURL = archiveSourceDir.appendingPathComponent(".metadata.json")
                        let metadata = ExportMetadata(
                            pinnedItemID: clipboardManager.pinnedItemID,
                            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                            totalUncompressedSize: totalFilesSize + historyJSONSize
                        )
                        let metadataData = try encoder.encode(metadata)
                        try metadataData.write(to: metadataURL)
                        
                        await MainActor.run { 
                            self.exportStatusText = "圧縮中..." 
                            self.exportProgress = 0.5
                        }
                        
                        let tempAarURL = tempDir.appendingPathComponent("archive.aar")
                        
                        // 進捗監視用のタイマー
                        let targetMaxEstimatedSize: Int64
                        if let preCalculated = estimatedFinalSize {
                            targetMaxEstimatedSize = max(preCalculated, 1024)
                        } else {
                            let estimatedSizes = await self.calculateEstimatedExportSize(clipboardManager: clipboardManager, includeFiles: includeFiles)
                            targetMaxEstimatedSize = max(estimatedSizes.max, 1024)
                        }
                        
                        let progressTask = Task {
                            while !Task.isCancelled {
                                do {
                                    try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                                    let attr = try fileManager.attributesOfItem(atPath: tempAarURL.path)
                                    if let currentSize = attr[.size] as? Int64 {
                                        // 容量推定の大きい方を基準にして進捗を計算。最大0.9まで。
                                        let progress = 0.5 + (Double(currentSize) / Double(targetMaxEstimatedSize) * 0.4)
                                        await MainActor.run {
                                            if !self.isCancelling {
                                                self.exportProgress = min(0.9, progress)
                                            }
                                        }
                                    }
                                } catch {
                                    // ignore
                                }
                            }
                        }
                        
                        let filePath = FilePath(tempAarURL.path)
                        guard let fileStream = ArchiveByteStream.fileStream(path: filePath, mode: .writeOnly, options: [.create, .truncate], permissions: FilePermissions(rawValue: 0o644)) else {
                            progressTask.cancel()
                            throw NSError(domain: "AppleArchiveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "ファイルストリームの作成に失敗しました。"])
                        }
                        guard let compressionStream = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: fileStream) else {
                            try? fileStream.close()
                            progressTask.cancel()
                            throw NSError(domain: "AppleArchiveError", code: 2, userInfo: [NSLocalizedDescriptionKey: "圧縮ストリームの作成に失敗しました。"])
                        }
                        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressionStream) else {
                            try? compressionStream.close()
                            try? fileStream.close()
                            progressTask.cancel()
                            throw NSError(domain: "AppleArchiveError", code: 3, userInfo: [NSLocalizedDescriptionKey: "エンコードストリームの作成に失敗しました。"])
                        }
                        
                        do {
                            let sourcePath = FilePath(archiveSourceDir.path)
                            guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM") else {
                                throw NSError(domain: "AppleArchiveError", code: 4, userInfo: [NSLocalizedDescriptionKey: "キーセットの作成に失敗しました。"])
                            }
                            try encodeStream.writeDirectoryContents(archiveFrom: sourcePath, keySet: keySet)
                            
                            try encodeStream.close()
                            try compressionStream.close()
                            try fileStream.close()
                        } catch {
                            try? encodeStream.close()
                            try? compressionStream.close()
                            try? fileStream.close()
                            progressTask.cancel()
                            throw error
                        }
                        
                        progressTask.cancel()
                        
                        if Task.isCancelled { throw CancellationError() }
                        
                        await MainActor.run { 
                            self.exportStatusText = "保存中..."
                            self.exportProgress = 0.9
                        }
                        
                        let _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        if fileManager.fileExists(atPath: url.path) {
                            try fileManager.removeItem(at: url)
                        }
                        try fileManager.copyItem(at: tempAarURL, to: url)
                        
                        await MainActor.run { self.exportProgress = 1.0 }
                        
                    } else {
                        // JSONのみエクスポート
                        let _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        if fileManager.fileExists(atPath: url.path) {
                            try fileManager.removeItem(at: url)
                        }
                        try fileManager.copyItem(at: jsonURL, to: url)
                    }
                    
                    if Task.isCancelled { throw CancellationError() }
                    
                    await MainActor.run {
                        self.sheetAlert = .success(Text("クリップボード履歴が正常にエクスポートされました。"), onDismiss: {
                            self.isExporting = false
                            onComplete()
                        })
                    }
                    print("Clipboard history exported successfully: \(url.path)")
                    
                } catch {
                    // キャンセルまたはエラー時に、中途半端に書き出された出力先ファイルを削除
                    let _ = url.startAccessingSecurityScopedResource()
                    if FileManager.default.fileExists(atPath: url.path) {
                        try? FileManager.default.removeItem(at: url)
                        print("Deleted incomplete export file at \(url.path)")
                    }
                    url.stopAccessingSecurityScopedResource()
                    
                    if error is CancellationError { return }
                    await MainActor.run {
                        self.sheetAlert = .error(Text("履歴のエクスポートに失敗しました: \(error.localizedDescription)"), onDismiss: {
                            self.isExporting = false
                            onComplete()
                        })
                    }
                    print("History export error: \(error.localizedDescription)")
                }
            }
            
        case .failure(let error):
            Task { @MainActor in
                self.currentAlert = .error(Text("ファイルの選択に失敗しました: \(error.localizedDescription)"), onDismiss: {
                    self.isExporting = false
                })
            }
            print("File selection error: \(error.localizedDescription)")
            onComplete()
        }
    }
}
