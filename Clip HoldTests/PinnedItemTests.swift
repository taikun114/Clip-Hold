import Testing
import Foundation
@testable import Clip_Hold

@MainActor
struct PinnedItemTests {
    
    @Test
    func testPinAndUnpinItem() {
        let manager = ClipboardManager.shared
        let testItem = ClipboardItem(text: "テスト用ピン留めテキスト")
        manager.clipboardHistory.append(testItem)
        
        // ピン留めの登録
        manager.pinItem(testItem)
        #expect(manager.pinnedItemID == testItem.id)
        #expect(manager.pinnedItem?.id == testItem.id)
        
        // ピン留めの解除
        manager.unpinItem()
        #expect(manager.pinnedItemID == nil)
        #expect(manager.pinnedItem == nil)
        
        // クリーンアップ
        if let index = manager.clipboardHistory.firstIndex(of: testItem) {
            manager.clipboardHistory.remove(at: index)
        }
    }
    
    @Test
    func testUnpinOnItemDeletion() {
        let manager = ClipboardManager.shared
        let testItem = ClipboardItem(text: "削除用テストアイテム")
        manager.clipboardHistory.append(testItem)
        
        manager.pinItem(testItem)
        #expect(manager.pinnedItemID == testItem.id)
        
        // アイテム削除時にピン留めが自動解除されるか検証
        manager.deleteItem(id: testItem.id)
        #expect(manager.pinnedItemID == nil)
        #expect(manager.pinnedItem == nil)
    }
}
