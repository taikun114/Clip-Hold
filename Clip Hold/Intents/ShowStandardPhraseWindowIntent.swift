import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct ShowStandardPhraseWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Standard Phrase Window"
    static let description = IntentDescription("Shows the standard phrase window.")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showStandardPhraseWindow()
        }
        return .result()
    }
}
