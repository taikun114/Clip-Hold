import AppKit
import SwiftUI
import Quartz

class ClipHoldWindowController: NSWindowController, NSWindowDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    private let maxContentWidth: CGFloat = 900
    private let minContentWidth: CGFloat = 300
    private let minContentHeight: CGFloat = 300
    private let maxContentHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? .infinity

    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    var applyTransparentBackground: Bool = true

    var windowFrameAutosaveKey: String?
    var onWindowWillClose: (() -> Void)?

    // MARK: - Quick Look Properties
    private var quickLookItem: QLPreviewItem?
    private weak var quickLookSourceView: NSView?

    // MARK: - Initializers
    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    convenience init(wrappingWindow: NSWindow, applyTransparentBackground: Bool = true, windowFrameAutosaveKey: String? = nil) {
        self.init(window: wrappingWindow)
        self.window?.delegate = self
        self.applyTransparentBackground = applyTransparentBackground
        self.windowFrameAutosaveKey = windowFrameAutosaveKey
        print("ClipHoldWindowController: Initialized with window \(wrappingWindow.identifier?.rawValue ?? "unknown").")
        
        // ウィンドウのカスタマイズを適用
        applyWindowCustomizations(window: wrappingWindow)

        if let key = self.windowFrameAutosaveKey {
            loadSavedFrame(for: key, to: wrappingWindow)
        }
    }

    // MARK: - Public Quick Look Methods
    func showQuickLook(for item: QLPreviewItem, from sourceView: NSView) {
        self.quickLookItem = item
        self.quickLookSourceView = sourceView

        if let panel = QLPreviewPanel.shared() {
            if panel.dataSource === self {
                panel.reloadData()
            }
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func hideQuickLook() {
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        }
    }

    // MARK: - NSWindowDelegate
    func windowDidUpdate(_ notification: Notification) {
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            print("ClipHoldWindowController: Window will close: \(window.identifier?.rawValue ?? "unknown").")
            if let key = self.windowFrameAutosaveKey {
                saveCurrentFrame(of: window, for: key)
            }
            onWindowWillClose?()
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
    
    // MARK: - QLPreviewPanelController (from NSResponder)
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
        self.quickLookItem = nil
        self.quickLookSourceView = nil
    }

    // MARK: - QLPreviewPanelDataSource
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return self.quickLookItem == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return self.quickLookItem
    }

    // MARK: - QLPreviewPanelDelegate
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor previewItem: QLPreviewItem!) -> NSRect {
        // アニメーションの開始位置を返す
        guard let sourceView = self.quickLookSourceView, let window = sourceView.window else {
            return .zero
        }
        let screenFrame = sourceView.convert(sourceView.bounds, to: nil)
        return window.convertToScreen(screenFrame)
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
        
        if applyTransparentBackground {
            window.isOpaque = false
            window.backgroundColor = .clear

            // SwiftUIコンテンツの背景レイヤーもクリアに設定 (念のため)
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.clear.cgColor
                print("ClipHoldWindowController: Set contentView layer backgroundColor to clear.")
            }
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            print("ClipHoldWindowController: Set window and contentView background to opaque.")
        }
    }
    private func saveCurrentFrame(of window: NSWindow, for key: String) {
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: key)
        print("ClipHoldWindowController: Saved frame for key '\(key)': \(frameString)")
    }

    private func loadSavedFrame(for key: String, to window: NSWindow) {
        if let frameString = UserDefaults.standard.string(forKey: key) {
            let savedFrame = NSRectFromString(frameString)
            // 画面範囲内に収まっているか確認し、必要に応じて調整
            if let screen = NSScreen.main { // または window.screen
                let visibleRect = screen.visibleFrame
                let adjustedOriginX = max(visibleRect.minX, min(savedFrame.minX, visibleRect.maxX - savedFrame.width))
                let adjustedOriginY = max(visibleRect.minY, min(savedFrame.minY, visibleRect.maxY - savedFrame.height))
                let adjustedFrame = NSRect(x: adjustedOriginX, y: adjustedOriginY, width: savedFrame.width, height: savedFrame.height)
                
                window.setFrame(adjustedFrame, display: true)
                print("ClipHoldWindowController: Loaded and applied saved frame for key '\(key)': \(frameString) -> \(NSStringFromRect(adjustedFrame))")
            } else {
                // スクリーン情報が取得できない場合はそのまま適用
                window.setFrame(savedFrame, display: true)
                print("ClipHoldWindowController: Loaded and applied saved frame (no screen check) for key '\(key)': \(frameString)")
            }
        } else {
            print("ClipHoldWindowController: No saved frame found for key '\(key)'.")
            // 保存されたフレームがない場合は、デフォルトで中央に配置
            window.center() // 初回起動時や保存データがない場合に中央に表示
        }
    }
}
