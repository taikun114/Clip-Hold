
import SwiftUI
import AppKit

@MainActor
class PresetIconGenerator: ObservableObject {
    static let shared = PresetIconGenerator()
    
    @Published private(set) var iconCache: [UUID: NSImage] = [:]
    @Published private(set) var miniIconCache: [UUID: NSImage] = [:] // New cache for mini icons
    
    private init() {}
    
    func generateIcon(for preset: StandardPhrasePreset) -> NSImage {
        if let cachedIcon = iconCache[preset.id] {
            // Also check if mini icon is cached, if not, generate it
            if miniIconCache[preset.id] == nil {
                let miniImage = createMiniImage(for: preset)
                miniIconCache[preset.id] = miniImage
            }
            return cachedIcon
        }
        
        let image = createImage(for: preset)
        iconCache[preset.id] = image

        let miniImage = createMiniImage(for: preset)
        miniIconCache[preset.id] = miniImage

        return image
    }
    
    func updateIcon(for preset: StandardPhrasePreset) {
        let image = createImage(for: preset)
        iconCache[preset.id] = image

        let miniImage = createMiniImage(for: preset)
        miniIconCache[preset.id] = miniImage

        objectWillChange.send()
    }
    
    func removeIcon(for presetId: UUID) {
        iconCache.removeValue(forKey: presetId)
        miniIconCache.removeValue(forKey: presetId) // Remove from mini cache as well
        objectWillChange.send()
    }
    
    func clearCache() {
        iconCache.removeAll()
        miniIconCache.removeAll() // Clear mini cache as well
        objectWillChange.send()
    }
    
    private func createImage(for preset: StandardPhrasePreset) -> NSImage {
        let size = CGSize(width: 24, height: 24)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let nsColor = getColor(from: preset.color)
        
        // 1. Draw the background circle
        let path = NSBezierPath(ovalIn: rect)
        nsColor.setFill()
        path.fill()
        
        // 2. Prepare the symbol image
        if let symbolImage = NSImage(systemSymbolName: preset.icon, accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                
                // Determine symbol color based on preset color
                let symbolForegroundColor: NSColor
                if preset.color == "yellow" || preset.color == "green" {
                    symbolForegroundColor = .black
                } else {
                    symbolForegroundColor = .white
                }

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
        let nsColor = getColor(from: preset.color)
        
        // 1. Draw the background circle
        let path = NSBezierPath(ovalIn: rect)
        nsColor.setFill()
        path.fill()
        
        // 2. Prepare the symbol image
        if let symbolImage = NSImage(systemSymbolName: preset.icon, accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold) // Smaller symbol size
            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                
                // Determine symbol color based on preset color
                let symbolForegroundColor: NSColor
                if preset.color == "yellow" || preset.color == "green" {
                    symbolForegroundColor = .black
                } else {
                    symbolForegroundColor = .white
                }

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

    private func getColor(from colorName: String) -> NSColor {
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
}
