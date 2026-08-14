import Foundation
import AppKit
import SwiftUI
import CoreImage // QRコード解析用
import UniformTypeIdentifiers // UTTypeのチェック用
import QuickLookThumbnailing // generateThumbnail が必要なので追加

extension ClipboardManager {
    // MARK: - Clipboard Monitoring
    public func startMonitoringPasteboard() {
        // 新しいタイマーを起動する前に、確実に既存のタイマーを無効化しnilにする
        if let timer = pasteboardMonitorTimer {
            timer.invalidate()
            self.pasteboardMonitorTimer = nil
#if DEBUG
            print("DEBUG: startMonitoringPasteboard: Invalidated old timer before starting new.")
#endif
        }
        
        lastChangeCount = NSPasteboard.general.changeCount
        print("ClipboardManager: Monitoring started. Initial pasteboard change count: \(lastChangeCount)")
        
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { 
#if DEBUG
                print("DEBUG: Timer fired, but self is nil. Timer will invalidate itself.")
#endif
                // selfがnilの場合、タイマーのターゲットがなくなったため、念のためタイマーを無効化
                self?.pasteboardMonitorTimer?.invalidate()
                return
            }
            // isMonitoring が true の場合にのみ checkPasteboard() を実行
            guard self.isMonitoring else {
#if DEBUG
                print("DEBUG: Timer fired, but isMonitoring is false. Skipping check.")
#endif
                return
            }
            self.checkPasteboard()
        }
        RunLoop.main.add(newTimer, forMode: .common) // メインRunLoopに明示的に追加
        self.pasteboardMonitorTimer = newTimer // 新しいタイマーをプロパティに保持
        isMonitoring = true
        print("ClipboardManager: Clipboard monitoring started. isMonitoring: \(isMonitoring)")
    }
    
    public func stopMonitoringPasteboard() {
        if let timer = pasteboardMonitorTimer {
            timer.invalidate()
            self.pasteboardMonitorTimer = nil
#if DEBUG
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
#endif
        } else {
#if DEBUG
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
#endif
        }
        isMonitoring = false
        print("ClipboardManager: Monitoring stopped. isMonitoring: \(self.isMonitoring)")
    }
    
    private func checkPasteboard() {
        guard isMonitoring else {
#if DEBUG
            print("DEBUG: checkPasteboard: isMonitoring is false, returning.")
#endif
            return
        }
        
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
#if DEBUG
            print("DEBUG: checkPasteboard - Pasteboard change detected. New changeCount: \(lastChangeCount)")
#endif
            
            let wasStandardPhraseCopy = isCopyingStandardPhrase
            // Check for standard phrase copy
            if self.ignoreStandardPhrases && wasStandardPhraseCopy {
#if DEBUG
                print("DEBUG: checkPasteboard: Standard phrase copy detected and ignored.")
#endif
                return // Skip adding to history
            }
            if wasStandardPhraseCopy {
#if DEBUG
                print("DEBUG: checkPasteboard: Standard phrase copy detected, but will be added to history.")
#endif
            }
            
            // 内部コピー操作中の場合は、この変更をスキップし、フラグをリセットする
            // isPerformingInternalCopy の状態をこのチェックの最初にキャプチャする
            let wasInternalCopyInitially = isPerformingInternalCopy || wasStandardPhraseCopy
            
            if wasInternalCopyInitially {
#if DEBUG
                print("DEBUG: checkPasteboard: Internal copy in progress. Will process content and reset flag at the end.")
#endif
                // ここでは isPerformingInternalCopy をリセットしない
            }
            
            // sourceAppPathをセットする処理と同様に、内部コピーの場合はClip Hold自身のBundle Identifierを除外判定の対象とする
            let activeAppBundleIdentifier = wasInternalCopyInitially ? Bundle.main.bundleIdentifier : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleIdentifier
            
            if let activeAppBundleIdentifier = activeAppBundleIdentifier {
                guard !excludedAppIdentifiers.contains(activeAppBundleIdentifier) else {
#if DEBUG
                    print("DEBUG: checkPasteboard - Excluded app detected: \(activeAppBundleIdentifier). Skipping.")
#endif
                    return // 除外アプリからのコピーは無視
                }
            }
            
            // 非同期処理を開始 (リトライロジック付き)
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                // クリップボードデータの読み取りを最大3回試行
                var attempt = 0
                let maxAttempts = 3
                var success = false
                
                while attempt < maxAttempts && !success {
                    attempt += 1
#if DEBUG
                    print("DEBUG: checkPasteboard - Attempt \(attempt) to read pasteboard data.")
#endif
                    
                    // 1. ペーストボードの主要なデータタイプを事前にチェック
                    let availableTypes = pasteboard.types ?? []
#if DEBUG
                    print("DEBUG: checkPasteboard - Available pasteboard types: \(availableTypes.map { $0.rawValue })")
#endif
                    let hasFileURLType = availableTypes.contains(.fileURL)
                    let hasRTFType = availableTypes.contains(.rtf) // RTFタイプのチェックを追加
                    let hasHTMLType = availableTypes.contains(.html) || availableTypes.contains(NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type"))
                    let hasPDFType = availableTypes.contains(.pdf) || availableTypes.contains(NSPasteboard.PasteboardType(rawValue: "Apple PDF pasteboard type"))
                    let imageUTIs = Set(NSImage.imageTypes)
                    let hasImageDataType = availableTypes.contains(.tiff) || availableTypes.contains(.png) || !Set(availableTypes.map { $0.rawValue }).isDisjoint(with: imageUTIs)
                    let hasURLType = availableTypes.contains(.URL) || pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.URL.rawValue])
                    
                    // 2. 処理ロジックの決定
                    // ローカルファイルURLが存在し、実際にローカルファイルが存在する場合 -> ファイルとして処理 (最高優先度)
                    if hasFileURLType {
                        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
#if DEBUG
                            print("DEBUG: checkPasteboard - File URLs detected: \(fileURLs.map { $0.lastPathComponent })")
#endif
                            
                            // ファイルURLが実際にローカルファイルを指しているか確認
                            var validLocalFileURLs: [URL] = []
                            var webURLStrings: [String] = []
                            
                            for url in fileURLs {
                                if url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                                    validLocalFileURLs.append(url)
                                } else if !url.isFileURL {
                                    webURLStrings.append(url.absoluteString)
                                }
                            }
                            
                            // 既に同じコピー元URLがコピー中の場合、タスクを新しく開始せず、プレースホルダーとして新しいアイテムを追加する
                            var remainingFileURLs: [URL] = []
                            for fileURL in validLocalFileURLs {
                                if let existingItem = self.clipboardHistory.first(where: { $0.isCopying && $0.sourceFileURL == fileURL }) {
#if DEBUG
                                    print("DEBUG: checkPasteboard - File is already being copied: \(fileURL.lastPathComponent), adding duplicate placeholder.")
#endif
                                    
                                    let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                                    let newItem = ClipboardItem(text: existingItem.text, date: Date(), filePath: existingItem.filePath, fileSize: existingItem.fileSize, fileHash: existingItem.fileHash, qrCodeContent: existingItem.qrCodeContent, sourceAppPath: sourceAppPath)
                                    newItem.sourceFileURL = fileURL
                                    newItem.cachedThumbnailImage = existingItem.cachedThumbnailImage
                                    await MainActor.run {
                                        newItem.isCopying = true
                                        newItem.isProgressBarVisible = existingItem.isProgressBarVisible
                                        newItem.copyProgress = existingItem.copyProgress // 元のアイテムと同じ進捗状態にする
                                    }
                                    
                                    await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "already copying file duplicate")
                                } else {
                                    remainingFileURLs.append(fileURL)
                                }
                            }
                            
                            // 有効なローカルファイルURLが存在する場合 -> ファイルとして処理
                            if !remainingFileURLs.isEmpty {
                                let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                                let copiedInternalItem = wasInternalCopyInitially ? lastCopiedInternalItem : nil
                                
                                await self.handleMultipleFilesChange(fileURLs: remainingFileURLs, sourceAppPath: sourceAppPath, originalItem: copiedInternalItem)
                            }
                            
                            if !validLocalFileURLs.isEmpty {
                                if wasInternalCopyInitially {
                                    await MainActor.run {
                                        self.isPerformingInternalCopy = false
#if DEBUG
                                        print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after local file URL processing.")
#endif
                                    }
                                }
                                success = true
                                return
                            }
                            
                            // Web URLのみの場合 -> URL文字列として処理 (ただし、画像データがなければ)
                            if !webURLStrings.isEmpty && validLocalFileURLs.isEmpty && !hasImageDataType {
                                let urlString = webURLStrings.first ?? ""
#if DEBUG
                                print("DEBUG: checkPasteboard - Web URL detected as file URL string (no image data): \(urlString.prefix(50))...")
#endif
                                let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                                let newItem = ClipboardItem(text: urlString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "web URL (as file URL string)")
                                success = true
                                return
                            }
                        } else if let stringURL = pasteboard.string(forType: .fileURL), let url = URL(string: stringURL) {
#if DEBUG
                            print("DEBUG: checkPasteboard - File URL (string) detected: \(url.lastPathComponent)")
#endif
                            
                            if url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                                // 既に同じコピー元URLがコピー中の場合、タスクを新しく開始せず、プレースホルダーとして新しいアイテムを追加する
                                if let existingItem = self.clipboardHistory.first(where: { $0.isCopying && $0.sourceFileURL == url }) {
#if DEBUG
                                    print("DEBUG: checkPasteboard - File is already being copied: \(url.lastPathComponent), adding duplicate placeholder.")
#endif
                                    
                                    let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                                    let newItem = ClipboardItem(text: existingItem.text, date: Date(), filePath: existingItem.filePath, fileSize: existingItem.fileSize, fileHash: existingItem.fileHash, qrCodeContent: existingItem.qrCodeContent, sourceAppPath: sourceAppPath)
                                    newItem.sourceFileURL = url
                                    newItem.cachedThumbnailImage = existingItem.cachedThumbnailImage
                                    await MainActor.run {
                                        newItem.isCopying = true
                                        newItem.isProgressBarVisible = existingItem.isProgressBarVisible
                                        newItem.copyProgress = existingItem.copyProgress // 元のアイテムと同じ進捗状態にする
                                    }
                                    
                                    await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "already copying file duplicate")
                                    success = true
                                    return
                                }

                                
                                let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                                let copiedInternalItem = wasInternalCopyInitially ? lastCopiedInternalItem : nil
                                await self.handleMultipleFilesChange(fileURLs: [url], sourceAppPath: sourceAppPath, originalItem: copiedInternalItem)
                                success = true
                                return
                            } else if !url.isFileURL && !hasImageDataType {
                                // file:// 以外のスキーム (http, httpsなど) は文字列として扱う (ただし、画像データがなければ)
#if DEBUG
                                print("DEBUG: checkPasteboard - Web URL detected as file URL string (no image data): \(url.absoluteString.prefix(50))...")
#endif
                                let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                                let newItem = ClipboardItem(text: url.absoluteString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "web URL (as file URL string)")
                                success = true
                                return
                            }
                        }
                    }
                    
                    // 3. URLタイプをチェック (高優先度)
                    // 画像データがある場合は、URLは無視する
                    if hasURLType && !hasImageDataType {
                        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
#if DEBUG
                            print("DEBUG: checkPasteboard - URL object detected (no image data): \(url.absoluteString.prefix(50))...")
#endif
                            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                            let newItem = ClipboardItem(text: url.absoluteString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "URL object")
                            success = true
                            return
                        } else if let urlString = pasteboard.string(forType: .URL) {
#if DEBUG
                            print("DEBUG: checkPasteboard - URL string detected (no image data): \(urlString.prefix(50))...")
#endif
                            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                            let newItem = ClipboardItem(text: urlString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "URL string")
                            success = true
                            return
                        }
                    }
                    
                    // 4. リッチテキストデータをチェック (中高優先度)
                    if hasRTFType, let rtfString = pasteboard.string(forType: .rtf) {
#if DEBUG
                        print("DEBUG: checkPasteboard - RTF String detected: \(rtfString.prefix(50))...")
#endif
                        
                        // RTFのプレーンテキスト表現も取得 (表示用)
                        let plainText = pasteboard.string(forType: .string) ?? rtfString // RTFからプレーンテキストを抽出できない場合は、RTF自体をプレーンテキストとして使用
                        
                        let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                        let newItem = ClipboardItem(richText: rtfString, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
                        await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "RTF string")
                        success = true
                        return
                    }
                    
                    // 5. HTMLデータをチェック (中優先度)
                    // 画像データがある場合は、HTMLは無視する
                    // RTFがある場合も、HTMLは無視する
                    if hasHTMLType && !hasImageDataType && !hasRTFType {
                        var htmlString: String? = nil
                        if availableTypes.contains(.html) {
                            htmlString = pasteboard.string(forType: .html)
                        } else if availableTypes.contains(NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type")) {
                            htmlString = pasteboard.string(forType: NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type"))
                        }
                        
                        if let htmlString = htmlString {
#if DEBUG
                            print("DEBUG: checkPasteboard - HTML String detected (first 200 chars): \(htmlString.prefix(200))...")
#endif
                            // HTMLのプレーンテキスト表現も取得 (表示用)
                            let plainText = pasteboard.string(forType: .string) ?? htmlString // HTMLからプレーンテキストを抽出できない場合は、HTML自体をプレーンテキストとして使用
                            
                            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                            let newItem = ClipboardItem(richText: htmlString, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
                            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "HTML string")
                            success = true
                            return
                        }
                    }
                    
                    // PDFデータをチェック (画像データより優先)
                    if hasPDFType {
                        if let pdfData = pasteboard.data(forType: .pdf) ?? pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: "Apple PDF pasteboard type")) {
#if DEBUG
                            print("DEBUG: checkPasteboard - PDF data detected.")
#endif
                            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                            if let newItem = await self.createClipboardItemFromPDFData(pdfData, sourceAppPath: sourceAppPath) {
                                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "PDF data")
                            }
                            success = true
                            return
                        }
                    }
                    
                    if hasImageDataType {
                        var imageDataFromPasteboard: Data?
                        var imageFromPasteboard: NSImage?
                        
                        if let pngData = pasteboard.data(forType: .png) {
                            imageDataFromPasteboard = pngData
                            imageFromPasteboard = NSImage(data: pngData)
#if DEBUG
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (PNG).")
#endif
                        } else if let tiffData = pasteboard.data(forType: .tiff), let image = NSImage(data: tiffData) {
                            imageFromPasteboard = image
                            // convert to PNG
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                imageDataFromPasteboard = bitmapRep.representation(using: .png, properties: [:])
                            }
#if DEBUG
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (TIFF converted to PNG).")
#endif
                        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                            imageFromPasteboard = image
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                imageDataFromPasteboard = bitmapRep.representation(using: .png, properties: [:])
                            }
                            if imageDataFromPasteboard != nil {
#if DEBUG
                                print("DEBUG: checkPasteboard - Image data detected on pasteboard (from generic NSImage converted to PNG).")
#endif
                            }
                        }
                        
                        if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                            let qrCodeContent = self.decodeQRCode(from: image)
                            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                            
                            if let newItem = await self.createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "image data")
                            }
                            success = true
                            return
                        }
                    }
                    
                    // 5. 画像データをチェック (中高優先度)
                    if hasImageDataType {
                        var imageDataFromPasteboard: Data?
                        var imageFromPasteboard: NSImage?
                        
                        if let pngData = pasteboard.data(forType: .png) {
                            imageDataFromPasteboard = pngData
                            imageFromPasteboard = NSImage(data: pngData)
#if DEBUG
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (PNG).")
#endif
                        } else if let tiffData = pasteboard.data(forType: .tiff), let image = NSImage(data: tiffData) {
                            imageFromPasteboard = image
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                imageDataFromPasteboard = bitmapRep.representation(using: .png, properties: [:])
                            }
#if DEBUG
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (TIFF converted to PNG).")
#endif
                        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                            imageFromPasteboard = image
                            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                imageDataFromPasteboard = bitmapRep.representation(using: .png, properties: [:])
                            }
                            if imageDataFromPasteboard != nil {
#if DEBUG
                                print("DEBUG: checkPasteboard - Image data detected on pasteboard (from generic NSImage converted to PNG).")
#endif
                            }
                        }
                        
                        if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                            let qrCodeContent = self.decodeQRCode(from: image)
                            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                            
                            if let newItem = await self.createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "image data")
                            }
                            success = true
                            return
                        }
                    }
                    
                    // 5. リッチテキストデータをチェック (中間優先度)
                    if let rtfString = pasteboard.string(forType: .rtf) {
#if DEBUG
                        print("DEBUG: checkPasteboard - RTF String detected: \(rtfString.prefix(50))...")
#endif
                        // RTFのプレーンテキスト表現も取得 (表示用)
                        let plainText = pasteboard.string(forType: .string) ?? rtfString // RTFからプレーンテキストを抽出できない場合は、RTF自体をプレーンテキストとして使用
                        
                        let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                        let newItem = ClipboardItem(richText: rtfString, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
                        await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "RTF string")
                        success = true
                        return
                    }
                    
                    // 6. 最後に、テキストデータをチェック (低優先度)
                    if let newString = pasteboard.string(forType: .string) {
#if DEBUG
                        print("DEBUG: checkPasteboard - String detected: \(newString.prefix(50))...")
#endif
                        let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
                        let newItem = ClipboardItem(text: newString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                        await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopyInitially, description: "string")
                        success = true
                        return
                    }
                    
                    // サポートされていないタイプの場合、少し待機してリトライ
                    if !success && attempt < maxAttempts {
#if DEBUG
                        print("DEBUG: checkPasteboard - No supported item type found. Retrying in 0.1 seconds...")
#endif
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                
                if !success {
                    print("ClipboardManager: No supported item type found on pasteboard after \(maxAttempts) attempts.")
                }
            }
        }
    }
    
    /// クリップボードアイテムを保存し、必要に応じて内部コピーフラグをリセットする共通関数
    private func processAndSaveItem(_ item: ClipboardItem, wasInternalCopy: Bool, description: String) async {
        await MainActor.run {
            self.addAndSaveItem(item)
            if wasInternalCopy {
                self.isPerformingInternalCopy = false
#if DEBUG
                print("DEBUG: processAndSaveItem: isPerformingInternalCopy reset to false after processing \(description).")
#endif
            }
        }
    }
    
    // MARK: - QR Code Decoding
    public func decodeQRCode(from image: NSImage) -> String? {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
            print("Failed to convert NSImage to CIImage.")
            return nil
        }
        
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage)
        
        if let qrFeature = features?.first as? CIQRCodeFeature {
            return qrFeature.messageString
        }
        return nil
    }
}
