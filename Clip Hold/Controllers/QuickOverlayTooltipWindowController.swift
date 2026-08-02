import AppKit
import SwiftUI

class QuickOverlayTooltipWindowController: NSWindowController {
    
    static let shared = QuickOverlayTooltipWindowController()
    
    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 100), // Height is dynamic, width is 500 content + 120 padding
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(showTooltip(_:)), name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideTooltip), name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideTooltip), name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func showTooltip(_ notification: Notification) {
        guard let window = self.window,
              let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String else { return }
        
        // Setup view
        let view = QuickOverlayTooltipView(text: text)
        let hostingView = NSHostingView(rootView: view)
        
        // Calculate height based on text. For simplicity, we can let NSHostingView size it,
        // but we need to set the window frame. NSHostingView's fittingSize can help.
        let targetWidth: CGFloat = 620
        hostingView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: 1000)
        let fittingSize = hostingView.fittingSize
        let finalHeight = fittingSize.height
        
        window.contentView = hostingView
        
        positionWindow(height: finalHeight)
        
        window.orderFront(nil)
    }
    
    @objc private func hideTooltip() {
        window?.orderOut(nil)
    }
    
    private func positionWindow(height: CGFloat) {
        guard let window = self.window else { return }
        
        // Get the overlay position setting
        let position = UserDefaults.standard.quickOverlayPosition
        
        // Get overlay window bounds directly from QuickOverlayWindowController
        guard let overlayWindow = QuickOverlayWindowController.shared.window else { return }
        
        // Overlay window is 620x620. The visual part is 500x500 padded by 60.
        // So the visual left edge is overlayWindow.frame.minX + 60.
        let overlayFrame = overlayWindow.frame
        let visualMinX = overlayFrame.minX + 60
        let visualMinY = overlayFrame.minY + 60
        let visualMaxY = overlayFrame.maxY - 60
        
        var newOrigin = NSPoint(x: visualMinX - 60, y: 0) // -60 for shadow padding of tooltip
        
        let gap: CGFloat = 12 // 隙間を開ける
        
        // Determine whether to place tooltip above or below the overlay
        // If overlay is at the bottom, place above.
        let isBottomPosition = ["bottom", "bottomLeft", "bottomRight"].contains(position)
        
        if isBottomPosition {
            // Place ABOVE the overlay
            // Tooltip visual bottom = overlay visual top + gap
            newOrigin.y = visualMaxY + gap - 60
        } else {
            // Place BELOW the overlay
            // Tooltip visual top = overlay visual bottom - gap
            newOrigin.y = visualMinY - gap + 60 - height
        }
        
        window.setFrame(NSRect(x: newOrigin.x, y: newOrigin.y, width: 620, height: height), display: true)
    }
}
