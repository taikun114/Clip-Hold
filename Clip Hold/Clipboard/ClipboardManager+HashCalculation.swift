import Foundation

extension ClipboardManager {
    // MARK: - ファイルハッシュの計算（起動時）
    func calculateMissingFileHashesInHistory() async {
        // チャンクされた履歴ファイルを一括で読み込む
        let chunkedHistoryManager = ChunkedHistoryManager.shared
        var allHistoryItems: [ClipboardItem] = []
        var updatedChunks: [(index: Int, items: [ClipboardItem])] = []
        
        do {
            let chunkCount = try await chunkedHistoryManager.getChunkCount()
            
            for index in 0..<chunkCount {
                let items = try await chunkedHistoryManager.loadHistoryChunk(at: index)
                var itemsUpdated = false
                
                // 各アイテムに対して、ファイルハッシュが存在しない場合に計算、存在する場合はキャッシュに保存
                for (itemIndex, item) in items.enumerated() {
                    if let filePath = item.filePath {
                        if let existingHash = item.fileHash {
                            // 既にハッシュが存在する場合はキャッシュに保存
                            Task { @MainActor in
                                self.updateFileHashCache(url: filePath, hash: existingHash)
                            }
                        } else {
                            // ファイルが存在する場合のみハッシュを計算
                            if FileManager.default.fileExists(atPath: filePath.path) {
                                let fileHash = HashCalculator.calculateFileHash(at: filePath)
                                items[itemIndex].fileHash = fileHash
                                itemsUpdated = true
                                if let fileHash = fileHash {
                                    Task { @MainActor in
                                        self.updateFileHashCache(url: filePath, hash: fileHash)
                                    }
                                }
                                print("ClipboardManager: Calculated missing hash for file item at chunk \(index), item index \(itemIndex).")
                            }
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
                try await chunkedHistoryManager.saveChunk(chunk.items, at: chunk.index)
                print("ClipboardManager: Saved updated chunk \(chunk.index) with calculated hashes.")
            }
            
        } catch {
            print("ClipboardManager: Error processing history for missing file hashes: \(error.localizedDescription)")
        }
    }
}