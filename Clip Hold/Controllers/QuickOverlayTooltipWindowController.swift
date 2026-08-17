import AppKit
import SwiftUI

class UnconstrainedPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
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
    private var currentTooltipIdentity: TooltipIdentity?
    
    private struct TooltipIdentity: Equatable {
        let text: String
        let sourceAppPath: String?
        let filePath: String?
        let dateString: String?
        let characterCount: Int?
        let isCompact: Bool
        let anchorPoint: CGPoint?
    }
    
    private init() {
        let panel = UnconstrainedPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 100), // Height is dynamic, width is 500 content + 120 padding
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .statusBar // オーバーレイ（.floating）の上に表示する
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        
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
        
        let rawText = (userInfo["rawText"] as? String) ?? text
        
        let sourceAppPath = userInfo["sourceAppPath"] as? String
        let filePath = userInfo["filePath"] as? String
        let fileSize = userInfo["fileSize"] as? UInt64
        let dateString = userInfo["dateString"] as? String
        let characterCount = userInfo["characterCount"] as? Int
        let isCompact = userInfo["isCompact"] as? Bool ?? false
        let buttonHeight = userInfo["buttonHeight"] as? CGFloat ?? 0
        
        // ボタン等の固定位置（スクリーン座標）に表示する場合はアンカーが指定される
        let anchorPoint: CGPoint?
        if let anchorX = userInfo["anchorX"] as? Double, let anchorY = userInfo["anchorY"] as? Double {
            anchorPoint = CGPoint(x: anchorX, y: anchorY)
        } else {
            anchorPoint = nil
        }
        
        let identity = TooltipIdentity(
            text: rawText,
            sourceAppPath: sourceAppPath,
            filePath: filePath,
            dateString: dateString,
            characterCount: characterCount,
            isCompact: isCompact,
            anchorPoint: anchorPoint
        )
        
        if window.isVisible && self.currentTooltipIdentity == identity {
            // 既に全く同じ内容・位置のツールチップが表示中の場合は再描画（マーキーリセット等）を防止する
            return
        }
        self.currentTooltipIdentity = identity
        
        positionWindow(text: text, sourceAppPath: sourceAppPath, filePath: filePath, fileSize: fileSize, dateString: dateString, characterCount: characterCount, anchorPoint: anchorPoint, isCompact: isCompact, buttonHeight: buttonHeight)
        
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
        
        self.currentTooltipIdentity = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.contentView = nil // 追加: ウインドウを隠した後にViewを破棄し、アニメーションループを完全に停止させる
            window.alphaValue = 1
            contentView.layer?.removeAllAnimations()
            contentView.layer?.transform = CATransform3DIdentity
        })
        
    }
    
    private func positionWindow(text: String, sourceAppPath: String?, filePath: String?, fileSize: UInt64?, dateString: String?, characterCount: Int?, anchorPoint: CGPoint?, isCompact: Bool = false, buttonHeight: CGFloat = 0) {
        guard let window = self.window else { return }
        
        guard let overlayWindow = QuickOverlayWindowController.shared.window,
              let screen = overlayWindow.screen ?? NSScreen.main else { return }
               
        let screenRect = screen.visibleFrame
        let overlayFrame = overlayWindow.frame
        
        let maxVisualWidth: CGFloat = 500
        let shadowPadding: CGFloat = isCompact ? 20 : 60
        let windowPadding: CGFloat = shadowPadding * 2
        let textPadding: CGFloat = 32 // テキストのパディング（上下16、左右16）
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        let gap: CGFloat = 12
        let safeMinX = screenRect.minX + gap
        let safeMaxX = screenRect.maxX - gap
        let safeMinY = screenRect.minY + gap
        let safeMaxY = screenRect.maxY - gap
        
        let initialVisualWidth: CGFloat
        if isCompact {
            // ボタンツールチップ等：内容に合わせて縮小する
            let naturalTextWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width) + textPadding
            initialVisualWidth = min(maxVisualWidth, naturalTextWidth)
        } else {
            initialVisualWidth = maxVisualWidth
        }
        
        enum Direction { case above, below, left, right }
        var newOrigin = NSPoint.zero
        var effectiveVisualWidth = initialVisualWidth
        var finalVisualHeight = maxVisualWidth
        
        if let anchor = anchorPoint {
            // ボタン等の固定位置（スクリーン座標）に表示する場合
            let effectiveMaxY = safeMaxY
            let effectiveMinY = safeMinY
            let spaceAbove = effectiveMaxY - anchor.y - gap
            let spaceBelow = anchor.y - buttonHeight - effectiveMinY - gap
            
            var chosenDirection: Direction
            if spaceAbove >= 100 {
                chosenDirection = .above
            } else if spaceBelow >= 100 {
                chosenDirection = .below
            } else {
                chosenDirection = spaceAbove > spaceBelow ? .above : .below
            }
            
            let windowWidth = initialVisualWidth + windowPadding
            switch chosenDirection {
            case .above:
                newOrigin.x = anchor.x - windowWidth / 2
                newOrigin.y = anchor.y + gap - shadowPadding
                finalVisualHeight = spaceAbove
            case .below:
                newOrigin.x = anchor.x - windowWidth / 2
                finalVisualHeight = spaceBelow
                newOrigin.y = anchor.y - buttonHeight - gap + shadowPadding - (finalVisualHeight + windowPadding)
            default:
                break
            }
            
            // 画面端からはみ出す場合はクランプする
            newOrigin.x = min(max(newOrigin.x, safeMinX - shadowPadding), safeMaxX - windowWidth + shadowPadding)
            newOrigin.y = min(max(newOrigin.y, safeMinY - shadowPadding), safeMaxY - finalVisualHeight - shadowPadding)
            
            tooltipDirection = chosenDirection == .above ? .above : .below
        } else {
            let visualMinX = overlayFrame.minX + 60
            let visualMinY = overlayFrame.minY + 60
            let visualMaxX = overlayFrame.maxX - 60
            let visualMaxY = overlayFrame.maxY - 60
            
            let spaceAbove = safeMaxY - visualMaxY - gap
            let spaceBelow = visualMinY - safeMinY - gap
            let spaceLeft = visualMinX - safeMinX - gap
            let spaceRight = safeMaxX - visualMaxX - gap
            
            let position = UserDefaults.standard.quickOverlayShortcutPosition
            let preferAbove = ["bottom", "bottomLeft", "bottomRight"].contains(position)
            
            var chosenDirection: Direction = preferAbove ? .above : .below
            
            // Try preferred vertical
            if chosenDirection == .above && spaceAbove < 200 {
                if spaceBelow >= 200 { chosenDirection = .below }
            } else if chosenDirection == .below && spaceBelow < 200 {
                if spaceAbove >= 200 { chosenDirection = .above }
            }
            
            // If still doesn't fit, check horizontal
            if (chosenDirection == .above && spaceAbove < 200) || (chosenDirection == .below && spaceBelow < 200) {
                if spaceRight >= 300 {
                    chosenDirection = .right
                } else if spaceLeft >= 300 {
                    chosenDirection = .left
                } else {
                    chosenDirection = spaceAbove > spaceBelow ? .above : .below
                }
            }
            
            // 画面端との余白を確保し、ツールチップが反対側にずれないよう幅を狭める
            switch chosenDirection {
            case .right:
                let targetVisualMinX = visualMaxX + gap
                let availableWidth = max(200, safeMaxX - targetVisualMinX)
                effectiveVisualWidth = min(initialVisualWidth, availableWidth)
                newOrigin.x = targetVisualMinX - shadowPadding
                newOrigin.y = visualMinY - shadowPadding
                finalVisualHeight = min(500, safeMaxY - visualMinY)
                
            case .left:
                let targetVisualMaxX = visualMinX - gap
                let availableWidth = max(200, targetVisualMaxX - safeMinX)
                effectiveVisualWidth = min(initialVisualWidth, availableWidth)
                newOrigin.x = targetVisualMaxX - effectiveVisualWidth - shadowPadding
                newOrigin.y = visualMinY - shadowPadding
                finalVisualHeight = min(500, safeMaxY - visualMinY)
                
            case .above:
                let targetVisualMinX = visualMinX
                if targetVisualMinX + initialVisualWidth > safeMaxX {
                    effectiveVisualWidth = max(200, safeMaxX - targetVisualMinX)
                }
                newOrigin.x = targetVisualMinX - shadowPadding
                finalVisualHeight = min(500, spaceAbove)
                newOrigin.y = visualMaxY + gap - shadowPadding
                
            case .below:
                let targetVisualMinX = visualMinX
                if targetVisualMinX + initialVisualWidth > safeMaxX {
                    effectiveVisualWidth = max(200, safeMaxX - targetVisualMinX)
                }
                newOrigin.x = targetVisualMinX - shadowPadding
                finalVisualHeight = min(500, spaceBelow)
                newOrigin.y = visualMinY - gap - finalVisualHeight - shadowPadding
            }

            tooltipDirection = switch chosenDirection {
            case .above: .above
            case .below: .below
            case .left: .left
            case .right: .right
            }
        }
        
        // 確定した effectiveVisualWidth に基づいてテキストの高さを正確に計算
        let textWidth = effectiveVisualWidth - textPadding
        let textRect = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let hasHeader = sourceAppPath != nil
        let hasFooter = dateString != nil || characterCount != nil
        let spacingCount: CGFloat = (hasHeader ? 1 : 0) + (hasFooter ? 1 : 0)
        let headerHeight: CGFloat = hasHeader ? 20 : 0
        let footerHeight: CGFloat = hasFooter ? 14 : 0
        let spacingHeight: CGFloat = spacingCount * 16
        let paddingHeight: CGFloat = 32
        let contentHeight: CGFloat = filePath != nil ? 256 : ceil(textRect.height)
        let naturalVisualHeight: CGFloat = contentHeight + paddingHeight + headerHeight + footerHeight + spacingHeight
        
        finalVisualHeight = min(finalVisualHeight, naturalVisualHeight)
        finalVisualHeight = max(finalVisualHeight, 50)
        
        // 下配置（.below）の場合、高さ確定後にY原点を再調整
        if anchorPoint == nil, tooltipDirection == .below {
            let visualMinY = overlayFrame.minY + 60
            newOrigin.y = visualMinY - gap - finalVisualHeight - shadowPadding
        }
        
        let windowWidth = effectiveVisualWidth + windowPadding
        let finalWindowHeight = finalVisualHeight + windowPadding
        
        let calculatedTextHeight = ceil(textRect.height)
        let finalView = QuickOverlayTooltipView(
            text: text,
            maxVisualHeight: finalVisualHeight,
            calculatedTextHeight: calculatedTextHeight,
            sourceAppPath: sourceAppPath,
            filePath: filePath,
            fileSize: fileSize,
            dateString: dateString,
            characterCount: characterCount,
            isCompact: isCompact
        )
        let finalHosting = NSHostingView(rootView: finalView)
        window.contentView = finalHosting
        
        window.setFrame(NSRect(x: newOrigin.x, y: newOrigin.y, width: windowWidth, height: finalWindowHeight), display: true)
    }
}
