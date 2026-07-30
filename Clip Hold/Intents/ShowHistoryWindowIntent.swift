import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct ShowHistoryWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Show History Window"
    static let description = IntentDescription("Shows the clipboard history window.")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showHistoryWindow()
        }
        return .result()
    }
}
