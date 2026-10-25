import AppKit
import CoreGraphics

/// 画面内容やアクセシビリティ情報を使わず、ウィンドウの形状だけを扱う。
struct ClipboardSourceMenuWindow: Equatable {
    let id: CGWindowID
    let processIdentifier: pid_t
    let layer: Int
    let bounds: CGRect

    init(id: CGWindowID, processIdentifier: pid_t, layer: Int, bounds: CGRect) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.layer = layer
        self.bounds = bounds
    }

    init?(info: [String: Any]) {
        guard let id = info[kCGWindowNumber as String] as? CGWindowID,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t,
              let layer = info[kCGWindowLayer as String] as? Int,
              let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha > 0.2,
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds),
              rect.width > 0, rect.height > 0 else { return nil }
        self.init(id: id, processIdentifier: pid, layer: layer, bounds: rect)
    }
}

struct ClipboardSourceMenuTracking {
    enum ClickDecision: Equatable {
        case unavailable
        case preserve
        case discard
    }

    let openingPoint: CGPoint
    let sourceProcessIdentifier: pid_t
    private(set) var visibleWindows: [ClipboardSourceMenuWindow] = []
    private(set) var lastKnownWindows: [ClipboardSourceMenuWindow] = []
    var hasDetectedMenu: Bool { !lastKnownWindows.isEmpty }

    mutating func update(windows: [ClipboardSourceMenuWindow]) {
        let menuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let candidates = windows.filter {
            $0.processIdentifier == sourceProcessIdentifier && $0.layer == menuLayer
        }
        let knownIDs = Set(visibleWindows.map(\.id))
        // 右クリックの近くに現れたメニューを起点に、隣接するサブメニューをたどる。
        var accepted = candidates.filter {
            knownIDs.contains($0.id) || $0.bounds.insetBy(dx: -24, dy: -24).contains(openingPoint)
        }
        while true {
            let ids = Set(accepted.map(\.id))
            let additions = candidates.filter { candidate in
                !ids.contains(candidate.id) && accepted.contains {
                    $0.bounds.insetBy(dx: -24, dy: -24).intersects(candidate.bounds)
                }
            }
            guard !additions.isEmpty else { break }
            accepted.append(contentsOf: additions)
        }
        visibleWindows = accepted
        if !accepted.isEmpty { lastKnownWindows = accepted }
    }

    func decision(at point: CGPoint, isButtonRelease: Bool) -> ClickDecision {
        guard hasDetectedMenu else { return .unavailable }
        // メニューが解放イベントより先に消えても、最後に取得した範囲を使用する。
        let windows = visibleWindows.isEmpty ? lastKnownWindows : visibleWindows
        if windows.contains(where: { $0.bounds.contains(point) }) { return .preserve }
        // 開いた直後の手ぶれによる右ボタン解放をキャンセルとみなさない。
        return isButtonRelease ? .preserve : .discard
    }
}
