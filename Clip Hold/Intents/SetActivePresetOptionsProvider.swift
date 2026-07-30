import Foundation
import AppIntents

@available(macOS 14.0, *)
struct SetActivePresetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [StandardPhrasePresetEntity] {
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        var result: [StandardPhrasePresetEntity] = []
        
        result.append(StandardPhrasePresetEntity(id: previousPresetDummyId, name: String(localized: "前のプリセット")))
        result.append(StandardPhrasePresetEntity(id: nextPresetDummyId, name: String(localized: "次のプリセット")))
        
        let customPresets = presets.map { StandardPhrasePresetEntity(id: $0.id, name: $0.name) }
        result.append(contentsOf: customPresets)
        
        return result
    }
    
    func defaultResult() async throws -> StandardPhrasePresetEntity? {
        return StandardPhrasePresetEntity(id: nextPresetDummyId, name: String(localized: "次のプリセット"))
    }
}
