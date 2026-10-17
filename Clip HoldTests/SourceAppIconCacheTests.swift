import AppKit
import Testing
@testable import Clip_Hold

@MainActor
struct SourceAppIconCacheTests {
    @Test("同じコピー元アプリは行を繰り返し表示しても一度だけ取得する")
    func testRepeatedRowsReuseIcon() {
        var loads = 0
        let icon = NSImage(size: NSSize(width: 32, height: 32))
        let cache = SourceAppIconCache(now: { 0 }, loadImage: { _ in
            loads += 1
            return icon
        })
        for _ in 0..<1000 {
            #expect(cache.image(forApplicationAt: "/Applications/Sample.app") === icon)
        }
        #expect(loads == 1)
    }

    @Test("異なるコピー元アプリのアイコンを混同しない")
    func testSeparateApplications() {
        let first = NSImage(size: NSSize(width: 32, height: 32))
        let second = NSImage(size: NSSize(width: 32, height: 32))
        let cache = SourceAppIconCache(now: { 0 }, loadImage: { path in
            path == "/Applications/First.app" ? first : second
        })
        #expect(cache.image(forApplicationAt: "/Applications/First.app") === first)
        #expect(cache.image(forApplicationAt: "/Applications/Second.app") === second)
    }

    @Test("アプリの更新や削除を有効期限後に反映する")
    func testExpiredIconRefreshes() {
        var time: TimeInterval = 0
        var image: NSImage? = NSImage(size: NSSize(width: 32, height: 32))
        let cache = SourceAppIconCache(now: { time }, loadImage: { _ in image })
        #expect(cache.image(forApplicationAt: "/Applications/Sample.app") != nil)
        time = 60
        image = NSImage(size: NSSize(width: 64, height: 64))
        #expect(cache.image(forApplicationAt: "/Applications/Sample.app") === image)
        time = 120
        image = nil
        #expect(cache.image(forApplicationAt: "/Applications/Sample.app") == nil)
    }

    @Test("見つからないアプリの確認を繰り返さず、再出現を後から反映する")
    func testMissingApplicationRecovers() {
        var time: TimeInterval = 0
        var loads = 0
        var image: NSImage?
        let cache = SourceAppIconCache(now: { time }, loadImage: { _ in
            loads += 1
            return image
        })
        for _ in 0..<100 {
            #expect(cache.image(forApplicationAt: "/Applications/Sample.app") == nil)
        }
        #expect(loads == 1)
        image = NSImage(size: NSSize(width: 32, height: 32))
        time = 5
        #expect(cache.image(forApplicationAt: "/Applications/Sample.app") === image)
        #expect(loads == 2)
    }
}
