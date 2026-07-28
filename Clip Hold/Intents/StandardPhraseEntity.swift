import Foundation
import AppIntents
import CoreSpotlight
import SwiftUI

@available(macOS 14.0, *)
struct StandardPhraseEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Standard Phrase")
    static let defaultQuery = StandardPhraseEntityQuery()
    
    let id: UUID
    let title: String
    let content: String
    
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
        // StandardPhraseManagerからIDに合致するアイテムを取得
        let manager = StandardPhraseManager.shared
        return manager.standardPhrases.filter { identifiers.contains($0.id) }.map { phrase in
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
