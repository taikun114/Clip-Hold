import Foundation
import AppIntents

@available(macOS 14.0, *)
struct CountPresetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [StandardPhrasePresetEntity] {
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        var result: [StandardPhrasePresetEntity] = []
        
        result.append(StandardPhrasePresetEntity(id: currentPresetDummyId, name: "現在のプリセット"))
        result.append(StandardPhrasePresetEntity(id: allPresetsDummyId, name: "すべてのプリセット"))
        
        let customPresets = presets.map { StandardPhrasePresetEntity(id: $0.id, name: $0.name) }
        result.append(contentsOf: customPresets)
        
        return result
    }
}
