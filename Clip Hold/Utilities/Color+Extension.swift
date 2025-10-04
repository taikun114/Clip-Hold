import SwiftUI
import AppKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String? {
        guard let components = cgColor?.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    func toHex() -> String? {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return nil
        }
        let r = Int(round(rgbColor.redComponent * 255.0))
        let g = Int(round(rgbColor.greenComponent * 255.0))
        let b = Int(round(rgbColor.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    var isLight: Bool {
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return true // Default to true if conversion fails
        }
        let luminance = (0.299 * rgbColor.redComponent) + (0.587 * rgbColor.greenComponent) + (0.114 * rgbColor.blueComponent)
        return luminance > 0.5
    }
    
    var isAccentColorYellowOrGreen: Bool {
        // 標準の黄色と緑色のアクセントカラーと比較
        let yellowComparison = isEqual(to: NSColor.yellow) || isEqual(to: NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0))
        let greenComparison = isEqual(to: NSColor.green) || isEqual(to: NSColor(red: 0.25, green: 0.8, blue: 0.4, alpha: 1.0))
        
        // 黄色または緑色に近い場合は true を返す
        if yellowComparison || greenComparison {
            return true
        }
        
        // getHueメソッドを使用して色相が黄色または緑色の範囲内にあるか確認
        // カタログカラー（例：controlAccentColor）をRGB色空間に変換
        guard let rgbColor = usingColorSpace(.sRGB) else {
            return false
        }
        
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        // 黄色は約60度（0-1スケールでは0.167）、緑色は約120度（0.333）
        // 黄色と緑色の両方をカバーする範囲を使用：約0.1から0.4（60°から144°）
        return (0.1 <= hue && hue <= 0.4) && (saturation > 0.2) // 薄すぎる色を避けるために彩度チェックを追加
    }
}
