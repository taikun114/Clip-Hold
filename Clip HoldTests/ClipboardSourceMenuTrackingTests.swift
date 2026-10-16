import Testing
import AppKit
import CoreGraphics
@testable import Clip_Hold

struct ClipboardSourceMenuTrackingTests {
    private func menu(_ id: CGWindowID, pid: pid_t = 42, x: CGFloat = 100,
                      y: CGFloat = 100, width: CGFloat = 180, layer: Int? = nil) -> ClipboardSourceMenuWindow {
        ClipboardSourceMenuWindow(id: id, processIdentifier: pid,
                                  layer: layer ?? Int(CGWindowLevelForKey(.popUpMenuWindow)),
                                  bounds: CGRect(x: x, y: y, width: width, height: 220))
    }

    private func tracking() -> ClipboardSourceMenuTracking {
        ClipboardSourceMenuTracking(openingPoint: CGPoint(x: 105, y: 105), sourceProcessIdentifier: 42)
    }

    @Test func menuClicksPreserveAndOutsidePressDiscards() {
        var state = tracking()
        state.update(windows: [menu(1)])
        // ボタンの種類によらず、メニュー内の押下は元のコピー元を保持する。
        #expect(state.decision(at: CGPoint(x: 150, y: 180), isButtonRelease: false) == .preserve)
        #expect(state.decision(at: CGPoint(x: 500, y: 500), isButtonRelease: false) == .discard)
    }

    @Test func releaseOutsideDoesNotCancelForPointerJitter() {
        var state = tracking()
        state.update(windows: [menu(1)])
        #expect(state.decision(at: CGPoint(x: 95, y: 95), isButtonRelease: true) == .preserve)
        #expect(state.decision(at: CGPoint(x: 150, y: 180), isButtonRelease: true) == .preserve)
    }

    @Test func followsSubmenusAndRemovesClosedSubmenuBounds() {
        var state = tracking()
        state.update(windows: [menu(3, x: 460), menu(2, x: 280), menu(1)])
        #expect(state.visibleWindows.count == 3)
        #expect(state.decision(at: CGPoint(x: 500, y: 180), isButtonRelease: false) == .preserve)
        state.update(windows: [menu(1)])
        #expect(state.decision(at: CGPoint(x: 500, y: 180), isButtonRelease: false) == .discard)
    }

    @Test func retainsLastBoundsAfterMenuClosesForDelayedCopyAndKeyboardSelection() {
        var state = tracking()
        state.update(windows: [menu(1)])
        state.update(windows: [])
        #expect(state.hasDetectedMenu)
        #expect(state.visibleWindows.isEmpty)
        #expect(state.decision(at: CGPoint(x: 150, y: 180), isButtonRelease: false) == .preserve)
        #expect(state.decision(at: CGPoint(x: 500, y: 500), isButtonRelease: false) == .discard)
    }

    @Test func customMenuWithoutWindowFallsBack() {
        var state = tracking()
        state.update(windows: [menu(1, layer: 0)])
        #expect(!state.hasDetectedMenu)
        #expect(state.decision(at: CGPoint(x: 150, y: 180), isButtonRelease: false) == .unavailable)
        #expect(state.decision(at: CGPoint(x: 500, y: 500), isButtonRelease: true) == .unavailable)
    }

    @Test func ignoresOtherAppsAndUnrelatedFloatingWindows() {
        var state = tracking()
        state.update(windows: [menu(1, pid: 99), menu(2, layer: 3), menu(3, x: 800)])
        #expect(!state.hasDetectedMenu)
    }

    @Test func repeatedMenuSelectionsDoNotInvalidateSource() {
        var context = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        // サブメニュー操作やメニュー内での再右クリック・ミドルクリックを想定。
        context.recordMenuSelection(at: 11)
        context.recordMenuSelection(at: 12)
        context.recordMenuSelection(at: 13)
        #expect(context.isValid(at: 15))
        #expect(context.processIdentifiers == [42])
        #expect(!context.isValid(at: 71))
    }

    @Test func parsesWindowBoundsWithoutWindowTitle() {
        let info: [String: Any] = [
            kCGWindowNumber as String: CGWindowID(1),
            kCGWindowOwnerPID as String: pid_t(42),
            kCGWindowLayer as String: Int(CGWindowLevelForKey(.popUpMenuWindow)),
            kCGWindowAlpha as String: CGFloat(1),
            kCGWindowBounds as String: CGRect(x: 100, y: -200, width: 180, height: 220).dictionaryRepresentation
        ]
        let window = ClipboardSourceMenuWindow(info: info)
        #expect(window?.bounds == CGRect(x: 100, y: -200, width: 180, height: 220))
        #expect(window?.processIdentifier == 42)
    }
    @Test func cancelledMenuWithoutFurtherClicksExpiresAfterThreeSeconds() {
        // Finderを背面で右クリック。アクティブアプリの切り替え通知は発生しない。
        var source = ClipboardSourceClickContext(processIdentifiers: [42], recordedAt: 10)
        var state = tracking()
        state.update(windows: [menu(1)])

        // 長押し後にメニュー外で右ボタンを離し、コピーせずメニューが閉じる。
        #expect(state.decision(at: CGPoint(x: 95, y: 95), isButtonRelease: true) == .preserve)
        state.update(windows: [])
        #expect(state.visibleWindows.isEmpty)

        source.recordMenuVisibility(isVisible: false, at: 12)
        // メニュー閉鎖の理由によらず、追加クリックなしでも3秒後に期限切れになる。
        #expect(source.selectionClickedAt == nil)
        #expect(source.isValid(at: 13.46))
        #expect(source.isValid(at: 15))
        #expect(!source.isValid(at: 15.01))
        #expect(source.processIdentifiers.first == 42)
    }

    @Test func accessibilityKeyboardClickOutsideRequestsDiscardAfterCancellation() {
        var state = tracking()
        state.update(windows: [menu(1)])
        state.update(windows: [])

        // アクセシビリティキーボードのキーが、最後のメニュー範囲外にある場合。
        #expect(state.decision(at: CGPoint(x: 500, y: 500), isButtonRelease: false) == .discard)
        print("検証結果: メニュー外にあるアクセシビリティキーボードをクリックすると、候補破棄の判定になる。")
    }
}
