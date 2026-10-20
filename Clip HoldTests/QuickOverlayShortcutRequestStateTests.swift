import Testing
@testable import Clip_Hold

struct QuickOverlayShortcutRequestStateTests {
    @Test("最新の要求と現在の修飾キーが一致している場合だけ表示する")
    func latestRequestWithHeldKeys() {
        var state = QuickOverlayShortcutRequestState()
        let request = state.begin(modifiers: 3)
        #expect(state.canPresent(request, currentModifiers: 3, isEnabled: true))
    }

    @Test("表示待ちやビュー構築中にキーを離した場合は表示しない")
    func releasedBeforePresentation() {
        var state = QuickOverlayShortcutRequestState()
        let request = state.begin(modifiers: 3)
        #expect(!state.canPresent(request, currentModifiers: 0, isEnabled: true))
    }

    @Test("履歴から定型文へ素早く切り替えて離した場合はどちらも表示しない")
    func rapidSwitchAndRelease() {
        var state = QuickOverlayShortcutRequestState()
        let history = state.begin(modifiers: 3)
        let phrase = state.begin(modifiers: 5)
        #expect(!state.canPresent(history, currentModifiers: 5, isEnabled: true))
        #expect(state.canPresent(phrase, currentModifiers: 5, isEnabled: true))
        #expect(!state.canPresent(history, currentModifiers: 0, isEnabled: true))
        #expect(!state.canPresent(phrase, currentModifiers: 0, isEnabled: true))
    }

    @Test("同じ修飾キーを押し直しても古い表示要求は復活しない")
    func repeatedSameModifiers() {
        var state = QuickOverlayShortcutRequestState()
        let previous = state.begin(modifiers: 3)
        state.cancel()
        let current = state.begin(modifiers: 3)
        #expect(!state.canPresent(previous, currentModifiers: 3, isEnabled: true))
        #expect(state.canPresent(current, currentModifiers: 3, isEnabled: true))
    }

    @Test("キャンセル後に表示待ちタスクが戻ってきても表示しない")
    func cancelledRequestCannotShow() {
        var state = QuickOverlayShortcutRequestState()
        let request = state.begin(modifiers: 3)
        state.cancel()
        #expect(state.current == nil)
        #expect(!state.canPresent(request, currentModifiers: 3, isEnabled: true))
    }

    @Test("表示開始時には押されていてもアニメーション完了時に離れていれば維持しない")
    func releaseDuringShowAnimation() {
        var state = QuickOverlayShortcutRequestState()
        let request = state.begin(modifiers: 3)
        #expect(state.canPresent(request, currentModifiers: 3, isEnabled: true))
        #expect(!state.canPresent(request, currentModifiers: 0, isEnabled: true))
    }

    @Test("ショートカット機能が無効ならキーが一致していても表示しない")
    func disabledShortcut() {
        var state = QuickOverlayShortcutRequestState()
        let request = state.begin(modifiers: 3)
        #expect(!state.canPresent(request, currentModifiers: 3, isEnabled: false))
    }

    @Test("未設定や異なる修飾キーでは表示しない")
    func invalidModifiers() {
        var state = QuickOverlayShortcutRequestState()
        let unset = state.begin(modifiers: 0)
        #expect(!state.canPresent(unset, currentModifiers: 0, isEnabled: true))
        let request = state.begin(modifiers: 3)
        #expect(!state.canPresent(request, currentModifiers: 7, isEnabled: true))
        #expect(!state.canPresent(request, currentModifiers: 1, isEnabled: true))
    }
}
