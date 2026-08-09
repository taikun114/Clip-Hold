import AppKit
import SwiftUI

class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class LargeFileAlertWindowController: NSWindowController {
    static let shared = LargeFileAlertWindowController()
    
    private init() {
        // Create an invisible, borderless window
        let panel = FocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // Shadow is handled by SwiftUI view
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true // Allow user to drag it
        panel.animationBehavior = .alertPanel
        
        // Center it
        panel.center()
        
        super.init(window: panel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showAlert(title: String, message: String, onSave: @escaping @MainActor () -> Void, onCancel: @escaping @MainActor () -> Void) {
        Task { @MainActor [weak self] in
            guard let self = self, let window = self.window else { return }
            
            let alertView = LargeFileAlertView(
                title: title,
                message: message,
                onSave: {
                    self.closeWindow()
                    onSave()
                },
                onCancel: {
                    self.closeWindow()
                    onCancel()
                }
            )
            
            let hostingController = NSHostingController(rootView: alertView)
            // Ensure background remains transparent
            hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
            hostingController.view.wantsLayer = true
            
            window.contentViewController = hostingController
            
            // Yield to allow SwiftUI layout to complete
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            window.center()
            
            NSApp.activate(ignoringOtherApps: true)
            self.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func closeWindow() {
        self.close()
    }
}
