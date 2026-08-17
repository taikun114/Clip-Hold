import Testing
import Foundation
@testable import Clip_Hold

struct IndexedClipboardItemTests {
    
    @Test
    func testInitializationFromClipboardItem() {
        let originalItem = ClipboardItem(
            text: "インデックス対象アイテム",
            date: Date(timeIntervalSince1970: 1720000000)
        )
        
        let indexedItem = IndexedClipboardItem(from: originalItem)
        
        #expect(indexedItem.id == originalItem.id)
        #expect(indexedItem.date == originalItem.date)
    }
    
    @Test
    func testCodableSerialization() throws {
        let originalItem = ClipboardItem(
            text: "シリアライズ検証",
            date: Date(timeIntervalSince1970: 1720001000)
        )
        let indexedItem = IndexedClipboardItem(from: originalItem)
        
        let encodedData = try JSONEncoder().encode(indexedItem)
        let decodedItem = try JSONDecoder().decode(IndexedClipboardItem.self, from: encodedData)
        
        #expect(decodedItem.id == indexedItem.id)
        #expect(decodedItem.date == indexedItem.date)
    }
}
