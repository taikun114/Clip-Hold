import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct SearchStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Standard Phrases"
    static let description = IntentDescription("Searches standard phrases and returns the matching items.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Query", description: "The text to search for")
    var query: String
    
    @Parameter(title: "Preset", description: "The preset to search in", default: nil, requestValueDialog: IntentDialog("どのプリセットを検索しますか？"))
    var preset: StandardPhrasePresetEntity?
    
    @Parameter(title: "Exact Match", description: "Search for items that exactly match the input text", default: false)
    var exactMatch: Bool
    
    @Parameter(title: "Case Sensitive", description: "Check to perform a case-sensitive search", default: false)
    var caseSensitive: Bool
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search standard phrases for \(\.$query)") {
            \.$preset
            \.$exactMatch
            \.$caseSensitive
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<[StandardPhraseEntity]> {
        let targetPhrases: [StandardPhrase]
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        
        if let presetEntity = preset, presetEntity.id == allPresetsDummyId {
            targetPhrases = presets.flatMap { $0.phrases }
        } else if let presetEntity = preset, presetEntity.id != currentPresetDummyId {
            targetPhrases = presets.first(where: { $0.id == presetEntity.id })?.phrases ?? []
        } else {
            targetPhrases = await MainActor.run { StandardPhraseManager.shared.standardPhrases }
        }
        
        let matchingPhrases = targetPhrases.filter { phrase in
            let titleMatch: Bool
            let contentMatch: Bool
            
            if exactMatch {
                if caseSensitive {
                    titleMatch = phrase.title == query
                    contentMatch = phrase.content == query
                } else {
                    titleMatch = phrase.title.caseInsensitiveCompare(query) == .orderedSame
                    contentMatch = phrase.content.caseInsensitiveCompare(query) == .orderedSame
                }
            } else {
                if caseSensitive {
                    titleMatch = phrase.title.contains(query)
                    contentMatch = phrase.content.contains(query)
                } else {
                    titleMatch = phrase.title.localizedCaseInsensitiveContains(query)
                    contentMatch = phrase.content.localizedCaseInsensitiveContains(query)
                }
            }
            
            return titleMatch || contentMatch
        }
        
        let entities = matchingPhrases.map { phrase in
            StandardPhraseEntity(
                id: phrase.id,
                title: phrase.title,
                content: phrase.content
            )
        }
        
        return .result(value: entities)
    }
}
