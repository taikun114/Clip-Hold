import AppKit
import Testing
@testable import Clip_Hold

@MainActor
struct QuickOverlayHoverTrackingTests {
    @MainActor
    private final class Harness {
        let coordinator = QuickOverlayHoverCoordinator()
        let panel: NSPanel
        let first = QuickOverlayHoverRegionView(frame: NSRect(x: 0, y: 0, width: 100, height: 50))
        let second = QuickOverlayHoverRegionView(frame: NSRect(x: 0, y: 50, width: 100, height: 50))
        var changes: [String] = []

        init() {
            panel = NSPanel(contentRect: NSRect(x: 100, y: 100, width: 100, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            let content = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            content.addSubview(first)
            content.addSubview(second)
            panel.contentView = content
            first.onChange = { [weak self] inside in self?.changes.append("first:\(inside)") }
            second.onChange = { [weak self] inside in self?.changes.append("second:\(inside)") }
            coordinator.add(first)
            coordinator.add(second)
            panel.orderBack(nil)
        }

        func point(in view: NSView, x: CGFloat = 20, y: CGFloat = 20) -> NSPoint {
            panel.convertPoint(toScreen: view.convert(NSPoint(x: x, y: y), to: nil))
        }

        func close() { panel.close() }
    }

    @Test("過去に通過した項目ではなく、最後のカーソル位置の項目を選ぶ")
    func usesLatestPosition() {
        let harness = Harness()
        defer { harness.close() }
        harness.coordinator.update(at: harness.point(in: harness.first))
        harness.coordinator.scheduleUpdate()
        harness.coordinator.scheduleUpdate()
        harness.coordinator.update(at: harness.point(in: harness.second))
        #expect(harness.changes == ["first:true", "first:false", "second:true"])
    }

    @Test("同じ項目内の移動では通知を繰り返さずツールチップ待機を維持する")
    func movingWithinSameRegion() {
        let harness = Harness()
        defer { harness.close() }
        harness.coordinator.update(at: harness.point(in: harness.first))
        harness.coordinator.update(at: harness.point(in: harness.first, x: 70, y: 35))
        #expect(harness.changes == ["first:true"])
    }

    @Test("領域から出た場合は古いホバー状態を解除する")
    func leavingRegions() {
        let harness = Harness()
        defer { harness.close() }
        harness.coordinator.update(at: harness.point(in: harness.first))
        harness.coordinator.update(at: NSPoint(x: -10000, y: -10000))
        #expect(harness.changes == ["first:true", "first:false"])
    }

    @Test("行高や配置が変わっても止まっているカーソルの位置で判定する")
    func layoutChangesUnderPointer() {
        let harness = Harness()
        defer { harness.close() }
        let cursor = harness.point(in: harness.first)
        harness.coordinator.update(at: cursor)
        harness.first.frame.origin.y = 50
        harness.second.frame.origin.y = 0
        harness.coordinator.update(at: cursor)
        #expect(harness.changes == ["first:true", "first:false", "second:true"])
    }

    @Test("重なった小さな操作領域への切り替えも解除してから選択する")
    func nestedButtonRegion() {
        let harness = Harness()
        defer { harness.close() }
        let button = QuickOverlayHoverRegionView(frame: NSRect(x: 10, y: 10, width: 30, height: 30))
        button.onChange = { [weak harness] inside in harness?.changes.append("button:\(inside)") }
        harness.first.addSubview(button)
        harness.coordinator.add(button)
        harness.coordinator.update(at: harness.point(in: harness.first, x: 80))
        harness.coordinator.update(at: harness.point(in: button))
        #expect(harness.changes == ["first:true", "first:false", "button:true"])
    }

    @Test("非表示または無効な項目にはホバーしない")
    func ignoresDisabledAndHiddenRegions() {
        let harness = Harness()
        defer { harness.close() }
        harness.first.isHoverEnabled = false
        harness.coordinator.update(at: harness.point(in: harness.first))
        harness.second.isHidden = true
        harness.coordinator.update(at: harness.point(in: harness.second))
        #expect(harness.changes.isEmpty)
    }

    @Test("削除した領域のホバー状態を解除する")
    func removedRegion() {
        let harness = Harness()
        defer { harness.close() }
        let cursor = harness.point(in: harness.first)
        harness.coordinator.update(at: cursor)
        harness.coordinator.remove(harness.first)
        harness.coordinator.update(at: cursor)
        #expect(harness.changes == ["first:true", "first:false"])
    }
}
