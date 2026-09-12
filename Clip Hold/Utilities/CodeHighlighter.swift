import Foundation
import AppKit
import SwiftUI
import Highlighter

/// ソースコードのシンタックスハイライトと等幅フォント描画を提供するシングルトンユーティリティ
@MainActor
public final class CodeHighlighter {
    
    public static let shared = CodeHighlighter()
    
    private let lightHighlighter: Highlighter?
    private let darkHighlighter: Highlighter?
    
    private init() {
        let light = Highlighter()
        let dark = Highlighter()
        
        let monospacedFont = NSFont(name: "Menlo", size: NSFont.systemFontSize)
            ?? NSFont.userFixedPitchFont(ofSize: NSFont.systemFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        
        _ = light?.setTheme("github")
        light?.theme?.setCodeFont(monospacedFont)
        
        _ = dark?.setTheme("github-dark")
        dark?.theme?.setCodeFont(monospacedFont)
        
        self.lightHighlighter = light
        self.darkHighlighter = dark
    }
    
    /// 指定されたコードテキストをシンタックスハイライトした AttributedString を生成する
    /// - Parameters:
    ///   - code: ハイライト対象のソースコード
    ///   - language: 言語指定（nil の場合は Highlight.js の自動検出）
    ///   - isDark: ダークモードかどうか
    ///   - fontSize: フォントサイズ（デフォルトはシステムフォントサイズ）
    /// - Returns: シンタックスハイライトおよび等幅フォントが適用された AttributedString
    public func highlight(
        _ code: String,
        as language: String? = nil,
        isDark: Bool,
        fontSize: CGFloat = NSFont.systemFontSize
    ) -> AttributedString {
        let highlighter = isDark ? darkHighlighter : lightHighlighter
        let monospacedFont = NSFont(name: "Menlo", size: fontSize)
            ?? NSFont.userFixedPitchFont(ofSize: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        highlighter?.theme?.setCodeFont(monospacedFont)
        
        if let highlighter = highlighter,
           let nsAttr = highlighter.highlight(code, as: language) {
            let mutable = NSMutableAttributedString(attributedString: nsAttr)
            // グラスエフェクト背景に調和させるため、ハイライターの単色背景色属性を削除
            mutable.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutable.length))
            if let attrString = try? AttributedString(mutable, including: \.appKit) {
                return attrString
            }
        }
        
        // フォールバック: 等幅フォントのプレーンテキスト
        var fallback = AttributedString(code)
        fallback.font = .system(size: fontSize, design: .monospaced)
        return fallback
    }
}
