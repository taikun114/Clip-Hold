import AppKit
import SwiftUI

private struct QuickOverlayHoverEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

private struct QuickOverlayHoverPriorityKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var quickOverlayHoverPriority: Int {
        get { self[QuickOverlayHoverPriorityKey.self] }
        set { self[QuickOverlayHoverPriorityKey.self] = newValue }
    }

    var quickOverlayHoverEnabled: Bool {
        get { self[QuickOverlayHoverEnabledKey.self] }
        set { self[QuickOverlayHoverEnabledKey.self] = newValue }
    }
}

extension View {
    func onQuickOverlayHover(_ action: @escaping (Bool) -> Void) -> some View {
        background(QuickOverlayHoverRegion(onChange: action))
    }

    func quickOverlayHoverBoundary() -> some View {
        background(QuickOverlayHoverRegion(kind: .boundary))
    }

    func blocksUnderlyingQuickOverlayHover() -> some View {
        background(QuickOverlayHoverRegion(kind: .blocker))
    }
}

private struct QuickOverlayHoverRegion: NSViewRepresentable {
    @Environment(\.quickOverlayHoverEnabled) private var isEnabled
    @Environment(\.quickOverlayHoverPriority) private var priority
    var kind: QuickOverlayHoverRegionView.Kind = .target
    var onChange: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> QuickOverlayHoverRegionView {
        let view = QuickOverlayHoverRegionView()
        view.onChange = onChange
        view.isHoverEnabled = isEnabled
        view.kind = kind
        view.priority = kind == .blocker ? 1 : priority
        return view
    }

    func updateNSView(_ nsView: QuickOverlayHoverRegionView, context: Context) {
        nsView.onChange = onChange
        nsView.isHoverEnabled = isEnabled
        nsView.kind = kind
        nsView.priority = kind == .blocker ? 1 : priority
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
    private var eventMonitors: [Any] = []
    private let cursorLocation: () -> NSPoint

    init(cursorLocation: @escaping () -> NSPoint = { NSEvent.mouseLocation }) {
        self.cursorLocation = cursorLocation
    }

    deinit {
        for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
    }

    private func startMonitoringIfNeeded() {
        guard eventMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in self?.scheduleUpdate() }
            return event
        }) {
            eventMonitors.append(monitor)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            Task { @MainActor in self?.scheduleUpdate() }
        }) {
            eventMonitors.append(monitor)
        }
    }

    func add(_ view: QuickOverlayHoverRegionView) {
        regions.add(view)
        startMonitoringIfNeeded()
        scheduleUpdate()
    }

    func remove(_ view: QuickOverlayHoverRegionView) {
        regions.remove(view)
        if regions.allObjects.isEmpty {
            for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
            eventMonitors.removeAll()
        }
        scheduleUpdate()
    }

    func scheduleUpdate() {
        guard !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateScheduled = false
            self.update(at: self.cursorLocation())
        }
    }

    func update(at screenPoint: NSPoint) {
        let allRegions = regions.allObjects
        let boundaries = allRegions.filter { $0.kind == .boundary }
        let containing = allRegions.filter { region in
            guard region.kind != .boundary, region.containsCursor(at: screenPoint) else { return false }
            let windowBoundaries = boundaries.filter { $0.window === region.window }
            return windowBoundaries.isEmpty || windowBoundaries.contains { $0.containsCursor(at: screenPoint) }
        }
        let blockingPriority = containing.filter { $0.kind == .blocker }.map(\.priority).max() ?? 0
        let candidates = containing.filter { $0.kind == .target && $0.priority >= blockingPriority }
        // バー内のボタンを、背後に隠れている行より優先する。
        let next = candidates.min {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
        }
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
    enum Kind { case target, blocker, boundary }
    var kind: Kind = .target
    var priority = 0
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
        let area = NSTrackingArea(rect: bounds.intersection(visibleRect), options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self)
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
