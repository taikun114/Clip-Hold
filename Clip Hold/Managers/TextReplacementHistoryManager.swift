import Foundation
import SwiftUI

/// 置換履歴の保存と管理を行うマネージャー
@MainActor
final class TextReplacementHistoryManager: ObservableObject {
    static let shared = TextReplacementHistoryManager()
    
    @Published private(set) var items: [TextReplacementHistoryItem] = []
    
    private let userDefaultsKey = "textReplacementHistory"
    private let maxHistoryCount = 50
    
    init() {
        loadHistory()
    }
    
    /// 履歴を追加します（同一内容が存在する場合は最新に更新）
    func addHistory(
        mode: TextReplacementMode,
        findText: String,
        replaceText: String,
        standardOptions: StandardSearchOptions? = nil,
        regexOptions: RegexSearchOptions? = nil
    ) {
        guard !findText.isEmpty else { return }
        
        // 既存の同一検索・置換ペアがあれば除去
        var newItems = items.filter { item in
            !(item.mode == mode && item.findText == findText && item.replaceText == replaceText)
        }
        
        let newItem = TextReplacementHistoryItem(
            mode: mode,
            findText: findText,
            replaceText: replaceText,
            standardOptions: standardOptions,
            regexOptions: regexOptions,
            date: Date()
        )
        
        newItems.insert(newItem, at: 0)
        
        // 最大件数を超えたら切り捨て
        if newItems.count > maxHistoryCount {
            newItems = Array(newItems.prefix(maxHistoryCount))
        }
        
        items = newItems
        saveHistory()
    }
    
    /// 指定された置換履歴アイテムを削除します
    func removeItem(_ item: TextReplacementHistoryItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    /// 全ての置換履歴を削除します
    func clearHistory() {
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - 永続化処理
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("置換履歴の保存に失敗しました: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode([TextReplacementHistoryItem].self, from: data)
            self.items = decoded
        } catch {
            print("置換履歴の読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
}
