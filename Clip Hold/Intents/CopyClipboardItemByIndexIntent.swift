import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CopyClipboardItemByIndexIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy History Item by Index"
    static let description = IntentDescription("Copies a history item at the specified index (1-based) to the clipboard.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Index (1-10)", default: .first)
    var index: ItemIndexEnum
    
    func perform() async throws -> some IntentResult {
        let history = await ChunkedHistoryManager.shared.loadHistory()
        
        let zeroBasedIndex = index.rawValue - 1
        guard zeroBasedIndex >= 0 && zeroBasedIndex < history.count else {
            return .result(dialog: "指定された番号の履歴が見つかりませんでした")
        }
        
        let item = history[zeroBasedIndex]
        
        await MainActor.run {
            NSPasteboard.general.clearContents()
            if let path = item.filePath {
                let url = path
                NSPasteboard.general.writeObjects([url as NSPasteboardWriting])
            } else {
                NSPasteboard.general.setString(item.text, forType: .string)
            }
            NotificationManager.shared.sendStandardNotification(title: "コピーしました", subtitle: String(item.text.prefix(50)))
        }
        
        return .result(dialog: "クリップボードにコピーしました")
    }
}
