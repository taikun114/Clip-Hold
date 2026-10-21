import SwiftUI

/// 画面の端の12箇所のセグメント位置を表す列挙型
enum ScreenEdgePosition: String, CaseIterable, Identifiable {
    // 上辺
    case topLeft = "screenEdgeTopLeft"
    case topCenter = "screenEdgeTopCenter"
    case topRight = "screenEdgeTopRight"
    
    // 下辺
    case bottomLeft = "screenEdgeBottomLeft"
    case bottomCenter = "screenEdgeBottomCenter"
    case bottomRight = "screenEdgeBottomRight"
    
    // 左辺
    case leftTop = "screenEdgeLeftTop"
    case leftCenter = "screenEdgeLeftCenter"
    case leftBottom = "screenEdgeLeftBottom"
    
    // 右辺
    case rightTop = "screenEdgeRightTop"
    case rightCenter = "screenEdgeRightCenter"
    case rightBottom = "screenEdgeRightBottom"
    
    var id: String { rawValue }
    
    /// 該当する画面の辺（上、下、左、右）
    var edgeSide: ScreenEdgeSide {
        switch self {
        case .topLeft, .topCenter, .topRight:
            return .top
        case .bottomLeft, .bottomCenter, .bottomRight:
            return .bottom
        case .leftTop, .leftCenter, .leftBottom:
            return .left
        case .rightTop, .rightCenter, .rightBottom:
            return .right
        }
    }
    
    /// 指定された画面（NSScreen）における該当反応エリアの中心座標を計算する
    func segmentCenter(in screen: NSScreen, cornerMargin: CGFloat = 100.0) -> CGPoint {
        let frame = screen.frame
        let validWidth = max(frame.width - (cornerMargin * 2), 0)
        let segWidth = validWidth / 3.0
        
        let validHeight = max(frame.height - (cornerMargin * 2), 0)
        let segHeight = validHeight / 3.0
        
        switch self {
        // 上辺
        case .topLeft:
            return CGPoint(x: frame.minX + cornerMargin + (segWidth * 0.5), y: frame.maxY)
        case .topCenter:
            return CGPoint(x: frame.minX + cornerMargin + (segWidth * 1.5), y: frame.maxY)
        case .topRight:
            return CGPoint(x: frame.minX + cornerMargin + (segWidth * 2.5), y: frame.maxY)
            
        // 下辺
        case .bottomLeft:
            return CGPoint(x: frame.minX + cornerMargin + (segWidth * 0.5), y: frame.minY)
        case .bottomCenter:
            return CGPoint(x: frame.minX + cornerMargin + (segWidth * 1.5), y: frame.minY)
        case .bottomRight:
            return CGPoint(x: frame.minX + cornerMargin + (segWidth * 2.5), y: frame.minY)
            
        // 左辺
        case .leftBottom:
            return CGPoint(x: frame.minX, y: frame.minY + cornerMargin + (segHeight * 0.5))
        case .leftCenter:
            return CGPoint(x: frame.minX, y: frame.minY + cornerMargin + (segHeight * 1.5))
        case .leftTop:
            return CGPoint(x: frame.minX, y: frame.minY + cornerMargin + (segHeight * 2.5))
            
        // 右辺
        case .rightBottom:
            return CGPoint(x: frame.maxX, y: frame.minY + cornerMargin + (segHeight * 0.5))
        case .rightCenter:
            return CGPoint(x: frame.maxX, y: frame.minY + cornerMargin + (segHeight * 1.5))
        case .rightTop:
            return CGPoint(x: frame.maxX, y: frame.minY + cornerMargin + (segHeight * 2.5))
        }
    }
}

/// 画面の4つの辺を表す列挙型
enum ScreenEdgeSide: String {
    case top
    case bottom
    case left
    case right
}

/// 各スクリーンエッジで表示するクイックオーバーレイの対象
enum ScreenEdgeTarget: String, CaseIterable, Identifiable {
    case none = "none"
    case standardPhrase = "standardPhrase"
    case history = "history"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none:
            return "-"
        case .standardPhrase:
            return String(localized: "定型文")
        case .history:
            return String(localized: "履歴")
        }
    }
}

/// 表示完了後の端への再接触と、閉じた直後の再表示抑止を管理する。
struct ScreenEdgeDismissState {
    private enum Phase {
        case opening, waitingForDeparture, waitingForReturn, suppressed
    }

    private var phase: Phase = .opening
    private var edge: ScreenEdgeSide?
    private var screenFrame: CGRect = .zero

    mutating func begin(edge: ScreenEdgeSide, screenFrame: CGRect) {
        self.edge = edge
        self.screenFrame = screenFrame
        phase = .opening
    }

    mutating func didFinishOpening() {
        guard edge != nil, phase == .opening else { return }
        phase = .waitingForDeparture
    }

    mutating func cancel() {
        guard phase != .suppressed else { return }
        edge = nil
        phase = .opening
    }

    mutating func shouldDismiss(at point: CGPoint) -> Bool {
        guard edge != nil else { return false }
        switch phase {
        case .waitingForDeparture:
            if !isNearEdge(point, allowance: 16) {
                phase = .waitingForReturn
            }
        case .waitingForReturn:
            if isNearEdge(point, allowance: 2) {
                phase = .suppressed
                return true
            }
        case .opening, .suppressed:
            break
        }
        return false
    }

    mutating func blocksTrigger(at point: CGPoint) -> Bool {
        guard phase == .suppressed else { return false }
        if isNearEdge(point, allowance: 16) {
            return true
        }
        edge = nil
        phase = .opening
        return false
    }

    private func isNearEdge(_ point: CGPoint, allowance: CGFloat) -> Bool {
        switch edge {
        case .top:
            return (screenFrame.minX...screenFrame.maxX).contains(point.x)
                && abs(point.y - screenFrame.maxY) <= allowance
        case .bottom:
            return (screenFrame.minX...screenFrame.maxX).contains(point.x)
                && abs(point.y - screenFrame.minY) <= allowance
        case .left:
            return (screenFrame.minY...screenFrame.maxY).contains(point.y)
                && abs(point.x - screenFrame.minX) <= allowance
        case .right:
            return (screenFrame.minY...screenFrame.maxY).contains(point.y)
                && abs(point.x - screenFrame.maxX) <= allowance
        case nil:
            return false
        }
    }
}
