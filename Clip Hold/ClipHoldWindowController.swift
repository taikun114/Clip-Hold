import AppKit
import SwiftUI

class ClipHoldWindowController: NSWindowController, NSWindowDelegate {

    private let maxContentWidth: CGFloat = 900
    private let minContentWidth: CGFloat = 300
    private let minContentHeight: CGFloat = 300
    private let maxContentHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? .infinity

    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    // MARK: - Initializers
    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    convenience init(wrappingWindow: NSWindow) {
        self.init(window: wrappingWindow)
        self.window?.delegate = self
        print("ClipHoldWindowController: Initialized with window \(wrappingWindow.identifier?.rawValue ?? "unknown").")
        
        applyWindowCustomizations(window: wrappingWindow)
    }

    // MARK: - NSWindowDelegate
    func windowDidUpdate(_ notification: Notification) {
        if notification.object is NSWindow {
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            print("ClipHoldWindowController: Window will close: \(window.identifier?.rawValue ?? "unknown").")
        } else {
            print("ClipHoldWindowController: Window will close (object unknown).")
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    // MARK: - ウィンドウのダブルクリック挙動を制御するデリゲートメソッド (タイトルバーなど)
    func windowShouldCloseOnDoubleClick(_ sender: NSWindow) -> Bool {
        // AppStorage の値に基づいて、ウィンドウを閉じるかどうかを決定
        return !preventWindowCloseOnDoubleClick
    }

    // MARK: - ウィンドウのカスタマイズ適用
    func applyWindowCustomizations(window: NSWindow) {
        // ウィンドウの背景を透明にする
        window.isOpaque = false
        window.backgroundColor = .clear

        // タイトルバーの非表示と、内容領域の拡張
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)

        // ドロップシャドウを有効にする (必要に応じて)
        window.hasShadow = true
        
        // SwiftUIコンテンツの背景レイヤーもクリアに設定 (念のため)
        if let contentView = window.contentView {
            contentView.wantsLayer = true // レイヤーを使うことを宣言
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            print("ClipHoldWindowController: Set contentView layer backgroundColor to clear.")
        }

    }
}
