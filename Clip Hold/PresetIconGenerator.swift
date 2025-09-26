import SwiftUI
import AppKit

@MainActor
class PresetIconGenerator: ObservableObject {
    static let shared = PresetIconGenerator()
    
    @Published private(set) var iconCache: [UUID: NSImage] = [:]
    @Published private(set) var miniIconCache: [UUID: NSImage] = [:]
    @Published private(set) var bigIconCache: [UUID: NSImage] = [:] // New cache for big icons
    
    private init() {}
    
    func generateIcon(for preset: StandardPhrasePreset) -> NSImage {
        if let cachedIcon = iconCache[preset.id] {
            // Also check if mini icon is cached, if not, generate it
            if miniIconCache[preset.id] == nil {
                let miniImage = createMiniImage(for: preset)
                miniIconCache[preset.id] = miniImage
            }
            // Also check if big icon is cached, if not, generate it
            if bigIconCache[preset.id] == nil {
                let bigImage = createBigImage(for: preset)
                bigIconCache[preset.id] = bigImage
            }
            return cachedIcon
        }
        
        let image = createImage(for: preset)
        iconCache[preset.id] = image

        let miniImage = createMiniImage(for: preset)
        miniIconCache[preset.id] = miniImage

        let bigImage = createBigImage(for: preset)
        bigIconCache[preset.id] = bigImage

        return image
    }
    
    func updateIcon(for preset: StandardPhrasePreset) {
        let image = createImage(for: preset)
        iconCache[preset.id] = image

        let miniImage = createMiniImage(for: preset)
        miniIconCache[preset.id] = miniImage

        let bigImage = createBigImage(for: preset)
        bigIconCache[preset.id] = bigImage

        objectWillChange.send()
    }
    
    func removeIcon(for presetId: UUID) {
        iconCache.removeValue(forKey: presetId)
        miniIconCache.removeValue(forKey: presetId)
        bigIconCache.removeValue(forKey: presetId) // Remove from big cache as well
        objectWillChange.send()
    }
    
    func clearCache() {
        iconCache.removeAll()
        miniIconCache.removeAll()
        bigIconCache.removeAll() // Clear big cache as well
        objectWillChange.send()
    }
    
    private func createImage(for preset: StandardPhrasePreset) -> NSImage {
        let size = CGSize(width: 24, height: 24)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let nsColor = getColor(from: preset.color, with: preset.customColor)
        
        // 1. Draw the background circle
        let path = NSBezierPath(ovalIn: rect)
        nsColor.setFill()
        path.fill()
        
        // 2. Prepare the symbol image
        if let symbolImage = NSImage(systemSymbolName: preset.icon, accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                
                // Determine symbol color based on preset color
                let symbolForegroundColor = getSymbolColor(for: preset.color, with: preset.customColor, on: nsColor)

                // 3. Create a tinted version of the symbol
                let tintedSymbol = NSImage(size: configuredSymbol.size, flipped: false) { (dstRect) -> Bool in
                    // Draw the tint color
                    symbolForegroundColor.drawSwatch(in: dstRect)
                    // Draw the symbol image over it using destinationIn to mask
                    configuredSymbol.draw(in: dstRect, from: .zero, operation: .destinationIn, fraction: 1.0)
                    return true
                }
                
                // 4. Draw the tinted symbol onto our main image
                let symbolRect = NSRect(x: (size.width - tintedSymbol.size.width) / 2,
                                        y: (size.height - tintedSymbol.size.height) / 2,
                                        width: tintedSymbol.size.width,
                                        height: tintedSymbol.size.height)
                
                tintedSymbol.draw(in: symbolRect)
            }
        }
        
