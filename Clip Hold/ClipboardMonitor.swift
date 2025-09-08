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
            print("DEBUG: startMonitoringPasteboard: Invalidated old timer before starting new.")
        }

        lastChangeCount = NSPasteboard.general.changeCount
        print("ClipboardManager: Monitoring started. Initial pasteboard change count: \(lastChangeCount)")

        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { 
                print("DEBUG: Timer fired, but self is nil. Timer will invalidate itself.")
                // selfがnilの場合、タイマーのターゲットがなくなったため、念のためタイマーを無効化
                self?.pasteboardMonitorTimer?.invalidate()
                return
            }
            // isMonitoring が true の場合にのみ checkPasteboard() を実行
            guard self.isMonitoring else {
                print("DEBUG: Timer fired, but isMonitoring is false. Skipping check.")
                return
            }
            self.checkPasteboard()
        }
        RunLoop.main.add(newTimer, forMode: .common) // メインRunLoopに明示的に追加
        self.pasteboardMonitorTimer = newTimer // 新しいタイマーをプロパティに保持
        isMonitoring = true
        print("ClipboardManager: クリップボード監視を開始しました。isMonitoring: \(isMonitoring)")
    }

    public func stopMonitoringPasteboard() {
        if let timer = pasteboardMonitorTimer {
            timer.invalidate()
            self.pasteboardMonitorTimer = nil
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
        } else {
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
        }
        isMonitoring = false
        print("ClipboardManager: Monitoring stopped. isMonitoring: \(self.isMonitoring)")
    }

    private func checkPasteboard() {
        guard isMonitoring else {
            print("DEBUG: checkPasteboard: isMonitoring is false, returning.")
            return
        }
        
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            print("DEBUG: checkPasteboard - Pasteboard change detected. New changeCount: \(lastChangeCount)")

            // 内部コピー操作中の場合は、この変更をスキップし、フラグをリセットする
            // isPerformingInternalCopy の状態をこのチェックの最初にキャプチャする
            let wasInternalCopyInitially = isPerformingInternalCopy
            if wasInternalCopyInitially {
                print("DEBUG: checkPasteboard: Internal copy in progress. Will process content and reset flag at the end.")
                // ここでは isPerformingInternalCopy をリセットしない
            }

            if let activeAppBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                guard !excludedAppIdentifiers.contains(activeAppBundleIdentifier) else {
                    print("DEBUG: checkPasteboard - Excluded app detected: \(activeAppBundleIdentifier). Skipping.")
                    // 内部コピーフラグが設定されていた場合、ここでリセット
                    if wasInternalCopyInitially {
                        isPerformingInternalCopy = false
                        print("DEBUG: checkPasteboard: Excluded app detected during internal copy. isPerformingInternalCopy reset to false.")
                    }
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
                    print("DEBUG: checkPasteboard - Attempt \(attempt) to read pasteboard data.")
                    
                    // 1. ペーストボードの主要なデータタイプを事前にチェック
                    let availableTypes = pasteboard.types ?? []
                    let hasFileURLType = availableTypes.contains(.fileURL)
                    let hasRTFType = availableTypes.contains(.rtf) // RTFタイプのチェックを追加
                    let hasImageDataType = availableTypes.contains(.tiff) || availableTypes.contains(.png) || (pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage) != nil
                    let hasURLType = availableTypes.contains(.URL) || pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.URL.rawValue])
                    
                    // 2. 処理ロジックの決定
                    // ローカルファイルURLが存在し、実際にローカルファイルが存在する場合 -> ファイルとして処理 (最高優先度)
                    if hasFileURLType {
                        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !fileURLs.isEmpty {
                            print("DEBUG: checkPasteboard - File URLs detected: \(fileURLs.map { $0.lastPathComponent })")
                            
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
                            
                            // 有効なローカルファイルURLが存在する場合 -> ファイルとして処理
                            if !validLocalFileURLs.isEmpty {
                                let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                                await self.handleMultipleFilesChange(fileURLs: validLocalFileURLs, sourceAppPath: sourceAppPath)
                                if wasInternalCopyInitially {
                                    await MainActor.run {
                                        self.isPerformingInternalCopy = false
                                        print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after local file URL processing.")
                                    }
                                }
                                success = true
                                return
                            }
                            
                            // Web URLのみの場合 -> URL文字列として処理 (ただし、画像データがなければ)
                            if !webURLStrings.isEmpty && validLocalFileURLs.isEmpty && !hasImageDataType {
                                let urlString = webURLStrings.first ?? ""
                                print("DEBUG: checkPasteboard - Web URL detected as file URL string (no image data): \(urlString.prefix(50))...")
                                let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                                let newItem = ClipboardItem(text: urlString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                                await MainActor.run {
                                    self.addAndSaveItem(newItem)
                                }
                                if wasInternalCopyInitially {
                                    await MainActor.run {
                                        self.isPerformingInternalCopy = false
                                        print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after web URL (as file URL string) processing.")
                                    }
                                }
                                success = true
                                return
                            }
                        } else if let stringURL = pasteboard.string(forType: .fileURL), let url = URL(string: stringURL) {
                            print("DEBUG: checkPasteboard - File URL (string) detected: \(url.lastPathComponent)")
                            
                            if url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                                var qrCodeContent: String? = nil
                                if let fileUTI = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                                   fileUTI.conforms(to: .image) {
                                    if let image = NSImage(contentsOf: url) {
                                        qrCodeContent = self.decodeQRCode(from: image)
                                    }
                                }
                                
                                let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                                if let newItem = await self.createClipboardItemForFileURL(url, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                                    await MainActor.run {
                                        self.addAndSaveItem(newItem)
                                    }
                                }
                                if wasInternalCopyInitially {
                                    await MainActor.run {
                                        self.isPerformingInternalCopy = false
                                        print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after file URL (string) processing.")
                                    }
                                }
                                success = true
                                return
                            } else if !url.isFileURL && !hasImageDataType {
                                // file:// 以外のスキーム (http, httpsなど) は文字列として扱う (ただし、画像データがなければ)
                                print("DEBUG: checkPasteboard - Web URL detected as file URL string (no image data): \(url.absoluteString.prefix(50))...")
                                let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                                let newItem = ClipboardItem(text: url.absoluteString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                                await MainActor.run {
                                    self.addAndSaveItem(newItem)
                                }
                                if wasInternalCopyInitially {
                                    await MainActor.run {
                                        self.isPerformingInternalCopy = false
                                        print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after web URL (as file URL string) processing.")
                                    }
                                }
                                success = true
                                return
                            }
                        }
                    }
                    
                    // 3. URLタイプをチェック (高優先度)
                    // 画像データがある場合は、URLは無視する
                    if hasURLType && !hasImageDataType {
                        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
                            print("DEBUG: checkPasteboard - URL object detected (no image data): \(url.absoluteString.prefix(50))...")
                            let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                            let newItem = ClipboardItem(text: url.absoluteString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                            await MainActor.run {
                                self.addAndSaveItem(newItem)
                            }
                            if wasInternalCopyInitially {
                                await MainActor.run {
                                    self.isPerformingInternalCopy = false
                                    print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after URL object processing.")
                                }
                            }
                            success = true
                            return
                        } else if let urlString = pasteboard.string(forType: .URL) {
                            print("DEBUG: checkPasteboard - URL string detected (no image data): \(urlString.prefix(50))...")
                            let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                            let newItem = ClipboardItem(text: urlString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                            await MainActor.run {
                                self.addAndSaveItem(newItem)
                            }
                            if wasInternalCopyInitially {
                                await MainActor.run {
                                    self.isPerformingInternalCopy = false
                                    print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after URL string processing.")
                                }
                            }
                            success = true
                            return
                        }
                    }
                    
                    // 4. リッチテキストデータをチェック (中高優先度)
                    if hasRTFType, let rtfString = pasteboard.string(forType: .rtf) {
                        print("DEBUG: checkPasteboard - RTF String detected: \(rtfString.prefix(50))...")
                        // RTFのプレーンテキスト表現も取得 (表示用)
                        let plainText = pasteboard.string(forType: .string) ?? rtfString // RTFからプレーンテキストを抽出できない場合は、RTF自体をプレーンテキストとして使用
                        
                        let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                        let newItem = ClipboardItem(richText: rtfString, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                        if wasInternalCopyInitially {
                            await MainActor.run {
                                self.isPerformingInternalCopy = false
                                print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after RTF string processing.")
                            }
                        }
                        success = true
                        return
                    }
                    
                    // 4. ローカルファイルURLが有効でない場合、またはWeb URLと画像データが両方存在する場合 -> 画像データを優先 (高優先度)
                    if hasImageDataType {
                        var imageDataFromPasteboard: Data?
                        var imageFromPasteboard: NSImage?

                        if let tiffData = pasteboard.data(forType: .tiff) {
                            imageDataFromPasteboard = tiffData
                            imageFromPasteboard = NSImage(data: tiffData)
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (TIFF).")
                        } else if let pngData = pasteboard.data(forType: .png) {
                            imageDataFromPasteboard = pngData
                            imageFromPasteboard = NSImage(data: pngData)
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (PNG).")
                        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                            imageDataFromPasteboard = image.tiffRepresentation
                            imageFromPasteboard = image
                            if imageDataFromPasteboard != nil {
                                print("DEBUG: checkPasteboard - Image data detected on pasteboard (from generic NSImage).")
                            }
                        }

                        if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                            let qrCodeContent = self.decodeQRCode(from: image)
                            let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path

                            if let newItem = await self.createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                                await MainActor.run {
                                    self.addAndSaveItem(newItem)
                                }
                            }
                            if wasInternalCopyInitially {
                                await MainActor.run {
                                    self.isPerformingInternalCopy = false
                                    print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after image data processing.")
                                }
                            }
                            success = true
                            return
                        }
                    }
                    
                    // 5. 画像データをチェック (中高優先度)
                    if hasImageDataType {
                        var imageDataFromPasteboard: Data?
                        var imageFromPasteboard: NSImage?

                        if let tiffData = pasteboard.data(forType: .tiff) {
                            imageDataFromPasteboard = tiffData
                            imageFromPasteboard = NSImage(data: tiffData)
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (TIFF).")
                        } else if let pngData = pasteboard.data(forType: .png) {
                            imageDataFromPasteboard = pngData
                            imageFromPasteboard = NSImage(data: pngData)
                            print("DEBUG: checkPasteboard - Image data detected on pasteboard (PNG).")
                        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                            imageDataFromPasteboard = image.tiffRepresentation
                            imageFromPasteboard = image
                            if imageDataFromPasteboard != nil {
                                print("DEBUG: checkPasteboard - Image data detected on pasteboard (from generic NSImage).")
                            }
                        }

                        if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                            let qrCodeContent = self.decodeQRCode(from: image)
                            let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path

                            if let newItem = await self.createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                                await MainActor.run {
                                    self.addAndSaveItem(newItem)
                                }
                            }
                            if wasInternalCopyInitially {
                                await MainActor.run {
                                    self.isPerformingInternalCopy = false
                                    print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after image data processing.")
                                }
                            }
                            success = true
                            return
                        }
                    }

                    // 5. リッチテキストデータをチェック (中間優先度)
                    if let rtfString = pasteboard.string(forType: .rtf) {
                        print("DEBUG: checkPasteboard - RTF String detected: \(rtfString.prefix(50))...")
                        // RTFのプレーンテキスト表現も取得 (表示用)
                        let plainText = pasteboard.string(forType: .string) ?? rtfString // RTFからプレーンテキストを抽出できない場合は、RTF自体をプレーンテキストとして使用
                        
                        let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                        let newItem = ClipboardItem(richText: rtfString, text: plainText, date: Date(), qrCodeContent: nil, sourceAppPath: sourceAppPath)
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                        if wasInternalCopyInitially {
                            await MainActor.run {
                                self.isPerformingInternalCopy = false
                                print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after RTF string processing.")
                            }
                        }
                        success = true
                        return
                    }
                    
                    // 6. 最後に、テキストデータをチェック (低優先度)
                    if let newString = pasteboard.string(forType: .string) {
                        print("DEBUG: checkPasteboard - String detected: \(newString.prefix(50))...")
                        let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                        let newItem = ClipboardItem(text: newString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                        if wasInternalCopyInitially {
                            await MainActor.run {
                                self.isPerformingInternalCopy = false
                                print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after string processing.")
                            }
                        }
                        success = true
                        return
                    }
                    
                    // サポートされていないタイプの場合、少し待機してリトライ
                    if !success && attempt < maxAttempts {
                        print("DEBUG: checkPasteboard - No supported item type found. Retrying in 0.1 seconds...")
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                
                if !success {
                    print("ClipboardManager: No supported item type found on pasteboard after \(maxAttempts) attempts.")
                    // どのタイプも処理されなかった場合でも、内部コピーフラグをリセット
                    if wasInternalCopyInitially {
                        await MainActor.run {
                            self.isPerformingInternalCopy = false
                            print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false as no supported item type found.")
                        }
                    }
                }
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
