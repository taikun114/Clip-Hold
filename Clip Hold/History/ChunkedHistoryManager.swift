import Foundation
import SwiftUI
import Combine

actor ChunkedHistoryManager {
    static let shared = ChunkedHistoryManager()
    
    private let historyDataDirectoryName = "historyData"
    private let historyIndexDirectoryName = "historyIndex"
    private let historyFilePrefix = "history_"
    private let historyIndexFilePrefix = "historyIndex_"
    private let fileExtension = "json"
    private let itemsPerChunk = 100
    
    // actorによりファイル操作は直列化されスレッドセーフになります
    
    private let historyFileName = "clipboardHistory.json"
    private let oldHistoryFileName = "oldClipboardHistory.json"
    
    private var appSpecificDirectory: URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ChunkedHistoryManager: Could not find Application Support directory.")
            return nil
        }
        return directory.appendingPathComponent("ClipHold")
    }
    
    private var historyDataDirectory: URL? {
        guard let appDir = appSpecificDirectory else { return nil }
        return appDir.appendingPathComponent(historyDataDirectoryName, isDirectory: true)
    }
    
    private var historyIndexDirectory: URL? {
        guard let dataDir = historyDataDirectory else { return nil }
        return dataDir.appendingPathComponent(historyIndexDirectoryName, isDirectory: true)
    }
    
    private init() {}
    
    // MARK: - Migration
    func migrateIfNeeded() -> Bool {
        guard let appDir = appSpecificDirectory else {
            print("ChunkedHistoryManager: Could not get app specific directory for migration.")
            return false
        }
        
        let oldHistoryFileURL = appDir.appendingPathComponent(historyFileName)
        let newHistoryFileURL = appDir.appendingPathComponent(oldHistoryFileName)
        
        // 古い履歴ファイルが存在しない場合はマイグレーション不要
        guard FileManager.default.fileExists(atPath: oldHistoryFileURL.path) else {
            print("ChunkedHistoryManager: No old history file found. Migration not needed.")
            return false
        }
        
        print("ChunkedHistoryManager: Old history file found. Starting migration...")
        
        do {
            // 既存の新しい履歴を読み込む
            let existingHistory = loadHistory()
            let existingItemIds = Set(existingHistory.map { $0.id })
            
            // 古い履歴ファイルを読み込む
            let data = try Data(contentsOf: oldHistoryFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let oldHistory = try decoder.decode([ClipboardItem].self, from: data)
            
            print("ChunkedHistoryManager: Loaded \(oldHistory.count) items from old history file.")
            
            // ファイルハッシュが存在しないアイテムに対してハッシュを計算して追加
            for (index, item) in oldHistory.enumerated() {
                if let filePath = item.filePath, item.fileHash == nil {
                    // ファイルが存在する場合のみハッシュを計算
                    if FileManager.default.fileExists(atPath: filePath.path) {
                        let fileHash = HashCalculator.calculateFileHash(at: filePath)
                        oldHistory[index].fileHash = fileHash
#if DEBUG
                        print("ChunkedHistoryManager: Calculated hash for migrated file item at index \(index).")
#endif
                    }
                }
            }
            
            // 既存の新しい履歴と古い履歴を統合（重複するアイテムは除外）
            let newItems = oldHistory.filter { !existingItemIds.contains($0.id) }
            let mergedHistory = existingHistory + newItems
            
            // 新しい形式で保存
            try saveHistoryItems(mergedHistory)
            
            // 古いファイルをリネーム
            try FileManager.default.moveItem(at: oldHistoryFileURL, to: newHistoryFileURL)
            
            print("ChunkedHistoryManager: Migration completed successfully.")
            return true
            
        } catch {
            print("ChunkedHistoryManager: Migration failed with error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - File Operations
    private func getOrCreateDirectory(_ directory: URL?) -> URL? {
        guard let dir = directory else { return nil }
        
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                print("ChunkedHistoryManager: Created directory: \(dir.path)")
            } catch {
                print("ChunkedHistoryManager: Error creating directory \(dir.path): \(error.localizedDescription)")
                return nil
            }
        }
        return dir
    }
    
    func getHistoryFileURL(for chunkIndex: Int) -> URL? {
        guard let dataDir = getOrCreateDirectory(historyDataDirectory) else { return nil }
        return dataDir.appendingPathComponent("\(historyFilePrefix)\(chunkIndex).\(fileExtension)")
    }
    
    private func getHistoryIndexFileURL(for chunkIndex: Int) -> URL? {
        guard let indexDir = getOrCreateDirectory(historyIndexDirectory) else { return nil }
        return indexDir.appendingPathComponent("\(historyIndexFilePrefix)\(chunkIndex).\(fileExtension)")
    }
    
    // MARK: - Save Operations
    func saveHistoryItem(_ item: ClipboardItem) {
        do {
            // 最新のチャンクを取得
            let (chunkIndex, items) = try self.loadLatestChunk()
            
            // 新しいアイテムを追加
            var updatedItems = items
            updatedItems.append(item)
            
            // チャンクが満杯になった場合、新しいチャンクを作成
            if updatedItems.count >= itemsPerChunk {
                // 現在のチャンクを保存
                try self.saveChunk(updatedItems, at: chunkIndex)
                
                // 次のチャンクを初期化して保存
                let nextChunkIndex = chunkIndex + 1
                try self.saveChunk([], at: nextChunkIndex)
            } else {
                // 現在のチャンクを更新して保存
                try self.saveChunk(updatedItems, at: chunkIndex)
            }
            
            // Spotlightのインデックスに追加
            SpotlightManager.shared.indexHistoryItem(item)
        } catch {
            print("ChunkedHistoryManager: Error saving history item: \(error.localizedDescription)")
        }
    }
    
    func updateHistoryItem(_ updatedItem: ClipboardItem) {
        do {
            let chunkCount = try self.getChunkCount()
            // 新しいアイテムほど後ろのチャンクにある可能性が高いため、逆順で検索
            for index in stride(from: chunkCount - 1, through: 0, by: -1) {
                var items = try self.loadHistoryChunk(at: index)
                if let itemIndex = items.firstIndex(where: { $0.id == updatedItem.id }) {
                    items[itemIndex] = updatedItem
                    try self.saveChunk(items, at: index)
#if DEBUG
                    print("ChunkedHistoryManager: Updated item with id \(updatedItem.id) in chunk \(index).")
#endif
                    
                    // Spotlightのインデックスも更新
                    SpotlightManager.shared.indexHistoryItem(updatedItem)
                    return
                }
            }
#if DEBUG
            print("ChunkedHistoryManager: Item with id \(updatedItem.id) not found for updating.")
#endif
        } catch {
            print("ChunkedHistoryManager: Error updating history item: \(error.localizedDescription)")
        }
    }
    
    func saveChunk(_ items: [ClipboardItem], at chunkIndex: Int) throws {
        guard let historyFileURL = getHistoryFileURL(for: chunkIndex) else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(items)
        try data.write(to: historyFileURL)
        
        // インデックスの更新
        try updateIndex(for: chunkIndex, with: items)
        
#if DEBUG
        print("ChunkedHistoryManager: Saved \(items.count) items to chunk \(chunkIndex).")
#endif
    }
    
    func saveHistoryItems(_ items: [ClipboardItem]) throws {
        // 既存のすべてのアイテムを読み込む
        let existingItems = loadHistory()
        
        // 既存のアイテムのIDセットを作成
        let existingItemIds = Set(existingItems.map { $0.id })
        
        // 新しいアイテムの中で、既存のIDと異なるもののみをフィルタリング
        let newItems = items.filter { !existingItemIds.contains($0.id) }
        
        // 既存のアイテムと新しいアイテムを結合
        var allItems = existingItems + newItems
        
        // 日付でソート（古い順）
        allItems.sort { $0.date < $1.date }
        
        // 既存のチャンクファイルをクリア
        let chunkCount = try getChunkCount()
        for index in 0..<chunkCount {
            if let historyFileURL = getHistoryFileURL(for: index), FileManager.default.fileExists(atPath: historyFileURL.path) {
                try FileManager.default.removeItem(at: historyFileURL)
            }
            if let indexFileURL = getHistoryIndexFileURL(for: index), FileManager.default.fileExists(atPath: indexFileURL.path) {
                try FileManager.default.removeItem(at: indexFileURL)
            }
        }
        
        // 新しいチャンクを保存
        let chunks = stride(from: 0, to: allItems.count, by: itemsPerChunk).map {
            Array(allItems[$0..<Swift.min($0 + itemsPerChunk, allItems.count)])
        }
        
        for (index, chunk) in chunks.enumerated() {
            try saveChunk(chunk, at: index)
        }
    }
    
    private func updateIndex(for chunkIndex: Int, with items: [ClipboardItem]) throws {
        guard let indexFileURL = getHistoryIndexFileURL(for: chunkIndex) else { return }
        
        let indexedItems = items.map { IndexedClipboardItem(from: $0) }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(indexedItems)
        try data.write(to: indexFileURL)
        
#if DEBUG
        print("ChunkedHistoryManager: Updated index for chunk \(chunkIndex) with \(indexedItems.count) items.")
#endif
    }
    
    // MARK: - Load Operations
    func loadHistory() -> [ClipboardItem] {
        do {
            let chunkCount = try getChunkCount()
            var allItems: [ClipboardItem] = []
            
            for index in 0..<chunkCount {
                let items = try loadHistoryChunk(at: index)
                allItems.append(contentsOf: items)
            }
            
            // 日付降順でソート
            allItems.sort { $0.date > $1.date }
            
            // 重複チェック & 安全救出ロジック
            var uniqueItems: [ClipboardItem] = []
            var seenIDs = Set<UUID>()
            
            for item in allItems {
                if !seenIDs.contains(item.id) {
                    seenIDs.insert(item.id)
                    uniqueItems.append(item)
                } else {
                    // IDが被っているアイテムを発見：内容が同一かどうかを判定
                    let isIdentical = uniqueItems.contains { existing in
                        existing.text == item.text &&
                        existing.date == item.date &&
                        existing.filePath == item.filePath &&
                        existing.fileHash == item.fileHash
                    }
                    
                    if isIdentical {
                        // 内容も完全に同一（二重保存された複製）なのでスキップ
                        #if DEBUG
                        print("ChunkedHistoryManager: Skipped identical duplicate item (ID: \(item.id)).")
                        #endif
                    } else {
                        // 万が一IDは同じだが内容が異なるアイテムだった場合は、新しいUUIDを採番して救出
                        var newUUID = UUID()
                        while seenIDs.contains(newUUID) {
                            newUUID = UUID()
                        }
                        seenIDs.insert(newUUID)
                        item.id = newUUID
                        uniqueItems.append(item)
                        #if DEBUG
                        print("ChunkedHistoryManager: Recovered item with collided ID by assigning new UUID: \(newUUID).")
                        #endif
                    }
                }
            }
            
            print("ChunkedHistoryManager: Loaded \(uniqueItems.count) items from \(chunkCount) chunks.")
            return uniqueItems
            
        } catch {
            print("ChunkedHistoryManager: Error loading history: \(error.localizedDescription)")
            return []
        }
    }
    
    func loadLatestChunk() throws -> (Int, [ClipboardItem]) {
        let chunkCount = try getChunkCount()
        
        if chunkCount == 0 {
            return (0, [])
        }
        
        let latestChunkIndex = chunkCount - 1
        let items = try loadHistoryChunk(at: latestChunkIndex)
        return (latestChunkIndex, items)
    }
    
    func loadHistoryChunk(at chunkIndex: Int) throws -> [ClipboardItem] {
        guard let historyFileURL = getHistoryFileURL(for: chunkIndex) else {
            return []
        }
        
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: historyFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([ClipboardItem].self, from: data)
    }
    
    func getChunkCount() throws -> Int {
        guard let dataDir = historyDataDirectory else { return 0 }
        
        guard FileManager.default.fileExists(atPath: dataDir.path) else {
            return 0
        }
        
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: dataDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        let historyFiles = fileURLs.filter { $0.lastPathComponent.hasPrefix(historyFilePrefix) }
        return historyFiles.count
    }
    
    // MARK: - Delete Operations
    func deleteHistoryItem(id: UUID) {
        do {
            let chunkCount = try self.getChunkCount()
            
            for index in 0..<chunkCount {
                var items = try self.loadHistoryChunk(at: index)
                let initialCount = items.count
                
                items.removeAll { $0.id == id }
                
                if items.count < initialCount {
                    // アイテムが削除されたチャンクを保存
                    try self.saveChunk(items, at: index)
#if DEBUG
                    print("ChunkedHistoryManager: Deleted item with id \(id) from chunk \(index).")
#endif
                    
                    // Spotlightから削除
                    SpotlightManager.shared.removeHistoryItem(id: id)
                    return // 1つのアイテムを削除したら終了
                }
            }
#if DEBUG
            print("ChunkedHistoryManager: Item with id \(id) not found for deletion.")
#endif
        } catch {
            print("ChunkedHistoryManager: Error deleting history item: \(error.localizedDescription)")
        }
    }
    
    // 特定のアプリからの履歴を一括削除するメソッド
    func deleteAllHistoryFromApp(sourceAppPath: String) {
        do {
            let chunkCount = try self.getChunkCount()
            
            for index in 0..<chunkCount {
                var items = try self.loadHistoryChunk(at: index)
                let initialCount = items.count
                
                // 特定のアプリからの履歴を削除
                items.removeAll { $0.sourceAppPath == sourceAppPath }
                
                // 削除が行われた場合のみ保存
                if items.count < initialCount {
                    try self.saveChunk(items, at: index)
#if DEBUG
                    print("ChunkedHistoryManager: Deleted \(initialCount - items.count) items from app \(sourceAppPath) in chunk \(index).")
#endif
                }
            }
        } catch {
            print("ChunkedHistoryManager: Error deleting all history from app: \(error.localizedDescription)")
        }
    }
    
    func clearAllHistory() {
        do {
            // 履歴データディレクトリを削除
            if let dataDir = self.historyDataDirectory, FileManager.default.fileExists(atPath: dataDir.path) {
                try FileManager.default.removeItem(at: dataDir)
                print("ChunkedHistoryManager: Cleared all history data.")
            }
            
            // ディレクトリを再作成
            _ = self.getOrCreateDirectory(self.historyDataDirectory)
            
            // Spotlightからすべての履歴アイテムを削除
            SpotlightManager.shared.removeAllHistoryItems()
        } catch {
            print("ChunkedHistoryManager: Error clearing all history: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Code Detection Index Persistence
    
    /// メモリ上で更新済みの履歴アイテムをチャンクファイルとしてディスクに高速保存します（二重判定なし）。
    /// - Parameters:
    ///   - items: メモリ上でコード検出更新済みの履歴アイテム配列。
    ///   - onProgress: チャンク単位で (進捗件数, 総件数) を通知するクロージャ。
    func persistHistoryChunks(
        _ items: [ClipboardItem],
        onProgress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async throws {
        // 重複チェック & 安全救出ロジック
        var uniqueItems: [ClipboardItem] = []
        var seenIDs = Set<UUID>()
        for item in items {
            if !seenIDs.contains(item.id) {
                seenIDs.insert(item.id)
                uniqueItems.append(item)
            } else {
                let isIdentical = uniqueItems.contains { existing in
                    existing.text == item.text &&
                    existing.date == item.date &&
                    existing.filePath == item.filePath &&
                    existing.fileHash == item.fileHash
                }
                if !isIdentical {
                    var newUUID = UUID()
                    while seenIDs.contains(newUUID) {
                        newUUID = UUID()
                    }
                    seenIDs.insert(newUUID)
                    item.id = newUUID
                    uniqueItems.append(item)
                }
            }
        }
        
        // チャンクファイルは日付昇順（古い順）で保存
        uniqueItems.sort { $0.date < $1.date }
        
        let totalItemsCount = uniqueItems.count
        guard totalItemsCount > 0 else { return }
        
        let previousChunkCount = try getChunkCount()
        
        let chunks = stride(from: 0, to: totalItemsCount, by: itemsPerChunk).map {
            Array(uniqueItems[$0..<Swift.min($0 + itemsPerChunk, totalItemsCount)])
        }
        
        var processedCount = 0
        for (index, chunk) in chunks.enumerated() {
            if Task.isCancelled { return }
            try saveChunk(chunk, at: index)
            processedCount += chunk.count
            if let onProgress = onProgress {
                await onProgress(processedCount, totalItemsCount)
            }
        }
        
        // もし以前のチャンク数が新しいチャンク数より多かった場合、余分なチャンクファイルを削除
        if previousChunkCount > chunks.count {
            for extraIndex in chunks.count..<previousChunkCount {
                if let historyFileURL = getHistoryFileURL(for: extraIndex), FileManager.default.fileExists(atPath: historyFileURL.path) {
                    try? FileManager.default.removeItem(at: historyFileURL)
                }
                if let indexFileURL = getHistoryIndexFileURL(for: extraIndex), FileManager.default.fileExists(atPath: indexFileURL.path) {
                    try? FileManager.default.removeItem(at: indexFileURL)
                }
            }
        }
    }
    
    /// コード検出インデックスを一括更新し、各チャンクをディスクに保存します。
    /// - Parameters:
    ///   - forceAll: true の場合は全アイテムを強制再判定。false の場合は未判定または旧バージョンのアイテムのみ更新。
    ///   - onProgress: チャンク単位で (進捗件数, 総件数) を通知するクロージャ。
    func updateCodeDetectionIndex(
        forceAll: Bool,
        onProgress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async throws {
        let chunkCount = try getChunkCount()
        var totalItemsCount = 0
        
        // まず総アイテム数を集計
        for index in 0..<chunkCount {
            if Task.isCancelled { return }
            let items = try loadHistoryChunk(at: index)
            totalItemsCount += items.count
        }
        
        guard totalItemsCount > 0 else { return }
        
        var processedCount = 0
        
        for index in 0..<chunkCount {
            if Task.isCancelled { return }
            let items = try loadHistoryChunk(at: index)
            var chunkModified = false
            
            for i in 0..<items.count {
                if Task.isCancelled { return }
                if forceAll || items[i].codeDetectorVersion != CodeDetector.currentDetectorVersion {
                    autoreleasepool {
                        items[i].updateCodeDetection()
                    }
                    chunkModified = true
                }
                processedCount += 1
            }
            
            if chunkModified {
                try saveChunk(items, at: index)
            }
            
            if let onProgress = onProgress {
                await onProgress(processedCount, totalItemsCount)
            }
        }
    }
}