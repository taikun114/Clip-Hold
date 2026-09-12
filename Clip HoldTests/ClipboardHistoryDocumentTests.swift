import Testing
import Foundation
import SwiftUI
@testable import Clip_Hold

struct ClipboardHistoryDocumentTests {
    
    @Test
    func testDocumentFileWrapperSerializationAndDeserialization() throws {
        // テスト用の履歴アイテムを作成
        let item1 = ClipboardItem(
            text: "エクスポートテスト1",
            date: Date(timeIntervalSince1970: 1710000000),
            qrCodeContent: "https://cliphold.app"
        )
        let item2 = ClipboardItem(
            richText: "<p>リッチテキスト</p>",
            text: "リッチテキスト",
            date: Date(timeIntervalSince1970: 1710001000)
        )
        
        let originalDocument = ClipboardHistoryDocument(clipboardItems: [item1, item2])
        
        // FileWrapper にエンコード
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let encodedData = try encoder.encode(originalDocument.clipboardItems)
        
        #expect(!encodedData.isEmpty)
        
        // JSONデータから復元
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedItems = try decoder.decode([ClipboardItem].self, from: encodedData)
        
        #expect(decodedItems.count == 2)
        #expect(decodedItems[0].id == item1.id)
        #expect(decodedItems[0].text == "エクスポートテスト1")
        #expect(decodedItems[0].qrCodeContent == "https://cliphold.app")
        #expect(decodedItems[1].id == item2.id)
        #expect(decodedItems[1].richText == "<p>リッチテキスト</p>")
    }
    
    @Test
    func testEmptyDocumentSerialization() throws {
        let emptyDocument = ClipboardHistoryDocument(clipboardItems: [])
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedData = try encoder.encode(emptyDocument.clipboardItems)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedItems = try decoder.decode([ClipboardItem].self, from: encodedData)
        
        #expect(decodedItems.isEmpty)
    }
}
