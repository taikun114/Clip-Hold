import Foundation

extension ClipboardManager {
    // MARK: - ファイルハッシュの計算（起動時）
    func calculateMissingFileHashesInHistory() {
        // チャンクされた履歴ファイルを一括で読み込む
        let chunkedHistoryManager = ChunkedHistoryManager.shared
        var allHistoryItems: [ClipboardItem] = []
        var updatedChunks: [(index: Int, items: [ClipboardItem])] = []
        
        do {
            let chunkCount = try chunkedHistoryManager.getChunkCount()
            
            for index in 0..<chunkCount {
                let items = try chunkedHistoryManager.loadHistoryChunk(at: index)
                var itemsUpdated = false
                
                // 各アイテムに対して、ファイルハッシュが存在しない場合に計算
                for (itemIndex, item) in items.enumerated() {
                    if let filePath = item.filePath, item.fileHash == nil {
                        // ファイルが存在する場合のみハッシュを計算
                        if FileManager.default.fileExists(atPath: filePath.path) {
                            let fileHash = HashCalculator.calculateFileHash(at: filePath)
                            items[itemIndex].fileHash = fileHash
                            itemsUpdated = true
                            print("ClipboardManager: Calculated missing hash for file item at chunk \(index), item index \(itemIndex).")
                        }
                    }
                }
                
                // 更新があった場合、そのチャンクを記録
                if itemsUpdated {
                    updatedChunks.append((index: index, items: items))
                }
                
                // 全アイテムを一時的に保持（UI表示用など）
                allHistoryItems.append(contentsOf: items)
            }
            
            // 更新されたチャンクを一括で保存
            for chunk in updatedChunks {
                try chunkedHistoryManager.saveHistoryItems(chunk.items, to: chunk.index)
                print("ClipboardManager: Saved updated chunk \(chunk.index) with calculated hashes.")
            }
            
        } catch {
            print("ClipboardManager: Error processing history for missing file hashes: \(error.localizedDescription)")
        }
    }
}