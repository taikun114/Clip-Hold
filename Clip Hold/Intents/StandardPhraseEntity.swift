import Foundation
import AppIntents
import CoreSpotlight
import SwiftUI

@available(macOS 14.0, *)
struct StandardPhraseEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Standard Phrase")
    static let defaultQuery = StandardPhraseEntityQuery()
    
    let id: UUID
    
    @Property(title: "Title")
    var title: String
    
    @Property(title: "Content")
    var content: String
    
    init(id: UUID, title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: String(content.prefix(100))),
            image: .init(systemName: "text.quote")
        )
    }
}

@available(macOS 14.0, *)
struct StandardPhraseEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [StandardPhraseEntity] {
        let presets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
        let currentPhrases = await MainActor.run { StandardPhraseManager.shared.standardPhrases }
        let allPhrases = presets.flatMap { $0.phrases } + currentPhrases
        
        // Remove duplicates by ID in case currentPhrases overlaps with presets
        var uniquePhrases = [UUID: StandardPhrase]()
        for phrase in allPhrases {
            uniquePhrases[phrase.id] = phrase
        }
        
        return uniquePhrases.values.filter { identifiers.contains($0.id) }.map { phrase in
            StandardPhraseEntity(
                id: phrase.id,
                title: phrase.title,
                content: phrase.content
            )
        }
    }
    
    func suggestedEntities() async throws -> [StandardPhraseEntity] {
        let manager = StandardPhraseManager.shared
        return manager.standardPhrases.map { phrase in
            StandardPhraseEntity(
                id: phrase.id,
                title: phrase.title,
                content: phrase.content
            )
        }
    }
}
