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
