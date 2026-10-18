import AppKit
import SwiftUI

private struct QuickOverlayHoverEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var quickOverlayHoverEnabled: Bool {
        get { self[QuickOverlayHoverEnabledKey.self] }
        set { self[QuickOverlayHoverEnabledKey.self] = newValue }
    }
}

extension View {
    func onQuickOverlayHover(_ action: @escaping (Bool) -> Void) -> some View {
        background(QuickOverlayHoverRegion(onChange: action))
    }
}

private struct QuickOverlayHoverRegion: NSViewRepresentable {
    @Environment(\.quickOverlayHoverEnabled) private var isEnabled
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> QuickOverlayHoverRegionView {
        let view = QuickOverlayHoverRegionView()
        view.onChange = onChange
        view.isHoverEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: QuickOverlayHoverRegionView, context: Context) {
        nsView.onChange = onChange
        nsView.isHoverEnabled = isEnabled
        QuickOverlayHoverCoordinator.shared.scheduleUpdate()
    }

    static func dismantleNSView(_ nsView: QuickOverlayHoverRegionView, coordinator: ()) {
        QuickOverlayHoverCoordinator.shared.remove(nsView)
    }
}

/// 過去のイベント座標ではなく、通知をまとめた後の実際のカーソル位置を使う。
@MainActor
final class QuickOverlayHoverCoordinator {
    static let shared = QuickOverlayHoverCoordinator()
    private let regions = NSHashTable<QuickOverlayHoverRegionView>.weakObjects()
    private var activeID: ObjectIdentifier?
    private var activeCallback: ((Bool) -> Void)?
    private var updateScheduled = false

    func add(_ view: QuickOverlayHoverRegionView) {
        regions.add(view)
        scheduleUpdate()
    }

    func remove(_ view: QuickOverlayHoverRegionView) {
        regions.remove(view)
        scheduleUpdate()
    }

    func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.update(at: NSEvent.mouseLocation)
        }
    }

    func update(at screenPoint: NSPoint) {
        let candidates = regions.allObjects.filter { $0.containsCursor(at: screenPoint) }
        // 領域が重なる場合は、操作ボタンなどの小さい領域を優先する。
        let next = candidates.min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
        let nextID = next.map(ObjectIdentifier.init)
        guard activeID != nextID else {
            activeCallback = next?.onChange
            return
        }
        let previousCallback = activeCallback
        activeID = nextID
        activeCallback = next?.onChange
        // 古い対象の解除を先に完了し、新しい対象の状態を後から上書きさせない。
        previousCallback?(false)
        activeCallback?(true)
    }
}

@MainActor
final class QuickOverlayHoverRegionView: NSView {
    var onChange: ((Bool) -> Void)?
    var isHoverEnabled = true
    private var hoverTrackingArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            window.acceptsMouseMovedEvents = true
            QuickOverlayHoverCoordinator.shared.add(self)
        } else {
            QuickOverlayHoverCoordinator.shared.remove(self)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverTrackingArea = area
        QuickOverlayHoverCoordinator.shared.scheduleUpdate()
    }

    override func layout() {
        super.layout()
        QuickOverlayHoverCoordinator.shared.scheduleUpdate()
    }

    override func mouseEntered(with event: NSEvent) { QuickOverlayHoverCoordinator.shared.scheduleUpdate() }
    override func mouseExited(with event: NSEvent) { QuickOverlayHoverCoordinator.shared.scheduleUpdate() }
    override func mouseMoved(with event: NSEvent) { QuickOverlayHoverCoordinator.shared.scheduleUpdate() }

    func containsCursor(at screenPoint: NSPoint) -> Bool {
        guard isHoverEnabled, !isHiddenOrHasHiddenAncestor,
              let window, window.isVisible else { return false }
        let localPoint = convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        return NSMouseInRect(localPoint, bounds.intersection(visibleRect), isFlipped)
    }
}
