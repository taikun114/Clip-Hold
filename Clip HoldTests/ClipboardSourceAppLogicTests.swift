import Testing
import AppKit
@testable import Clip_Hold

struct ClipboardSourceAppLogicTests {
    
    @Test
    @MainActor
    func testUpdateExcludedAppIdentifiers() {
        let manager = ClipboardManager.shared
        let originalExcluded = manager.excludedAppIdentifiers
        
        defer {
            // テスト終了時に元の除外アプリ設定を確実に復元
            manager.updateExcludedAppIdentifiers(originalExcluded)
        }
        
        let testExcludedList = ["com.test.excludedApp1", "com.test.excludedApp2"]
        
        // 除外リストの更新
        manager.updateExcludedAppIdentifiers(testExcludedList)
        #expect(manager.excludedAppIdentifiers == testExcludedList)
        
        // 空リストへの更新
        manager.updateExcludedAppIdentifiers([])
        #expect(manager.excludedAppIdentifiers.isEmpty)
    }
}
