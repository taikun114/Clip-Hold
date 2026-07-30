import Foundation
import AppIntents
import CoreSpotlight
import SwiftUI

@available(macOS 14.0, *)
struct ClipboardItemEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Clipboard History Item")
    static let defaultQuery = ClipboardItemEntityQuery()
    
    let id: UUID
    
    @Property(title: "Content Text")
    var contentText: String
    
    @Property(title: "Date")
    var date: Date
    
    @Property(title: "Is File")
    var isFile: Bool
    
    @Property(title: "Filename")
    var filename: String?
    
    init(id: UUID, contentText: String, date: Date, isFile: Bool, filename: String?) {
        self.id = id
        self.contentText = contentText
        self.date = date
        self.isFile = isFile
        self.filename = filename
    }
    
    var displayRepresentation: DisplayRepresentation {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateStr = dateFormatter.string(from: date)
        
        let cleanText = contentText.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
        
        if isFile, let filename = filename {
            let iconName: String
            if #available(macOS 15.0, *) {
                iconName = "document"
            } else {
                iconName = "doc"
            }
            return DisplayRepresentation(
                title: LocalizedStringResource(stringLiteral: filename),
                subtitle: LocalizedStringResource(stringLiteral: "\(dateStr) - \(String(cleanText.prefix(100)))"),
                image: .init(systemName: iconName)
            )
        } else {
            let iconName: String
            if #available(macOS 15.0, *) {
                iconName = "document.on.document"
            } else {
                iconName = "doc.on.doc"
            }
            return DisplayRepresentation(
                title: LocalizedStringResource(stringLiteral: String(cleanText.prefix(100))),
                subtitle: LocalizedStringResource(stringLiteral: dateStr),
                image: .init(systemName: iconName)
            )
        }
    }
}

@available(macOS 14.0, *)
struct ClipboardItemEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ClipboardItemEntity] {
        // ChunkedHistoryManagerからIDに合致するアイテムを取得
        let history = await ChunkedHistoryManager.shared.loadHistory()
        return history.filter { identifiers.contains($0.id) }.map { item in
            ClipboardItemEntity(
                id: item.id,
                contentText: item.text,
                date: item.date,
                isFile: item.filePath != nil,
                filename: item.filePath?.lastPathComponent
            )
        }
    }
    
    func suggestedEntities() async throws -> [ClipboardItemEntity] {
        let history = await ChunkedHistoryManager.shared.loadHistory()
        return history.prefix(20).map { item in
            ClipboardItemEntity(
                id: item.id,
                contentText: item.text,
                date: item.date,
                isFile: item.filePath != nil,
                filename: item.filePath?.lastPathComponent
            )
        }
    }
}
