import Foundation
import SwiftUI
import Combine

class ChunkedHistoryManager: ObservableObject {
    static let shared = ChunkedHistoryManager()
    
    private let historyDataDirectoryName = "historyData"
    private let historyIndexDirectoryName = "historyIndex"
    private let historyFilePrefix = "history_"
    private let historyIndexFilePrefix = "historyIndex_"
    private let fileExtension = "json"
    private let itemsPerChunk = 100
    
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
                        print("ChunkedHistoryManager: Calculated hash for migrated file item at index \(index).")
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
    
    func getHistoryFileURL(for chunkIndex: Int) -> URL? { // private から internal に変更
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
            let (chunkIndex, items) = try loadLatestChunk()
            
            // 新しいアイテムを追加
            var updatedItems = items
            updatedItems.append(item)
            
            // チャンクが満杯になった場合、新しいチャンクを作成
            if updatedItems.count > itemsPerChunk {
                // 現在のチャンクを保存
                try saveHistoryItems(updatedItems.dropLast(), to: chunkIndex)
                
                // 新しいチャンクに最新のアイテムのみを保存
                try saveHistoryItems([item], to: chunkIndex + 1)
            } else {
                // 現在のチャンクを更新
                try saveHistoryItems(updatedItems, to: chunkIndex)
            }
        } catch {
            print("ChunkedHistoryManager: Error saving history item: \(error.localizedDescription)")
        }
    }
    
    func saveHistoryItems(_ items: [ClipboardItem], to chunkIndex: Int) throws { // private から internal に変更
        guard let historyFileURL = getHistoryFileURL(for: chunkIndex) else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(items)
        try data.write(to: historyFileURL)
        
        // インデックスの更新
        try updateIndex(for: chunkIndex, with: items)
        
        print("ChunkedHistoryManager: Saved \(items.count) items to chunk \(chunkIndex).")
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
            try saveHistoryItems(chunk, to: index)
        }
    }
    
    private func updateIndex(for chunkIndex: Int, with items: [ClipboardItem]) throws {
        guard let indexFileURL = getHistoryIndexFileURL(for: chunkIndex) else { return }
        
        let indexedItems = items.map { IndexedClipboardItem(from: $0) }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(indexedItems)
        try data.write(to: indexFileURL)
        
        print("ChunkedHistoryManager: Updated index for chunk \(chunkIndex) with \(indexedItems.count) items.")
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
            
            print("ChunkedHistoryManager: Loaded \(allItems.count) items from \(chunkCount) chunks.")
            return allItems
            
        } catch {
            print("ChunkedHistoryManager: Error loading history: \(error.localizedDescription)")
            return []
        }
    }
    
    func loadLatestChunk() throws -> (Int, [ClipboardItem]) { // private から internal に変更
        let chunkCount = try getChunkCount()
        
        if chunkCount == 0 {
            return (0, [])
        }
        
        let latestChunkIndex = chunkCount - 1
        let items = try loadHistoryChunk(at: latestChunkIndex)
        return (latestChunkIndex, items)
    }
    
    func loadHistoryChunk(at chunkIndex: Int) throws -> [ClipboardItem] { // private から internal に変更
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
    
    func getChunkCount() throws -> Int { // private から internal に変更
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
            let chunkCount = try getChunkCount()
            
            for index in 0..<chunkCount {
                var items = try loadHistoryChunk(at: index)
                let initialCount = items.count
                
                items.removeAll { $0.id == id }
                
                // アイテムが削除された場合のみファイルを更新
                if items.count != initialCount {
                    // アイテム数が0でもファイルは削除しない
                    try saveHistoryItems(items, to: index)
                    print("ChunkedHistoryManager: Deleted item with id \(id) from chunk \(index).")
                    return
                }
            }
            
            print("ChunkedHistoryManager: Item with id \(id) not found for deletion.")
            
        } catch {
            print("ChunkedHistoryManager: Error deleting history item: \(error.localizedDescription)")
        }
    }
    
    func clearAllHistory() {
        do {
            // 履歴データディレクトリを削除
            if let dataDir = historyDataDirectory, FileManager.default.fileExists(atPath: dataDir.path) {
                try FileManager.default.removeItem(at: dataDir)
                print("ChunkedHistoryManager: Cleared all history data.")
            }
            
            // ディレクトリを再作成
            _ = getOrCreateDirectory(historyDataDirectory)
        } catch {
            print("ChunkedHistoryManager: Error clearing all history: \(error.localizedDescription)")
        }
    }
}