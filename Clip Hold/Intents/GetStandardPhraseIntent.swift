import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct GetStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Standard Phrase"
    static let description = IntentDescription("Gets the content of a specific standard phrase.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Preset", description: "The preset to get the phrase from", default: nil, requestValueDialog: IntentDialog("どのプリセットから取得しますか？"))
    var preset: StandardPhrasePresetEntity?
    
    @Parameter(title: "定型文", optionsProvider: GetPhraseOptionsProvider())
    var phrase: StandardPhraseEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get standard phrase \(\.$phrase)") {
            \.$preset
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: phrase.content)
    }
}
