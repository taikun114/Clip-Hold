import Foundation
import AppIntents

let currentPresetDummyId = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
let allPresetsDummyId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let nextPresetDummyId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
let previousPresetDummyId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

@available(macOS 14.0, *)
struct StandardPhrasePresetEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "定型文プリセット"
    static let defaultQuery = StandardPhrasePresetEntityQuery()
    
    let id: UUID
    
    @Property(title: "Name")
    var name: String
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(macOS 14.0, *)
struct StandardPhrasePresetEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [StandardPhrasePresetEntity] {
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        var result: [StandardPhrasePresetEntity] = []
        
        if identifiers.contains(currentPresetDummyId) {
            result.append(StandardPhrasePresetEntity(id: currentPresetDummyId, name: String(localized: "現在のプリセット")))
        }
        if identifiers.contains(allPresetsDummyId) {
            result.append(StandardPhrasePresetEntity(id: allPresetsDummyId, name: String(localized: "すべてのプリセット")))
        }
        if identifiers.contains(nextPresetDummyId) {
            result.append(StandardPhrasePresetEntity(id: nextPresetDummyId, name: String(localized: "次のプリセット")))
        }
        if identifiers.contains(previousPresetDummyId) {
            result.append(StandardPhrasePresetEntity(id: previousPresetDummyId, name: String(localized: "前のプリセット")))
        }
        
        let matchedPresets = presets
            .filter { identifiers.contains($0.id) }
            .map { StandardPhrasePresetEntity(id: $0.id, name: $0.name) }
            
        result.append(contentsOf: matchedPresets)
        return result
    }
    
    func suggestedEntities() async throws -> [StandardPhrasePresetEntity] {
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        var result: [StandardPhrasePresetEntity] = [
            StandardPhrasePresetEntity(id: currentPresetDummyId, name: "現在のプリセット")
        ]
        result.append(contentsOf: presets.map { StandardPhrasePresetEntity(id: $0.id, name: $0.name) })
        return result
    }
    
    func defaultResult() async -> StandardPhrasePresetEntity? {
        return StandardPhrasePresetEntity(id: currentPresetDummyId, name: "現在のプリセット")
    }
}
