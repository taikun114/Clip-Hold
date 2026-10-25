import Testing
import AppKit
@testable import Clip_Hold

struct ClipboardSourceClickContextTests {
    @Test func selectionClickPreservesOriginalCandidates() {
        var context = ClipboardSourceClickContext(processIdentifiers: [42, 73], recordedAt: 10)
        context.recordSelectionClick(at: 20)
        #expect(context.processIdentifiers == [42, 73])
        #expect(context.isValid(at: 20.2))
        // 実際に失敗した約1.46秒の遅延でも候補を保持する。
        #expect(context.isValid(at: 21.46))
        #expect(context.isValid(at: 70))
        #expect(!context.isValid(at: 70.01))
    }

    @Test func subsequentClickInvalidatesContext() {
        var context = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        context.recordSelectionClick(at: 11)
        context.recordSelectionClick(at: 11.2)
        #expect(!context.isValid(at: 11.3))
    }

    @Test func abandonedMenuExpires() {
        let context = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        #expect(context.isValid(at: 69))
        #expect(!context.isValid(at: 71))
        #expect(!context.isValid(at: 9))
    }
    @Test func activatingCopySourcePreservesContext() {
        let context = ClipboardSourceClickContext(processIdentifiers: [42, 73], recordedAt: 10)
        #expect(!context.shouldDiscardOnActivation(of: 42))
    }

    @Test func switchingToAnotherAppDiscardsContext() {
        let context = ClipboardSourceClickContext(processIdentifiers: [42, 73], recordedAt: 10)
        #expect(context.shouldDiscardOnActivation(of: 99))
        // 同じ座標の奥にあったアプリでも、別の操作先へ切り替わったら破棄する。
        #expect(context.shouldDiscardOnActivation(of: 73))
    }

    @Test func emptyCandidatesAreDiscardedOnActivation() {
        let context = ClipboardSourceClickContext(processIdentifiers: [], recordedAt: 10)
        #expect(context.shouldDiscardOnActivation(of: 42))
    }
    @Test func hitTestCoordinatesUsePrimaryScreenOrigin() {
        #expect(ClipboardSourceHitTestCoordinates.appKitPoint(
            from: CGPoint(x: 100, y: 200), primaryScreenMaxY: 2160) == NSPoint(x: 100, y: 1960))
        // 主画面より左・上・下に配置した画面でも同じ原点で変換する。
        #expect(ClipboardSourceHitTestCoordinates.appKitPoint(
            from: CGPoint(x: -100, y: -200), primaryScreenMaxY: 2160) == NSPoint(x: -100, y: 2360))
        #expect(ClipboardSourceHitTestCoordinates.appKitPoint(
            from: CGPoint(x: 100, y: 2400), primaryScreenMaxY: 2160) == NSPoint(x: 100, y: -240))
    }
    @Test func repeatedMissingSamplesDoNotExtendDeadline() {
        var context = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        context.recordMenuVisibility(isVisible: false, at: 12)
        context.recordMenuVisibility(isVisible: false, at: 12.5)
        #expect(context.menuDisappearedAt == 12)
        #expect(!context.isValid(at: 15.01))
    }

    @Test func menuReappearanceResetsDisappearanceDeadline() {
        var context = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        context.recordMenuVisibility(isVisible: false, at: 12)
        context.recordMenuVisibility(isVisible: true, at: 13)
        #expect(context.menuDisappearedAt == nil)
        #expect(context.isValid(at: 20))
        context.recordMenuVisibility(isVisible: false, at: 21)
        #expect(context.isValid(at: 24))
        #expect(!context.isValid(at: 24.01))
    }

    @Test func originalSixtySecondLimitStillAppliesAfterClosure() {
        var context = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        context.recordMenuVisibility(isVisible: false, at: 69)
        #expect(context.isValid(at: 70))
        #expect(!context.isValid(at: 70.01))
    }
}
