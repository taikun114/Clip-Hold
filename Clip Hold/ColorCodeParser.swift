import Foundation
import SwiftUI

struct ColorCodeParser {
    /// カラーコードの正規表現パターン
    private static let hexPattern = #"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$"#
    // RGBA形式のパターン (カンマ区切りとスペース区切り、%表記(少数点含む)、アルファ値(%表記含む)に対応)
    private static let rgbaPattern = #"^rgba?\(\s*(?:(\d{1,3}(?:\.\d+)?)|(\d{1,3}(?:\.\d+)?)%)\s*[, ]\s*(?:(\d{1,3}(?:\.\d+)?)|(\d{1,3}(?:\.\d+)?)%)\s*[, ]\s*(?:(\d{1,3}(?:\.\d+)?)|(\d{1,3}(?:\.\d+)?)%)\s*(?:[, /]\s*(?:(0|1|0?\.\d+)|(\d{1,3}(?:\.\d+)?)%?)\s*)?\)$"#
    // HSLA形式のパターン (カンマ区切りとスペース区切り、deg表記、%省略、アルファ値(%表記含む)に対応)
    private static let hslaPattern = #"^hsla?\(\s*(\d{1,3}(?:\.\d+)?)(?:deg)?\s*[, ]\s*(\d{1,3}(?:\.\d+)?)%?\s*[, ]\s*(\d{1,3}(?:\.\d+)?)%?\s*(?:[, /]\s*(?:(0|1|0?\.\d+)|(\d{1,3}(?:\.\d+)?)%?)\s*)?\)$"#
    // RGB形式のパターン (カンマ区切りとスペース区切り、%表記(少数点含む)に対応)
    private static let rgbPattern = #"^rgb\(\s*(?:(\d{1,3}(?:\.\d+)?)|(\d{1,3}(?:\.\d+)?)%)\s*[, ]\s*(?:(\d{1,3}(?:\.\d+)?)|(\d{1,3}(?:\.\d+)?)%)\s*[, ]\s*(?:(\d{1,3}(?:\.\d+)?)|(\d{1,3}(?:\.\d+)?)%)\s*\)$"#
    // HSL形式のパターン (カンマ区切りとスペース区切り、deg表記、%省略に対応)
    private static let hslPattern = #"^hsl\(\s*(\d{1,3}(?:\.\d+)?)(?:deg)?\s*[, ]\s*(\d{1,3}(?:\.\d+)?)%?\s*[, ]\s*(\d{1,3}(?:\.\d+)?)%?\s*\)$"#

    /// カラーコードを解析して、対応するColorオブジェクトを返す
    /// - Parameter text: 解析する文字列
    /// - Returns: 解析されたColorオブジェクト。解析できない場合はnil
    static func parseColor(from text: String) -> Color? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // HEX形式 (例: #FFFFFF, #FFFFFFFF)
        if let hexColor = parseHex(trimmedText) {
            return hexColor
        }
        
        // RGBA形式 (例: rgba(255, 0, 0, 1), rgba(255 0 0 / 1), rgba(255,0,0,1))
        if let rgbaColor = parseRgba(trimmedText) {
            return rgbaColor
        }
        
        // HSLA形式 (例: hsla(0, 100%, 50%, 1), hsla(0 100% 50% / 1))
        if let hslaColor = parseHsla(trimmedText) {
            return hslaColor
        }
        
        // RGB形式 (例: rgb(255, 0, 0), rgb(255 0 0), rgb(255,0,0))
        if let rgbColor = parseRgb(trimmedText) {
            return rgbColor
        }
        
        // HSL形式 (例: hsl(0, 100%, 50%), hsl(0 100% 50%))
        if let hslColor = parseHsl(trimmedText) {
            return hslColor
        }
        
