import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct GetClipboardItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Clipboard History Item"
    static let description = IntentDescription("Gets the content of a specific clipboard history item.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "履歴項目")
    var historyItem: ClipboardItemEntity
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: historyItem.contentText)
    }
}
