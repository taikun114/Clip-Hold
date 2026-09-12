import Foundation
import AppIntents

@available(macOS 14.0, *)
struct GetStandardPhraseCountIntent: AppIntent {
    static let title: LocalizedStringResource = "定型文の個数を取得"
    static let description = IntentDescription("選択したプリセット内の定型文の個数を取得します。")
    
    @Parameter(
        title: "プリセット",
        description: "個数を取得するプリセット",
        requestValueDialog: IntentDialog("どのプリセットを選択しますか？"),
        optionsProvider: CountPresetOptionsProvider()
    )
    var preset: StandardPhrasePresetEntity?
    
    @Parameter(
        title: "重複をカウントしない",
        description: "IDまたは内容が一致する定型文を重複とみなし、1つとしてカウントします。",
        default: false
    )
    var ignoreDuplicates: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Get standard phrase count") {
            \.$preset
            \.$ignoreDuplicates
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let count = await MainActor.run { () -> Int in
            let presets = StandardPhrasePresetManager.shared.presets
            
            // 現在のプリセットを取得
            var currentPresetPhrases: [StandardPhrase] = []
            if let selectedPresetId = StandardPhrasePresetManager.shared.selectedPresetId,
               let currentPreset = presets.first(where: { $0.id == selectedPresetId }) {
                currentPresetPhrases = currentPreset.phrases
            } else if let defaultPreset = presets.first(where: { $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }) {
                currentPresetPhrases = defaultPreset.phrases
            }
            
            // ターゲットIDを決定 (nilの場合は現在のプリセットとして扱う)
            let targetId = preset?.id ?? currentPresetDummyId
            
            var targetPhrases: [StandardPhrase] = []
            
            if targetId == currentPresetDummyId {
                targetPhrases = currentPresetPhrases
            } else if targetId == allPresetsDummyId {
                targetPhrases = presets.flatMap { $0.phrases }
            } else {
                if let specificPreset = presets.first(where: { $0.id == targetId }) {
                    targetPhrases = specificPreset.phrases
                } else {
                    targetPhrases = currentPresetPhrases
                }
            }
            
            if ignoreDuplicates {
                var uniquePhrases: [StandardPhrase] = []
                var seenIds: Set<UUID> = []
                var seenContents: Set<String> = []
                
                for phrase in targetPhrases {
                    if !seenIds.contains(phrase.id) && !seenContents.contains(phrase.content) {
                        uniquePhrases.append(phrase)
                        seenIds.insert(phrase.id)
                        seenContents.insert(phrase.content)
                    }
                }
                return uniquePhrases.count
            } else {
                return targetPhrases.count
            }
        }
        
        return .result(value: count)
    }
}
