import Cocoa
import CoreGraphics

struct ClipboardSourceAppDetector {
    private static var globalMonitor: Any?
    private static var localMonitor: Any?
    private static var context: ClipboardSourceClickContext?
    private static var activationObserver: NSObjectProtocol?
    private static var menuTracking: ClipboardSourceMenuTracking?
    private static var menuMonitorTimer: Timer?
    private static var menuMissingSince: TimeInterval?

    static func startMonitoring() {
        stopMonitoring()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let recordedContext = context else { return }
            if recordedContext.shouldDiscardOnActivation(of: app.processIdentifier) {
#if DEBUG
                print("DEBUG: [コピー元] 候補破棄: 別アプリがアクティブになった, \(debugDescription(app)), \(recordedContext.debugStatus(at: ProcessInfo.processInfo.systemUptime))")
#endif
                clearContext()
            } else {
#if DEBUG
                print("DEBUG: [コピー元] 候補保持: コピー元候補がアクティブになった, \(debugDescription(app))")
#endif
            }
        }
        let mask: NSEvent.EventTypeMask = [.rightMouseDown, .leftMouseDown, .otherMouseDown, .rightMouseUp, .otherMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            let now = ProcessInfo.processInfo.systemUptime
#if DEBUG
            print("DEBUG: [コピー元] マウスイベント: 種類=\(event.type.rawValue), ボタン=\(event.buttonNumber), Control=\(event.modifierFlags.contains(.control)), 時刻=\(now), アクティブ=\(debugDescription(NSWorkspace.shared.frontmostApplication))")
#endif
            let isRelease = event.type == .rightMouseUp || event.type == .otherMouseUp
            let point = event.cgEvent?.location
            refreshMenuTracking(forMouseEvent: true)
            if let point, let menuTracking {
                switch menuTracking.decision(at: point, isButtonRelease: isRelease) {
                case .preserve:
                    if !isRelease { context?.recordMenuSelection(at: now) }
#if DEBUG
                    print("DEBUG: [コピー元] メニュー操作で候補保持: 種類=\(event.type.rawValue), 座標=\(point), 解放=\(isRelease)")
#endif
                    return
                case .discard:
#if DEBUG
                    print("DEBUG: [コピー元] メニュー外のクリックで候補破棄: 種類=\(event.type.rawValue), 座標=\(point)")
#endif
                    clearContext()
                case .unavailable:
                    break
                }
            }
            // ボタンを離しただけでは、新しい候補の記録や破棄を行わない。
            if isRelease { return }
            if event.type == .rightMouseDown ||
                (event.type == .leftMouseDown && event.modifierFlags.contains(.control)) {
                clearContext()
                guard let point else {
#if DEBUG
                    print("DEBUG: [コピー元] 候補破棄: イベント座標を取得できない")
#endif
                    return
                }
                let apps = candidateApps(at: point)
                context = ClipboardSourceClickContext(
                    processIdentifiers: apps.map(\.processIdentifier), recordedAt: now)
#if DEBUG
                print("DEBUG: [コピー元] 候補記録: 種類=\(event.type == .rightMouseDown ? "右クリック" : "Control＋クリック"), 座標=\(point), アプリ=\(apps.map { debugDescription($0) })")
#endif
                if let pid = apps.first?.processIdentifier { startMenuTracking(at: point, sourcePID: pid) }
            } else if event.type == .leftMouseDown {
                context?.recordSelectionClick(at: now)
#if DEBUG
                print("DEBUG: [コピー元] 左クリック後: \(context?.debugStatus(at: now) ?? "候補なし")")
#endif
            } else {
#if DEBUG
                print("DEBUG: [コピー元] 候補破棄: その他のマウスボタン（メニュー未検出）")
#endif
                clearContext()
            }
        }
        // Clip Hold内の操作には、外部アプリの候補を引き継がない。
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            if event.type == .rightMouseUp || event.type == .otherMouseUp { return event }
#if DEBUG
            print("DEBUG: [コピー元] 候補破棄: Clip Hold内のクリック, 種類=\(event.type.rawValue)")
#endif
            clearContext()
            return event
        }
#if DEBUG
        print("DEBUG: [コピー元] 監視開始: 外部=\(globalMonitor != nil), 内部=\(localMonitor != nil)")
