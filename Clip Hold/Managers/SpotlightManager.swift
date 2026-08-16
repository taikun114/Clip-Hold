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
    
    // 定型文のCSSearchableItemを生成するヘルパー
    // アイコン画像（thumbnailData）は事前にMainActorで生成しておく必要がある
    private func createPhraseSearchableItem(
        for phrase: StandardPhrase,
        presetName: String,
        thumbnailData: Data?
    ) -> CSSearchableItem {
        let cleanPhraseContent = phrase.content.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        
        let truncatedTitle = phrase.title.count > 150 ? "\(phrase.title.prefix(150))…" : phrase.title
        attributeSet.title = String(localized: "定型文をコピー: \(truncatedTitle)")
        
        let truncatedContent = cleanPhraseContent.count > 200 ? "\(cleanPhraseContent.prefix(200))…" : cleanPhraseContent
        attributeSet.contentDescription = "\(presetName): \(truncatedContent)"
        attributeSet.textContent = phrase.content
        attributeSet.setValue(["copyAction"], forKey: "actionIdentifiers")
        attributeSet.thumbnailData = thumbnailData
        
        return CSSearchableItem(
            uniqueIdentifier: "phrase_\(phrase.id.uuidString)",
            domainIdentifier: domainIdentifierStandardPhrase,
            attributeSet: attributeSet
        )
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
    
    // 定型文を100件ずつバッチ処理でインデックスするヘルパー
    // phraseBuildDataはMainActorで事前に収集したデータ（プリセット名・アイコンデータを含む）
    private func _indexStandardPhrasesInBatch(
        _ phraseBuildData: [(phrase: StandardPhrase, presetName: String, thumbnailData: Data?)],
        onProgress: ((Int) async -> Void)? = nil
    ) async {
        let chunkSize = 100
        for i in stride(from: 0, to: phraseBuildData.count, by: chunkSize) {
            if Task.isCancelled { return }
            let end = min(i + chunkSize, phraseBuildData.count)
            let chunk = Array(phraseBuildData[i..<end])
            
            var searchableItems: [CSSearchableItem] = []
            for data in chunk {
                autoreleasepool {
                    searchableItems.append(createPhraseSearchableItem(
                        for: data.phrase,
                        presetName: data.presetName,
                        thumbnailData: data.thumbnailData
                    ))
                }
            }
            
            do {
                try await CSSearchableIndex.default().indexSearchableItems(searchableItems)
                await onProgress?(chunk.count)
            } catch {
                print("Spotlight phrase batch indexing error: \(error.localizedDescription)")
            }
            
            // 1チャンク100件は履歴と同じため、待機時間も合わせて0.1秒
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    private func _indexHistoryItemsQuietly(_ items: [ClipboardItem], onProgress: ((Int) async -> Void)? = nil) async {
        let chunkSize = 100
        for i in stride(from: 0, to: items.count, by: chunkSize) {
            if Task.isCancelled { return }
            let end = min(i + chunkSize, items.count)
            let chunk = Array(items[i..<end])
            
            var searchableItems: [CSSearchableItem] = []
            for item in chunk {
                autoreleasepool {
                    searchableItems.append(createSearchableItem(for: item))
                }
            }
            
            do {
                try await CSSearchableIndex.default().indexSearchableItems(searchableItems)
                await onProgress?(chunk.count)
            } catch {
                print("Spotlight batch indexing error: \(error.localizedDescription)")
            }
            
            // チャンクごとに少し待機してメモリのスパイクを防ぐ
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
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
        
        await _indexHistoryItemsQuietly(items) { processedCount in
            await MainActor.run {
                self.indexedCount += processedCount
            }
        }
        
        await MainActor.run {
            if self.indexedCount >= self.totalCount {
                self.isIndexing = false
            }
        }
    }
    
    // インポート時など、複数の定型文をまとめてSpotlightに登録するためのメソッド
    // presetにはそれらの定型文が属するプリセットを渡す（nilの場合はアイコンなしで登録）
    func indexStandardPhrases(_ phrases: [StandardPhrase], inPreset preset: StandardPhrasePreset?) async {
        guard !phrases.isEmpty else { return }
        
        // MainActorでアイコン画像を生成してビルドデータを収集
        let phraseBuildData: [(phrase: StandardPhrase, presetName: String, thumbnailData: Data?)] = await MainActor.run {
            let presetName = preset?.name ?? "Default"
            let thumbnailData: Data? = preset.flatMap { p in
                PresetIconGenerator.shared.generateSpotlightIcon(for: p).tiffRepresentation
            }
            return phrases.map { (phrase: $0, presetName: presetName, thumbnailData: thumbnailData) }
        }
        
        let count = phrases.count
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
        
        await _indexStandardPhrasesInBatch(phraseBuildData) { processedCount in
            await MainActor.run {
                self.indexedCount += processedCount
                if self.indexedCount >= self.totalCount {
                    self.isIndexing = false
                }
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
            self.resetID = UUID()
        }
        
        indexingTask = Task.detached {
            do {
                // アプリが登録したすべてのSpotlightインデックスを削除
                try await CSSearchableIndex.default().deleteAllSearchableItems()
                
                if Task.isCancelled { return }
                
                // インデックス済みフラグをリセット（@AppStorageのバックグラウンド発行警告を防ぐためメインスレッドで実行）
                await MainActor.run {
                    let defaults = UserDefaults.standard
                    defaults.set(false, forKey: "hasIndexedExistingHistoryForSpotlight_v1_7_0_full")
                    defaults.set(0, forKey: "lastIndexedHistoryChunkForSpotlight_v1_7_0_full")
                }
                
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
            // 定型文データを収集 (全プリセット)
            // MainActorでプリセット情報とアイコン画像を収集してから、バックグラウンドでバッチ処理する
            let allPresets = await MainActor.run { StandardPhrasePresetManager.shared.presets }
            let phraseBuildData: [(phrase: StandardPhrase, presetName: String, thumbnailData: Data?)] = await MainActor.run {
                allPresets.flatMap { preset in
                    let icon = PresetIconGenerator.shared.generateSpotlightIcon(for: preset)
                    let thumbnailData = icon.tiffRepresentation
                    return preset.phrases.map { phrase in
                        (phrase: phrase, presetName: preset.name, thumbnailData: thumbnailData)
                    }
                }
            }
            
            let phraseCount = phraseBuildData.count
            
            // 履歴のインデックスが必要か確認し、総数を計算
            // 今後のアップデート等でSpotlightのインデックス内容やフォーマットを大きく変更し、既存ユーザーに再インデックスを促したい場合は、
            // 以下のキー名のバージョン部分（"v1_7_0_full"など）を変更してください。キーが変わることで自動的に再インデックス処理が実行されます。
            let defaults = UserDefaults.standard
            let hasIndexedHistory = defaults.bool(forKey: "hasIndexedExistingHistoryForSpotlight_v1_7_0_full")
            
            var historyChunkCount = 0
            var exactHistoryTotalCount = 0
            var historyStartIndex = 0
            
            if !hasIndexedHistory {
                do {
                    historyChunkCount = try await ChunkedHistoryManager.shared.getChunkCount()
                    if historyChunkCount > 0 {
                        let lastChunk = try await ChunkedHistoryManager.shared.loadHistoryChunk(at: historyChunkCount - 1)
                        exactHistoryTotalCount = (historyChunkCount - 1) * 100 + lastChunk.count
                    }
                    historyStartIndex = defaults.integer(forKey: "lastIndexedHistoryChunkForSpotlight_v1_7_0_full")
                } catch {
                    print("SpotlightManager: Failed to get history chunk count: \(error.localizedDescription)")
                }
            }
            
            let totalAllItems = phraseCount + (!hasIndexedHistory ? exactHistoryTotalCount : 0)
            
            if totalAllItems == 0 {
                await MainActor.run {
                    self.isIndexing = false
                    self.totalCount = 0
                    self.indexedCount = 0
                }
                return
            }
            
            // 途中再開の場合の初期進捗計算
            let initialCompletedCount: Int
            if !hasIndexedHistory && historyStartIndex > 0 {
                if historyStartIndex >= historyChunkCount {
                    initialCompletedCount = totalAllItems
                } else {
                    initialCompletedCount = phraseCount + (historyStartIndex * 100)
                }
            } else {
                initialCompletedCount = 0
            }
            
            // UIに全体の総数と初期進捗を反映
            // 最初はindexedCount = 0（途中再開時はinitialCompletedCount）となり、最初のチャンク完了までProgressViewが往復アニメーションになる
            await MainActor.run {
                self.isIndexing = true
                self.totalCount = totalAllItems
                self.indexedCount = initialCompletedCount
                self.resetID = UUID()
            }
            
            var currentIndexedCount = initialCompletedCount
            var pendingBatch: [CSSearchableItem] = []
            
            // 100件ごとにCSSearchableIndexに登録し、進捗を更新するヘルパー
            func flushPendingBatch(force: Bool) async throws {
                while pendingBatch.count >= 100 || (force && !pendingBatch.isEmpty) {
                    if Task.isCancelled { return }
                    
                    let batchSize = min(100, pendingBatch.count)
                    let itemsToIndex = Array(pendingBatch.prefix(batchSize))
                    pendingBatch.removeFirst(batchSize)
                    
                    try await CSSearchableIndex.default().indexSearchableItems(itemsToIndex)
                    currentIndexedCount += batchSize
                    
                    let capturedCount = currentIndexedCount
                    await MainActor.run {
                        self.indexedCount = capturedCount
                    }
                    
                    // メモリ負荷軽減とUI更新のためのウェイト（0.1秒）
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            
            // 1. 定型文アイテムをバッファに追加
            if phraseCount > 0 {
                if Task.isCancelled { return }
                
                for data in phraseBuildData {
                    autoreleasepool {
                        let item = self.createPhraseSearchableItem(
                            for: data.phrase,
                            presetName: data.presetName,
                            thumbnailData: data.thumbnailData
                        )
                        pendingBatch.append(item)
                    }
                }
                
                do {
                    try await flushPendingBatch(force: false)
                } catch {
                    print("SpotlightManager: Error indexing phrase batch: \(error.localizedDescription)")
                }
            }
            
            // 2. 履歴アイテムをチャンクごとに読み込んでバッファに追加し、100件単位でインデックス
            if !hasIndexedHistory {
                if historyStartIndex < historyChunkCount {
                    for index in historyStartIndex..<historyChunkCount {
                        if Task.isCancelled {
                            print("SpotlightManager: Indexing task was cancelled.")
                            return
                        }
                        
                        do {
                            let historyItems = try await ChunkedHistoryManager.shared.loadHistoryChunk(at: index)
                            for item in historyItems {
                                autoreleasepool {
                                    let searchableItem = self.createSearchableItem(for: item)
                                    pendingBatch.append(searchableItem)
                                }
                            }
                            
                            // 100件に達した分をインデックス登録
                            try await flushPendingBatch(force: false)
                            
                            let nextChunkIndex = index + 1
                            await MainActor.run {
                                UserDefaults.standard.set(nextChunkIndex, forKey: "lastIndexedHistoryChunkForSpotlight_v1_7_0_full")
                            }
                        } catch {
                            print("SpotlightManager: Error indexing history chunk \(index): \(error.localizedDescription)")
                        }
                    }
                }
                
                await MainActor.run {
                    UserDefaults.standard.set(true, forKey: "hasIndexedExistingHistoryForSpotlight_v1_7_0_full")
                }
                print("SpotlightManager: Finished indexing all existing history chunks.")
            }
            
            // 3. 最後に残った端数（100件未満のバッファ）をフラッシュ
            if Task.isCancelled { return }
            do {
                try await flushPendingBatch(force: true)
            } catch {
                print("SpotlightManager: Error indexing final batch: \(error.localizedDescription)")
            }
            
            // 4. 完了処理
            await MainActor.run {
                self.isIndexing = false
                self.indexedCount = self.totalCount
            }
            print("SpotlightManager: Finished indexing all existing items. Total completed: \(currentIndexedCount)/\(totalAllItems)")
        }
    }
}
