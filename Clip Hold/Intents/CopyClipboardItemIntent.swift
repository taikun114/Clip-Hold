import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CopyClipboardItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy History Item"
    static let description = IntentDescription("Copies a specific history item to the clipboard.")
    
    // Spotlightで開いたときのデフォルトアクションにするため
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Item")
    var item: ClipboardItemEntity
    
    func perform() async throws -> some IntentResult {
        // IDからアイテムを取得
        let history = await ChunkedHistoryManager.shared.loadHistory()
        if let originalItem = history.first(where: { $0.id == item.id }) {
            await MainActor.run {
                ClipboardManager.shared.copyItemToClipboard(originalItem)
            }
            return .result(dialog: "クリップボードにコピーしました")
        }
        return .result(dialog: "項目が見つかりませんでした")
    }
}
