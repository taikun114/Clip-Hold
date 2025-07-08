import Foundation
import AppKit
import SwiftUI
import CoreImage

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var clipboardHistory: [ClipboardItem] = [] {
        didSet {
            // clipboardHistoryが変更されたら自動的に保存
            saveClipboardHistory()
        }
    }

    @AppStorage("maxHistoryToSave") private var maxHistoryToSave: Int = 0 // 無制限を0で表す (GeneralSettingsViewとキーを合わせる)

    @AppStorage("scanQRCodeImage") private var scanQRCodeImage = false

    @Published var excludedAppIdentifiers: [String] = []

    private var pasteboardMonitorTimer: Timer?
    private var lastChangeCount: Int = 0
    private let historyFileName = "clipboardHistory.json"

    @Published var isMonitoring: Bool = false

    private var isClipboardMonitoringPausedObserver: NSKeyValueObservation?

    private init() {
        loadClipboardHistory()
        
        print("ClipboardManager: Initialized with history count: \(clipboardHistory.count)")

        // 既存の除外アプリ識別子をロード（UserDefaultsから）
        if let data = UserDefaults.standard.data(forKey: "excludedAppIdentifiersData"),
           let identifiers = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedAppIdentifiers = identifiers
        }

        isClipboardMonitoringPausedObserver = UserDefaults.standard.observe(\.isClipboardMonitoringPaused, options: [.initial, .new]) { [weak self] defaults, change in
            guard let self = self else { return }
            let isPaused = defaults.isClipboardMonitoringPaused
            
            // @Published isMonitoring の状態を更新
            self.isMonitoring = !isPaused // isPausedがtrueならisMonitoringはfalse

            // 監視状態に応じてタイマーを制御
            if isPaused {
                self.stopMonitoringPasteboard() // UserDefaultsが停止状態ならタイマーを停止
            } else {
                self.startMonitoringPasteboard() // UserDefaultsが再開状態ならタイマーを開始
            }
            print("DEBUG: ClipboardManager: UserDefaults.isClipboardMonitoringPaused changed to \(isPaused). isMonitoring set to \(self.isMonitoring).")
        }
    }

    // オブジェクト破棄時に監視を停止する
    deinit {
        isClipboardMonitoringPausedObserver?.invalidate()
        print("DEBUG: ClipboardManager: isClipboardMonitoringPausedObserver invalidated.")
    }

    // MARK: - Clipboard Monitoring
    func startMonitoringPasteboard() {
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

    func stopMonitoringPasteboard() {
        if let timer = pasteboardMonitorTimer {
            timer.invalidate()
            self.pasteboardMonitorTimer = nil
            print("DEBUG: stopMonitoringPasteboard: Timer invalidated and nilled.")
        } else {
            print("DEBUG: stopMonitoringPasteboard: No active timer to stop.")
        }
        // isMonitoringはobserverによって更新されるため、ここで明示的に設定する必要はないかもしれませんが、
        // stopMonitoringPasteboardが呼び出された際の意図を明確にするために残します。
        isMonitoring = false // observerが設定するためコメントアウト
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

            // 現在アクティブなアプリケーションを取得
            if let activeAppBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                // 除外リストに含まれていないかチェック
                guard !excludedAppIdentifiers.contains(activeAppBundleIdentifier) else {
                    return // 除外アプリからのコピーは無視
                }
            }

            var copiedText: String?

            // 1. まずは文字列として取得を試みる
            if let newString = pasteboard.string(forType: .string) {
                copiedText = newString
            }
            // 2. 文字列が取得できなかった場合、画像として取得を試み、QRコードを解析
            else if scanQRCodeImage, let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                print("ClipboardManager: Image detected on pasteboard. Attempting QR code decoding...")
                if let decodedText = decodeQRCode(from: image) {
                    copiedText = decodedText
                    print("ClipboardManager: QR code successfully decoded: \(decodedText.prefix(50))...")
                } else {
                    print("ClipboardManager: Image detected but no QR code found or decoding failed.")
                }
            }

            if let finalCopiedText = copiedText {
                // 同じ内容のものが連続してコピーされた場合は追加しない
                if let lastItem = clipboardHistory.first, lastItem.text == finalCopiedText {
                    return
                }

                let newItem = ClipboardItem(text: finalCopiedText, date: Date())
                clipboardHistory.insert(newItem, at: 0) // 先頭に追加
                print("ClipboardManager: New item added. Total history: \(clipboardHistory.count)")

                // 最大履歴数を超過した場合の処理
                enforceMaxHistoryCount()
            } else {
                print("ClipboardManager: No supported content found on pasteboard.")
            }
        }
    }

    // MARK: - QR Code Decoding
    private func decodeQRCode(from image: NSImage) -> String? {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else { // NSImageをCIImageに変換
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

    // MARK: - History Management
    func clearAllHistory() {
        clipboardHistory = []
        print("ClipboardManager: All history cleared.")
    }

    func deleteItem(id: UUID) {
        clipboardHistory.removeAll { $0.id == id }
        print("ClipboardManager: Item deleted. Total history: \(clipboardHistory.count)")
    }
    
    // MARK: - History Import/Export (ClipboardHistoryImporterExporterが使うメソッドを定義)
    func importHistory(from items: [ClipboardItem]) {
        // バックグラウンドで処理することでUIのブロックを防ぐ
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // 1. 重複を避けて新しいアイテムを結合
            // テキスト内容が重複するアイテムは追加しない
            let existingTexts = Set(self.clipboardHistory.map { $0.text })
            let newItems = items.filter { !existingTexts.contains($0.text) }

            // 2. 既存の履歴に新しいアイテムを追加 (メインスレッドでPublishedプロパティを更新)
            DispatchQueue.main.async {
                self.clipboardHistory.append(contentsOf: newItems)

                // 3. 全体を日付（date）の降順でソート
                // （新しいものが先頭に来るように）
                self.clipboardHistory.sort { $0.date > $1.date }

                // 4. 最大履歴数を超過した場合の処理
                self.enforceMaxHistoryCount()
                
                print("ClipboardManager: 履歴をインポートしました。追加された項目数: \(newItems.count), 総履歴数: \(self.clipboardHistory.count)")
            }
        }
    }
    
    // MARK: - Max History Count Enforcement
    func enforceMaxHistoryCount() {
        print("DEBUG: enforceMaxHistoryCount() - maxHistoryToSave: \(self.maxHistoryToSave), 現在の履歴数: \(self.clipboardHistory.count)")
        if self.maxHistoryToSave > 0 && self.clipboardHistory.count > self.maxHistoryToSave {
            self.clipboardHistory.removeLast(self.clipboardHistory.count - self.maxHistoryToSave)
            print("DEBUG: enforceMaxHistoryCount() - 履歴を \(self.maxHistoryToSave) に調整しました。現在の履歴数: \(self.clipboardHistory.count)")
        } else if self.maxHistoryToSave == 0 { // 無制限の場合
            print("DEBUG: enforceMaxHistoryCount() - 無制限設定のため調整なし。")
        }
    }

    // MARK: - Excluded App Management
    func updateExcludedAppIdentifiers(_ identifiers: [String]) {
        // 現在のリストと新しいリストが同じでなければ更新する
        if self.excludedAppIdentifiers != identifiers {
            self.excludedAppIdentifiers = identifiers
            print("ClipboardManager: Excluded app identifiers updated. Count: \(identifiers.count)")
        }
    }

    // MARK: - History Persistence (ファイルシステムに保存)
    private func saveClipboardHistory() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ClipboardManager: Could not find Application Support directory (save).")
            return
        }

        // アプリ固有のサブディレクトリを作成
        let appSpecificDirectory = directory.appendingPathComponent("ClipHold")
        let fileURL = appSpecificDirectory.appendingPathComponent(historyFileName)

        do {
            // ディレクトリが存在しない場合は作成
            if !FileManager.default.fileExists(atPath: appSpecificDirectory.path) {
                try FileManager.default.createDirectory(at: appSpecificDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601 // 日付のエンコード形式を合わせる (ClipboardHistoryDocumentと一致させる)
            encoder.outputFormatting = .prettyPrinted // 可読性のために整形 (Optional)

            let data = try encoder.encode(clipboardHistory)
            try data.write(to: fileURL)
        } catch {
            print("ClipboardManager: Error saving clipboard history to file: \(error.localizedDescription)")
        }
    }

    // MARK: - History Loading (ファイルシステムからロード)
    private func loadClipboardHistory() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ClipboardManager: Could not find Application Support directory (load).")
            return
        }

        let appSpecificDirectory = directory.appendingPathComponent("ClipHold")
        let fileURL = appSpecificDirectory.appendingPathComponent(historyFileName)

        // ファイルが存在しない場合は早期リターン
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ClipboardManager: Clipboard history file not found, starting with empty history.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601 // 日付のデコード形式を合わせる (ClipboardHistoryDocumentと一致させる)
            
            self.clipboardHistory = try decoder.decode([ClipboardItem].self, from: data)
            print("ClipboardManager: Clipboard history loaded from file. Count: \(clipboardHistory.count), Size: \(data.count) bytes.")
        } catch {
            print("ClipboardManager: Error loading clipboard history from file: \(error.localizedDescription)")
        }
    }
}
extension ClipboardManager {
    func addHistoryItem(text: String) {
        // 同じ内容のものが連続してコピーされた場合は追加しない
        if let lastItem = clipboardHistory.first, lastItem.text == text {
            print("ClipboardManager: Duplicate item detected via addHistoryItem, skipping. Text: \(text.prefix(50))...")
            return
        }

        let newItem = ClipboardItem(text: text, date: Date())
        clipboardHistory.insert(newItem, at: 0) // 先頭に追加
        print("ClipboardManager: New item added via addHistoryItem. Total history: \(clipboardHistory.count)")

        // 最大履歴数を超過した場合の処理を適用
        enforceMaxHistoryCount()
    }
}
