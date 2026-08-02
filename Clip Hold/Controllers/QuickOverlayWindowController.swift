import AppKit
import SwiftUI

class ActivePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    // macOSがウィンドウを画面内に強制的に収めようとする（押し下げる）挙動を無効化する
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
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
        guard let window = self.window else { return }
        
        // マウスカーソルが存在するディスプレイを取得する（見つからない場合は現在のメインディスプレイ）
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let screen = screen else { return }
        
        let position = UserDefaults.standard.quickOverlayPosition
        let visualPadding: CGFloat = 16
        let padding: CGFloat = visualPadding - 60
        
        let screenRect = screen.visibleFrame // Accounts for Dock and Menu Bar
        let windowSize = window.frame.size
        
        var newOrigin = NSPoint(x: 0, y: 0)
        
        switch position {
        case "cursor":
            let visualWidth = windowSize.width - 120
            let visualHeight = windowSize.height - 120
            
            // 視覚的な左端をカーソル位置に（右に余裕がなければ右端をカーソル位置に）
            var x = mouseLocation.x - 60
            if screenRect.maxX - mouseLocation.x < visualWidth + visualPadding {
                x = mouseLocation.x - windowSize.width + 60
            }
            
            // X方向の画面端の余白を保証する
            let visualMinX = x + 60
            if visualMinX < screenRect.minX + visualPadding {
                x = screenRect.minX + visualPadding - 60
            }
            let visualMaxX = x + 60 + visualWidth
            if visualMaxX > screenRect.maxX - visualPadding {
                x = screenRect.maxX - visualPadding - visualWidth - 60
            }
            
            // 視覚的な上端をカーソル位置に
            var y = mouseLocation.y - windowSize.height + 60
            
            // 下に余裕がなければ上にずらす
            let visualMinY = y + 60
            if visualMinY < screenRect.minY + visualPadding {
                y = screenRect.minY + visualPadding - 60
            }
            
            // 万が一上にはみ出す場合は下にずらす
            let visualMaxY = y + 60 + visualHeight
            if visualMaxY > screenRect.maxY - visualPadding {
                y = screenRect.maxY - visualPadding - visualHeight - 60
            }
            
            newOrigin.x = x
            newOrigin.y = y
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
