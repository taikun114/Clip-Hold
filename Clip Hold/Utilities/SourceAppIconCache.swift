import AppKit

/// コピー元アプリのアイコンと存在確認を再利用し、描画中のファイルアクセスを抑える
@MainActor
final class SourceAppIconCache {
    static let shared = SourceAppIconCache()

    private final class Entry {
        let image: NSImage?
        let expiresAt: TimeInterval

        init(image: NSImage?, expiresAt: TimeInterval) {
            self.image = image
            self.expiresAt = expiresAt
        }
    }

    private let entries = NSCache<NSString, Entry>()
    private let now: () -> TimeInterval
    private let loadImage: (String) -> NSImage?

    init(
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        loadImage: ((String) -> NSImage?)? = nil
    ) {
        self.now = now
        self.loadImage = loadImage ?? { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return NSWorkspace.shared.icon(forFile: path)
        }
        entries.countLimit = 128
    }

    func image(forApplicationAt path: String) -> NSImage? {
        let key = path as NSString
        let timestamp = now()
        if let entry = entries.object(forKey: key), timestamp < entry.expiresAt {
            return entry.image
        }
        let image = loadImage(path)
        // アプリの更新・削除を反映するため定期的に再取得し、見つからない場合は早めに再確認する
        let lifetime: TimeInterval = image == nil ? 5 : 60
        entries.setObject(Entry(image: image, expiresAt: timestamp + lifetime), forKey: key)
        return image
    }
}
