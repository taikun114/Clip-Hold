import AppKit
import SwiftUI

class UnconstrainedPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

class QuickOverlayTooltipWindowController: NSWindowController {
    
    static let shared = QuickOverlayTooltipWindowController()

    private enum TooltipDirection {
        case above, below, left, right
    }

    private var tooltipDirection: TooltipDirection = .below
    
    private init() {
        let panel = UnconstrainedPanel(
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
        panel.animationBehavior = .none
        
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
        
        let sourceAppPath = userInfo["sourceAppPath"] as? String
        positionWindow(text: text, sourceAppPath: sourceAppPath)
        
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.removeAllAnimations()
        
        // ツールチップが現れる方向へ少しスライドしながら表示する
        window.alphaValue = 0
        let slideDistance: CGFloat = 12
        let initialTransform: CATransform3D
        switch tooltipDirection {
        case .above: initialTransform = CATransform3DMakeTranslation(0, -slideDistance, 0)
        case .below: initialTransform = CATransform3DMakeTranslation(0, slideDistance, 0)
        case .left: initialTransform = CATransform3DMakeTranslation(slideDistance, 0, 0)
        case .right: initialTransform = CATransform3DMakeTranslation(-slideDistance, 0, 0)
        }
        contentView.layer?.transform = initialTransform
        window.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        
        let slideAnim = CABasicAnimation(keyPath: "transform")
        slideAnim.fromValue = initialTransform
        slideAnim.toValue = CATransform3DIdentity
        slideAnim.duration = 0.15
        slideAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        contentView.layer?.add(slideAnim, forKey: "showSlide")
        contentView.layer?.transform = CATransform3DIdentity
    }
    
    @objc private func hideTooltip() {
        guard let window = self.window, let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
            contentView.layer?.removeAllAnimations()
            contentView.layer?.transform = CATransform3DIdentity
        })
        
    }
    
    private func positionWindow(text: String, sourceAppPath: String?) {
        guard let window = self.window else { return }
        
        guard let overlayWindow = QuickOverlayWindowController.shared.window,
              let screen = overlayWindow.screen ?? NSScreen.main else { return }
              
        let screenRect = screen.visibleFrame
        let overlayFrame = overlayWindow.frame
        
        // Overlay visual bounds (620x620 with 60 padding)
        let visualMinX = overlayFrame.minX + 60
        let visualMinY = overlayFrame.minY + 60
        let visualMaxX = overlayFrame.maxX - 60
        let visualMaxY = overlayFrame.maxY - 60
        
        let gap: CGFloat = 12
        
        let spaceAbove = screenRect.maxY - visualMaxY - gap
        let spaceBelow = visualMinY - screenRect.minY - gap
        let spaceLeft = visualMinX - screenRect.minX - gap
        let spaceRight = screenRect.maxX - visualMaxX - gap
        
        // Measure natural text height reliably using NSString to avoid NSHostingView bugs
        let textWidth: CGFloat = 468 // 620 (window) - 120 (shadow padding) - 32 (text padding)
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let textRect = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // Add 32 for padding (16 top, 16 bottom).
        // Since we now use .fixedSize in the view, it will never truncate with '...', so we don't need a buffer.
        let headerHeight: CGFloat = sourceAppPath == nil ? 0 : 28
        let headerSpacing: CGFloat = 0
        let naturalVisualHeight = ceil(textRect.height) + 32 + headerHeight + headerSpacing
        
        // Cap max visual height at 500 (same as overlay)
        let targetVisualHeight = min(naturalVisualHeight, 500)
        
        let position = UserDefaults.standard.quickOverlayPosition
        let preferAbove = ["bottom", "bottomLeft", "bottomRight"].contains(position)
        
        enum Direction { case above, below, left, right }
        var chosenDirection: Direction = preferAbove ? .above : .below
        var finalVisualHeight = targetVisualHeight
        
        // Try preferred vertical
        if chosenDirection == .above && spaceAbove < targetVisualHeight {
            if spaceBelow >= targetVisualHeight { chosenDirection = .below }
        } else if chosenDirection == .below && spaceBelow < targetVisualHeight {
            if spaceAbove >= targetVisualHeight { chosenDirection = .above }
        }
        
        // If still doesn't fit, check horizontal
        if (chosenDirection == .above && spaceAbove < targetVisualHeight) || (chosenDirection == .below && spaceBelow < targetVisualHeight) {
            let neededWidth: CGFloat = 500
            if spaceRight >= neededWidth {
                chosenDirection = .right
            } else if spaceLeft >= neededWidth {
                chosenDirection = .left
            } else {
                // Nowhere fits well, just pick vertical with most space
                chosenDirection = spaceAbove > spaceBelow ? .above : .below
                finalVisualHeight = max(spaceAbove, spaceBelow)
            }
        }
        
        // Now compute actual bounds
        var newOrigin = NSPoint.zero
        switch chosenDirection {
        case .above:
            newOrigin.x = visualMinX - 60
            finalVisualHeight = min(finalVisualHeight, spaceAbove)
            newOrigin.y = visualMaxY + gap - 60
        case .below:
            newOrigin.x = visualMinX - 60
            finalVisualHeight = min(finalVisualHeight, spaceBelow)
            newOrigin.y = visualMinY - gap - finalVisualHeight - 60
        case .left:
            newOrigin.x = visualMinX - gap - 500 - 60
            finalVisualHeight = min(finalVisualHeight, screenRect.maxY - visualMinY)
            // Align bottom with overlay bottom
            newOrigin.y = visualMinY - 60
        case .right:
            newOrigin.x = visualMaxX + gap - 60
            finalVisualHeight = min(finalVisualHeight, screenRect.maxY - visualMinY)
            // Align bottom with overlay bottom
            newOrigin.y = visualMinY - 60
        }

        tooltipDirection = switch chosenDirection {
        case .above: .above
        case .below: .below
        case .left: .left
        case .right: .right
        }
        
        // Ensure minimum height
        finalVisualHeight = max(finalVisualHeight, 50)
        
        let finalWindowHeight = finalVisualHeight + 120
        
        let finalView = QuickOverlayTooltipView(text: text, maxVisualHeight: finalVisualHeight, sourceAppPath: sourceAppPath)
        let finalHosting = NSHostingView(rootView: finalView)
        window.contentView = finalHosting
        
        window.setFrame(NSRect(x: newOrigin.x, y: newOrigin.y, width: 620, height: finalWindowHeight), display: true)
    }
}
