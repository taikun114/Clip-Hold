import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    
    convenience init() {
        let settingsView = SettingsView()
            .environmentObject(ClipboardManager.shared)
            .environmentObject(StandardPhraseManager.shared)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: settingsView)
        window.title = "設定"
        
        self.init(window: window)
        
        // ウィンドウデリゲートの設定
        window.delegate = self
        
        // ウィンドウの位置とサイズをUserDefaultsから復元
        loadWindowFrame()
        
        // ウィンドウが閉じられるときに位置とサイズをUserDefaultsに保存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    // ウィンドウの位置とサイズをUserDefaultsから復元
    private func loadWindowFrame() {
        let autosaveKey = "SettingsWindowFrame"
        if let frameString = UserDefaults.standard.string(forKey: autosaveKey),
           let screen = NSScreen.main {
            let savedFrame = NSRectFromString(frameString)
            let visibleRect = screen.visibleFrame
            let adjustedOriginX = max(visibleRect.minX, min(savedFrame.minX, visibleRect.maxX - savedFrame.width))
            let adjustedOriginY = max(visibleRect.minY, min(savedFrame.minY, visibleRect.maxY - savedFrame.height))
            let adjustedFrame = NSRect(x: adjustedOriginX, y: adjustedOriginY, width: savedFrame.width, height: savedFrame.height)
            
            window?.setFrame(adjustedFrame, display: true)
            print("SettingsWindowController: Loaded and applied saved frame for key '\(autosaveKey)': \(frameString) -> \(NSStringFromRect(adjustedFrame))")
        } else {
            print("SettingsWindowController: No saved frame found for key 'SettingsWindowFrame'.")
            // 保存されたフレームがない場合は、デフォルトで中央に配置
            window?.center()
        }
    }
    
    // ウィンドウが閉じられるときに位置とサイズをUserDefaultsに保存
    @objc func windowWillClose(_ notification: Notification) {
        let autosaveKey = "SettingsWindowFrame"
        if let window = self.window {
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: autosaveKey)
            print("SettingsWindowController: Saved frame for key '\(autosaveKey)': \(frameString)")
        }
        // 通知の監視を解除
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: self.window)
    }
    
    // NSWindowDelegate method to handle window closing
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // ウィンドウを閉じたときにコントローラーの参照を解放する
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.settingsWindowController = nil
        }
        return true
    }
}