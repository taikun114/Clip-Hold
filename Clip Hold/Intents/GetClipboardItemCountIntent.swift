import Foundation
import AppIntents

@available(macOS 14.0, *)
struct GetClipboardItemCountIntent: AppIntent {
    static let title: LocalizedStringResource = "履歴の総数を取得"
    static let description = IntentDescription("保存されているコピー履歴の総数を取得します。")
    
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let history = await ChunkedHistoryManager.shared.loadHistory()
        return .result(value: history.count)
    }
}
