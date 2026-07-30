import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct CopyPhraseOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<CopyStandardPhraseIntent>( \.$preset )
    var intent
    
    func results() async throws -> [StandardPhraseEntity] {
        let presetEntity = intent?.preset
        
        let targetPhrases: [StandardPhrase]
        if let presetEntity = presetEntity, presetEntity.id != currentPresetDummyId {
            let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
            targetPhrases = presets.first(where: { $0.id == presetEntity.id })?.phrases ?? []
        } else {
            targetPhrases = await MainActor.run { StandardPhraseManager.shared.standardPhrases }
        }
        
        return targetPhrases.map { phrase in
            StandardPhraseEntity(id: phrase.id, title: phrase.title, content: phrase.content)
        }
    }
}

@available(macOS 14.0, *)
struct DeletePhraseOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<DeleteStandardPhraseIntent>( \.$preset )
    var intent
    
    func results() async throws -> [StandardPhraseEntity] {
        let presetEntity = intent?.preset
        
        let targetPhrases: [StandardPhrase]
        if let presetEntity = presetEntity, presetEntity.id != currentPresetDummyId {
            let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
            targetPhrases = presets.first(where: { $0.id == presetEntity.id })?.phrases ?? []
        } else {
            targetPhrases = await MainActor.run { StandardPhraseManager.shared.standardPhrases }
        }
        
        return targetPhrases.map { phrase in
            StandardPhraseEntity(id: phrase.id, title: phrase.title, content: phrase.content)
        }
    }
}
