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

            for item in self.clipboardHistory where item.filePath != nil {
                generateThumbnail(for: item, at: item.filePath!)
            }

            print("ClipboardManager: Clipboard history loaded from file. Count: \(clipboardHistory.count), Size: \(data.count) bytes.")
        } catch {
            print("ClipboardManager: Error loading clipboard history from file: \(error.localizedDescription)")
        }
    }
}