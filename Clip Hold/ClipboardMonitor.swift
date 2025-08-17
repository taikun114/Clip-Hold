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

            // 非同期処理を開始
            Task.detached { [weak self] in
                guard let self = self else { return }

                // 1. ファイルURLを読み込もうとする（最優先）
                // readObjectsがNSURLを返す場合と、stringがfileURLを返す場合を両方チェック
                if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                   let firstFileURL = fileURLs.first {
                    print("DEBUG: checkPasteboard - File URL detected: \(firstFileURL.lastPathComponent)")

                    var qrCodeContent: String? = nil

                    // コピーされたファイルが画像であるかチェック
                    if let fileUTI = try? firstFileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
                       fileUTI.conforms(to: .image) {
                        if let image = NSImage(contentsOf: firstFileURL) {
                            qrCodeContent = self.decodeQRCode(from: image)
                        }
                    }
                    
                    // 最前面のアプリケーションのパスを取得
                    let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path

                    if let newItem = await self.createClipboardItemForFileURL(firstFileURL, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                    // 処理が完了したので、内部コピーフラグをリセット
                    if wasInternalCopyInitially {
                        await MainActor.run {
                            self.isPerformingInternalCopy = false
                            print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after file URL processing.")
                        }
                    }
                    return // ファイルの有無に関わらず、ファイルパスのチェックが完了したので終了
                } else if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue]),
                          let stringURL = pasteboard.string(forType: .fileURL),
                          let url = URL(string: stringURL) {
                    print("DEBUG: checkPasteboard - File URL (string) detected: \(url.lastPathComponent)")

                    var qrCodeContent: String? = nil

                    if let fileUTI = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                       fileUTI.conforms(to: .image) {
                        if let image = NSImage(contentsOf: url) {
                            qrCodeContent = self.decodeQRCode(from: image)
                        }
                    }
                    
                    // 最前面のアプリケーションのパスを取得
                    let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path

                    if let newItem = await self.createClipboardItemForFileURL(url, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                    // 処理が完了したので、内部コピーフラグをリセット
                    if wasInternalCopyInitially {
                        await MainActor.run {
                            self.isPerformingInternalCopy = false
                            print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after file URL (string) processing.")
                        }
                    }
                    return // ファイルの有無に関わらず、ファイルパスのチェックが完了したので終了
                }

                // 2. ファイルURLがなければ、画像データを直接読み込もうとする
                var imageDataFromPasteboard: Data?
                var imageFromPasteboard: NSImage?

                // ネイティブな画像データを優先して読み込む
                if let tiffData = pasteboard.data(forType: .tiff) {
                    imageDataFromPasteboard = tiffData
                    imageFromPasteboard = NSImage(data: tiffData)
                    print("DEBUG: checkPasteboard - Image data detected on pasteboard (TIFF).")
                } else if let pngData = pasteboard.data(forType: .png) {
                    imageDataFromPasteboard = pngData
                    imageFromPasteboard = NSImage(data: pngData)
                    print("DEBUG: checkPasteboard - Image data detected on pasteboard (PNG).")
                } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                    // どちらも見つからない場合、一般的なNSImageオブジェクトのTIFF表現を試みる
                    imageDataFromPasteboard = image.tiffRepresentation
                    imageFromPasteboard = image
                    if imageDataFromPasteboard != nil {
                        print("DEBUG: checkPasteboard - Image data detected on pasteboard (from generic NSImage).")
                    }
                }

                if let imageData = imageDataFromPasteboard, let image = imageFromPasteboard {
                    let qrCodeContent = self.decodeQRCode(from: image)
                    
                    // 最前面のアプリケーションのパスを取得
                    let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path

                    if let newItem = await self.createClipboardItemFromImageData(imageData, qrCodeContent: qrCodeContent, sourceAppPath: sourceAppPath) {
                        await MainActor.run {
                            self.addAndSaveItem(newItem)
                        }
                    }
                    // 処理が完了したので、内部コピーフラグをリセット
                    if wasInternalCopyInitially {
                        await MainActor.run {
                            self.isPerformingInternalCopy = false
                            print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after image data processing.")
                        }
                    }
                    return // 画像の有無に関わらず、画像データのチェックが完了したので終了
                }

                // 3. ファイルも画像もなかった場合、文字列として処理を試みる
                if let newString = pasteboard.string(forType: .string) {
                    print("DEBUG: checkPasteboard - String detected: \(newString.prefix(50))...")
                    // 最前面のアプリケーションのパスを取得
                    let sourceAppPath = NSWorkspace.shared.frontmostApplication?.bundleURL?.path
                    let newItem = ClipboardItem(text: newString, date: Date(), filePath: nil, fileSize: nil, qrCodeContent: nil, sourceAppPath: sourceAppPath)
                    await MainActor.run {
                        self.addAndSaveItem(newItem)
                    }
                    // 処理が完了したので、内部コピーフラグをリセット
                    if wasInternalCopyInitially {
                        await MainActor.run {
                            self.isPerformingInternalCopy = false
                            print("DEBUG: checkPasteboard: isPerformingInternalCopy reset to false after string processing.")
                        }
                    }
                    return
                }

                print("ClipboardManager: No supported item type found on pasteboard.")
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