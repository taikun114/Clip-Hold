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
    @Published var isHistoryLoaded: Bool = false
    @Published var isExporting: Bool = false {
        didSet {
            if isExporting {
                previousMonitoringState = UserDefaults.standard.bool(forKey: "isClipboardMonitoringPaused")
                UserDefaults.standard.set(true, forKey: "isClipboardMonitoringPaused")
            } else {
                if let previousState = previousMonitoringState {
                    UserDefaults.standard.set(previousState, forKey: "isClipboardMonitoringPaused")
                }
            }
        }
    }
    
    @Published var isMonitoring: Bool = false
    
    /// 実際に監視が行われている状態でのみ false（動作中）を返し、
    /// 監視開始前（履歴読み込み中など）や明示的一時停止中は true（一時停止中）を返す
    var isClipboardMonitoringPaused: Bool {
        return !isMonitoring
    }
    
    private var previousMonitoringState: Bool? = nil
    
    // 進行中のインポートタスクを保持し、クリア時にキャンセル可能にする
    var activeImportTask: Task<Void, Never>?
    
    // サンドボックスファイルURLからハッシュを引くためのキャッシュ
    @MainActor private var fileHashCache: [URL: String] = [:]
    
    @MainActor
    func updateFileHashCache(url: URL, hash: String) {
        fileHashCache[url] = hash
    }
    
    @MainActor
    func getCachedFileHash(for url: URL) -> String? {
        return fileHashCache[url]
    }
    
    // ハッシュからキャッシュ内のファイルURLを検索する
    @MainActor
    func getFileURL(forHash hash: String) -> URL? {
        return fileHashCache.first(where: { $1 == hash })?.key
    }
    
    // アプリケーション名のキャッシュ
    @Published var localizedAppNames: [String: String] = [:]
    
    // アプリケーションアイコンのキャッシュ（リサイズ済み）
    @Published var resizedAppIcons: [String: NSImage] = [:]
    
    // キャッシュを利用してリサイズ済みのアプリアイコンを取得するメソッド
    func getResizedAppIcon(for path: String) -> NSImage? {
        if let cachedIcon = resizedAppIcons[path] {
            return cachedIcon
        }
        
        // macOS 14でのSwiftUIメニュー表示不具合対策として、初回のみ同期的にリサイズして返す
        let originalIcon = NSWorkspace.shared.icon(forFile: path)
        let resizedIcon = NSImage(size: CGSize(width: 16, height: 16))
        resizedIcon.lockFocus()
        originalIcon.draw(in: NSRect(origin: .zero, size: CGSize(width: 16, height: 16)),
                          from: NSRect(origin: .zero, size: originalIcon.size),
                          operation: .sourceOver,
                          fraction: 1.0)
        resizedIcon.unlockFocus()
        
        // 描画サイクル中の状態更新による警告を防ぐため非同期でキャッシュに保存
        Task { @MainActor in
            self.resizedAppIcons[path] = resizedIcon
        }
        
        return resizedIcon
    }
    
    // ピン留めされた履歴アイテムのID
    @Published var pinnedItemID: UUID? {
        didSet {
            if let pinnedItemID = pinnedItemID {
                UserDefaults.standard.set(pinnedItemID.uuidString, forKey: "pinnedItemID")
            } else {
                UserDefaults.standard.removeObject(forKey: "pinnedItemID")
            }
            updateQuickOverlayHistoryCache()
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
    
    // クイックオーバーレイ用の事前同期キャッシュ（最新50件＋ピン留め）
    @Published var quickOverlayHistoryItems: [ClipboardItem] = []
    
    /// クイックオーバーレイ用の最新50件（+ピン留め）キャッシュを同期更新する
    func updateQuickOverlayHistoryCache() {
        guard !clipboardHistory.isEmpty else {
            if !quickOverlayHistoryItems.isEmpty {
                quickOverlayHistoryItems = []
            }
            return
        }
        
        let allSortedHistory = clipboardHistory.sorted { $0.date > $1.date }
        var raw = Array(allSortedHistory.prefix(50))
        
        if let pinnedID = pinnedItemID,
           let pinnedItem = clipboardHistory.first(where: { $0.id == pinnedID }) {
            raw.insert(pinnedItem.createPinnedDuplicate(), at: 0)
        }
        quickOverlayHistoryItems = raw
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
    var maxHistoryToSave: Int {
        UserDefaults.standard.integer(forKey: "maxHistoryToSave")
    }
    var maxFileSizeToSave: Int {
        let val = UserDefaults.standard.object(forKey: "maxFileSizeToSave") as? Int
        return val ?? 1_000_000_000
    }
    var largeFileAlertThreshold: Int {
        let val = UserDefaults.standard.object(forKey: "largeFileAlertThreshold") as? Int
        return val ?? 100_000_000
    }
    var folderCalculationTimeout: Double {
        let val = UserDefaults.standard.object(forKey: "folderCalculationTimeout") as? Double
        return val ?? 3.0
    }
    var ignoreStandardPhrases: Bool {
        UserDefaults.standard.bool(forKey: "ignoreStandardPhrases")
    }
    @Published var excludedAppIdentifiers: [String] = []
    var pasteboardMonitorTimer: Timer?
    var lastChangeCount: Int = 0
    let historyFileName = "clipboardHistory.json"
    let filesDirectoryName = "ClipboardFiles"
    
    private var internalCopyTimeoutTask: Task<Void, Never>?
    @Published var isPerformingInternalCopy: Bool = false {
        didSet {
            if isPerformingInternalCopy {
                internalCopyTimeoutTask?.cancel()
                internalCopyTimeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    if !Task.isCancelled {
                        self?.isPerformingInternalCopy = false
                        self?.lastCopiedInternalItem = nil
#if DEBUG
                        print("DEBUG: isPerformingInternalCopy auto-reset to false")
#endif
                    }
                }
            } else {
                lastCopiedInternalItem = nil
            }
        }
    }
    var lastCopiedInternalItem: ClipboardItem? = nil
    
    private var standardPhraseCopyTimeoutTask: Task<Void, Never>?
    @Published var isCopyingStandardPhrase: Bool = false {
        didSet {
            if isCopyingStandardPhrase {
                standardPhraseCopyTimeoutTask?.cancel()
                standardPhraseCopyTimeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    if !Task.isCancelled {
                        self?.isCopyingStandardPhrase = false
#if DEBUG
                        print("DEBUG: isCopyingStandardPhrase auto-reset to false")
#endif
                    }
                }
            }
        }
    }
    
    var isClipboardMonitoringPausedObserver: NSKeyValueObservation?
    @Published var showingLargeFileAlert: Bool = false {
        didSet {
            if showingLargeFileAlert && !oldValue {
                presentLargeFileConfirmationAlert()
            }
        }
    }
    // MARK: - Large File Alert Properties
    // 大容量ファイルの保留リスト（統合）
    @Published var pendingLargeFileItemsWithSize: [ClipboardItem] = [] {
        didSet {
            if showingLargeFileAlert {
                presentLargeFileConfirmationAlert()
            }
        }
    }
    @Published var pendingLargeFileItemsSourceAppPath: String?
    @Published var pendingLargeFileIsTimeout: Bool = false
    
    // 画像データ用の保留プロパティ（これはそのまま保持）
    var pendingLargeImageData: (imageData: Data, qrCodeContent: String?)?
    
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
            await MainActor.run {
                self.isHistoryLoaded = true
                let isPaused = UserDefaults.standard.bool(forKey: "isClipboardMonitoringPaused")
                self.isMonitoring = !isPaused
                if !isPaused {
                    self.startMonitoringPasteboard()
                }
            }
            print("ClipboardManager: Initialized with history count: \(self.clipboardHistory.count)")
        }
        
        // 既存の除外アプリ識別子をロード（UserDefaultsから）
        if let data = UserDefaults.standard.data(forKey: "excludedAppIdentifiersData"),
           let identifiers = try? JSONDecoder().decode([String].self, from: data) {
            self.excludedAppIdentifiers = identifiers
        }
        
        isClipboardMonitoringPausedObserver = UserDefaults.standard.observe(\.isClipboardMonitoringPaused, options: [.new]) { [weak self] defaults, change in
            guard let self = self, self.isHistoryLoaded else { return }
            let isPaused = defaults.isClipboardMonitoringPaused
            
            // @Published isMonitoring の状態を更新
            self.isMonitoring = !isPaused // isPausedがtrueならisMonitoringはfalse
            
            // 監視状態に応じてタイマーを制御
            if isPaused {
                self.stopMonitoringPasteboard() // UserDefaultsが停止状態ならタイマーを停止
            } else {
                self.startMonitoringPasteboard() // UserDefaultsが再開状態ならタイマーを開始
            }
#if DEBUG
            print("DEBUG: ClipboardManager: UserDefaults.isClipboardMonitoringPaused changed to \(isPaused). isMonitoring set to \(self.isMonitoring).")
#endif
        }
    }
    
    // オブジェクト破棄時に監視を停止する
    deinit {
        isClipboardMonitoringPausedObserver?.invalidate()
#if DEBUG
        print("DEBUG: ClipboardManager: isClipboardMonitoringPausedObserver invalidated.")
#endif
    }
    
    private var _cachedAppPaths: Set<String>?
    private var _cachedAppPathsHistoryCount: Int = -1

    // アプリケーションの履歴を返す算出プロパティ
    var appUsageHistory: [String: String] {
        let appPaths: Set<String>
        if _cachedAppPathsHistoryCount == clipboardHistory.count, let cached = _cachedAppPaths {
            appPaths = cached
        } else {
            appPaths = Set(clipboardHistory.compactMap { $0.sourceAppPath })
            _cachedAppPaths = appPaths
            _cachedAppPathsHistoryCount = clipboardHistory.count
        }
        
        var appNames = [String: String]()
        
        for path in appPaths {
            if let cachedName = localizedAppNames[path] {
                appNames[path] = cachedName
            } else {
                let appURL = URL(fileURLWithPath: path)
                let nonLocalizedName = appURL.deletingPathExtension().lastPathComponent
                
                let appName: String
                if let appBundle = Bundle(url: appURL) {
                    appName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? appBundle.localizedInfoDictionary?["CFBundleName"] as? String ?? appBundle.infoDictionary?["CFBundleName"] as? String ?? nonLocalizedName
                } else {
                    appName = nonLocalizedName
                }
                appNames[path] = appName
                
                Task { @MainActor [weak self] in
                    self?.localizedAppNames[path] = appName
                }
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
        guard !isExporting else { return }
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
            
            // 削除後に孤立ファイルのクリーンアップをトリガー
            self.triggerOrphanedFilesCleanup()
        }
    }
    
    // 特定のアプリからの履歴の数をカウントする関数
    func countHistoryFromApp(sourceAppPath: String) -> Int {
        return clipboardHistory.count { $0.sourceAppPath == sourceAppPath }
    }
    
    // インポートや設定画面からの「再計算」を共通化するメソッド
    func recalculateAllFolderSizes(progressHandler: ((Double, UInt64) async -> Void)? = nil) async -> UInt64 {
        let fileManager = FileManager.default
        guard let appSpecificDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("ClipHold") else {
            return 0
        }
        let filesDirectory = appSpecificDirectory.appendingPathComponent("ClipboardFiles", isDirectory: true)
        
        var newTotalSize: UInt64 = 0
        var updatedItems: [ClipboardItem] = []
        var lastUIUpdate = Date()
        
        do {
            let allChildURLs = try fileManager.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [])
            let childURLs = allChildURLs.filter { $0.lastPathComponent != ".DS_Store" }
            let totalFiles = childURLs.count
            
            // メインスレッドで現在の履歴アイテムのファイル名リストを取得（孤立ファイルの判定用）
            let validFileNames = await MainActor.run {
                var names = Set<String>()
                for item in self.clipboardHistory {
                    if let fileName = item.filePath?.lastPathComponent {
                        names.insert(fileName)
                    }
                }
                return names
            }
            
            for (index, childURL) in childURLs.enumerated() {
                let fileName = childURL.lastPathComponent
                let isOrphan = !validFileNames.contains(fileName)
                
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: childURL.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        if isOrphan {
                            // 孤立したフォルダ（履歴にない）は浅いサイズのみ加算
                            if let fileSize = (try? childURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                                newTotalSize += UInt64(fileSize)
                            }
                        } else {
                            var folderSize: UInt64 = 0
                            if let enumerator = fileManager.enumerator(at: childURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsPackageDescendants]) {
                                while let subFileURL = enumerator.nextObject() as? URL {
                                    if let fileSize = (try? subFileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                                        folderSize += UInt64(fileSize)
                                        newTotalSize += UInt64(fileSize)
                                        
                                        // サブファイルごとの細かいUI更新 (0.5秒ごと)
                                        let now = Date()
                                        if now.timeIntervalSince(lastUIUpdate) >= 0.5, let handler = progressHandler {
                                            lastUIUpdate = now
                                            let progress = Double(index) / Double(max(1, totalFiles))
                                            let currentSize = newTotalSize
                                            await handler(progress, currentSize)
                                        }
                                    }
                                }
                            }
                            
                            let matchedItems = await MainActor.run { [folderSize, childURL] in
                                let matchingItems = self.clipboardHistory.filter { $0.filePath?.lastPathComponent == childURL.lastPathComponent }
                                for item in matchingItems {
                                    item.fileSize = folderSize
                                    item.isPartialSize = false
                                    item.isSizeCalculated = true
                                }
                                return matchingItems
                            }
                            updatedItems.append(contentsOf: matchedItems)
                        }
                    } else {
                        if let fileSize = (try? childURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                            newTotalSize += UInt64(fileSize)
                        }
                    }
                }
                
                // アイテムごとのUI更新 (0.5秒ごと または 最後)
                let now = Date()
                if now.timeIntervalSince(lastUIUpdate) >= 0.5 || index == totalFiles - 1 {
                    if let handler = progressHandler {
                        lastUIUpdate = now
                        let progress = Double(index + 1) / Double(max(1, totalFiles))
                        let currentSize = newTotalSize
                        await handler(progress, currentSize)
                    }
                }
            }
            
            // ChunkedHistoryManager に保存
            do {
                let chunkCount = try await ChunkedHistoryManager.shared.getChunkCount()
                var remainingUpdates = Dictionary(uniqueKeysWithValues: updatedItems.map { ($0.id, $0) })
                
                for index in stride(from: chunkCount - 1, through: 0, by: -1) {
                    if remainingUpdates.isEmpty { break }
                    var chunkItems = try await ChunkedHistoryManager.shared.loadHistoryChunk(at: index)
                    var chunkModified = false
                    
                    for i in 0..<chunkItems.count {
                        if let updatedItem = remainingUpdates[chunkItems[i].id] {
                            chunkItems[i] = updatedItem
                            chunkModified = true
                            remainingUpdates.removeValue(forKey: chunkItems[i].id)
                        }
                    }
                    
                    if chunkModified {
                        try await ChunkedHistoryManager.shared.saveChunk(chunkItems, at: index)
                    }
                }
            } catch {
                print("Error bulk updating history chunks: \(error.localizedDescription)")
            }
            
        } catch {
            print("Error recalculating folder sizes: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            self.objectWillChange.send()
        }
        
        return newTotalSize
    }
}
