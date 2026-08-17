import Testing
import Foundation
@testable import Clip_Hold

@MainActor
struct PinnedItemTests {
    
    @Test
    func testPinAndUnpinItem() {
        let manager = ClipboardManager.shared
        let originalPinnedItemID = manager.pinnedItemID
        let testItem = ClipboardItem(text: "テスト用ピン留めテキスト")
        manager.clipboardHistory.append(testItem)
        
        defer {
            // テスト用アイテムの削除と、ピン留め状態の復元
            if let index = manager.clipboardHistory.firstIndex(of: testItem) {
                manager.clipboardHistory.remove(at: index)
            }
            manager.pinnedItemID = originalPinnedItemID
        }
        
        // ピン留めの登録
        manager.pinItem(testItem)
        #expect(manager.pinnedItemID == testItem.id)
        #expect(manager.pinnedItem?.id == testItem.id)
        
        // ピン留めの解除
        manager.unpinItem()
        #expect(manager.pinnedItemID == nil)
        #expect(manager.pinnedItem == nil)
    }
    
    @Test
    func testUnpinOnItemDeletion() {
        let manager = ClipboardManager.shared
        let originalPinnedItemID = manager.pinnedItemID
        let testItem = ClipboardItem(text: "削除用テストアイテム")
        manager.clipboardHistory.append(testItem)
        
        defer {
            // テスト用アイテムが残っていれば削除し、ピン留め状態を復元
            if let index = manager.clipboardHistory.firstIndex(of: testItem) {
                manager.clipboardHistory.remove(at: index)
            }
            manager.pinnedItemID = originalPinnedItemID
        }
        
        manager.pinItem(testItem)
        #expect(manager.pinnedItemID == testItem.id)
        
        // アイテム削除時にピン留めが自動解除されるか検証
        manager.deleteItem(id: testItem.id)
        #expect(manager.pinnedItemID == nil)
        #expect(manager.pinnedItem == nil)
    }
    
    @Test
    func testPinStateRestoration() {
        let manager = ClipboardManager.shared
        let originalPinnedItemID = manager.pinnedItemID
        
        // 事前にピン留めが存在する状況を再現
        let dummyExistingItem = ClipboardItem(text: "事前ピン留めダミーアイテム")
        manager.clipboardHistory.append(dummyExistingItem)
        manager.pinnedItemID = dummyExistingItem.id
        
        defer {
            if let index = manager.clipboardHistory.firstIndex(of: dummyExistingItem) {
                manager.clipboardHistory.remove(at: index)
            }
            manager.pinnedItemID = originalPinnedItemID
        }
        
        // テスト内スコープでのピン留め変更
        do {
            let innerOriginalID = manager.pinnedItemID
            let innerTestItem = ClipboardItem(text: "内部テスト用アイテム")
            manager.clipboardHistory.append(innerTestItem)
            
            defer {
                if let index = manager.clipboardHistory.firstIndex(of: innerTestItem) {
                    manager.clipboardHistory.remove(at: index)
                }
                manager.pinnedItemID = innerOriginalID
            }
            
            manager.pinItem(innerTestItem)
            #expect(manager.pinnedItemID == innerTestItem.id)
            
            manager.unpinItem()
            #expect(manager.pinnedItemID == nil)
        }
        
        // スコープ終了後に事前ピン留め状態へ復元されていることを検証
        #expect(manager.pinnedItemID == dummyExistingItem.id)
    }
}
