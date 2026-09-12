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
    
    /// 1行表示用（履歴一覧やクイックオーバーレイなど）に、最初の非空行を抽出する。
    /// 後続に有効な行が存在する場合は末尾に "..." を付与する。
    /// 改行や空白のみで構成されている場合は空文字列を返す。
    func firstNonEmptyLine(appendEllipsisIfMultiLine: Bool = true) -> String {
        let lines = self.components(separatedBy: .newlines)
        
        guard let firstIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return ""
        }
        
        let firstLine = lines[firstIndex]
        
        if appendEllipsisIfMultiLine {
            let hasRemainingLines = lines[(firstIndex + 1)...].contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            if hasRemainingLines {
                if firstLine.hasSuffix("...") || firstLine.hasSuffix("…") {
                    return firstLine
                } else {
                    return firstLine + "..."
                }
            }
        }
        
        return firstLine
    }
    
    /// 不可視文字（半角スペース、全角スペース、タブ、改行）をターシャリーカラーの記号で可視化した AttributedString を生成する
    /// - Parameter singleLine: true の場合、改行文字を1行の記号（↵）に置換して複数行にならないようにする
    func formatWithInvisibleSymbols(singleLine: Bool = false) -> AttributedString {
        var result = AttributedString()
        let normalized = self.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let breakOpportunity = singleLine ? "" : "\u{200B}"
        
        for char in normalized {
            switch char {
            case " ": // 半角スペース (U+0020)
                var attr = AttributedString("␣" + breakOpportunity)
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\u{3000}": // 全角スペース (U+3000)
                var attr = AttributedString("□" + breakOpportunity)
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\t": // タブ (U+0009)
                var attr = AttributedString("⇥" + breakOpportunity)
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
        let breakOpportunity = singleLine ? "" : "\u{200B}"
        
        for char in normalized {
            switch char {
            case " ":
                result.append("␣" + breakOpportunity)
            case "\u{3000}":
                result.append("□" + breakOpportunity)
            case "\t":
                result.append("⇥" + breakOpportunity)
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

