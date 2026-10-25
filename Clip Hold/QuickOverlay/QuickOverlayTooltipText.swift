import AppKit
import CoreText
import SwiftUI
import Highlighter

struct QuickOverlayTooltipTextRequest: Hashable, Sendable {
    let text: String
    let language: String?
    let isCode: Bool
    let width: CGFloat
    let fontSize: CGFloat
    let isDark: Bool
    let showsInvisibleCharacters: Bool
}

/// 組版後は変更せず、バックグラウンド処理の終了後に表示側へ渡す。
final class QuickOverlayTooltipTextLayout: @unchecked Sendable {
    let frame: CTFrame
    let size: CGSize
    let text: String

    init(frame: CTFrame, size: CGSize, text: String) {
        self.frame = frame
        self.size = size
        self.text = text
    }
}

actor QuickOverlayTooltipTextRenderer {
    static let shared = QuickOverlayTooltipTextRenderer()
    private var lightHighlighter: Highlighter?
    private var darkHighlighter: Highlighter?

    func prepare(_ request: QuickOverlayTooltipTextRequest) throws -> QuickOverlayTooltipTextLayout {
        try Task.checkCancellation()
        let started = ContinuousClock.now
        let font = !request.isCode
            ? NSFont.systemFont(ofSize: request.fontSize)
            : (NSFont(name: "Menlo", size: request.fontSize) ?? NSFont.monospacedSystemFont(ofSize: request.fontSize, weight: .regular))
        let foreground = request.isDark ? NSColor.white.withAlphaComponent(0.85) : NSColor.black.withAlphaComponent(0.85)
        let attributed: NSMutableAttributedString
        if request.showsInvisibleCharacters {
            attributed = NSMutableAttributedString(attributedString: NSAttributedString(request.text.formatWithInvisibleSymbols(singleLine: false)))
            attributed.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributed.length))
            attributed.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
                let color = value == nil ? foreground : foreground.withAlphaComponent(0.3)
                attributed.addAttribute(.foregroundColor, value: color, range: range)
            }
        } else if request.isCode,
                  let highlighted = highlighter(isDark: request.isDark, font: font)?.highlight(request.text, as: request.language) {
            attributed = NSMutableAttributedString(attributedString: highlighted)
            attributed.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: attributed.length))
        } else {
            attributed = NSMutableAttributedString(string: request.text, attributes: [.font: font, .foregroundColor: foreground])
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = []
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
        try Task.checkCancellation()
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let width = max(1, request.width)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil
        )
        let size = CGSize(width: width, height: max(ceil(measured.height) + 2, ceil(font.ascender - font.descender + font.leading)))
        let path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        try Task.checkCancellation()
#if DEBUG
        print("DEBUG: [ツールチップ計測] 本文組版完了: 文字数=\(request.text.count), 幅=\(width), 所要時間=\(started.duration(to: .now))")
#endif
        return QuickOverlayTooltipTextLayout(frame: frame, size: size, text: attributed.string)
    }

    private func highlighter(isDark: Bool, font: NSFont) -> Highlighter? {
        if isDark {
            if darkHighlighter == nil {
                darkHighlighter = Highlighter()
                _ = darkHighlighter?.setTheme("github-dark")
            }
            darkHighlighter?.theme?.setCodeFont(font)
            return darkHighlighter
        }
        if lightHighlighter == nil {
            lightHighlighter = Highlighter()
            _ = lightHighlighter?.setTheme("github")
        }
        lightHighlighter?.theme?.setCodeFont(font)
        return lightHighlighter
    }
}

@MainActor
final class QuickOverlayTooltipTextCache {
    static let shared = QuickOverlayTooltipTextCache()
    private final class Key: NSObject {
        let request: QuickOverlayTooltipTextRequest
        init(_ request: QuickOverlayTooltipTextRequest) { self.request = request }
        override var hash: Int { request.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? Key)?.request == request }
    }
    private let cache = NSCache<Key, QuickOverlayTooltipTextLayout>()

    init() {
        cache.countLimit = 32
        cache.totalCostLimit = 4 * 1024 * 1024
    }

    func layout(for request: QuickOverlayTooltipTextRequest) -> QuickOverlayTooltipTextLayout? {
        cache.object(forKey: Key(request))
    }

    func insert(_ layout: QuickOverlayTooltipTextLayout, for request: QuickOverlayTooltipTextRequest) {
        cache.setObject(layout, forKey: Key(request), cost: max(1, layout.text.utf16.count * 64))
    }
}

