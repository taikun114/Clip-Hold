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
    
    /// ペーストボードから抽出されたコンテンツを表す型
    private enum ExtractedPasteboardContent {
        case fileURLs(validLocalFileURLs: [URL], webURLStrings: [String])
        case fileURLString(url: URL, isLocalFile: Bool)
        case url(String)
        case rtf(richText: String, plainText: String)
        case html(richText: String, plainText: String)
        case pdf(Data)
        case image(image: NSImage, imageData: Data)
        case text(String)
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
            // 定型文コピーのチェック
            if self.ignoreStandardPhrases && wasStandardPhraseCopy {
#if DEBUG
                print("DEBUG: checkPasteboard: Standard phrase copy detected and ignored.")
#endif
                return // 履歴への追加をスキップ
            }
#if DEBUG
            if wasStandardPhraseCopy {
                print("DEBUG: checkPasteboard: Standard phrase copy detected, but will be added to history.")
            }
#endif
            
            // 内部コピー操作中の場合は、この変更をスキップし、フラグをリセットする
            let wasInternalCopyInitially = isPerformingInternalCopy || wasStandardPhraseCopy
            
#if DEBUG
            if wasInternalCopyInitially {
                print("DEBUG: checkPasteboard: Internal copy in progress. Will process content and reset flag at the end.")
            }
#endif
            
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
            
            let sourceAppPath = wasInternalCopyInitially ? Bundle.main.bundleURL.path : ClipboardSourceAppDetector.appOwningFrontmostWindow()?.bundleURL?.path
            let copiedInternalItem = wasInternalCopyInitially ? lastCopiedInternalItem : nil
            
            // メインスレッドで安全にペーストボードからデータを抽出し、非同期で処理する
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                var attempt = 0
                let maxAttempts = 3
                var extractedContent: ExtractedPasteboardContent? = nil
                
                while attempt < maxAttempts {
                    attempt += 1
#if DEBUG
                    print("DEBUG: checkPasteboard - Attempt \(attempt) to read pasteboard data.")
#endif
                    if let content = self.extractPasteboardContent(from: pasteboard) {
                        extractedContent = content
                        break
                    }
                    
                    if attempt < maxAttempts {
#if DEBUG
                        print("DEBUG: checkPasteboard - No supported item type found. Retrying in 0.1 seconds...")
#endif
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                
                guard let content = extractedContent else {
                    print("ClipboardManager: No supported item type found on pasteboard after \(maxAttempts) attempts.")
                    return
                }
                
                // 抽出したコンテンツの重い処理（ファイルコピー・画像変換・保存等）を非同期タスクで実行
                await self.handleExtractedContent(
                    content,
                    wasInternalCopy: wasInternalCopyInitially,
                    sourceAppPath: sourceAppPath,
                    originalItem: copiedInternalItem
                )
            }
        }
    }
    
    /// メインスレッド上で安全にNSPasteboardからデータを抽出する
    @MainActor
    private func extractPasteboardContent(from pasteboard: NSPasteboard) -> ExtractedPasteboardContent? {
        guard let availableTypes = pasteboard.types, !availableTypes.isEmpty else {
            return nil
        }
#if DEBUG
        print("DEBUG: extractPasteboardContent - Available pasteboard types: \(availableTypes.map { $0.rawValue })")
#endif
        
        let hasFileURLType = availableTypes.contains(.fileURL)
        let hasRTFType = availableTypes.contains(.rtf)
        let hasHTMLType = availableTypes.contains(.html) || availableTypes.contains(NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type"))
        let hasPDFType = availableTypes.contains(.pdf) || availableTypes.contains(NSPasteboard.PasteboardType(rawValue: "Apple PDF pasteboard type"))
        let imageUTIs = Set(NSImage.imageTypes)
        let hasImageDataType = availableTypes.contains(.tiff) || availableTypes.contains(.png) || !Set(availableTypes.map { $0.rawValue }).isDisjoint(with: imageUTIs)
        let hasURLType = availableTypes.contains(.URL) || pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.URL.rawValue])
        
        // 1. ファイルURL
        if hasFileURLType {
            if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
                var validLocalFileURLs: [URL] = []
                var webURLStrings: [String] = []
                
                for url in fileURLs {
                    if url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                        validLocalFileURLs.append(url)
                    } else if !url.isFileURL {
                        webURLStrings.append(url.absoluteString)
                    }
                }
                
                if !validLocalFileURLs.isEmpty || !webURLStrings.isEmpty {
                    return .fileURLs(validLocalFileURLs: validLocalFileURLs, webURLStrings: webURLStrings)
                }
            } else if let stringURL = pasteboard.string(forType: .fileURL), let url = URL(string: stringURL) {
                let isLocal = url.isFileURL && FileManager.default.fileExists(atPath: url.path)
                return .fileURLString(url: url, isLocalFile: isLocal)
            }
        }
        
        // 2. URL（画像データが存在しない場合）
        if hasURLType && !hasImageDataType {
            if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
                return .url(url.absoluteString)
            } else if let urlString = pasteboard.string(forType: .URL) {
                return .url(urlString)
            }
        }
        
        // 3. RTF
        if hasRTFType, let rtfString = pasteboard.string(forType: .rtf) {
            let plainText = pasteboard.string(forType: .string) ?? rtfString
            return .rtf(richText: rtfString, plainText: plainText)
        }
        
        // 4. HTML（画像データやRTFが存在しない場合）
        if hasHTMLType && !hasImageDataType && !hasRTFType {
            var htmlString: String? = nil
            if availableTypes.contains(.html) {
                htmlString = pasteboard.string(forType: .html)
            } else if availableTypes.contains(NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type")) {
                htmlString = pasteboard.string(forType: NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type"))
            }
            
            if let htmlString = htmlString {
                let plainText = pasteboard.string(forType: .string) ?? htmlString
                return .html(richText: htmlString, plainText: plainText)
            }
        }
        
        // 5. PDF
        if hasPDFType {
            if let pdfData = pasteboard.data(forType: .pdf) ?? pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: "Apple PDF pasteboard type")) {
                return .pdf(pdfData)
            }
        }
        
        // 6. 画像データ
        if hasImageDataType {
            var imageDataFromPasteboard: Data?
            var imageFromPasteboard: NSImage?
            
            if let pngData = pasteboard.data(forType: .png) {
                imageDataFromPasteboard = pngData
                imageFromPasteboard = NSImage(data: pngData)
            } else if let tiffData = pasteboard.data(forType: .tiff), let image = NSImage(data: tiffData) {
                imageFromPasteboard = image
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    imageDataFromPasteboard = bitmapRep.representation(using: .png, properties: [:])
                }
            } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                imageFromPasteboard = image
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    imageDataFromPasteboard = bitmapRep.representation(using: .png, properties: [:])
                }
            }
            
            if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                return .image(image: image, imageData: imageData)
            }
        }
        
        // 7. リッチテキスト（フォールバック）
        if let rtfString = pasteboard.string(forType: .rtf) {
            let plainText = pasteboard.string(forType: .string) ?? rtfString
            return .rtf(richText: rtfString, plainText: plainText)
        }
        
        // 8. プレーンテキスト
        if let newString = pasteboard.string(forType: .string) {
            return .text(newString)
        }
        
        return nil
    }
    
    /// 抽出されたペーストボードコンテンツを非同期で処理する
    private func handleExtractedContent(
        _ content: ExtractedPasteboardContent,
        wasInternalCopy: Bool,
        sourceAppPath: String?,
        originalItem: ClipboardItem?
    ) async {
        switch content {
        case .fileURLs(let validLocalFileURLs, let webURLStrings):
#if DEBUG
            print("DEBUG: handleExtractedContent - File URLs detected: \(validLocalFileURLs.map { $0.lastPathComponent })")
#endif
            var remainingFileURLs: [URL] = []
            for fileURL in validLocalFileURLs {
                if let existingItem = self.clipboardHistory.first(where: { $0.isCopying && $0.sourceFileURL == fileURL }) {
#if DEBUG
                    print("DEBUG: handleExtractedContent - File is already being copied: \(fileURL.lastPathComponent), adding duplicate placeholder.")
#endif
                    let newItem = ClipboardItem(
                        text: existingItem.text,
                        date: Date(),
                        filePath: existingItem.filePath,
                        fileSize: existingItem.fileSize,
                        fileHash: existingItem.fileHash,
                        qrCodeContent: existingItem.qrCodeContent,
                        sourceAppPath: sourceAppPath
                    )
                    newItem.sourceFileURL = fileURL
                    newItem.cachedThumbnailImage = existingItem.cachedThumbnailImage
                    await MainActor.run {
                        newItem.isCopying = true
                        newItem.isProgressBarVisible = existingItem.isProgressBarVisible
                        newItem.copyProgress = existingItem.copyProgress
                    }
                    await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "already copying file duplicate")
                } else {
                    remainingFileURLs.append(fileURL)
                }
            }
            
            if !remainingFileURLs.isEmpty {
                await self.handleMultipleFilesChange(fileURLs: remainingFileURLs, sourceAppPath: sourceAppPath, originalItem: originalItem)
            }
            
            if !validLocalFileURLs.isEmpty {
                if wasInternalCopy {
                    await MainActor.run {
                        self.isPerformingInternalCopy = false
#if DEBUG
                        print("DEBUG: handleExtractedContent: isPerformingInternalCopy reset to false after local file URL processing.")
#endif
                    }
                }
                return
            }
            
            // Web URLのみの場合
            if let firstWebURL = webURLStrings.first {
#if DEBUG
                print("DEBUG: handleExtractedContent - Web URL detected: \(firstWebURL.prefix(50))...")
#endif
                let newItem = ClipboardItem(text: firstWebURL, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "web URL (as file URL string)")
            }
            
        case .fileURLString(let url, let isLocalFile):
#if DEBUG
            print("DEBUG: handleExtractedContent - File URL (string) detected: \(url.lastPathComponent)")
#endif
            if isLocalFile {
                if let existingItem = self.clipboardHistory.first(where: { $0.isCopying && $0.sourceFileURL == url }) {
#if DEBUG
                    print("DEBUG: handleExtractedContent - File is already being copied: \(url.lastPathComponent), adding duplicate placeholder.")
#endif
                    let newItem = ClipboardItem(
                        text: existingItem.text,
                        date: Date(),
                        filePath: existingItem.filePath,
                        fileSize: existingItem.fileSize,
                        fileHash: existingItem.fileHash,
                        qrCodeContent: existingItem.qrCodeContent,
                        sourceAppPath: sourceAppPath
                    )
                    newItem.sourceFileURL = url
                    newItem.cachedThumbnailImage = existingItem.cachedThumbnailImage
                    await MainActor.run {
                        newItem.isCopying = true
                        newItem.isProgressBarVisible = existingItem.isProgressBarVisible
                        newItem.copyProgress = existingItem.copyProgress
                    }
                    await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "already copying file duplicate")
                    return
                }
                
                await self.handleMultipleFilesChange(fileURLs: [url], sourceAppPath: sourceAppPath, originalItem: originalItem)
            } else {
#if DEBUG
                print("DEBUG: handleExtractedContent - Web URL detected as file URL string: \(url.absoluteString.prefix(50))...")
#endif
                let newItem = ClipboardItem(text: url.absoluteString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "web URL (as file URL string)")
            }
            
        case .url(let urlString):
