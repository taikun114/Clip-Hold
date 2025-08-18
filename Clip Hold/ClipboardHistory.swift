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
        ChunkedHistoryManager.shared.saveHistoryItem(newItem)
        // 既存のスケジューリングは削除
        // scheduleSaveClipboardHistory()
    }

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
        // 履歴をクリアした際に、一時ファイルもクリーンアップ
        cleanUpTemporaryFiles()
        
        // 新しい履歴管理システムもクリア
        ChunkedHistoryManager.shared.clearAllHistory()
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

            // 新しい履歴管理システムからも削除
            ChunkedHistoryManager.shared.deleteHistoryItem(id: id)
        }
    }

    // MARK: - History Import/Export (ClipboardHistoryImporterExporterが使うメソッドを定義)
    func importHistory(from items: [ClipboardItem]) {
        // バックグラウンドで処理することでUIのブロックを防ぐ
        Task.detached { [weak self] in
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
            await MainActor.run {
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

    // MARK: - History Persistence (ファイルシステムに保存)
    private func saveClipboardHistory() {
        // 新しい履歴管理システムを使用するため、このメソッドは使用しない
        // 既存のコードは削除
    }

    // MARK: - History Loading (ファイルシステムからロード)
    public func loadClipboardHistory() {
        // 新しい履歴管理システムから履歴をロード
        let loadedHistory = ChunkedHistoryManager.shared.loadHistory()
        
        // ロードした履歴アイテムのfilePathが指すファイルが実際に存在するかを確認し、存在しない場合は削除
        var validHistory = loadedHistory.filter { item in
            if let filePath = item.filePath {
                return FileManager.default.fileExists(atPath: filePath.path)
            }
            return true // ファイルパスがない場合は常に有効とみなす
        }
        
        // 最大履歴数を超過した場合の処理を適用
        if self.maxHistoryToSave > 0 && validHistory.count > self.maxHistoryToSave {
            // 古いアイテム（配列の末尾）を削除
            validHistory = Array(validHistory.prefix(self.maxHistoryToSave))
        }
        
        self.clipboardHistory = validHistory

        for item in self.clipboardHistory where item.filePath != nil {
            generateThumbnail(for: item, at: item.filePath!)
        }

        print("ClipboardManager: Clipboard history loaded from new system. Count: \(clipboardHistory.count)")
    }
}