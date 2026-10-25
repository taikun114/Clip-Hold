import AppKit

enum UniversalClipboardFilter {
    static func shouldIgnore(types: [NSPasteboard.PasteboardType]?, isEnabled: Bool) -> Bool {
        isEnabled && types?.contains(NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")) == true
    }
}
