import Foundation
import AppKit

extension String {
    func truncate(maxLength: Int) -> String {
        if self.count > maxLength {
            return String(self.prefix(maxLength)) + "..."
        }
        return self
    }
    
    /// 改行文字（CRLF、CR、LF）を半角スペースに置換して1行表示用にする
    func replacingNewlinesWithSpaces() -> String {
        return self
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
    
    /// 不可視文字（半角スペース、全角スペース、タブ、改行）をターシャリーカラーの記号で可視化した AttributedString を生成する
    /// - Parameter singleLine: true の場合、改行文字を1行の記号（↵）に置換して複数行にならないようにする
    func formatWithInvisibleSymbols(singleLine: Bool = false) -> AttributedString {
        var result = AttributedString()
        let normalized = self.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        for char in normalized {
            switch char {
            case " ": // 半角スペース (U+0020)
                var attr = AttributedString("␣")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\u{3000}": // 全角スペース (U+3000)
                var attr = AttributedString("□")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\t": // タブ (U+0009)
                var attr = AttributedString("⇥")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\n": // 改行 (LF)
                var attr = AttributedString("↵")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
                if !singleLine {
                    result.append(AttributedString("\n"))
                }
            default:
                let attr = AttributedString(String(char))
                result.append(attr)
            }
        }
        return result
    }
    
    /// 不可視文字（半角スペース、全角スペース、タブ、改行）をプレーンテキストの記号で置換した文字列を生成する
    /// - Parameter singleLine: true の場合、改行文字を1行の記号（↵）に置換する
    func formatWithInvisibleSymbolsPlain(singleLine: Bool = false) -> String {
        var result = ""
        let normalized = self.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        for char in normalized {
            switch char {
            case " ":
                result.append("␣")
            case "\u{3000}":
                result.append("□")
            case "\t":
                result.append("⇥")
            case "\n":
                result.append("↵")
                if !singleLine {
                    result.append("\n")
                }
            default:
                result.append(char)
            }
        }
        return result
    }
    
    /// 入力フィールドのオーバーレイ用に、不可視文字（半角スペース、全角スペース、タブ）のみをターシャリーカラーにし、通常文字を透明にした AttributedString を生成する
    func formatWithInvisibleSymbolsOverlay() -> AttributedString {
        var result = AttributedString()
        for char in self {
            switch char {
            case " ":
                var attr = AttributedString("␣")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\u{3000}":
                var attr = AttributedString("□")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\t":
                var attr = AttributedString("⇥")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            default:
                var attr = AttributedString(String(char))
                attr.foregroundColor = .clear
                result.append(attr)
            }
        }
        return result
    }
}

