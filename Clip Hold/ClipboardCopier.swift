import Foundation
import AppKit // NSPasteboard
import SwiftUI // @Published

extension ClipboardManager {
    func copyItemToClipboard(_ item: ClipboardItem) {
        // 古い一時ファイルをすべて削除する
        cleanUpTemporaryFiles()

        isPerformingInternalCopy = true // 内部コピー操作が開始されたことを示す
        print("DEBUG: copyItemToClipboard: isPerformingInternalCopy = true")

        NSPasteboard.general.clearContents()

        // ファイルコピー処理を非同期タスクで実行
        Task.detached { [weak self] in
            guard let self = self else { return }
            if let filePath = item.filePath {
                // ファイルパスが存在する場合
                if let tempURL = await self.createTemporaryCopy(for: item) {
                    // 一時的なファイルリンクのURLをクリップボードに書き込む
                    await MainActor.run {
                        if NSPasteboard.general.writeObjects([tempURL as NSURL]) {
                            print("クリップボードにファイルがコピーされました (元のファイル名): \(tempURL.lastPathComponent)")
                            // success = true // 非同期タスク内なので直接UI更新はしない
                        } else {
                            print("クリップボードに一時ファイル (NSURL) をコピーできませんでした。")
                            // フォールバックとして、元のサンドボックスURLをコピー
                            if NSPasteboard.general.writeObjects([filePath as NSURL]) {
                                print("フォールバック: サンドボックス内のファイルがコピーされました。")
                                // success = true
                            }
                        }
                    }
                }
                // ファイルパスが存在する場合は、テキストのコピーをスキップ
                return
            }

            // ファイルパスがない場合、テキストをコピー
            // item.text は非オプショナルなので、直接使用する
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                
                // リッチテキストが存在する場合は、リッチテキストとプレーンテキストの両方を書き込む
                if let richText = item.richText {
                    // リッチテキストを書き込む
                    if pasteboard.setString(richText, forType: .rtf) {
                        print("クリップボードにリッチテキストがコピーされました: \(richText.prefix(20))...")
                    }
                    // プレーンテキストも書き込む (フォールバック用)
                    if pasteboard.setString(item.text, forType: .string) {
                        print("クリップボードにプレーンテキストがコピーされました: \(item.text.prefix(20))...")
                    }
                } else {
                    // リッチテキストがない場合は、プレーンテキストのみを書き込む
                    if pasteboard.string(forType: .string) != item.text { // クリップボードの内容がすでに同じでなければコピー
                        if pasteboard.setString(item.text, forType: .string) {
                            print("クリップボードにテキストがコピーされました: \(item.text.prefix(20))...")
                            // success = true
                        }
                    }
                }
            }
        }
    }

    // 履歴にテキストアイテムを明示的に追加するメソッド
    // クリップボード監視以外からの入力 (例: ドラッグ&ドロップ) に使用
    func addTextItem(text: String) {
        // 同じ内容のものが連続して追加された場合はスキップ (ファイルパスがないテキストアイテムとしてのみチェック)
        if let lastItem = clipboardHistory.first, lastItem.text == text, lastItem.filePath == nil {
            print("ClipboardManager: Duplicate text item detected via addTextItem, skipping. Text: \(text.prefix(50))...\n")
            return
        }

        self.objectWillChange.send() // UI更新を促す
        let newItem = ClipboardItem(text: text, date: Date(), filePath: nil, fileSize: nil) // ファイルパスとサイズはnil
        clipboardHistory.insert(newItem, at: 0) // 先頭に追加
        print("ClipboardManager: New text item added via addTextItem. Total history: \(clipboardHistory.count)")

        // 最大履歴数を超過した場合の処理を適用
        enforceMaxHistoryCount()

        scheduleSaveClipboardHistory()
    }
}
