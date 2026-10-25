import Testing
import AppKit
import SwiftUI
@testable import Clip_Hold

struct ScreenEdgeModelsTests {
    
    // MARK: - 画面の辺の分類テスト
    
    @Test
    func testScreenEdgeSideClassification() {
        // 上辺
        #expect(ScreenEdgePosition.topLeft.edgeSide == .top)
        #expect(ScreenEdgePosition.topCenter.edgeSide == .top)
        #expect(ScreenEdgePosition.topRight.edgeSide == .top)
        
        // 下辺
        #expect(ScreenEdgePosition.bottomLeft.edgeSide == .bottom)
        #expect(ScreenEdgePosition.bottomCenter.edgeSide == .bottom)
        #expect(ScreenEdgePosition.bottomRight.edgeSide == .bottom)
        
        // 左辺
        #expect(ScreenEdgePosition.leftTop.edgeSide == .left)
        #expect(ScreenEdgePosition.leftCenter.edgeSide == .left)
        #expect(ScreenEdgePosition.leftBottom.edgeSide == .left)
        
        // 右辺
        #expect(ScreenEdgePosition.rightTop.edgeSide == .right)
        #expect(ScreenEdgePosition.rightCenter.edgeSide == .right)
        #expect(ScreenEdgePosition.rightBottom.edgeSide == .right)
    }
    
    // MARK: - 全セグメントの網羅性とIDテスト
    
    @Test
    func testAllCasesAndIDs() {
        let allPositions = ScreenEdgePosition.allCases
        #expect(allPositions.count == 12)
        
        for pos in allPositions {
            #expect(!pos.id.isEmpty)
            #expect(pos.id == pos.rawValue)
        }
    }
    
    // MARK: - セグメント座標計算テスト
    
    @Test
    func testSegmentCenterCoordinates() {
        guard let screen = NSScreen.screens.first ?? NSScreen.main else {
            return
        }
        
        let frame = screen.frame
        let margin: CGFloat = 100.0
        let validWidth = max(frame.width - (margin * 2), 0)
        let segWidth = validWidth / 3.0
        let validHeight = max(frame.height - (margin * 2), 0)
        let segHeight = validHeight / 3.0
        
        // 上辺中央の計算検証
        let topCenter = ScreenEdgePosition.topCenter.segmentCenter(in: screen, cornerMargin: margin)
        #expect(abs(topCenter.x - (frame.minX + margin + segWidth * 1.5)) < 0.1)
        #expect(abs(topCenter.y - frame.maxY) < 0.1)
        
        // 下辺左の計算検証
        let bottomLeft = ScreenEdgePosition.bottomLeft.segmentCenter(in: screen, cornerMargin: margin)
        #expect(abs(bottomLeft.x - (frame.minX + margin + segWidth * 0.5)) < 0.1)
        #expect(abs(bottomLeft.y - frame.minY) < 0.1)
        
        // 左辺中央の計算検証
        let leftCenter = ScreenEdgePosition.leftCenter.segmentCenter(in: screen, cornerMargin: margin)
        #expect(abs(leftCenter.x - frame.minX) < 0.1)
        #expect(abs(leftCenter.y - (frame.minY + margin + segHeight * 1.5)) < 0.1)
        
        // 右辺上の計算検証
        let rightTop = ScreenEdgePosition.rightTop.segmentCenter(in: screen, cornerMargin: margin)
        #expect(abs(rightTop.x - frame.maxX) < 0.1)
        #expect(abs(rightTop.y - (frame.minY + margin + segHeight * 2.5)) < 0.1)
    }
    
    // MARK: - ScreenEdgeTarget のテスト
    
    @Test
    func testScreenEdgeTargetProperties() {
        #expect(ScreenEdgeTarget.none.id == "none")
        #expect(ScreenEdgeTarget.standardPhrase.id == "standardPhrase")
        #expect(ScreenEdgeTarget.history.id == "history")
        
        #expect(!ScreenEdgeTarget.standardPhrase.displayName.isEmpty)
        #expect(!ScreenEdgeTarget.history.displayName.isEmpty)
        #expect(ScreenEdgeTarget.allCases.count == 3)
    }
}

