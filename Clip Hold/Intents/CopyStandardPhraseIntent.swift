import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CopyStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Standard Phrase"
    static let description = IntentDescription("Copies a specific standard phrase to the clipboard.")
    
    // Spotlightで開いたときのデフォルトアクションにするため
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Phrase")
    var phrase: StandardPhraseEntity
    
    func perform() async throws -> some IntentResult {
        // IDからアイテムを取得
        let manager = StandardPhraseManager.shared
        if let originalPhrase = manager.standardPhrases.first(where: { $0.id == phrase.id }) {
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(originalPhrase.content, forType: .string)
            }
            return .result(dialog: "クリップボードにコピーしました")
        }
        return .result(dialog: "定型文が見つかりませんでした")
    }
}