#endif
        if globalMonitor == nil {
            print("ClipboardSourceAppDetector: マウス監視を開始できませんでした。アクティブアプリの判定を使用します。")
        }
    }

    static func stopMonitoring() {
#if DEBUG
        print("DEBUG: [コピー元] 監視停止・候補破棄")
#endif
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        globalMonitor = nil
        localMonitor = nil
        clearContext()
    }

    private static func clearContext() {
        context = nil
        menuTracking = nil
        menuMissingSince = nil
        menuMonitorTimer?.invalidate()
        menuMonitorTimer = nil
    }

    private static func startMenuTracking(at point: CGPoint, sourcePID: pid_t) {
        menuTracking = ClipboardSourceMenuTracking(openingPoint: point, sourceProcessIdentifier: sourcePID)
        let timer = Timer(timeInterval: 0.15, repeats: true) { _ in refreshMenuTracking() }
        timer.tolerance = 0.03
        menuMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refreshMenuTracking()
    }

    private static func refreshMenuTracking(forMouseEvent: Bool = false) {
        guard let context else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard context.isValid(at: now) else {
            clearContext()
            return
        }
        guard var tracking = menuTracking else { return }
        // 未検出の探索は最初の2秒で終了。以後もマウス操作時には再確認する。
        if menuMonitorTimer == nil && !forMouseEvent { return }
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
#if DEBUG
            print("DEBUG: [コピー元] メニュー情報を取得できないため、既存の判定を維持")
#endif
            stopMenuPolling()
            return
        }
        let previous = tracking.visibleWindows
        tracking.update(windows: info.compactMap { ClipboardSourceMenuWindow(info: $0) })
        menuTracking = tracking
        if tracking.hasDetectedMenu {
            Self.context?.recordMenuVisibility(isVisible: !tracking.visibleWindows.isEmpty, at: now)
        }
        if tracking.visibleWindows != previous {
#if DEBUG
            print("DEBUG: [コピー元] メニュー範囲更新: PID=\(tracking.sourceProcessIdentifier), ウィンドウ=\(tracking.visibleWindows)")
#endif
        }
        if tracking.visibleWindows.isEmpty {
            if tracking.hasDetectedMenu {
                if menuMissingSince == nil { menuMissingSince = now }
                if let missingSince = menuMissingSince, now - missingSince >= 0.45 {
#if DEBUG
                    print("DEBUG: [コピー元] メニュー消失: 最初の消失検知から3秒まで候補を保持して範囲監視を終了")
#endif
                    stopMenuPolling()
                }
            } else if now - context.recordedAt >= 2 {
#if DEBUG
                print("DEBUG: [コピー元] メニュー未検出: 現在のクリック判定へフォールバック")
#endif
                stopMenuPolling()
            }
        } else {
            menuMissingSince = nil
        }
    }

    private static func stopMenuPolling() {
        menuMonitorTimer?.invalidate()
        menuMonitorTimer = nil
    }

    static func consumeSourceApplication(isInternalCopy: Bool) -> NSRunningApplication? {
        defer { clearContext() }
        let now = ProcessInfo.processInfo.systemUptime
#if DEBUG
        print("DEBUG: [コピー元] コピー検知: changeCount=\(NSPasteboard.general.changeCount), 内部コピー=\(isInternalCopy), アクティブ=\(debugDescription(NSWorkspace.shared.frontmostApplication)), 候補状態=\(context?.debugStatus(at: now) ?? "候補なし")")
#endif
        if isInternalCopy {
#if DEBUG
            print("DEBUG: [コピー元] 採用: 内部コピー, \(debugDescription(NSRunningApplication.current))")
#endif
            return NSRunningApplication.current
        }
        if let context, context.isValid(at: now) {
            for pid in context.processIdentifiers {
                if let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated {
#if DEBUG
                    print("DEBUG: [コピー元] 採用: クリック位置の候補, \(debugDescription(app))")
#endif
                    return app
                }
            }
        }
#if DEBUG
        print("DEBUG: [コピー元] アクティブアプリ判定へ: \(context.map { $0.isValid(at: now) ? "候補アプリが終了または取得不可" : $0.debugStatus(at: now) } ?? "候補なし")")
#endif
        if let app = NSWorkspace.shared.frontmostApplication {
#if DEBUG
            print("DEBUG: [コピー元] 採用: アクティブアプリ, \(debugDescription(app))")
#endif
            return app
        }
#if DEBUG
        print("DEBUG: [コピー元] フォールバック: アクティブアプリを取得できないため、コピー元パスなし")
#endif
        return nil
    }

#if DEBUG
    static func debugDescription(_ app: NSRunningApplication?) -> String {
        guard let app else { return "不明" }
        return "名前=\(app.localizedName ?? "不明"), PID=\(app.processIdentifier), Bundle ID=\(app.bundleIdentifier ?? "なし"), パス=\(app.bundleURL?.path ?? "なし")"
    }
