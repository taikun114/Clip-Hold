import Foundation

extension ClipboardManager {
    // MARK: - ファイルハッシュの計算（起動時）
    func calculateMissingFileHashesInHistory() async {
        // チャンクされた履歴ファイルを一括で読み込む
        let chunkedHistoryManager = ChunkedHistoryManager.shared
        
        do {
            let chunkCount = try await chunkedHistoryManager.getChunkCount()
            
            for index in 0..<chunkCount {
                // チャンクごとに処理し、即座に保存することで競合（Race Condition）を防ぐ
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
                            var isDirectory: ObjCBool = false
                            if FileManager.default.fileExists(atPath: filePath.path, isDirectory: &isDirectory) && !isDirectory.boolValue {
                                if let fileHash = HashCalculator.calculateFileHash(at: filePath) {
                                    items[itemIndex].fileHash = fileHash
                                    itemsUpdated = true
                                    
                                    Task { @MainActor in
                                        self.updateFileHashCache(url: filePath, hash: fileHash)
                                    }
                                    print("ClipboardManager: Calculated missing hash for file item at chunk \(index), item index \(itemIndex).")
                                }
                            }
                        }
                    }
                }
                
                // 更新があった場合のみ、そのチャンクを即座に保存
                if itemsUpdated {
                    try await chunkedHistoryManager.saveChunk(items, at: index)
                    print("ClipboardManager: Saved updated chunk \(index) with calculated hashes.")
                }
            }
            
        } catch {
            print("ClipboardManager: Error processing history for missing file hashes: \(error.localizedDescription)")
        }
    }
}