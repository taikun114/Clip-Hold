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
