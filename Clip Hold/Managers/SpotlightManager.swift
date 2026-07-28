import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import AppKit
import SwiftUI

class SpotlightManager {
    static let shared = SpotlightManager()
    
    private let domainIdentifierStandardPhrase = "com.cliphold.standardphrase"
    private let domainIdentifierHistoryItem = "com.cliphold.historyitem"
    
    func indexStandardPhrase(_ phrase: StandardPhrase, presetName: String? = nil) {
        Task {
            let actualPreset: StandardPhrasePreset? = await MainActor.run {
                if let provided = presetName {
                    if let p = StandardPhrasePresetManager.shared.presets.first(where: { $0.name == provided }) { return p }
                }
                for preset in StandardPhrasePresetManager.shared.presets {
                    if preset.phrases.contains(where: { $0.id == phrase.id }) {
                        return preset
                    }
                }
                // If not found in presets yet, maybe it's in the active preset being added
                if let activePreset = StandardPhrasePresetManager.shared.presets.first(where: { $0.id == StandardPhrasePresetManager.shared.selectedPresetId }) {
                    return activePreset
                }
                return nil
            }
            
            let actualPresetName = actualPreset?.name ?? "Default"
            
            let cleanPhraseContent = phrase.content.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = String(localized: "定型文をコピー: \(phrase.title)")
            attributeSet.contentDescription = "\(actualPresetName): \(String(cleanPhraseContent.prefix(200)))"
            attributeSet.textContent = phrase.content
            attributeSet.setValue(["copyAction"], forKey: "actionIdentifiers")
            
            if let preset = actualPreset {
                let image = await MainActor.run(body: { PresetIconGenerator.shared.generateSpotlightIcon(for: preset) })
                attributeSet.thumbnailData = image.tiffRepresentation
            }
            
            let item = CSSearchableItem(
                uniqueIdentifier: "phrase_\(phrase.id.uuidString)",
                domainIdentifier: self.domainIdentifierStandardPhrase,
                attributeSet: attributeSet
            )
            
            Task {
                do {
                    try await CSSearchableIndex.default().indexSearchableItems([item])
                } catch {
                    print("Spotlight indexing error for phrase: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func removeStandardPhrase(id: UUID) {
        Task {
            do {
                try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["phrase_\(id.uuidString)"])
            } catch {
                print("Spotlight delete error for phrase: \(error.localizedDescription)")
            }
        }
    }
    
    func indexHistoryItem(_ item: ClipboardItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        let dateStr = dateFormatter.string(from: item.date)
        
        let cleanText = item.text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
        
        if let filename = item.filePath?.lastPathComponent {
            attributeSet.title = String(localized: "履歴をコピー: \(filename)")
            attributeSet.contentDescription = "\(dateStr) - \(String(cleanText.prefix(200)))"
        } else {
            attributeSet.title = String(localized: "履歴をコピー: \(String(cleanText.prefix(50)))")
            attributeSet.contentDescription = "\(dateStr) - \(String(cleanText.prefix(200)))"
        }
        
        attributeSet.textContent = item.text
        attributeSet.setValue(["copyAction"], forKey: "actionIdentifiers")
        
        if let filePath = item.filePath, FileManager.default.fileExists(atPath: filePath.path) {
            attributeSet.thumbnailData = NSWorkspace.shared.icon(forFile: filePath.path).tiffRepresentation
        } else if let color = ColorCodeParser.parseColor(from: item.text) {
            attributeSet.thumbnailData = self.createColorImage(from: color).tiffRepresentation
        } else if item.isURL {
            attributeSet.thumbnailData = self.createSymbolImage(systemName: "link", shape: .roundedRect).tiffRepresentation
        } else {
            if item.richText != nil {
                if #available(macOS 15.0, *) {
                    attributeSet.thumbnailData = self.createSymbolImage(systemName: "richtext.page", shape: .roundedRect).tiffRepresentation
                } else {
                    attributeSet.thumbnailData = self.createSymbolImage(systemName: "doc.richtext", shape: .roundedRect).tiffRepresentation
                }
            } else {
                if #available(macOS 15.0, *) {
                    attributeSet.thumbnailData = self.createSymbolImage(systemName: "text.page", shape: .roundedRect).tiffRepresentation
                } else {
                    attributeSet.thumbnailData = self.createSymbolImage(systemName: "doc.text", shape: .roundedRect).tiffRepresentation
                }
            }
        }
        
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "history_\(item.id.uuidString)",
            domainIdentifier: domainIdentifierHistoryItem,
            attributeSet: attributeSet
        )
        
        Task {
            do {
                try await CSSearchableIndex.default().indexSearchableItems([searchableItem])
            } catch {
                print("Spotlight indexing error for history item: \(error.localizedDescription)")
            }
        }
    }
    
    func removeHistoryItem(id: UUID) {
        Task {
            do {
                try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["history_\(id.uuidString)"])
            } catch {
                print("Spotlight delete error for history item: \(error.localizedDescription)")
            }
        }
    }
    
    func removeAllHistoryItems() {
        Task {
            do {
                try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifierHistoryItem])
            } catch {
                print("Spotlight delete all history items error: \(error.localizedDescription)")
            }
        }
    }
    
    enum BackgroundShape {
        case circle
        case roundedRect
    }
    
    private func createSymbolImage(systemName: String, shape: BackgroundShape) -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let backgroundColor = NSColor(srgbRed: 72/255.0, green: 121/255.0, blue: 226/255.0, alpha: 1.0)
        backgroundColor.set()
        let rect = NSRect(origin: .zero, size: size)
        
        switch shape {
        case .circle:
            NSBezierPath(ovalIn: rect).fill()
        case .roundedRect:
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
        }
        
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        
        if let symbolImage = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let symbolSize = symbolImage.size
            let symbolRect = NSRect(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            
            let tintedSymbol = NSImage(size: symbolSize, flipped: false) { (dstRect) -> Bool in
                NSColor.white.drawSwatch(in: dstRect)
                symbolImage.draw(in: dstRect, from: .zero, operation: .destinationIn, fraction: 1.0)
                return true
            }
            tintedSymbol.draw(in: symbolRect)
        }
        
        image.unlockFocus()
        return image
    }
    
    private func createColorImage(from color: Color) -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(color).set()
        let rect = NSRect(origin: .zero, size: size)
        NSBezierPath(ovalIn: rect).fill()
        image.unlockFocus()
        return image
    }
    
    func indexAllExistingItems() {
        Task.detached {
            // 定型文のインデックス (全プリセット)
            let allPresets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
            for preset in allPresets {
                for phrase in preset.phrases {
                    self.indexStandardPhrase(phrase, presetName: preset.name)
                }
            }
            
            // 履歴のインデックス (重い可能性があるためチャンクごとにバックグラウンドで処理)
            let history = await ChunkedHistoryManager.shared.loadHistory()
            for item in history {
                self.indexHistoryItem(item)
            }
        }
    }
}
