import Testing
import SwiftUI
import AppKit
@testable import Clip_Hold

struct ColorExtensionTests {
    
    // MARK: - Color(hex:) / NSColor(hex:) の初期化テスト
    
    @Test
    func testHexInit6Digits() {
        let redColor = NSColor(hex: "#FF0000").usingColorSpace(.sRGB)
        #expect(redColor != nil)
        if let redColor = redColor {
            #expect(abs(redColor.redComponent - 1.0) < 0.01)
            #expect(abs(redColor.greenComponent - 0.0) < 0.01)
            #expect(abs(redColor.blueComponent - 0.0) < 0.01)
            #expect(abs(redColor.alphaComponent - 1.0) < 0.01)
        }
        
        // #なし形式
        let greenColor = NSColor(hex: "00FF00").usingColorSpace(.sRGB)
        #expect(greenColor != nil)
        if let greenColor = greenColor {
            #expect(abs(greenColor.redComponent - 0.0) < 0.01)
            #expect(abs(greenColor.greenComponent - 1.0) < 0.01)
            #expect(abs(greenColor.blueComponent - 0.0) < 0.01)
        }
    }
    
    @Test
    func testHexInit3Digits() {
        let blueColor = NSColor(hex: "#00F").usingColorSpace(.sRGB)
        #expect(blueColor != nil)
        if let blueColor = blueColor {
            #expect(abs(blueColor.redComponent - 0.0) < 0.01)
            #expect(abs(blueColor.greenComponent - 0.0) < 0.01)
            #expect(abs(blueColor.blueComponent - 1.0) < 0.01)
        }
    }
    
    @Test
    func testToHex() {
        let red = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        #expect(red.toHex() == "#FF0000")
        
        let white = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        #expect(white.toHex() == "#FFFFFF")
        
        let black = NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        #expect(black.toHex() == "#000000")
    }
    
    // MARK: - isLight の輝度判定テスト
    
    @Test
    func testIsLight() {
        let white = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        #expect(white.isLight)
        
        let lightGray = NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        #expect(lightGray.isLight)
        
        let yellow = NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        #expect(yellow.isLight)
        
        let black = NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        #expect(!black.isLight)
        
        let darkNavy = NSColor(srgbRed: 0.05, green: 0.05, blue: 0.2, alpha: 1.0)
        #expect(!darkNavy.isLight)
    }
    
    // MARK: - isAccentColorYellowOrGreen のテスト
    
    @Test
    func testIsAccentColorYellowOrGreen() {
        #expect(NSColor.yellow.isAccentColorYellowOrGreen)
        #expect(NSColor.green.isAccentColorYellowOrGreen)
        #expect(!NSColor.red.isAccentColorYellowOrGreen)
        #expect(!NSColor.blue.isAccentColorYellowOrGreen)
    }
}
