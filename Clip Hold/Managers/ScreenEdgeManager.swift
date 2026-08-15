import AppKit
import SwiftUI

/// 画面端（スクリーンエッジ）へのマウス接触を監視・判定し、クイックオーバーレイを起動するマネージャー
final class ScreenEdgeManager {
    static let shared = ScreenEdgeManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalClickMonitor: Any?
    private var pollingTimer: Timer?
    private var triggerTask: Task<Void, Never>?
    private var outsideCloseTask: Task<Void, Never>?
    
    private var isPeeking: Bool = false
    private var isFullyTriggered: Bool = false
    private var currentTouchingPosition: ScreenEdgePosition?
    private var peakMouseLocation: NSPoint = .zero
    
    private init() {}
    
    deinit {
        stopMonitoring()
    }
    
    /// マウス監視を開始する
    func startMonitoring() {
        stopMonitoring()
        
        // グローバルおよびローカルのマウス移動監視
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.checkMousePosition()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.checkMousePosition()
            return event
        }
        
        // 外側クリック監視
        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] _ in
            guard let self = self, self.isFullyTriggered else { return }
            let mouseLoc = NSEvent.mouseLocation
            if let visualFrame = QuickOverlayWindowController.shared.visualFrame, !visualFrame.insetBy(dx: -4, dy: -4).contains(mouseLoc) {
                self.cancelTrigger()
                Task { @MainActor in
                    QuickOverlayManager.shared.hideOverlayWithoutAction()
                }
            }
        }
        
        // マウスが静止した状態でも確実に検知できるようにタイマーで定期確認を行う（0.05秒間隔）
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
    }
    
    /// マウス監視を停止する
    func stopMonitoring() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalClickMonitor = globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        cancelTrigger()
    }
    
    private func cancelTrigger() {
        triggerTask?.cancel()
        triggerTask = nil
        outsideCloseTask?.cancel()
        outsideCloseTask = nil
        if isPeeking && !isFullyTriggered {
            Task { @MainActor in
                QuickOverlayManager.shared.hideOverlayWithoutAction()
            }
        }
        isPeeking = false
        isFullyTriggered = false
        currentTouchingPosition = nil
    }
    
    /// 現在のマウスカーソル位置をチェックし、スクリーンエッジのトリガーを管理する
    private func checkMousePosition() {
        // ショートカットキーでの表示中はスクリーンエッジ判定・外側監視を完全にスキップして負荷をゼロにする
        if QuickOverlayManager.shared.isOverlayVisible && QuickOverlayManager.shared.presentationMode == .shortcut {
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // フルオープン状態で表示されている場合：オーバーレイ全領域または画面エッジへの接触を判定
        if QuickOverlayManager.shared.isOverlayVisible && isFullyTriggered {
            if let visualFrame = QuickOverlayWindowController.shared.visualFrame {
                let activeRect = visualFrame.insetBy(dx: -4, dy: -4)
                let isInVisualFrame = activeRect.contains(mouseLocation)
                
                // 現在表示中のエッジサイドを取得
                let isTouchingEdge: Bool
                if case .screenEdge(let edge, _, _, _) = QuickOverlayManager.shared.presentationMode {
                    isTouchingEdge = isMouseTouchingEdgeSide(mouseLocation, edgeSide: edge.edgeSide)
                } else if let edgeSide = currentTouchingPosition?.edgeSide {
                    isTouchingEdge = isMouseTouchingEdgeSide(mouseLocation, edgeSide: edgeSide)
                } else {
                    isTouchingEdge = false
                }
                
                if isInVisualFrame || isTouchingEdge {
                    // カーソルはオーバーレイの領域内、または画面エッジに触れている -> 外側離脱タイマーをキャンセル
                    outsideCloseTask?.cancel()
                    outsideCloseTask = nil
                } else {
                    // カーソルがオーバーレイ領域の外側に移動し、かつ画面エッジからも離れた -> 0.2秒後にスムーズに閉じる
                    if outsideCloseTask == nil {
                        outsideCloseTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
                            guard !Task.isCancelled else { return }
                            self.cancelTrigger()
                            QuickOverlayManager.shared.hideOverlayWithoutAction()
                        }
                    }
                }
            }
            return
        }
        
        // クイックオーバーレイが非表示になった場合の状態リセット
        if !QuickOverlayManager.shared.isOverlayVisible && isFullyTriggered {
            isFullyTriggered = false
            currentTouchingPosition = nil
            outsideCloseTask?.cancel()
            outsideCloseTask = nil
        }
        
        // ピーク中の場合：マウスがピーク領域、または同じ画面エッジに触れ続けているかチェック
        if isPeeking, let position = currentTouchingPosition {
            if isMouseTouchingEdgeSide(mouseLocation, edgeSide: position.edgeSide) || isMouseInPeekArea(mouseLocation, for: position) {
                // エッジに触れている間はキャンセルせず、位置も固定でキープ
                return
            } else {
                // エッジから完全に離れたためキャンセル
                cancelTrigger()
                return
            }
        }
        
        // 非表示状態：画面端（2px以内）への接触を検知
        let detectedPosition = detectEdgePosition(at: mouseLocation)
        
        if let position = detectedPosition {
            let target = UserDefaults.standard.getScreenEdgeTarget(for: position)
            guard target != .none else {
                if isPeeking {
                    cancelTrigger()
                }
                return
            }
            
            if currentTouchingPosition != position {
                currentTouchingPosition = position
                startTriggerDelay(for: position, mouseLocation: mouseLocation)
            }
        } else {
            if isPeeking {
                cancelTrigger()
            }
            // 画面端から離れたら現在の接触位置をリセット（再トリガー可能にする）
            if !QuickOverlayManager.shared.isOverlayVisible {
                currentTouchingPosition = nil
            }
        }
    }
    
    /// 指定された遅延時間の待機とピーク表示を開始する
    private func startTriggerDelay(for position: ScreenEdgePosition, mouseLocation: NSPoint) {
        triggerTask?.cancel()
        
        let target = UserDefaults.standard.getScreenEdgeTarget(for: position)
        guard target != .none else { return }
        let overlayType: QuickOverlayType = (target == .standardPhrase) ? .standardPhrase : .history
        
        isPeeking = true
        isFullyTriggered = false
        peakMouseLocation = mouseLocation
        
        // 1. 即座に24pxのピーク（覗き見プレビュー）表示を行う
        Task { @MainActor in
            QuickOverlayManager.shared.showPeekOverlayFromScreenEdge(
                type: overlayType,
                position: position,
                mouseLocation: mouseLocation
            )
        }
        
        let delay = UserDefaults.standard.screenEdgeDelay
        let nanoseconds = UInt64(delay * 1_000_000_000)
        
        triggerTask = Task { @MainActor in
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            
            guard !Task.isCancelled else { return }
            
            let currentLoc = NSEvent.mouseLocation
            guard self.isMouseInPeekArea(currentLoc, for: position) else {
                self.cancelTrigger()
                return
            }
            
            // 2. 指定時間経過後、フルオープンへ完全展開
            self.isPeeking = false
            self.isFullyTriggered = true
            
            QuickOverlayManager.shared.expandPeekToFullOverlay(
                position: position,
                mouseLocation: self.peakMouseLocation
            )
        }
    }
    
    /// マウスカーソルが該当セグメントのピーク有効領域（画面端から内側24px以内）にあるかを判定する
    func isMouseInPeekArea(_ mouseLocation: NSPoint, for position: ScreenEdgePosition) -> Bool {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame.insetBy(dx: -10, dy: -10), false) }) ?? NSScreen.main else {
            return false
        }
        let frame = screen.frame
        let margin: CGFloat = 100.0
        let peekAllowance: CGFloat = 60.0 // 24px + 36pxのゆとり
        let slack: CGFloat = 60.0 // セグメント境界の遊びマージン
        
        switch position.edgeSide {
        case .top:
            guard mouseLocation.y >= frame.maxY - peekAllowance else { return false }
            let validWidth = max(frame.width - (margin * 2), 0)
            let segWidth = validWidth / 3.0
            let relX = mouseLocation.x - (frame.minX + margin)
            switch position {
            case .topLeft: return relX >= -slack && relX <= segWidth + slack
            case .topCenter: return relX >= segWidth - slack && relX <= segWidth * 2.0 + slack
            case .topRight: return relX >= segWidth * 2.0 - slack && relX <= validWidth + slack
            default: return false
            }
            
        case .bottom:
            guard mouseLocation.y <= frame.minY + peekAllowance else { return false }
            let validWidth = max(frame.width - (margin * 2), 0)
            let segWidth = validWidth / 3.0
            let relX = mouseLocation.x - (frame.minX + margin)
            switch position {
            case .bottomLeft: return relX >= -slack && relX <= segWidth + slack
            case .bottomCenter: return relX >= segWidth - slack && relX <= segWidth * 2.0 + slack
            case .bottomRight: return relX >= segWidth * 2.0 - slack && relX <= validWidth + slack
            default: return false
            }
            
        case .left:
            guard mouseLocation.x <= frame.minX + peekAllowance else { return false }
            let validHeight = max(frame.height - (margin * 2), 0)
            let segHeight = validHeight / 3.0
            let relY = mouseLocation.y - (frame.minY + margin)
            switch position {
            case .leftBottom: return relY >= -slack && relY <= segHeight + slack
            case .leftCenter: return relY >= segHeight - slack && relY <= segHeight * 2.0 + slack
            case .leftTop: return relY >= segHeight * 2.0 - slack && relY <= validHeight + slack
            default: return false
            }
            
        case .right:
            guard mouseLocation.x >= frame.maxX - peekAllowance else { return false }
            let validHeight = max(frame.height - (margin * 2), 0)
            let segHeight = validHeight / 3.0
            let relY = mouseLocation.y - (frame.minY + margin)
            switch position {
            case .rightBottom: return relY >= -slack && relY <= segHeight + slack
            case .rightCenter: return relY >= segHeight - slack && relY <= segHeight * 2.0 + slack
            case .rightTop: return relY >= segHeight * 2.0 - slack && relY <= validHeight + slack
            default: return false
            }
        }
    }
    
    /// 座標からスクリーンエッジのセグメント位置を判定する
    func detectEdgePosition(at mouseLocation: NSPoint) -> ScreenEdgePosition? {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return nil
        }
        
        let frame = screen.frame
        let margin: CGFloat = 100.0 // ホットコーナー回避用の四隅マージン
        let touchThreshold: CGFloat = 2.0 // 画面端への接触判定幅（ピクセル）
        
        // 四隅（ホットコーナー）の領域内にある場合は除外
        let isNearTop = mouseLocation.y >= frame.maxY - touchThreshold
        let isNearBottom = mouseLocation.y <= frame.minY + touchThreshold
        let isNearLeft = mouseLocation.x <= frame.minX + touchThreshold
        let isNearRight = mouseLocation.x >= frame.maxX - touchThreshold
        
        // 四隅チェック
        if (mouseLocation.x < frame.minX + margin && mouseLocation.y > frame.maxY - margin) ||
           (mouseLocation.x > frame.maxX - margin && mouseLocation.y > frame.maxY - margin) ||
           (mouseLocation.x < frame.minX + margin && mouseLocation.y < frame.minY + margin) ||
           (mouseLocation.x > frame.maxX - margin && mouseLocation.y < frame.minY + margin) {
            return nil
        }
        
        // 上辺
        if isNearTop {
            let validWidth = frame.width - (margin * 2)
            guard validWidth > 0 else { return nil }
            let segWidth = validWidth / 3.0
            let relX = mouseLocation.x - (frame.minX + margin)
            
            if relX < segWidth {
                return .topLeft
            } else if relX < segWidth * 2.0 {
                return .topCenter
            } else {
                return .topRight
            }
        }
        
        // 下辺
        if isNearBottom {
            let validWidth = frame.width - (margin * 2)
            guard validWidth > 0 else { return nil }
            let segWidth = validWidth / 3.0
            let relX = mouseLocation.x - (frame.minX + margin)
            
            if relX < segWidth {
                return .bottomLeft
            } else if relX < segWidth * 2.0 {
                return .bottomCenter
            } else {
                return .bottomRight
            }
        }
        
        // 左辺
        if isNearLeft {
            let validHeight = frame.height - (margin * 2)
            guard validHeight > 0 else { return nil }
            let segHeight = validHeight / 3.0
            let relY = mouseLocation.y - (frame.minY + margin)
            
            if relY < segHeight {
                return .leftBottom
            } else if relY < segHeight * 2.0 {
                return .leftCenter
            } else {
                return .leftTop
            }
        }
        
        // 右辺
        if isNearRight {
            let validHeight = frame.height - (margin * 2)
            guard validHeight > 0 else { return nil }
            let segHeight = validHeight / 3.0
            let relY = mouseLocation.y - (frame.minY + margin)
            
            if relY < segHeight {
                return .rightBottom
            } else if relY < segHeight * 2.0 {
                return .rightCenter
            } else {
                return .rightTop
            }
        }
        
        return nil
    }
    
    /// カーソルが指定された画面端（エッジ）に触れている（端から6px以内にある）かを判定する
    func isMouseTouchingEdgeSide(_ mouseLocation: NSPoint, edgeSide: ScreenEdgeSide) -> Bool {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame.insetBy(dx: -10, dy: -10), false) }) ?? NSScreen.main else {
            return false
        }
        let frame = screen.frame
        let touchAllowance: CGFloat = 6.0 // 画面端への接触許容幅
        
        switch edgeSide {
        case .top:
            return mouseLocation.y >= frame.maxY - touchAllowance
        case .bottom:
            return mouseLocation.y <= frame.minY + touchAllowance
        case .left:
            return mouseLocation.x <= frame.minX + touchAllowance
        case .right:
            return mouseLocation.x >= frame.maxX - touchAllowance
        }
    }
}
