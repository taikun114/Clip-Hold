import Testing
@testable import Clip_Hold

@MainActor
struct QuickOverlayPasteRequestTests {
    enum CompletionOrder: CaseIterable {
        case copyFirst
        case animationFirst
    }

    @Test("コピーと閉じるアニメーションの両方が完了するまで貼り付けない", arguments: CompletionOrder.allCases)
    func waitsForBothCompletions(order: CompletionOrder) {
        var pasteCount = 0
        let request = QuickOverlayPasteRequest { pasteCount += 1 }

        switch order {
        case .copyFirst:
            request.copyDidComplete()
            #expect(pasteCount == 0)
            request.overlayDidClose()
        case .animationFirst:
            request.overlayDidClose()
            #expect(pasteCount == 0)
            request.copyDidComplete()
        }

        #expect(pasteCount == 1)
    }

    @Test("完了通知が重複しても貼り付けは一度だけ実行する")
    func duplicateCompletionsPasteOnce() {
        var pasteCount = 0
        let request = QuickOverlayPasteRequest { pasteCount += 1 }
        request.copyDidComplete()
        request.copyDidComplete()
        #expect(pasteCount == 0)

        request.overlayDidClose()
        request.overlayDidClose()
        request.copyDidComplete()
        #expect(pasteCount == 1)
    }

    @Test("再表示や中断で取り消した後は残りの完了通知が届いても貼り付けない", arguments: CompletionOrder.allCases)
    func cancellationWhileWaiting(order: CompletionOrder) {
        var pasteCount = 0
        let request = QuickOverlayPasteRequest { pasteCount += 1 }
        switch order {
        case .copyFirst:
            request.copyDidComplete()
        case .animationFirst:
            request.overlayDidClose()
        }

        request.cancel()
        request.copyDidComplete()
        request.overlayDidClose()
        #expect(pasteCount == 0)
    }

    @Test("クイックペーストが無効なら両方の処理が完了しても貼り付けない")
    func cancellationBeforeCompletions() {
        var pasteCount = 0
        let request = QuickOverlayPasteRequest { pasteCount += 1 }
        request.cancel()
        request.copyDidComplete()
        request.overlayDidClose()
        #expect(pasteCount == 0)
    }

    @Test("前のコピーが遅れて完了しても新しい操作の貼り付けに混ざらない")
    func cancelledRequestDoesNotAffectNextRequest() {
        var pastedItems: [String] = []
        let previous = QuickOverlayPasteRequest { pastedItems.append("古い架空の項目") }
        previous.overlayDidClose()
        previous.cancel()

        let current = QuickOverlayPasteRequest { pastedItems.append("新しい架空の項目") }
        current.copyDidComplete()
        previous.copyDidComplete()
        #expect(pastedItems.isEmpty)

        current.overlayDidClose()
        #expect(pastedItems == ["新しい架空の項目"])
    }
}
