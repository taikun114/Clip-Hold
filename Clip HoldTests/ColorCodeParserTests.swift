import Testing
import SwiftUI
import AppKit
@testable import Clip_Hold

struct ColorCodeParserTests {
    
    // RGBA成分の抽出ヘルパー
    private func extractRGBA(from color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        return (nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent, nsColor.alphaComponent)
    }
    
    // MARK: - HEX形式のテスト
    
    @Test
    func testHex6Digits() {
        // #FFFFFF（白）
        if let color = ColorCodeParser.parseColor(from: "#FFFFFF"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 1.0) < 0.01)
            #expect(abs(rgba.b - 1.0) < 0.01)
            #expect(abs(rgba.a - 1.0) < 0.01)
        } else {
            Issue.record("#FFFFFF のパースに失敗しました")
        }
        
        // #000000（黒）
        if let color = ColorCodeParser.parseColor(from: "#000000"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 0.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
            #expect(abs(rgba.a - 1.0) < 0.01)
        } else {
            Issue.record("#000000 のパースに失敗しました")
        }
        
        // #なし形式（FF0000: 赤）
        if let color = ColorCodeParser.parseColor(from: "FF0000"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
            #expect(abs(rgba.a - 1.0) < 0.01)
        } else {
            Issue.record("FF0000 のパースに失敗しました")
        }
    }
    
    @Test
    func testHex3Digits() {
        // #FFF（白）
        if let color = ColorCodeParser.parseColor(from: "#FFF"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 1.0) < 0.01)
            #expect(abs(rgba.b - 1.0) < 0.01)
            #expect(abs(rgba.a - 1.0) < 0.01)
        } else {
            Issue.record("#FFF のパースに失敗しました")
        }
        
        // #F00（赤）
        if let color = ColorCodeParser.parseColor(from: "#F00"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
        } else {
            Issue.record("#F00 のパースに失敗しました")
        }
    }
    
    @Test
    func testHex8And4DigitsWithAlpha() {
        // #FF000080（半透明の赤、アルファ約0.5）
        if let color = ColorCodeParser.parseColor(from: "#FF000080"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
            #expect(abs(rgba.a - (128.0 / 255.0)) < 0.02)
        } else {
            Issue.record("#FF000080 のパースに失敗しました")
        }
        
        // #F008（4桁: 赤、アルファ約0.53）
        if let color = ColorCodeParser.parseColor(from: "#F008"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
            #expect(abs(rgba.a - (136.0 / 255.0)) < 0.02)
        } else {
            Issue.record("#F008 のパースに失敗しました")
        }
    }
    
    // MARK: - RGB形式のテスト
    
    @Test
    func testRgbParsing() {
        // カンマ区切り
        if let color = ColorCodeParser.parseColor(from: "rgb(255, 0, 128)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - (128.0 / 255.0)) < 0.02)
            #expect(abs(rgba.a - 1.0) < 0.01)
        } else {
            Issue.record("rgb(255, 0, 128) のパースに失敗しました")
        }
        
        // スペース区切り
        if let color = ColorCodeParser.parseColor(from: "rgb(0 255 0)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 0.0) < 0.01)
            #expect(abs(rgba.g - 1.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
        } else {
            Issue.record("rgb(0 255 0) のパースに失敗しました")
        }
        
        // %表記
        if let color = ColorCodeParser.parseColor(from: "rgb(100%, 0%, 0%)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
        } else {
            Issue.record("rgb(100%, 0%, 0%) のパースに失敗しました")
        }
    }
    
    // MARK: - RGBA形式のテスト
    
    @Test
    func testRgbaParsing() {
        // 小数アルファ値
        if let color = ColorCodeParser.parseColor(from: "rgba(255, 0, 0, 0.5)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
            #expect(abs(rgba.a - 0.5) < 0.02)
        } else {
            Issue.record("rgba(255, 0, 0, 0.5) のパースに失敗しました")
        }
        
        // スラッシュ区切り + %アルファ
        if let color = ColorCodeParser.parseColor(from: "rgba(0 0 255 / 80%)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 0.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 1.0) < 0.01)
            #expect(abs(rgba.a - 0.8) < 0.02)
        } else {
            Issue.record("rgba(0 0 255 / 80%) のパースに失敗しました")
        }
    }
    
    // MARK: - HSL / HSLA形式のテスト
    
    @Test
    func testHslParsing() {
        // HSL (赤: 0, 100%, 50%)
        if let color = ColorCodeParser.parseColor(from: "hsl(0, 100%, 50%)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 1.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
        } else {
            Issue.record("hsl(0, 100%, 50%) のパースに失敗しました")
        }
        
        // HSL deg単位 (緑: 120deg, 100%, 50%)
        if let color = ColorCodeParser.parseColor(from: "hsl(120deg 100% 50%)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 0.0) < 0.01)
            #expect(abs(rgba.g - 1.0) < 0.01)
            #expect(abs(rgba.b - 0.0) < 0.01)
        } else {
            Issue.record("hsl(120deg 100% 50%) のパースに失敗しました")
        }
        
        // HSLA (青: 240, 100%, 50%, 0.6)
        if let color = ColorCodeParser.parseColor(from: "hsla(240, 100%, 50%, 0.6)"),
           let rgba = extractRGBA(from: color) {
            #expect(abs(rgba.r - 0.0) < 0.01)
            #expect(abs(rgba.g - 0.0) < 0.01)
            #expect(abs(rgba.b - 1.0) < 0.01)
            #expect(abs(rgba.a - 0.6) < 0.02)
        } else {
            Issue.record("hsla(240, 100%, 50%, 0.6) のパースに失敗しました")
        }
    }
    
    // MARK: - エッジケース・不正入力のテスト
    
    @Test
    func testInvalidInputs() {
        #expect(ColorCodeParser.parseColor(from: "") == nil)
        #expect(ColorCodeParser.parseColor(from: "invalid") == nil)
        #expect(ColorCodeParser.parseColor(from: "#GGGGGG") == nil)
        #expect(ColorCodeParser.parseColor(from: "#12345") == nil)
        #expect(ColorCodeParser.parseColor(from: "rgb(300, 0, 0)") == nil)
        #expect(ColorCodeParser.parseColor(from: "rgba(0, 0, 0, 2.0)") == nil)
    }
    
    @Test
    func testLongStringOptimization() {
        // 100文字を超える長いテキストが渡された場合でも、先頭100文字から安全に処理されクラッシュしないこと
        let veryLongText = String(repeating: "a", count: 200)
        #expect(ColorCodeParser.parseColor(from: veryLongText) == nil)
        
        let validWithSpaces = "   #FF0000   "
        #expect(ColorCodeParser.parseColor(from: validWithSpaces) != nil)
    }
}
