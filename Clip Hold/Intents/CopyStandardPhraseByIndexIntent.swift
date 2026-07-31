import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CopyStandardPhraseByIndexIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Standard Phrase by Index"
    static let description = IntentDescription("Copies a standard phrase at the specified index (1-based) to the clipboard.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Number", description: "The number of the item to copy (1 or greater)")
    var index: Int
    
    @Parameter(title: "プリセット", optionsProvider: SpecificPresetOptionsProvider())
    var preset: StandardPhrasePresetEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Copy the \(\.$index)th standard phrase") {
            \.$preset
        }
    }
    
    func perform() async throws -> some IntentResult {
        let targetPresetId = preset.id
        
        let phrases: [StandardPhrase] = await MainActor.run {
            let manager = StandardPhrasePresetManager.shared
            if targetPresetId == currentPresetDummyId {
                return StandardPhraseManager.shared.standardPhrases
            } else if targetPresetId == allPresetsDummyId {
                return manager.presets.flatMap { $0.phrases }
            } else if let selectedPreset = manager.presets.first(where: { $0.id == targetPresetId }) {
                return selectedPreset.phrases
            } else {
                return StandardPhraseManager.shared.standardPhrases
            }
        }
        
        let zeroBasedIndex = index - 1
        guard zeroBasedIndex >= 0 && zeroBasedIndex < phrases.count else {
            return .result(dialog: "指定された番号の定型文が見つかりませんでした")
        }
        
        let phrase = phrases[zeroBasedIndex]
        
        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(phrase.content, forType: .string)
            NotificationManager.shared.sendStandardNotification(title: "コピーしました", subtitle: phrase.title)
        }
        
        return .result(dialog: "クリップボードにコピーしました")
    }
}
