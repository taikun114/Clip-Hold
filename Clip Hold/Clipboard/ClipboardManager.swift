import Foundation
import AppKit
import SwiftUI
import CoreImage // QRコード解析用
import UniformTypeIdentifiers // UTTypeのチェック用
import QuickLookThumbnailing

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var filteredHistoryForShortcuts: [ClipboardItem]? = nil
    
    // アプリケーション名のキャッシュ
    @Published var localizedAppNames: [String: String] = [:]
    
    // ピン留めされた履歴アイテムのID
    @Published var pinnedItemID: UUID? {
        didSet {
            if let pinnedItemID = pinnedItemID {
                UserDefaults.standard.set(pinnedItemID.uuidString, forKey: "pinnedItemID")
            } else {
                UserDefaults.standard.removeObject(forKey: "pinnedItemID")
            }
        }
    }
    
    // ピン留めされた ClipboardItem オブジェクトを取得する算出プロパティ
    var pinnedItem: ClipboardItem? {
        guard let pinnedItemID = pinnedItemID else { return nil }
        return clipboardHistory.first { $0.id == pinnedItemID }
    }
    
    // アイテムをピン留めする
    func pinItem(_ item: ClipboardItem) {
        pinnedItemID = item.id
    }
    
    // ピン留めを解除する
    func unpinItem() {
        pinnedItemID = nil
    }
    
    // History Window States
    @Published var historySelectedFilter: ItemFilter = .all
    @Published var historySelectedSort: ItemSort = .newest
    @Published var historySelectedApp: String? = nil
    
    // キャッシュを利用してローカライズされたアプリ名を取得するメソッド
    func getLocalizedName(for sourceAppPath: String?) -> String? {
        guard let sourceAppPath = sourceAppPath else { return nil }
        
        // 1. キャッシュを確認
        if let cachedName = localizedAppNames[sourceAppPath] {
            return cachedName
        }
        
        // 2. キャッシュにない場合はファイルシステムから取得
        let appURL = URL(fileURLWithPath: sourceAppPath)
        let nonLocalizedName = appURL.deletingPathExtension().lastPathComponent
        
        var finalName = nonLocalizedName
        if let appBundle = Bundle(url: appURL) {
            finalName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ??
            appBundle.localizedInfoDictionary?["CFBundleName"] as? String ??
            appBundle.infoDictionary?["CFBundleName"] as? String ??
            nonLocalizedName
        }
        
        // 3. 取得した名前をキャッシュに保存
        Task { @MainActor [weak self] in
            self?.localizedAppNames[sourceAppPath] = finalName
        }
        
        return finalName
    }
    
    func resetHistoryViewFilters() {
        historySelectedFilter = .all
        historySelectedSort = .newest
        historySelectedApp = nil
    }
    
    // MARK: - Properties that need to remain in the main class
    var saveTask: Task<Void, Never>?
    var temporaryFileUrls: Set<URL> = []
    @AppStorage("maxHistoryToSave") var maxHistoryToSave: Int = 0
    @AppStorage("maxFileSizeToSave") var maxFileSizeToSave: Int = 1_000_000_000
    @AppStorage("largeFileAlertThreshold") var largeFileAlertThreshold: Int = 1_000_000_000
    @AppStorage("ignoreStandardPhrases") var ignoreStandardPhrases: Bool = false
    @Published var excludedAppIdentifiers: [String] = []
    var pasteboardMonitorTimer: Timer?
    var lastChangeCount: Int = 0
    let historyFileName = "clipboardHistory.json"
    let filesDirectoryName = "ClipboardFiles"
    @Published var isMonitoring: Bool = false
    @Published var isPerformingInternalCopy: Bool = false
    @Published var isCopyingStandardPhrase: Bool = false
    
    var isClipboardMonitoringPausedObserver: NSKeyValueObservation?
    @Published var showingLargeFileAlert: Bool = false {
        didSet {
            if showingLargeFileAlert && !oldValue {
                presentLargeFileConfirmationAlert()
            }
        }
    }
    // 既存のプロパティ（将来的な互換性維持のため保持）
    var pendingLargeFileItem: (fileURL: URL, qrCodeContent: String?)?
    var pendingLargeFileItems: [(fileURL: URL, qrCodeContent: String?)]?
    var pendingLargeFileItemsSourceAppPath: String? // 新しく追加
    var pendingLargeImageData: (imageData: Data, qrCodeContent: String?)?
    
    // 新しく追加: ファイルサイズ情報を含む新しいプロパティ
    var pendingLargeFileItemsWithSize: [(fileURL: URL, qrCodeContent: String?, fileSize: UInt64?)]?
    
    // MARK: - Initialization
    private init() {
        // ファイル保存ディレクトリの準備
        _ = createClipboardFilesDirectoryIfNeeded()
        
        // マイグレーションと履歴のロードを非同期で実行
        Task {
            let migrationPerformed = await ChunkedHistoryManager.shared.migrateIfNeeded()
            
            // マイグレーションが成功した場合、通知を表示
            if migrationPerformed {
                await MainActor.run {
                    NotificationManager.shared.sendMigrationSuccessNotification()
                }
            } else if !migrationPerformed && FileManager.default.fileExists(atPath: (self.getAppSpecificDirectory()?.appendingPathComponent(self.historyFileName).path ?? "")) {
                // マイグレーションが失敗した場合、失敗通知を表示
                await MainActor.run {
                    NotificationManager.shared.sendMigrationFailureNotification()
                }
            }
            
            // アプリ起動時にファイルハッシュが存在しない履歴アイテムに対してハッシュを計算
            await self.calculateMissingFileHashesInHistory()
            
            // 保存されたピン留めアイテムIDをロード
            if let pinnedIDString = UserDefaults.standard.string(forKey: "pinnedItemID"),
               let pinnedUUID = UUID(uuidString: pinnedIDString) {
                await MainActor.run {
                    self.pinnedItemID = pinnedUUID
                }
            }
            
            await self.loadClipboardHistory()
            print("ClipboardManager: Initialized with history count: \(self.clipboardHistory.count)")
        }
        
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
    
    // アプリケーションの履歴を返す算出プロパティ
    var appUsageHistory: [String: String] {
        let appPaths = Set(clipboardHistory.compactMap { $0.sourceAppPath })
        var appNames = [String: String]()
        
        for path in appPaths {
            let appURL = URL(fileURLWithPath: path)
            let nonLocalizedName = appURL.deletingPathExtension().lastPathComponent
            
            if let appBundle = Bundle(url: appURL) {
                let appName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? appBundle.localizedInfoDictionary?["CFBundleName"] as? String ?? appBundle.infoDictionary?["CFBundleName"] as? String ?? nonLocalizedName
                appNames[path] = appName
            } else {
                appNames[path] = nonLocalizedName
            }
        }
        return appNames
    }
    
    // 画像を正方形にパディングするヘルパー関数（アスペクト比を維持）
    func padToSquare(_ image: NSImage, size: CGSize) -> NSImage {
        let imageSize = image.size
        let maxSide = max(imageSize.width, imageSize.height)
        let squareSize = CGSize(width: maxSide, height: maxSide)
        
        let paddedImage = NSImage(size: squareSize)
        paddedImage.lockFocus()
        
        // 透明な背景を描画
        NSColor.clear.set()
        NSBezierPath(rect: CGRect(origin: .zero, size: squareSize)).fill()
        
        // 画像を中央に配置
        let originX = (maxSide - imageSize.width) / 2
        let originY = (maxSide - imageSize.height) / 2
        image.draw(
            in: CGRect(x: originX, y: originY, width: imageSize.width, height: imageSize.height),
            from: CGRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1.0
        )
        
        paddedImage.unlockFocus()
        
        // 必要に応じてリサイズ
        if maxSide != size.width || maxSide != size.height {
            let resizedImage = NSImage(size: size)
            resizedImage.lockFocus()
            paddedImage.draw(
                in: CGRect(origin: .zero, size: size),
                from: CGRect(origin: .zero, size: squareSize),
                operation: .copy,
                fraction: 1.0
            )
            resizedImage.unlockFocus()
            return resizedImage
        }
        
        return paddedImage
    }
    
    // 色から円形のNSImageを生成するヘルパー関数
    func createColorIcon(color: Color, size: CGSize) -> NSImage {
        let nsColor = NSColor(color)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        
        // 円形のパスを作成
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
        
        // 色を塗りつぶし
        nsColor.setFill()
        path.fill()
        
        // 枠線を描画
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        image.unlockFocus()
        return image
    }
    
    // 特定のアプリからの履歴をすべて削除する関数
    func deleteAllHistoryFromApp(sourceAppPath: String) {
        Task { @MainActor in
            // 対象となるアイテムを一括で取得
            let itemsToDelete = clipboardHistory.filter { $0.sourceAppPath == sourceAppPath }
            
            // 非同期でファイルシステムの操作を並列処理
            await withTaskGroup(of: Void.self) { group in
                for item in itemsToDelete {
                    if let filePath = item.filePath {
                        group.addTask {
                            self.deleteFileFromSandbox(at: filePath)
                        }
                    }
                }
            }
            
            // ChunkedHistoryManagerからも一括削除（チャンク単位で効率的に削除）
            Task {
                await ChunkedHistoryManager.shared.deleteAllHistoryFromApp(sourceAppPath: sourceAppPath)
            }
            
            // メモリ上の履歴から対象アイテムを一括削除
            if let pinnedID = pinnedItemID, itemsToDelete.contains(where: { $0.id == pinnedID }) {
                unpinItem()
            }
            clipboardHistory.removeAll { $0.sourceAppPath == sourceAppPath }
            
            // UI更新のための通知
            objectWillChange.send()
            
            print("ClipboardManager: All history from app \(sourceAppPath) deleted. Removed \(itemsToDelete.count) items.")
        }
    }
    
    // 特定のアプリからの履歴の数をカウントする関数
    func countHistoryFromApp(sourceAppPath: String) -> Int {
        return clipboardHistory.count { $0.sourceAppPath == sourceAppPath }
    }
}

