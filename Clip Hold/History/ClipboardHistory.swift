import Foundation
import AppKit // NSAlert, NSWorkspace, NSPasteboard, NSImage, NSScreen
import SwiftUI // @AppStorage, ObservableObject, @Published
import QuickLookThumbnailing // QLThumbnailGenerator

extension ClipboardManager {
    // MARK: - History Management
    func scheduleSaveClipboardHistory() {
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
    
    // MARK: - Helper function to add and save a new item
    func addAndSaveItem(_ newItem: ClipboardItem) { // private から internal に変更
        guard !isExporting else { return }
        
        // 万が一既存の履歴と同じIDが生成されていた場合は新しく生成し直す（念のためのエラーハンドリング）
        while clipboardHistory.contains(where: { $0.id == newItem.id }) {
            print("ClipboardManager: ID collision detected for \(newItem.id). Regenerating UUID...")
            newItem.id = UUID()
        }
        
        // 日付が最も新しいアイテムを「最後のアイテム」として取得
        let lastItem = clipboardHistory.max { $0.date < $1.date }
        
        // 最後の履歴項目とアイテムのタイプ（テキスト or ファイル）が一致する場合のみ重複チェックを行う
        if let lastItem = lastItem {
            print("ClipboardManager: Last item details - Text: '\(lastItem.text.prefix(50))...', Date: \(lastItem.date), FilePath: \(String(describing: lastItem.filePath))")
            let lastItemType = lastItem.filePath != nil ? "File" : "Text"
            let newItemType = newItem.filePath != nil ? "File" : "Text"
            print("ClipboardManager: Checking duplicate. Last item type: \(lastItemType) (filePath: \(String(describing: lastItem.filePath))), New item type: \(newItemType) (filePath: \(String(describing: newItem.filePath)))")
            
            // newItemがテキストアイテムで、最後のアイテムもテキストの場合
            if newItem.filePath == nil && lastItem.filePath == nil {
                print("ClipboardManager: Both items are text. Checking for duplication...")
                if isDuplicate(newItem, of: lastItem) {
                    print("ClipboardManager: Text item is a duplicate of the last text item, skipping addition.")
                    return
                } else {
                    print("ClipboardManager: Text items are not duplicates.")
                }
            }
            // newItemがファイルアイテムで、最後のアイテムもファイルの場合
            else if newItem.filePath != nil && lastItem.filePath != nil {
                print("ClipboardManager: Both items are files. Checking for duplication...")
                if isDuplicate(newItem, of: lastItem) {
                    print("ClipboardManager: File item is a duplicate of the last file item, skipping addition.")
                    return
                } else {
                    print("ClipboardManager: File items are not duplicates.")
                }
            }
            // タイプが異なる場合は重複チェックを行わず、履歴に追加
            else {
                print("ClipboardManager: Item types are different. Skipping duplicate check and adding to history.")
            }
        } else {
            print("ClipboardManager: History is empty. Adding new item.")
        }
        
        self.objectWillChange.send()
        // 履歴を末尾に追加するように変更
        clipboardHistory.append(newItem)
        print("ClipboardManager: New item added to history: \(newItem.text.prefix(50))...")
        
        if let filePath = newItem.filePath {
            generateThumbnail(for: newItem, at: filePath)
        }
        
        // 最大履歴数を超過した場合の処理を適用
        enforceMaxHistoryCount()
        
        // 履歴を保存 (新しいシステムを使用)
        Task {
            await ChunkedHistoryManager.shared.saveHistoryItem(newItem)
        }
        
        // 追加後に孤立ファイルのクリーンアップをトリガー
        triggerOrphanedFilesCleanup()
    }
    
    func clearAllHistory() {
        guard !isExporting else { return }
        
        // インポートタスクが実行中の場合はキャンセル
        activeImportTask?.cancel()
        activeImportTask = nil
        
        // ピン留めを解除
        unpinItem()
        
        // 関連するファイルをすべて削除
        for item in clipboardHistory {
            if let filePath = item.filePath {
                deleteFileFromSandbox(at: filePath)
            }
        }
        // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
        self.objectWillChange.send()
        clipboardHistory = []
        filteredHistoryForShortcuts = nil // UI用のキャッシュもクリアしてメモリを解放
        print("ClipboardManager: All history cleared.")
        // 履歴をクリアした際に、一時ファイルもクリーンアップ
        cleanUpTemporaryFiles()
        
        // 新しい履歴管理システムもクリア
        Task {
            await ChunkedHistoryManager.shared.clearAllHistory()
        }
        
        // 削除後に孤立ファイルのクリーンアップをトリガー
        triggerOrphanedFilesCleanup()
    }
    
    func deleteItem(id: UUID, deleteOnlyThisItem: Bool = false) {
        guard !isExporting else { return }
        
        if id == pinnedItemID {
            unpinItem()
        }
        
        guard let index = clipboardHistory.firstIndex(where: { $0.id == id }) else { return }
        let itemToDelete = clipboardHistory[index]
        
        self.objectWillChange.send()
        
        // ファイルアイテムの場合、同じファイルを参照している他の履歴もまとめて削除するかどうか
        if let filePath = itemToDelete.filePath {
            if deleteOnlyThisItem {
                // この項目のみ削除
                clipboardHistory.remove(at: index)
                
                // ChunkedHistoryManager からも削除
                Task {
                    await ChunkedHistoryManager.shared.deleteHistoryItem(id: id)
                }
                
                // もし他に同じ filePath を参照している履歴がもうなければ、実ファイルも削除する
                if !clipboardHistory.contains(where: { $0.filePath == filePath }) {
                    deleteFileFromSandbox(at: filePath)
                }
                
                print("ClipboardManager: Single file item deleted. Total history: \(clipboardHistory.count)")
            } else {
                // 同じfilePathを持つアイテムを全て見つける
                let duplicatedItems = clipboardHistory.filter { $0.filePath == filePath }
                
                // メモリ上の履歴から全て削除
                clipboardHistory.removeAll(where: { $0.filePath == filePath })
                
                // ファイル実体を削除
                deleteFileFromSandbox(at: filePath)
                
                // ChunkedHistoryManager からも全て削除
                for duplicate in duplicatedItems {
                    Task {
                        await ChunkedHistoryManager.shared.deleteHistoryItem(id: duplicate.id)
                    }
                }
                print("ClipboardManager: Item and its duplicates deleted. Total history: \(clipboardHistory.count)")
            }
        } else {
            // テキストアイテムの場合は単体削除
            clipboardHistory.remove(at: index)
            print("ClipboardManager: Item deleted. Total history: \(clipboardHistory.count)")
            
            Task {
                await ChunkedHistoryManager.shared.deleteHistoryItem(id: id)
            }
        }
        
        // 削除後に孤立ファイルのクリーンアップをトリガー
        triggerOrphanedFilesCleanup()
    }
    
    // MARK: - History Import/Export (ClipboardHistoryImporterExporterが使うメソッドを定義)
    func importHistory(from items: [ClipboardItem]) {
        // 既存のインポートタスクがあればキャンセル
        activeImportTask?.cancel()
        
        // バックグラウンドで処理することでUIのブロックを防ぐ
        activeImportTask = Task.detached { [weak self] in
            guard let self = self else { return }
            
            if Task.isCancelled { return }
            
            // インポートされたアイテムのファイルパスが指すファイルが実際に存在するかを確認し、存在しない場合は削除
            let validItems = items.filter { item in
                if let filePath = item.filePath {
                    return FileManager.default.fileExists(atPath: filePath.path)
                }
                return true // ファイルパスがない場合は常に有効とみなす
            }
            
            // 1. 重複を避けて新しいアイテムを結合
            let existingItems = await MainActor.run { self.clipboardHistory }
            let existingItemsDict = Dictionary(existingItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            
            let existingContentSet = Set(existingItems.map {
                let pathComponent = $0.filePath?.lastPathComponent ?? "nil"
                return "\($0.text)-\(pathComponent)"
            })
            
            var newItems: [ClipboardItem] = []
            
            for item in validItems {
                if let existingItem = existingItemsDict[item.id] {
                    var isContentSame = false
                    if item.text == existingItem.text {
                        if item.filePath == nil && existingItem.filePath == nil {
                            isContentSame = true
                        } else if let newHash = item.fileHash, let existingHash = existingItem.fileHash {
                            isContentSame = (newHash == existingHash)
                        } else {
                            isContentSame = false
                        }
                    }
                    
                    if isContentSame {
                        continue
                    } else {
                        item.id = UUID()
                    }
                }
                
                let pathComponent = item.filePath?.lastPathComponent ?? "nil"
                if !existingContentSet.contains("\(item.text)-\(pathComponent)") {
                    newItems.append(item)
                }
            }
            
            if newItems.isEmpty || Task.isCancelled {
                print("ClipboardManager: No new items to import or task cancelled. Skipping update.")
                return
            }
            
            let itemsToAdd = newItems
            
            // 2. 既存の履歴に新しいアイテムを追加 (メインスレッドでPublishedプロパティを更新)
            let updatedHistory: [ClipboardItem] = await MainActor.run {
                self.objectWillChange.send()
                self.clipboardHistory.append(contentsOf: itemsToAdd)
                
                // 新しい順（日付が新しいものが先頭）にソート
                self.clipboardHistory.sort { $0.date > $1.date }
                
                // 3. 最大履歴数を超過した場合の処理
                self.enforceMaxHistoryCount()
                
                print("ClipboardManager: History imported. Added \(itemsToAdd.count) items, total history count: \(self.clipboardHistory.count)")
                
                return self.clipboardHistory
            }
            
            if Task.isCancelled { return }
            
            if Task.isCancelled { return }
            
            // 新しい履歴管理システムに一括で保存
            // 削除されたアイテムを反映するため、一度クリアして最新の履歴を保存する
            await ChunkedHistoryManager.shared.clearAllHistory()
            
            if Task.isCancelled { return }
            try? await ChunkedHistoryManager.shared.saveHistoryItems(updatedHistory)
            
            if Task.isCancelled { return }
            
            // Spotlightのインデックスも一括更新（UIにも進捗が表示される）
            // 既存の履歴はすでにインデックス済みのため、新規追加分のみを登録する
            await SpotlightManager.shared.indexHistoryItems(newItems)
        }
    }
    
    // MARK: - Max History Count Enforcement
    func enforceMaxHistoryCount() {
        print("DEBUG: enforceMaxHistoryCount() - maxHistoryToSave: \(self.maxHistoryToSave), current history count: \(self.clipboardHistory.count)")
        if self.maxHistoryToSave > 0 && self.clipboardHistory.count > self.maxHistoryToSave {
            // 履歴を日付の新しい順に並べ替える（メモリ内でのみ）
            let sortedHistory = self.clipboardHistory.sorted { $0.date > $1.date }
            
            // 設定された数の最新の履歴のみを保持
            let itemsToKeep = Array(sortedHistory.prefix(self.maxHistoryToSave))
            
            // 削除されるアイテムから関連するファイルも削除
            let itemsToRemove = sortedHistory.suffix(sortedHistory.count - self.maxHistoryToSave)
            for item in itemsToRemove {
                if let filePath = item.filePath {
                    deleteFileFromSandbox(at: filePath)
                }
            }
            
            // objectWillChange.send() を明示的に呼び出すことでUI更新を促す
            self.objectWillChange.send()
            self.clipboardHistory = itemsToKeep
            print("DEBUG: enforceMaxHistoryCount() - Adjusted history to \(self.maxHistoryToSave). Current history count: \(self.clipboardHistory.count)")
        } else if self.maxHistoryToSave == 0 { // 無制限の場合
            print("DEBUG: enforceMaxHistoryCount() - No adjustment needed for unlimited setting.")
        }
    }
    
    // MARK: - History Persistence (ファイルシステムに保存)
    private func saveClipboardHistory() {
        // 新しい履歴管理システムを使用するため、このメソッドは使用しない
        // 既存のコードは削除
    }
    
    // MARK: - History Loading (ファイルシステムからロード)
    public func loadClipboardHistory() async {
        // 新しい履歴管理システムから履歴をロード
        let loadedHistory = await ChunkedHistoryManager.shared.loadHistory()
        
        // メインスレッドでUI更新を行う
        await MainActor.run {
            // ロードした履歴アイテムのfilePathが指すファイルが実際に存在するかを確認し、存在しない場合は削除
            var validHistory = loadedHistory.filter { item in
                if let filePath = item.filePath {
                    return FileManager.default.fileExists(atPath: filePath.path)
                }
                return true // ファイルパスがない場合は常に有効とみなす
            }
            
            // 履歴を日付の新しい順に並べ替える（メモリ内でのみ）
            validHistory.sort { $0.date > $1.date }
            
            // 最大履歴数を超過した場合の処理を適用
            if self.maxHistoryToSave > 0 && validHistory.count > self.maxHistoryToSave {
                // 古いアイテムを削除
                validHistory = Array(validHistory.prefix(self.maxHistoryToSave))
            }
            
            self.clipboardHistory = validHistory
            
            print("ClipboardManager: Clipboard history loaded from new system. Count: \(self.clipboardHistory.count)")
            
            // 起動時の履歴読み込み後に孤立ファイルのクリーンアップをトリガー
            self.triggerOrphanedFilesCleanup()
        }
    }
    
    // MARK: - Orphaned Files Cleanup
    
    /// バックグラウンドで孤立ファイルのクリーンアップをトリガーします。
    func triggerOrphanedFilesCleanup() {
        Task.detached(priority: .background) {
            await self.cleanUpOrphanedFiles()
        }
    }
    
    /// 履歴リストに含まれていない（孤立した）ファイルを ClipboardFiles フォルダから削除します。
    func cleanUpOrphanedFiles() async {
        let fileManager = FileManager.default
        let appDir = await MainActor.run { self.getAppSpecificDirectory() }
        guard let appSpecificDirectory = appDir else { return }
        
        let filesDirectory = appSpecificDirectory.appendingPathComponent(self.filesDirectoryName, isDirectory: true)
        
        guard fileManager.fileExists(atPath: filesDirectory.path) else { return }
        
        do {
            let childURLs = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            // メインスレッドで現在の履歴アイテムが参照しているファイル名リストを取得
            let validFileNames = await MainActor.run {
                var names = Set<String>()
                for item in self.clipboardHistory {
                    if let fileName = item.filePath?.lastPathComponent {
                        names.insert(fileName)
                    }
                }
                return names
            }
            
            var cleanedCount = 0
            for childURL in childURLs {
                let fileName = childURL.lastPathComponent
                // 履歴リストに含まれていないファイルは孤立ファイルとして削除
                if !validFileNames.contains(fileName) {
                    do {
                        try fileManager.removeItem(at: childURL)
                        cleanedCount += 1
                    } catch {
                        print("ClipboardManager: Error removing orphaned file \(fileName): \(error.localizedDescription)")
                    }
                }
            }
            
            if cleanedCount > 0 {
                print("ClipboardManager: Cleaned up \(cleanedCount) orphaned files.")
            }
        } catch {
            print("ClipboardManager: Error cleaning up orphaned files: \(error.localizedDescription)")
        }
    }
}