        return nil
    }
    
    /// HEXカラーコードを解析
    private static func parseHex(_ text: String) -> Color? {
        let regex = try! NSRegularExpression(pattern: hexPattern, options: [])
        let nsRange = NSRange(text.startIndex..., in: text)
        
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        
        let hexCode = String(text[Range(match.range(at: 1), in: text)!])
        
        var hexValue: UInt64 = 0
        Scanner(string: hexCode).scanHexInt64(&hexValue)
        
        let a, r, g, b: Double
        
        if hexCode.count == 8 {
            // RGBA形式 (#FFFFFFFF) として解析
            // SwiftではUInt64として読み込まれるため、ビットシフトで各成分を抽出
            let redComponent = (hexValue >> 24) & 0xFF
            let greenComponent = (hexValue >> 16) & 0xFF
            let blueComponent = (hexValue >> 8) & 0xFF
            let alphaComponent = hexValue & 0xFF
            
            // 各成分を0.0〜1.0の範囲に正規化
            r = Double(redComponent) / 255.0
            g = Double(greenComponent) / 255.0
            b = Double(blueComponent) / 255.0
            a = Double(alphaComponent) / 255.0
        } else {
            // RGB形式 (#FFFFFF)
            // 透明度は1.0（完全不透明）
            a = 1.0
            
            // 各成分を0.0〜1.0の範囲に正規化
            r = Double((hexValue >> 16) & 0xFF) / 255.0
            g = Double((hexValue >> 8) & 0xFF) / 255.0
            b = Double(hexValue & 0xFF) / 255.0
        }
        
        // sRGBカラースペースを使用してColorオブジェクトを生成
        // これにより、RGBAやHSLA形式との一貫性が保たれる
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    /// RGBカラーコードを解析
    private static func parseRgb(_ text: String) -> Color? {
        let regex = try! NSRegularExpression(pattern: rgbPattern, options: .caseInsensitive)
        let nsRange = NSRange(text.startIndex..., in: text)
        
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        
        // %表記の値を取得
        var rPercent: Double? = nil
        var gPercent: Double? = nil
        var bPercent: Double? = nil
        
        if let rPercentRange = Range(match.range(at: 2), in: text) {
            rPercent = Double(String(text[rPercentRange]))
        }
        if let gPercentRange = Range(match.range(at: 4), in: text) {
            gPercent = Double(String(text[gPercentRange]))
        }
        if let bPercentRange = Range(match.range(at: 6), in: text) {
            bPercent = Double(String(text[bPercentRange]))
        }
        
        // 数値表記の値を取得
        var rValue: Double? = nil
        var gValue: Double? = nil
        var bValue: Double? = nil
        
        if let rValueRange = Range(match.range(at: 1), in: text) {
            rValue = Double(String(text[rValueRange]))
        }
        if let gValueRange = Range(match.range(at: 3), in: text) {
            gValue = Double(String(text[gValueRange]))
        }
        if let bValueRange = Range(match.range(at: 5), in: text) {
            bValue = Double(String(text[bValueRange]))
        }
        
        // %表記または数値表記のどちらかが必須
        guard (rPercent != nil || rValue != nil) &&
              (gPercent != nil || gValue != nil) &&
              (bPercent != nil || bValue != nil) else { return nil }
        
        // %表記と数値表記を0-255の範囲に変換
        let r: Double = rPercent != nil ? rPercent! * 2.55 : rValue!
        let g: Double = gPercent != nil ? gPercent! * 2.55 : gValue!
        let b: Double = bPercent != nil ? bPercent! * 2.55 : bValue!
        
        guard r >= 0 && r <= 255,
              g >= 0 && g <= 255,
              b >= 0 && b <= 255 else { return nil }
        
        return Color(.sRGB, red: r / 255.0, green: g / 255.0, blue: b / 255.0, opacity: 1.0)
    }
    
    /// RGBAカラーコードを解析
    private static func parseRgba(_ text: String) -> Color? {
        let regex = try! NSRegularExpression(pattern: rgbaPattern, options: .caseInsensitive)
        let nsRange = NSRange(text.startIndex..., in: text)
        
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        
        // %表記の値を取得
        var rPercent: Double? = nil
        var gPercent: Double? = nil
        var bPercent: Double? = nil
        
        if let rPercentRange = Range(match.range(at: 2), in: text) {
            rPercent = Double(String(text[rPercentRange]))
        }
        if let gPercentRange = Range(match.range(at: 4), in: text) {
            gPercent = Double(String(text[gPercentRange]))
        }
        if let bPercentRange = Range(match.range(at: 6), in: text) {
            bPercent = Double(String(text[bPercentRange]))
        }
        
        // 数値表記の値を取得
        var rValue: Double? = nil
        var gValue: Double? = nil
        var bValue: Double? = nil
        
        if let rValueRange = Range(match.range(at: 1), in: text) {
            rValue = Double(String(text[rValueRange]))
        }
        if let gValueRange = Range(match.range(at: 3), in: text) {
            gValue = Double(String(text[gValueRange]))
        }
        if let bValueRange = Range(match.range(at: 5), in: text) {
            bValue = Double(String(text[bValueRange]))
        }
        
        // %表記または数値表記のどちらかが必須
        guard (rPercent != nil || rValue != nil) &&
              (gPercent != nil || gValue != nil) &&
              (bPercent != nil || bValue != nil) else { return nil }
        
        // %表記と数値表記を0-255の範囲に変換
        let r: Double = rPercent != nil ? rPercent! * 2.55 : rValue!
        let g: Double = gPercent != nil ? gPercent! * 2.55 : gValue!
        let b: Double = bPercent != nil ? bPercent! * 2.55 : bValue!
        
        guard r >= 0 && r <= 255,
              g >= 0 && g <= 255,
              b >= 0 && b <= 255 else { return nil }
        
        var a: Double = 1.0 // デフォルトの不透明度
        // 10進数形式のアルファ値をチェック
        if let alphaDecimalRange = Range(match.range(at: 7), in: text),
           let alphaDecimalStr = Double(String(text[alphaDecimalRange])) {
            a = alphaDecimalStr
        }
        // %形式のアルファ値をチェック
        else if let alphaPercentRange = Range(match.range(at: 8), in: text),
                let alphaPercentStr = Double(String(text[alphaPercentRange])),
                alphaPercentStr >= 0 && alphaPercentStr <= 100 {
            a = alphaPercentStr / 100.0
        }
        
        guard a >= 0 && a <= 1 else { return nil }
        
        return Color(.sRGB, red: r / 255.0, green: g / 255.0, blue: b / 255.0, opacity: a)
    }
    
    /// HSLカラーコードを解析
    private static func parseHsl(_ text: String) -> Color? {
        let regex = try! NSRegularExpression(pattern: hslPattern, options: .caseInsensitive)
        let nsRange = NSRange(text.startIndex..., in: text)
        
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        
        guard let h = Int(String(text[Range(match.range(at: 1), in: text)!])),
              let s = Int(String(text[Range(match.range(at: 2), in: text)!])),
              let l = Int(String(text[Range(match.range(at: 3), in: text)!])),
              h >= 0 && h <= 360,
              s >= 0 && s <= 100,
              l >= 0 && l <= 100 else { return nil }
        
        // HSLをRGBに変換
        let (r, g, b) = hslToRgb(h: Double(h), s: Double(s), l: Double(l))
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
    
    /// HSLAカラーコードを解析
    private static func parseHsla(_ text: String) -> Color? {
        let regex = try! NSRegularExpression(pattern: hslaPattern, options: .caseInsensitive)
        let nsRange = NSRange(text.startIndex..., in: text)
        
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        
        guard let h = Double(String(text[Range(match.range(at: 1), in: text)!])),
              let s = Double(String(text[Range(match.range(at: 2), in: text)!])),
              let l = Double(String(text[Range(match.range(at: 3), in: text)!])),
              h >= 0 && h <= 360,
              s >= 0 && s <= 100,
              l >= 0 && l <= 100 else { return nil }
        
        var a: Double = 1.0 // デフォルトの不透明度
        // 10進数形式のアルファ値をチェック
        if let alphaDecimalRange = Range(match.range(at: 4), in: text),
           let alphaDecimalStr = Double(String(text[alphaDecimalRange])) {
            a = alphaDecimalStr
        }
        // %形式のアルファ値をチェック
        else if let alphaPercentRange = Range(match.range(at: 5), in: text),
                let alphaPercentStr = Double(String(text[alphaPercentRange])),
                alphaPercentStr >= 0 && alphaPercentStr <= 100 {
            a = alphaPercentStr / 100.0
        }
        
        guard a >= 0 && a <= 1 else { return nil }
        
        // HSLをRGBに変換
        let (r, g, b) = hslToRgb(h: h, s: s, l: l)
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    /// HSLをRGBに変換するヘルパー関数
    private static func hslToRgb(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        let s = s / 100.0
        let l = l / 100.0
        
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2.0
        
        var r, g, b: Double
        
        if 0 <= h && h < 60 {
            r = c; g = x; b = 0
        } else if 60 <= h && h < 120 {
            r = x; g = c; b = 0
        } else if 120 <= h && h < 180 {
            r = 0; g = c; b = x
        } else if 180 <= h && h < 240 {
            r = 0; g = x; b = c
        } else if 240 <= h && h < 300 {
            r = x; g = 0; b = c
        } else {
            r = c; g = 0; b = x
        }
        
        return (r: r + m, g: g + m, b: b + m)
    }
}