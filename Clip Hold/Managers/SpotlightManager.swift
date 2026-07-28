import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import AppKit
import SwiftUI

class SpotlightManager: ObservableObject {
    static let shared = SpotlightManager()
    
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var resetID = UUID()
    @Published var progress = Progress(totalUnitCount: 0)
    
    private var indexingTask: Task<Void, Never>?
    
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
            
            let truncatedTitle = phrase.title.count > 150 ? "\(phrase.title.prefix(150))…" : phrase.title
            attributeSet.title = String(localized: "定型文をコピー: \(truncatedTitle)")
            
            let truncatedContent = cleanPhraseContent.count > 200 ? "\(cleanPhraseContent.prefix(200))…" : cleanPhraseContent
            attributeSet.contentDescription = "\(actualPresetName): \(truncatedContent)"
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
    
    private func createSearchableItem(for item: ClipboardItem) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        let dateStr = dateFormatter.string(from: item.date)
        
        let cleanText = item.text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
        
        let truncatedContent = cleanText.count > 200 ? "\(cleanText.prefix(200))…" : cleanText
        
        if let filename = item.filePath?.lastPathComponent {
            attributeSet.title = String(localized: "履歴をコピー: \(filename)")
            attributeSet.contentDescription = "\(dateStr) - \(truncatedContent)"
        } else {
            let truncatedTitle = cleanText.count > 150 ? "\(cleanText.prefix(150))…" : cleanText
            attributeSet.title = String(localized: "履歴をコピー: \(truncatedTitle)")
            attributeSet.contentDescription = "\(dateStr) - \(truncatedContent)"
        }
        
        attributeSet.textContent = item.text
        attributeSet.setValue(["copyAction"], forKey: "actionIdentifiers")
        
        if let filePath = item.filePath, FileManager.default.fileExists(atPath: filePath.path) {
            let iconImage = NSWorkspace.shared.icon(forFile: filePath.path)
            attributeSet.thumbnailData = self.generateThumbnailData(from: iconImage)
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
        
        return CSSearchableItem(
            uniqueIdentifier: "history_\(item.id.uuidString)",
            domainIdentifier: domainIdentifierHistoryItem,
            attributeSet: attributeSet
        )
    }

    func indexHistoryItem(_ item: ClipboardItem) {
        let searchableItem = createSearchableItem(for: item)
        Task {
            await MainActor.run {
                if !self.isIndexing {
                    self.isIndexing = true
                    self.totalCount = 1
                    self.indexedCount = 0
                    self.resetID = UUID()
                } else {
                    self.totalCount += 1
                }
            }
            
            do {
                try await CSSearchableIndex.default().indexSearchableItems([searchableItem])
                await MainActor.run {
                    self.indexedCount += 1
                    if self.indexedCount >= self.totalCount {
                        self.isIndexing = false
                    }
                }
            } catch {
                print("Spotlight indexing error for history item: \(error.localizedDescription)")
                await MainActor.run {
                    self.indexedCount += 1
                    if self.indexedCount >= self.totalCount {
                        self.isIndexing = false
                    }
                }
            }
        }
    }
    
    private func _indexHistoryItemsQuietly(_ items: [ClipboardItem]) async {
        var searchableItems: [CSSearchableItem] = []
        for item in items {
            autoreleasepool {
                searchableItems.append(createSearchableItem(for: item))
            }
        }
        
        do {
            try await CSSearchableIndex.default().indexSearchableItems(searchableItems)
        } catch {
            print("Spotlight batch indexing error: \(error.localizedDescription)")
        }
    }
    