@MainActor
final class QuickOverlayTooltipTextModel: ObservableObject {
    let request: QuickOverlayTooltipTextRequest
    @Published private(set) var layout: QuickOverlayTooltipTextLayout?
    private let cache: QuickOverlayTooltipTextCache
    private let placeholderHeight: CGFloat

    var bodyHeight: CGFloat {
        max(placeholderHeight, layout?.size.height ?? 0)
    }

    init(request: QuickOverlayTooltipTextRequest, cache: QuickOverlayTooltipTextCache? = nil) {
        self.request = request
        let font = request.isCode
            ? (NSFont(name: "Menlo", size: request.fontSize) ?? NSFont.monospacedSystemFont(ofSize: request.fontSize, weight: .regular))
            : NSFont.systemFont(ofSize: request.fontSize)
        placeholderHeight = max(20, ceil(font.ascender - font.descender + font.leading) + 2)
        let resolvedCache = cache ?? .shared
        self.cache = resolvedCache
        layout = resolvedCache.layout(for: request)
    }

    func load() async {
        guard layout == nil else { return }
        do {
            let prepared = try await QuickOverlayTooltipTextRenderer.shared.prepare(request)
            try Task.checkCancellation()
            cache.insert(prepared, for: request)
            let animation: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? nil : .easeInOut(duration: 0.25)
            withAnimation(animation) {
                layout = prepared
            }
        } catch is CancellationError {
            return
        } catch {
            print("ツールチップの本文準備に失敗しました: \(error)")
        }
    }
}

struct QuickOverlayPreparedTooltipText: NSViewRepresentable {
    let layout: QuickOverlayTooltipTextLayout

    func makeNSView(context: Context) -> QuickOverlayTooltipDrawingView {
        let view = QuickOverlayTooltipDrawingView()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.staticText)
        return view
    }

    func updateNSView(_ nsView: QuickOverlayTooltipDrawingView, context: Context) {
        nsView.layout = layout
        nsView.setAccessibilityValue(layout.text)
        nsView.needsDisplay = true
    }
}

final class QuickOverlayTooltipDrawingView: NSView {
    var layout: QuickOverlayTooltipTextLayout?

    override func draw(_ dirtyRect: NSRect) {
        guard let layout, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(layout.frame, context)
        context.restoreGState()
    }
}

struct QuickOverlayTooltipAsyncText: View {
    @ObservedObject var model: QuickOverlayTooltipTextModel
    let visibleHeight: CGFloat

    var body: some View {
        ZStack {
            if let layout = model.layout {
                QuickOverlayTooltipScrollingText(layout: layout, visibleHeight: visibleHeight)
                    .transition(.opacity)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: visibleHeight, alignment: .top)
        .clipped()
        .task {
            await model.load()
        }
    }
}

private struct QuickOverlayTooltipScrollingText: View {
    let layout: QuickOverlayTooltipTextLayout
    let visibleHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    var body: some View {
        QuickOverlayPreparedTooltipText(layout: layout)
            .frame(width: layout.size.width, height: layout.size.height)
            .offset(y: offset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: visibleHeight, alignment: .top)
            .clipped()
            .task(id: visibleHeight) {
                offset = 0
                guard !reduceMotion else { return }
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch { return }
                let distance = max(0, layout.size.height - visibleHeight)
                guard distance > 0, !Task.isCancelled else { return }
                withAnimation(.linear(duration: Double(distance) / 30).delay(1.5).repeatForever(autoreverses: true)) {
                    offset = -distance
                }
            }
    }
}

struct QuickOverlayTooltipSizedContent<Content: View>: View {
    @ObservedObject var model: QuickOverlayTooltipTextModel
    let maximumHeight: CGFloat
    let chromeHeight: CGFloat
    let alignment: Alignment
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        let height = max(50, min(maximumHeight, chromeHeight + model.bodyHeight))
        content(height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}
