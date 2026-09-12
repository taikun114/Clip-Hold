import Testing
import AppKit
@testable import Clip_Hold

struct ClipboardSourceAppLogicTests {
    
    @Test
    func testAppOwningFrontmostWindowExecutionSafety() {
        // テスト実行環境においてクラッシュせず、フォールバックまたは有効なアプリが返ることを検証
        let app = ClipboardSourceAppDetector.appOwningFrontmostWindow()
        
        // 通常は現在のテストランナーまたはアクティブアプリが返る
        if let app = app {
            #expect(app.processIdentifier > 0)
        }
    }
    
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