#if DEBUG
            print("DEBUG: handleExtractedContent - URL detected: \(urlString.prefix(50))...")
#endif
            let newItem = ClipboardItem(text: urlString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "URL")
            
        case .rtf(let richText, let plainText):
#if DEBUG
            print("DEBUG: handleExtractedContent - RTF String detected: \(richText.prefix(50))...")
#endif
            let newItem = ClipboardItem(richText: richText, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "RTF string")
            
        case .html(let htmlString, let plainText):
#if DEBUG
            print("DEBUG: handleExtractedContent - HTML String detected: \(htmlString.prefix(50))...")
#endif
            let newItem = ClipboardItem(richText: htmlString, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "HTML string")
            
        case .pdf(let pdfData):
#if DEBUG
            print("DEBUG: handleExtractedContent - PDF data detected.")
#endif
            if let newItem = await self.createClipboardItemFromPDFData(pdfData, sourceAppPath: sourceAppPath) {
                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "PDF data")
            }
            
        case .image(let image, let imageData):
#if DEBUG
            print("DEBUG: handleExtractedContent - Image data detected.")
#endif
            let qrCodeContent = self.decodeQRCode(from: image)
            if let newItem = await self.createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "image data")
            }
            
        case .text(let text):
#if DEBUG
            print("DEBUG: handleExtractedContent - String detected: \(text.prefix(50))...")
#endif
            let newItem = ClipboardItem(text: text, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
            await self.processAndSaveItem(newItem, wasInternalCopy: wasInternalCopy, description: "string")
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
