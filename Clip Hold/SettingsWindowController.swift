import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var settingsWindow: NSWindow?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        
        let settingsView = SettingsView()
            .environmentObject(ClipboardManager.shared)
            .environmentObject(StandardPhraseManager.shared)
        
        window.contentView = NSHostingView(rootView: settingsView)
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        if let window = self.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        } else {
            self.window?.center()
            self.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // ウィンドウが閉じられたときにnilを設定するなど、必要に応じてクリーンアップ処理を行う
    }
}