#endif

    
    private static let appIgnoreList: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.systemuiserver",
        "com.apple.WindowManager",
        "com.apple.TextInputMenuAgent",
        "com.apple.screencaptureui",
        "com.apple.PIPAgent",
        "com.apple.inputmethod.AssistiveControl"
    ]

    private static func candidateApps(at point: CGPoint) -> [NSRunningApplication] {
        // AppKitは主画面の左下、CGEventとウィンドウ一覧は左上を原点とする。
        guard let primaryScreen = NSScreen.screens.first else { return [] }
        let screenPoint = ClipboardSourceHitTestCoordinates.appKitPoint(
            from: point, primaryScreenMaxY: primaryScreen.frame.maxY)
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let windowsByID = Dictionary(windowInfoList.compactMap { info -> (Int, [String: Any])? in
            guard let id = info[kCGWindowNumber as String] as? NSNumber else { return nil }
            return (id.intValue, info)
        }, uniquingKeysWith: { first, _ in first })
        var belowWindow = 0
        var visited: Set<Int> = []
        while true {
            // 四角い外枠ではなく、透明部分とマウス透過を考慮した対象を取得する。
            let windowID = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: belowWindow)
            guard windowID > 0, visited.insert(windowID).inserted else { break }
            belowWindow = windowID
            guard let info = windowsByID[windowID] else {
#if DEBUG
                print("DEBUG: [コピー元] ヒット対象の情報なし: ウィンドウID=\(windowID)")
#endif
                continue
            }
#if DEBUG
            print("DEBUG: [コピー元] ヒット対象: CG座標=\(point), AppKit座標=\(screenPoint), ウィンドウID=\(windowID), PID=\(String(describing: info[kCGWindowOwnerPID as String])), レイヤー=\(String(describing: info[kCGWindowLayer as String]))")
#endif
            if let ownerName = info[kCGWindowOwnerName as String] as? String,
               ownerName.lowercased().hasSuffix("agent") || ownerName == "Window Server" {
                continue
            }
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { continue }
            if let identifier = app.bundleIdentifier,
               identifier == Bundle.main.bundleIdentifier || appIgnoreList.contains(identifier) {
                continue
            }
#if DEBUG
            print("DEBUG: [コピー元] ヒットテストで候補採用: \(debugDescription(app))")
#endif
            return [app]
        }
#if DEBUG
        print("DEBUG: [コピー元] ヒットテストの有効候補なし。外枠の重なり順では補完しない")
#endif
        return []
    }
}

/// 実際の履歴や権限に依存しない、操作候補の有効期間の管理。
struct ClipboardSourceClickContext {
    let processIdentifiers: [pid_t]
    let recordedAt: TimeInterval
    private(set) var selectionClickedAt: TimeInterval?
    private(set) var menuDisappearedAt: TimeInterval?
    private var invalidated = false

    // Control＋クリックに伴うコピー元自身のアクティブ化では候補を失効させない。
    func shouldDiscardOnActivation(of processIdentifier: pid_t) -> Bool {
        processIdentifiers.first != processIdentifier
    }

    mutating func recordMenuVisibility(isVisible: Bool, at now: TimeInterval) {
        if isVisible {
            menuDisappearedAt = nil
        } else if menuDisappearedAt == nil {
            menuDisappearedAt = now
        }
    }

    mutating func recordMenuSelection(at now: TimeInterval) {
        selectionClickedAt = now
    }

    mutating func recordSelectionClick(at now: TimeInterval) {
        if selectionClickedAt != nil { invalidated = true }
        else { selectionClickedAt = now }
    }

#if DEBUG
    func debugStatus(at now: TimeInterval) -> String {
        let reason: String
        if invalidated { reason = "次の左クリックで失効" }
        else if now < recordedAt { reason = "記録時刻より前" }
        else if now - recordedAt > 60 { reason = "記録から60秒超過" }
        else if let menuDisappearedAt, now - menuDisappearedAt > 3 { reason = "メニュー消失から3秒超過" }
        else { reason = "有効" }
        let selectionAge = selectionClickedAt.map { String(now - $0) } ?? "未クリック"
        let disappearanceAge = menuDisappearedAt.map { String(now - $0) } ?? "未検出または表示中"
        return "状態=\(reason), 記録後=\(now - recordedAt)秒, 左クリック後=\(selectionAge), メニュー消失後=\(disappearanceAge), PID=\(processIdentifiers)"
    }
#endif

    func isValid(at now: TimeInterval) -> Bool {
        guard !invalidated, now >= recordedAt, now - recordedAt <= 60 else { return false }
        if let menuDisappearedAt {
            return now >= menuDisappearedAt && now - menuDisappearedAt <= 3
        }
        return true
    }
}

struct ClipboardSourceHitTestCoordinates {
    static func appKitPoint(from point: CGPoint, primaryScreenMaxY: CGFloat) -> NSPoint {
        NSPoint(x: point.x, y: primaryScreenMaxY - point.y)
    }
}
