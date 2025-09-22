import AppKit
import SwiftUI

// ウィンドウの種類を識別するための列挙型
enum WindowType: String, CaseIterable {
    case addPhrase = "AddPhrase"
    case addPreset = "AddPreset"
    case editHistory = "EditHistory"
}

class ClipHoldStandardWindowController: NSWindowController, NSWindowDelegate {
    
    // ウィンドウの種類
    private var windowType: WindowType
    
    // MARK: - Initializers
    override init(window: NSWindow?) {
        self.windowType = .addPhrase // デフォルト値
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        self.windowType = .addPhrase // デフォルト値
        super.init(coder: coder)
    }
    
    convenience init<Content: View>(rootView: Content, title: String = "", windowType: WindowType) {
        // 新しいウィンドウを作成
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
        
        self.init(window: window)
        self.windowType = windowType
        self.window?.delegate = self
        
        // ウィンドウの位置とサイズをログに出力
        print("ClipHoldStandardWindowController: New window created. Frame: \(window.frame), Type: \(windowType)")
        
        print("ClipHoldStandardWindowController: Initialized with title '\(title)', Type: \(windowType)")
    }
    
    func showWindowAndCenter(_ center: Bool = true) {
        if center {
            // ウィンドウを画面中央に配置
            self.window?.center()
        }
        // ウィンドウを最前面に表示
        self.window?.makeKeyAndOrderFront(nil)
        // ウィンドウの位置とサイズをログに出力
        if let window = self.window {
            print("ClipHoldStandardWindowController: showWindow called. Frame: \(window.frame), Type: \(windowType), Center: \(center)")
        }
        super.showWindow(nil)
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        // ウィンドウが閉じられるときにコントローラーを解放する
        self.window?.contentViewController = nil
        print("ClipHoldStandardWindowController: Window closed and controller released. Type: \(windowType)")
        
        // AppDelegateのwindowWillCloseメソッドを呼び出す
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.windowWillClose(notification)
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}
