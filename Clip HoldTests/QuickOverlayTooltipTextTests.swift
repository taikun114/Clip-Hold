import AppKit
import CoreText
import Testing
@testable import Clip_Hold

struct QuickOverlayTooltipTextTests {
    private func request(text: String, width: CGFloat = 468, language: String? = nil, invisible: Bool = false, dark: Bool = false) -> QuickOverlayTooltipTextRequest {
        QuickOverlayTooltipTextRequest(text: text, language: language, isCode: language != nil, width: width, fontSize: 13, isDark: dark, showsInvisibleCharacters: invisible)
    }

    @Test("長い日本語段落を末尾まで組版できる")
    func longParagraph() async throws {
        let text = String(repeating: "これは動作確認用の架空の文章です。改行のない段落を折り返します。", count: 220).truncate(maxLength: 5000)
        let layout = try await QuickOverlayTooltipTextRenderer().prepare(request(text: text))
        #expect(layout.text == text)
        #expect(CTFrameGetVisibleStringRange(layout.frame).length == text.utf16.count)
        #expect(layout.size.height > 400)
    }

    @Test("表示幅に応じて高さが変わり、改行や絵文字を欠落させない")
    func widthAndUnicode() async throws {
        let text = String(repeating: "架空のサンプル 👨‍👩‍👧‍👦 café\nSecond fictional line.\n", count: 40)
        let renderer = QuickOverlayTooltipTextRenderer()
        let wide = try await renderer.prepare(request(text: text, width: 468))
        let narrow = try await renderer.prepare(request(text: text, width: 100))
        #expect(narrow.size.height > wide.size.height)
        #expect(CTFrameGetVisibleStringRange(narrow.frame).length == text.utf16.count)
    }

    @Test("不可視文字を記号に変換して改行を保持する")
    func invisibleCharacters() async throws {
        let layout = try await QuickOverlayTooltipTextRenderer().prepare(request(text: "a b\t\n次の行", invisible: true))
        #expect(layout.text == "a␣\u{200B}b⇥\u{200B}↵\n次の行")
    }

    @Test("コードの色付け後もライト・ダークの両方で本文全体を保持する")
    func highlightedCode() async throws {
        let text = "func sample() -> Int {\n    return 42\n}"
        let renderer = QuickOverlayTooltipTextRenderer()
        for dark in [false, true] {
            let layout = try await renderer.prepare(request(text: text, language: "swift", dark: dark))
            #expect(layout.text == text)
            #expect(CTFrameGetVisibleStringRange(layout.frame).length == text.utf16.count)
            let lines = CTFrameGetLines(layout.frame) as! [CTLine]
            #expect(lines.contains { CFArrayGetCount(CTLineGetGlyphRuns($0)) > 1 })
        }
    }

    @Test("空の本文でも有効な表示領域を持つ")
    func emptyText() async throws {
        let layout = try await QuickOverlayTooltipTextRenderer().prepare(request(text: ""))
        #expect(layout.size.height > 0)
        #expect(layout.text.isEmpty)
    }

    @Test("キャッシュは本文、表示幅、テーマ、装飾の組み合わせを区別する")
    @MainActor
    func cachedLayout() async throws {
        let cache = QuickOverlayTooltipTextCache()
        let original = request(text: "架空のキャッシュ確認用テキスト")
        let layout = try await QuickOverlayTooltipTextRenderer().prepare(original)
        cache.insert(layout, for: original)
        #expect(cache.layout(for: original) === layout)
        #expect(cache.layout(for: request(text: original.text, width: 100)) == nil)
        #expect(cache.layout(for: request(text: original.text, invisible: true)) == nil)
        #expect(cache.layout(for: request(text: original.text, dark: true)) == nil)
        #expect(cache.layout(for: request(text: "別の架空の項目")) == nil)
    }
    @Test("初回は未準備で、読み込み完了後は再表示でも組版を再利用する")
    @MainActor
    func loadingAndReuse() async {
        let cache = QuickOverlayTooltipTextCache()
        let key = request(text: "架空の読み込み確認用テキスト")
        let first = QuickOverlayTooltipTextModel(request: key, cache: cache)
        #expect(first.layout == nil)
        await first.load()
        #expect(first.layout != nil)
        let second = QuickOverlayTooltipTextModel(request: key, cache: cache)
        #expect(second.layout === first.layout)
    }

    @Test("キャンセルした読み込みは本文を公開せずキャッシュにも追加しない")
    @MainActor
    func cancelledLoading() async {
        let cache = QuickOverlayTooltipTextCache()
        let key = request(text: "架空のキャンセル確認用テキスト")
        let model = QuickOverlayTooltipTextModel(request: key, cache: cache)
        let loading = Task { await model.load() }
        loading.cancel()
        await loading.value
        #expect(model.layout == nil)
        #expect(cache.layout(for: key) == nil)
    }

}
