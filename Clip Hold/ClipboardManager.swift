import Foundation
import AppKit
import SwiftUI
import CoreImage // QRコード解析用
import UniformTypeIdentifiers // UTTypeのチェック用
import QuickLookThumbnailing

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var clipboardHistory: [ClipboardItem] = []

    // MARK: - Properties that need to remain in the main class
    var saveTask: Task<Void, Never>?
    var temporaryFileUrls: Set<URL> = []
    @AppStorage("maxHistoryToSave") var maxHistoryToSave: Int = 0
    @AppStorage("maxFileSizeToSave") var maxFileSizeToSave: Int = 1_000_000_000
    @AppStorage("largeFileAlertThreshold") var largeFileAlertThreshold: Int = 1_000_000_000
    @Published var excludedAppIdentifiers: [String] = []
    var pasteboardMonitorTimer: Timer?
    var lastChangeCount: Int = 0
    let historyFileName = "clipboardHistory.json"
    let filesDirectoryName = "ClipboardFiles"
    @Published var isMonitoring: Bool = false
    @Published var isPerformingInternalCopy: Bool = false
    var isClipboardMonitoringPausedObserver: NSKeyValueObservation?
    @Published var showingLargeFileAlert: Bool = false {
        didSet {
            if showingLargeFileAlert && !oldValue {
                presentLargeFileConfirmationAlert()
            }
        }
    }
    var pendingLargeFileItem: (fileURL: URL, qrCodeContent: String?)?
    var pendingLargeImageData: (imageData: Data, qrCodeContent: String?)?

    // MARK: - Initialization
    private init() {
        // ファイル保存ディレクトリの準備
        _ = createClipboardFilesDirectoryIfNeeded()

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
}