        image.unlockFocus()
        return image
    }

    private func createMiniImage(for preset: StandardPhrasePreset) -> NSImage {
        let size = CGSize(width: 16, height: 16) // Mini size
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let nsColor = getColor(from: preset.color, with: preset.customColor)
        
        // 1. Draw the background circle
        let path = NSBezierPath(ovalIn: rect)
        nsColor.setFill()
        path.fill()
        
        // 2. Prepare the symbol image
        if let symbolImage = NSImage(systemSymbolName: preset.icon, accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold) // Smaller symbol size
            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                
                // Determine symbol color based on preset color
                let symbolForegroundColor = getSymbolColor(for: preset.color, with: preset.customColor, on: nsColor)

                // 3. Create a tinted version of the symbol
                let tintedSymbol = NSImage(size: configuredSymbol.size, flipped: false) { (dstRect) -> Bool in
                    // Draw the tint color
                    symbolForegroundColor.drawSwatch(in: dstRect)
                    // Draw the symbol image over it using destinationIn to mask
                    configuredSymbol.draw(in: dstRect, from: .zero, operation: .destinationIn, fraction: 1.0)
                    return true
                }
                
                // 4. Draw the tinted symbol onto our main image
                let symbolRect = NSRect(x: (size.width - tintedSymbol.size.width) / 2,
                                        y: (size.height - tintedSymbol.size.height) / 2,
                                        width: tintedSymbol.size.width,
                                        height: tintedSymbol.size.height)
                
                tintedSymbol.draw(in: symbolRect)
            }
        }
        
        image.unlockFocus()
        return image
    }

    private func createBigImage(for preset: StandardPhrasePreset) -> NSImage {
        let size = CGSize(width: 32, height: 32) // Big size
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let nsColor = getColor(from: preset.color, with: preset.customColor)
        
        // 1. Draw the background circle
        let path = NSBezierPath(ovalIn: rect)
        nsColor.setFill()
        path.fill()
        
        // 2. Prepare the symbol image
        if let symbolImage = NSImage(systemSymbolName: preset.icon, accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold) // Larger symbol size
            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                
                // Determine symbol color based on preset color
                let symbolForegroundColor = getSymbolColor(for: preset.color, with: preset.customColor, on: nsColor)

                // 3. Create a tinted version of the symbol
                let tintedSymbol = NSImage(size: configuredSymbol.size, flipped: false) { (dstRect) -> Bool in
                    // Draw the tint color
                    symbolForegroundColor.drawSwatch(in: dstRect)
                    // Draw the symbol image over it using destinationIn to mask
                    configuredSymbol.draw(in: dstRect, from: .zero, operation: .destinationIn, fraction: 1.0)
                    return true
                }
                
                // 4. Draw the tinted symbol onto our main image
                let symbolRect = NSRect(x: (size.width - tintedSymbol.size.width) / 2,
                                        y: (size.height - tintedSymbol.size.height) / 2,
                                        width: tintedSymbol.size.width,
                                        height: tintedSymbol.size.height)
                
                tintedSymbol.draw(in: symbolRect)
            }
        }
        
        image.unlockFocus()
        return image
    }

    private func getColor(from colorName: String, with customColor: PresetCustomColor?) -> NSColor {
        if colorName == "custom", let custom = customColor {
            return NSColor(hex: custom.background)
        }
        
        let swiftUIColor: Color
        switch colorName {
        case "red": swiftUIColor = .red
        case "orange": swiftUIColor = .orange
        case "yellow": swiftUIColor = .yellow
        case "green": swiftUIColor = .green
        case "blue": swiftUIColor = .blue
        case "purple": swiftUIColor = .purple
        case "pink": swiftUIColor = .pink
        default: swiftUIColor = .accentColor
        }
        return NSColor(swiftUIColor)
    }
    
    private func getSymbolColor(for colorName: String, with customColor: PresetCustomColor?, on backgroundColor: NSColor) -> NSColor {
        if colorName == "custom", let custom = customColor {
            return NSColor(hex: custom.icon)
        }
        
        // For predefined colors, use the old logic
        if colorName == "yellow" || colorName == "green" {
            return .black
        } else {
            return .white
        }
    }
}
