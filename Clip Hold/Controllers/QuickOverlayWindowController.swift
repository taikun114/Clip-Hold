import AppKit
import SwiftUI

class ActivePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

class QuickOverlayWindowController: NSWindowController {
    
    static let shared = QuickOverlayWindowController()
    
    private var isObserving = false
    
    private init() {
        // Creates a transparent, borderless panel
        let panel = ActivePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating // Stay on top
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        super.init(window: panel)
        
        NotificationCenter.default.addObserver(self, selector: #selector(showOverlay), name: NSNotification.Name("QuickOverlayShouldShow"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideOverlay), name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func showOverlay() {
        guard let window = self.window, let type = QuickOverlayManager.shared.currentOverlayType else { return }
        
        // Load the view
        let view = QuickOverlayView(type: type)
            .environmentObject(ClipboardManager.shared)
            .environmentObject(StandardPhraseManager.shared)
            .environmentObject(StandardPhrasePresetManager.shared)
            .environmentObject(DateReloader.shared)
        
        window.contentView = NSHostingView(rootView: view)
        
        positionWindow()
        
        // Show window without taking app focus, but make panel key for active appearance
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc private func hideOverlay() {
        window?.orderOut(nil)
    }
    
    private func positionWindow() {
        guard let window = self.window, let screen = NSScreen.main else { return }
        
        let position = UserDefaults.standard.quickOverlayPosition
        let padding: CGFloat = 20
        
        let screenRect = screen.visibleFrame // Accounts for Dock and Menu Bar
        let windowSize = window.frame.size
        
        var newOrigin = NSPoint(x: 0, y: 0)
        
        switch position {
        case "top":
            newOrigin.x = screenRect.midX - (windowSize.width / 2)
            newOrigin.y = screenRect.maxY - windowSize.height - padding
        case "topRight":
            newOrigin.x = screenRect.maxX - windowSize.width - padding
            newOrigin.y = screenRect.maxY - windowSize.height - padding
        case "right":
            newOrigin.x = screenRect.maxX - windowSize.width - padding
            newOrigin.y = screenRect.midY - (windowSize.height / 2)
        case "bottomRight":
            newOrigin.x = screenRect.maxX - windowSize.width - padding
            newOrigin.y = screenRect.minY + padding
        case "bottom":
            newOrigin.x = screenRect.midX - (windowSize.width / 2)
            newOrigin.y = screenRect.minY + padding
        case "bottomLeft":
            newOrigin.x = screenRect.minX + padding
            newOrigin.y = screenRect.minY + padding
        case "left":
            newOrigin.x = screenRect.minX + padding
            newOrigin.y = screenRect.midY - (windowSize.height / 2)
        case "topLeft":
            newOrigin.x = screenRect.minX + padding
            newOrigin.y = screenRect.maxY - windowSize.height - padding
        default: // center
            newOrigin.x = screenRect.midX - (windowSize.width / 2)
            newOrigin.y = screenRect.midY - (windowSize.height / 2)
        }
        
        window.setFrameOrigin(newOrigin)
    }
}
