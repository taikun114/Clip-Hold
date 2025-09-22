import AppKit
import SwiftUI

class ClipHoldStandardWindowController: NSWindowController, NSWindowDelegate {
    
    // MARK: - Properties
    private static var existingWindowController: ClipHoldStandardWindowController?
    
    // MARK: - Initializers
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // シングルトンパターンでウィンドウコントローラーを取得するメソッド
    static func shared<Content: View>(rootView: Content, title: String = "") -> ClipHoldStandardWindowController {
        // 既存のウィンドウコントローラーがあればそれを返す
        if let existing = existingWindowController {
            DispatchQueue.main.async {
                existing.window?.makeKeyAndOrderFront(nil)
                existing.window?.center() // ウィンドウを画面中央に配置
                // ウィンドウの位置とサイズをログに出力
                if let window = existing.window {
                    print("ClipHoldStandardWindowController: Reusing existing window. Frame: \(window.frame)")
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            print("ClipHoldStandardWindowController: Reusing existing window controller.")
            return existing
        }
        
        // 新しいウィンドウコントローラーを作成
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 310),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = title

        // コンテンツビューの設定
        let hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController
        
        // ウィンドウのサイズを明示的に設定
        window.setContentSize(NSSize(width: 400, height: 310))
        window.center() // ウィンドウを画面中央に配置
        
        let newController = ClipHoldStandardWindowController(window: window)
        newController.window?.delegate = newController
        
        // ウィンドウの位置とサイズをログに出力
        print("ClipHoldStandardWindowController: New window created. Frame: \(window.frame)")
        
        // 新しいインスタンスを保持
        existingWindowController = newController
        
        print("ClipHoldStandardWindowController: Initialized with title '\(title)'.")
        return newController
    }
    
    override func showWindow(_ sender: Any?) {
        // ウィンドウを画面中央に配置
        self.window?.center()
        // ウィンドウの位置とサイズをログに出力
        if let window = self.window {
            print("ClipHoldStandardWindowController: showWindow called. Frame: \(window.frame)")
        }
        super.showWindow(sender)
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        // ウィンドウが閉じられるときにコントローラーを解放する
        self.window?.contentViewController = nil
        ClipHoldStandardWindowController.existingWindowController = nil
        print("ClipHoldStandardWindowController: Window closed and controller released.")
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
