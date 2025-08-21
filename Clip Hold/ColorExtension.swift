import SwiftUI
import AppKit

extension Color {
    func adjustedSaturation(_ amount: Double) -> Color {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return self }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let adjustedSaturation = min(max(saturation + CGFloat(amount), 0), 1)
        let adjustedColor = NSColor(hue: hue, saturation: adjustedSaturation, brightness: brightness, alpha: alpha)
        return Color(adjustedColor)
    }
    
    func adjustedBrightness(_ amount: Double) -> Color {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return self }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let adjustedBrightness = min(max(brightness + CGFloat(amount), 0), 1)
        let adjustedColor = NSColor(hue: hue, saturation: saturation, brightness: adjustedBrightness, alpha: alpha)
        return Color(adjustedColor)
    }
}
