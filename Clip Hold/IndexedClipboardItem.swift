import Foundation

// インデックスファイルに保存するための軽量な履歴アイテム構造
struct IndexedClipboardItem: Codable {
    let id: UUID
    let date: Date
    
    init(from item: ClipboardItem) {
        self.id = item.id
        self.date = item.date
    }
}