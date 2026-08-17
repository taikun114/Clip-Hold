import Testing
import Foundation
@testable import Clip_Hold

@MainActor
struct PresetAppAssignmentLogicTests {
    
    @Test
    func testAssignmentOperationsWithStateRestoration() {
        let manager = PresetAppAssignmentManager.shared
        let originalAssignments = manager.assignments
        
        defer {
            // テスト終了時に元の割り当て状態を確実に復元
            manager.assignments = originalAssignments
        }
        
        let testPresetID1 = UUID()
        let testPresetID2 = UUID()
        let safariBundleID = "com.apple.Safari"
        let notesBundleID = "com.apple.Notes"
        
        // 1. 割り当ての追加
        manager.addAssignment(for: testPresetID1, bundleIdentifier: safariBundleID)
        #expect(manager.getAssignments(for: testPresetID1).contains(safariBundleID))
        #expect(manager.getPresetId(for: safariBundleID) == testPresetID1)
        
        // 2. 重複追加の防止（同じBundleIDを再追加しても要素数は1つ）
        manager.addAssignment(for: testPresetID1, bundleIdentifier: safariBundleID)
        #expect(manager.getAssignments(for: testPresetID1).filter { $0 == safariBundleID }.count == 1)
        
        // 3. 別アプリの追加
        manager.addAssignment(for: testPresetID1, bundleIdentifier: notesBundleID)
        #expect(manager.getAssignments(for: testPresetID1).count == 2)
        
        // 4. プリセットID2へ別アプリを追加
        let xcodeBundleID = "com.apple.dt.Xcode"
        manager.addAssignment(for: testPresetID2, bundleIdentifier: xcodeBundleID)
        #expect(manager.getPresetId(for: xcodeBundleID) == testPresetID2)
        
        // 5. 特定アプリの割り当て解除
        manager.removeAssignment(for: safariBundleID)
        #expect(!manager.getAssignments(for: testPresetID1).contains(safariBundleID))
        #expect(manager.getPresetId(for: safariBundleID) == nil)
        
        // 6. プリセット単位での割り当て全解除
        manager.clearAssignments(for: testPresetID1)
        #expect(manager.getAssignments(for: testPresetID1).isEmpty)
        
        // プリセット2の割り当ては保持されていること
        #expect(manager.getPresetId(for: xcodeBundleID) == testPresetID2)
    }
}
