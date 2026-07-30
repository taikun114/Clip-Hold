import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct GetStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Standard Phrase"
    static let description = IntentDescription("Gets the content of a specific standard phrase.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "定型文")
    var phrase: StandardPhraseEntity
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: phrase.content)
    }
}
