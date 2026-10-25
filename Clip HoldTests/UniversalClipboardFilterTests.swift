import AppKit
import Testing
@testable import Clip_Hold

struct UniversalClipboardFilterTests {
    @Test("設定がオフなら同期マーカーがあっても無視しない", arguments: [false, true])
    func disabledAllowsAllContent(hasMarker: Bool) {
        var types: [NSPasteboard.PasteboardType] = [.string]
        if hasMarker {
            types.append(NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
        }
        #expect(!UniversalClipboardFilter.shouldIgnore(types: types, isEnabled: false))
    }

    @Test("設定がオンならコンテンツ形式にかかわらず同期マーカーを無視する", arguments: [NSPasteboard.PasteboardType.string, .png, .fileURL])
    func enabledIgnoresRemoteContent(contentType: NSPasteboard.PasteboardType) {
        let types = [contentType, NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")]
        #expect(UniversalClipboardFilter.shouldIgnore(types: types, isEnabled: true))
    }

    @Test("同期マーカーのない通常のコピーは無視しない")
    func enabledAllowsLocalContent() {
        #expect(!UniversalClipboardFilter.shouldIgnore(types: [.string, .png], isEnabled: true))
        #expect(!UniversalClipboardFilter.shouldIgnore(types: [NSPasteboard.PasteboardType("com.apple.is-remote-clipboard-other")], isEnabled: true))
    }

    @Test("型情報が空または取得できない場合は同期コンテンツと判定しない")
    func missingTypesAreNotRemote() {
        #expect(!UniversalClipboardFilter.shouldIgnore(types: nil, isEnabled: true))
        #expect(!UniversalClipboardFilter.shouldIgnore(types: [], isEnabled: true))
    }
}
