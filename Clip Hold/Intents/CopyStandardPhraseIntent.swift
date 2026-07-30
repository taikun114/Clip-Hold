import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CopyStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Standard Phrase"
    static let description = IntentDescription("Copies a specific standard phrase to the clipboard.")
    
    // Spotlightで開いたときのデフォルトアクションにするため
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Preset", description: "The preset to copy the phrase from", default: nil, requestValueDialog: IntentDialog("どのプリセットの定型文をコピーしますか？"))
    var preset: StandardPhrasePresetEntity?
    
    @Parameter(title: "Phrase", description: "The standard phrase to copy", requestValueDialog: IntentDialog("どの定型文をコピーしますか？"), optionsProvider: CopyPhraseOptionsProvider())
    var phrase: StandardPhraseEntity
    
    func perform() async throws -> some IntentResult {
        // IDからアイテムを取得
        let targetPhrases: [StandardPhrase]
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        if let presetEntity = preset, presetEntity.id != currentPresetDummyId {
            targetPhrases = presets.first(where: { $0.id == presetEntity.id })?.phrases ?? []
        } else {
            targetPhrases = await MainActor.run { StandardPhraseManager.shared.standardPhrases }
        }
        
        if let originalPhrase = targetPhrases.first(where: { $0.id == phrase.id }) {
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(originalPhrase.content, forType: .string)
            }
            return .result(dialog: "クリップボードにコピーしました")
        }
        return .result(dialog: "定型文が見つかりませんでした")
    }
}
