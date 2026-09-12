import AppKit
import CoreText
import SwiftUI

/// プロポーショナルフォントでも累積ズレを起こさず、各不可視文字の正確なグリフ座標に記号を描画するオーバーレイビュー
struct InvisibleSymbolsOverlayView: NSViewRepresentable {
    let text: String
    let font: NSFont
    var paddingLeading: CGFloat = 0
    
    func makeNSView(context: Context) -> CustomInvisibleSymbolsView {
        let view = CustomInvisibleSymbolsView()
        view.text = text
        view.font = font
        view.paddingLeading = paddingLeading
        return view
    }
    
    func updateNSView(_ nsView: CustomInvisibleSymbolsView, context: Context) {
        nsView.text = text
        nsView.font = font
        nsView.paddingLeading = paddingLeading
        nsView.needsDisplay = true
    }
}

final class CustomInvisibleSymbolsView: NSView {
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var paddingLeading: CGFloat = 0
    
    override var isFlipped: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }
        
        let nsString = text as NSString
        let textLength = nsString.length
        guard textLength > 0 else { return }
        
        let attrString = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attrString)
        
        let symbolAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        
        let fontHeight = font.ascender - font.descender
        let originY = max(0, (bounds.height - fontHeight) / 2)
        
        for i in 0..<textLength {
            let char = nsString.character(at: i)
            let symbol: String?
            switch char {
            case 0x0020: // 半角スペース
                symbol = "␣"
            case 0x3000: // 全角スペース
                symbol = "□"
            case 0x0009: // タブ
                symbol = "⇥"
            default:
                symbol = nil
            }
            
            guard let symbol = symbol else { continue }
            
            // CoreTextからその文字の正確な開始X座標と幅を取得
            let startX = CTLineGetOffsetForStringIndex(line, i, nil)
            let nextX = CTLineGetOffsetForStringIndex(line, i + 1, nil)
            let charWidth = max(nextX - startX, 0)
            
            let symbolSize = (symbol as NSString).size(withAttributes: symbolAttributes)
            let xOffset = (charWidth - symbolSize.width) / 2
            let drawX = paddingLeading + startX + xOffset
            
            let drawPoint = NSPoint(x: drawX, y: originY)
            (symbol as NSString).draw(at: drawPoint, withAttributes: symbolAttributes)
        }
    }
}