    func indexHistoryItems(_ items: [ClipboardItem]) async {
        let count = items.count
        await MainActor.run {
            if !self.isIndexing {
                self.isIndexing = true
                self.totalCount = count
                self.indexedCount = 0
                self.resetID = UUID()
            } else {
                self.totalCount += count
            }
        }
        
        await _indexHistoryItemsQuietly(items)
        
        await MainActor.run {
            self.indexedCount += count
            if self.indexedCount >= self.totalCount {
                self.isIndexing = false
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
    
    func resetAndReindexAll() {
        indexingTask?.cancel()
        
        // 即座に待機中状態（インデックス中）にする
        Task { @MainActor in
            self.isIndexing = true
            self.indexedCount = 0
            self.totalCount = 0
            self.progress = Progress(totalUnitCount: 0)
            self.resetID = UUID()
        }
        
        indexingTask = Task.detached {
            do {
                // アプリが登録したすべてのSpotlightインデックスを削除
                try await CSSearchableIndex.default().deleteAllSearchableItems()
                
                if Task.isCancelled { return }
                
                // インデックス済みフラグをリセット
                let defaults = UserDefaults.standard
                defaults.set(false, forKey: "hasIndexedExistingHistoryForSpotlight_v1_7_0_full")
                defaults.set(0, forKey: "lastIndexedHistoryChunkForSpotlight_v1_7_0_full")
                
                // 再インデックスを実行
                self.indexAllExistingItems()
                print("SpotlightManager: Reset and reindex triggered successfully.")
            } catch {
                print("SpotlightManager: Reset error: \(error.localizedDescription)")
            }
        }
    }
    
    enum BackgroundShape: String {
        case circle
        case roundedRect
    }
    
    private var symbolImageCache: [String: NSImage] = [:]
    
    // サムネイル用に画像をリサイズしてDataを返す（巨大な未圧縮TIFFによるメモリ爆発を防ぐため）
    private func generateThumbnailData(from image: NSImage) -> Data? {
        let targetSize = NSSize(width: 64, height: 64)
        let newImage = NSImage(size: targetSize)
        
        newImage.lockFocus()
        // 高品質にリサイズ
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImage.unlockFocus()
        
        // JPEGで圧縮してさらに軽量化する（TIFFよりはるかに小さい）
        if let tiffData = newImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            return jpegData
        }
        
        return newImage.tiffRepresentation
    }
    
    private func createSymbolImage(systemName: String, shape: BackgroundShape) -> NSImage {
        let cacheKey = "\(systemName)_\(shape.rawValue)"
        if let cachedImage = symbolImageCache[cacheKey] {
            return cachedImage
        }
        
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
        symbolImageCache[cacheKey] = image
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
        indexingTask?.cancel()
        
        indexingTask = Task.detached {
            // 定型文のインデックス (全プリセット)
            let allPresets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
            for preset in allPresets {
                for phrase in preset.phrases {
                    self.indexStandardPhrase(phrase, presetName: preset.name)
                }
            }
            
            // 履歴のインデックス (全件インデックスを行うが、メモリ負荷を抑えるためにチャンクごとに分散処理する)
            // 今後のアップデート等でSpotlightのインデックス内容やフォーマットを大きく変更し、既存ユーザーに再インデックスを促したい場合は、
            // 以下のキー名のバージョン部分（"v1_7_0_full"など）を変更してください。キーが変わることで自動的に再インデックス処理が実行されます。
            let defaults = UserDefaults.standard
            let hasIndexed = defaults.bool(forKey: "hasIndexedExistingHistoryForSpotlight_v1_7_0_full")
            
            if !hasIndexed {
                // UI更新のためメインスレッドで状態を初期化
                Task { @MainActor in
                    self.isIndexing = true
                    self.indexedCount = 0
                }
                
                do {
                    let chunkCount = try await ChunkedHistoryManager.shared.getChunkCount()
                    
                    // 実際の総数を正確に計算する
                    var exactTotalCount = 0
                    if chunkCount > 0 {
                        let lastChunk = try await ChunkedHistoryManager.shared.loadHistoryChunk(at: chunkCount - 1)
                        exactTotalCount = (chunkCount - 1) * 100 + lastChunk.count
                    }
                    
                    let startIndex = defaults.integer(forKey: "lastIndexedHistoryChunkForSpotlight_v1_7_0_full")
                    var completedCount = 0
                    if startIndex >= chunkCount {
                        completedCount = exactTotalCount
                    } else {
                        completedCount = startIndex * 100 // 途中のチャンクまでは1チャンク100件で正確
                    }
                    
                    let initialCompletedCount = completedCount
                    Task { @MainActor in
                        self.totalCount = exactTotalCount
                        self.indexedCount = initialCompletedCount
                        self.progress.totalUnitCount = Int64(exactTotalCount)
                        self.progress.completedUnitCount = Int64(initialCompletedCount)
                    }
                    
                    if startIndex < chunkCount {
                        for index in startIndex..<chunkCount {
                            if Task.isCancelled {
                                print("SpotlightManager: Indexing task was cancelled.")
                                return
                            }
                            
                            let items = try await ChunkedHistoryManager.shared.loadHistoryChunk(at: index)
                            let currentCount = items.count
                            
                            // 1チャンクずつバッチインデックスする
                            await self._indexHistoryItemsQuietly(items)
                            
                            completedCount += currentCount
                            
                            let remainingChunks = chunkCount - (index + 1)
                            let estimatedRemainingItems = remainingChunks * 100
                            print("SpotlightManager: [Indexing Progress] Completed: \(completedCount), Remaining (est.): \(estimatedRemainingItems) (Chunk \(index + 1)/\(chunkCount))")
                            
                            let capturedCount = completedCount
                            Task { @MainActor in
                                self.indexedCount = capturedCount
                                self.progress.completedUnitCount = Int64(capturedCount)
                            }
                            
                            // 進行状況を保存（途中でアプリが終了しても、次回ここから再開できる）
                            defaults.set(index + 1, forKey: "lastIndexedHistoryChunkForSpotlight_v1_7_0_full")
                            
                            // メモリのスパイクを防ぐため、少し待機する（4.8GBまで上がっていたため、待機時間を0.1秒に増加してGCを促す）
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                        }
                    }
                    
                    defaults.set(true, forKey: "hasIndexedExistingHistoryForSpotlight_v1_7_0_full")
                    print("SpotlightManager: Finished indexing all existing history chunks. Total completed: \(completedCount)")
                    
                    Task { @MainActor in
                        self.isIndexing = false
                    }
                } catch {
                    print("SpotlightManager: Failed to index all existing history chunks: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isIndexing = false
                    }
                }
            }
        }
    }
}