struct ScreenEdgeDismissStateTests {
    private let frame = CGRect(x: -1000, y: 100, width: 800, height: 600)

    @Test(arguments: [ScreenEdgeSide.top, .bottom, .left, .right])
    func waitsForCompletionAndDeparture(edge: ScreenEdgeSide) {
        var state = ScreenEdgeDismissState()
        state.begin(edge: edge, screenFrame: frame)
        let contact = point(edge: edge, distance: 0)
        let away = point(edge: edge, distance: 17)
        let result1 = state.shouldDismiss(at: away)
        #expect(!result1)
        let result2 = state.shouldDismiss(at: contact)
        #expect(!result2)
        state.didFinishOpening()
        let result3 = state.shouldDismiss(at: contact)
        #expect(!result3)
        let result4 = state.shouldDismiss(at: point(edge: edge, distance: 16))
        #expect(!result4)
        let result5 = state.shouldDismiss(at: contact)
        #expect(!result5)
        let result6 = state.shouldDismiss(at: away)
        #expect(!result6)
        let result7 = state.shouldDismiss(at: point(edge: edge, distance: 3))
        #expect(!result7)
        let result8 = state.shouldDismiss(at: point(edge: edge, distance: 2))
        #expect(result8)
        let result9 = state.shouldDismiss(at: contact)
        #expect(!result9)
        state.cancel()
        let result10 = state.blocksTrigger(at: contact)
        #expect(result10)
        let result11 = state.blocksTrigger(at: point(edge: edge, distance: 16))
        #expect(result11)
        let result12 = state.blocksTrigger(at: away)
        #expect(!result12)
        let result13 = state.blocksTrigger(at: contact)
        #expect(!result13)
    }

    @Test
    func ignoresOtherScreensAndCancelledOpening() {
        var state = ScreenEdgeDismissState()
        state.begin(edge: .top, screenFrame: frame)
        state.didFinishOpening()
        let result14 = state.shouldDismiss(at: CGPoint(x: 100, y: frame.maxY))
        #expect(!result14)
        let result15 = state.shouldDismiss(at: CGPoint(x: 200, y: frame.maxY))
        #expect(!result15)
        state.cancel()
        state.didFinishOpening()
        let result16 = state.shouldDismiss(at: point(edge: .top, distance: 0))
        #expect(!result16)
        let result17 = state.shouldDismiss(at: point(edge: .top, distance: 30))
        #expect(!result17)
        let result18 = state.shouldDismiss(at: point(edge: .top, distance: 0))
        #expect(!result18)
    }

    @Test
    func newOpeningResetsPreviousDeparture() {
        var state = ScreenEdgeDismissState()
        state.begin(edge: .top, screenFrame: frame)
        state.didFinishOpening()
        let result19 = state.shouldDismiss(at: point(edge: .top, distance: 30))
        #expect(!result19)
        state.begin(edge: .bottom, screenFrame: frame)
        let result20 = state.shouldDismiss(at: point(edge: .bottom, distance: 30))
        #expect(!result20)
        state.didFinishOpening()
        let result21 = state.shouldDismiss(at: point(edge: .bottom, distance: 0))
        #expect(!result21)
        let result22 = state.shouldDismiss(at: point(edge: .bottom, distance: 30))
        #expect(!result22)
        let result23 = state.shouldDismiss(at: point(edge: .bottom, distance: 0))
        #expect(result23)
    }

    private func point(edge: ScreenEdgeSide, distance: CGFloat) -> CGPoint {
        switch edge {
        case .top: return CGPoint(x: frame.midX, y: frame.maxY - distance)
        case .bottom: return CGPoint(x: frame.midX, y: frame.minY + distance)
        case .left: return CGPoint(x: frame.minX + distance, y: frame.midY)
        case .right: return CGPoint(x: frame.maxX - distance, y: frame.midY)
        }
    }
}
