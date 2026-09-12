import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct SearchClipboardHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Search History"
    static let description = IntentDescription("Searches the clipboard history and returns the matching items.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Query", description: "The text to search for")
    var query: String
    
    @Parameter(title: "Exact Match", description: "Search for items that exactly match the input text", default: false)
    var exactMatch: Bool
    
    @Parameter(title: "Case Sensitive", description: "Check to perform a case-sensitive search", default: false)
    var caseSensitive: Bool
    
    @Parameter(title: "Limit", description: "The maximum number of items to return", default: 50)
    var limit: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search history for \(\.$query)") {
            \.$exactMatch
            \.$caseSensitive
            \.$limit
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<[ClipboardItemEntity]> {
        let history = await ChunkedHistoryManager.shared.loadHistory()
        
        let matchingItems = history.filter { item in
            if exactMatch {
                if caseSensitive {
                    return item.text == query
                } else {
                    return item.text.caseInsensitiveCompare(query) == .orderedSame
                }
            } else {
                if caseSensitive {
                    return item.text.contains(query)
                } else {
                    return item.text.localizedCaseInsensitiveContains(query)
                }
            }
        }
        
        // Date sort (newest first)
        let sortedItems = matchingItems.sorted { $0.date > $1.date }
        
        let limitedItems = Array(sortedItems.prefix(limit))
        
        let entities = limitedItems.map { item in
            ClipboardItemEntity(
                id: item.id,
                contentText: item.text,
                date: item.date,
                isFile: item.filePath != nil,
                filename: item.filePath?.lastPathComponent
            )
        }
        
        return .result(value: entities)
    }
}
