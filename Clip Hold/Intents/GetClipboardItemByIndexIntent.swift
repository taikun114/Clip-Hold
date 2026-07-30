import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct GetClipboardItemByIndexIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Clipboard History Item by Index"
    static let description = IntentDescription("Gets a clipboard history item at the specified index.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Number", description: "The number of the item to get (1 or greater)")
    var index: Int
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let history = await ChunkedHistoryManager.shared.loadHistory()
        
        let zeroBasedIndex = index - 1
        guard zeroBasedIndex >= 0 && zeroBasedIndex < history.count else {
            throw IntentItemNotFoundError(message: "指定された番号の履歴項目が見つかりませんでした")
        }
        
        let item = history[zeroBasedIndex]
        return .result(value: item.text)
    }
}

struct IntentItemNotFoundError: Error, LocalizedError {
    var message: String
    var errorDescription: String? { return message }
}
