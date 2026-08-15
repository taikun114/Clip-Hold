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
    private var currentTooltipIdentity: TooltipIdentity?
    
    private struct TooltipIdentity: Equatable {
        let text: String
        let sourceAppPath: String?
        let filePath: String?
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
        
        panel.level = .statusBar // オーバーレイ（.statusBar）の上に表示する
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
              let rawText = userInfo["text"] as? String else { return }
        
        // ツールチップの用途では数万文字を全てスクロールして読むことはないため、
        // 深刻なパフォーマンス低下（フリーズ）を防ぐために5000文字で切り詰める
        let maxLength = 5000
        let text = rawText.count > maxLength ? String(rawText.prefix(maxLength)) + "..." : rawText
        
        let sourceAppPath = userInfo["sourceAppPath"] as? String
        let filePath = userInfo["filePath"] as? String
        let fileSize = userInfo["fileSize"] as? UInt64
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
            isCompact: isCompact,
            anchorPoint: anchorPoint
        )
        
        if window.isVisible && self.currentTooltipIdentity == identity {
            // 既に全く同じ内容・位置のツールチップが表示中の場合は再描画（マーキーリセット等）を防止する
            return
        }
        self.currentTooltipIdentity = identity
        
        positionWindow(text: text, sourceAppPath: sourceAppPath, filePath: filePath, fileSize: fileSize, anchorPoint: anchorPoint, isCompact: isCompact, buttonHeight: buttonHeight)
        
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
    
    private func positionWindow(text: String, sourceAppPath: String?, filePath: String?, fileSize: UInt64?, anchorPoint: CGPoint?, isCompact: Bool = false, buttonHeight: CGFloat = 0) {
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
        
        let visualWidth: CGFloat
        if isCompact {
            // ボタンツールチップ等：内容に合わせて縮小する
            let naturalTextWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width) + textPadding
            visualWidth = min(maxVisualWidth, naturalTextWidth)
        } else if filePath != nil {
            // ファイルツールチップはサムネイル表示のため固定幅
            visualWidth = maxVisualWidth
        } else {
            // 通常のテキストツールチップは固定幅（元の挙動）
            visualWidth = maxVisualWidth
        }
        
        // Measure natural text height reliably using NSString to avoid NSHostingView bugs
        let textWidth = visualWidth - textPadding
        let textRect = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // Add 32 for padding (16 top, 16 bottom).
        // Since we now use .fixedSize in the view, it will never truncate with '...', so we don't need a buffer.
        let headerHeight: CGFloat = sourceAppPath == nil ? 0 : 52
        let contentVerticalPadding: CGFloat = sourceAppPath == nil ? 32 : 16
        let naturalVisualHeight: CGFloat
        if filePath != nil {
            naturalVisualHeight = 256 + contentVerticalPadding + headerHeight
        } else {
            naturalVisualHeight = ceil(textRect.height) + contentVerticalPadding + headerHeight
        }
        
        // Cap max visual height at 500 (same as overlay)
        let targetVisualHeight = min(naturalVisualHeight, 500)
        
        let gap: CGFloat = 12
        let windowWidth = visualWidth + windowPadding
        
        enum Direction { case above, below, left, right }
        var newOrigin = NSPoint.zero
        var finalVisualHeight = targetVisualHeight
        
        if let anchor = anchorPoint {
            // ボタン等の固定位置（スクリーン座標）に表示する場合
            // スクリーンエッジ表示時（メニューバー方向含む）でもショートカットと同じくボタンの真上に表示できるよう、画面フレーム全体（screen.frame）を基準にする
            let effectiveMaxY = screen.frame.maxY
            let effectiveMinY = screen.frame.minY
            let spaceAbove = effectiveMaxY - anchor.y - gap
            let spaceBelow = anchor.y - buttonHeight - effectiveMinY - gap
            
            var chosenDirection: Direction
            if spaceAbove >= targetVisualHeight {
                chosenDirection = .above
            } else if spaceBelow >= targetVisualHeight {
                chosenDirection = .below
            } else {
                chosenDirection = spaceAbove > spaceBelow ? .above : .below
            }
            
            switch chosenDirection {
            case .above:
                // ツールチップの視覚的下端（= ウィンドウ下端 + 影パディング）がボタンの上端の上に来るようにする
                newOrigin.x = anchor.x - windowWidth / 2
                newOrigin.y = anchor.y + gap - shadowPadding
                finalVisualHeight = min(finalVisualHeight, spaceAbove)
            case .below:
                // ツールチップの視覚的上端（= ウィンドウ上端 - 影パディング）がボタンの下辺の下に来るようにする
                newOrigin.x = anchor.x - windowWidth / 2
                newOrigin.y = anchor.y - buttonHeight - gap + shadowPadding - (finalVisualHeight + windowPadding)
                finalVisualHeight = min(finalVisualHeight, spaceBelow)
            default:
                break
            }
            
            // 画面端からはみ出す場合はクランプする
            if isCompact {
                // コンパクトツールチップは影のパディング分だけは画面外にはみ出しても良い
                // （内容自体は画面内に収める）。メニューバー付近での過度の押し下げを防ぐ。
                newOrigin.x = min(max(newOrigin.x, screen.frame.minX - shadowPadding), screen.frame.maxX - windowWidth + shadowPadding)
                newOrigin.y = min(max(newOrigin.y, effectiveMinY - shadowPadding), effectiveMaxY - finalVisualHeight - shadowPadding)
            } else {
                newOrigin.x = min(max(newOrigin.x, screenRect.minX), screenRect.maxX - windowWidth)
                newOrigin.y = min(max(newOrigin.y, screenRect.minY), screenRect.maxY - (finalVisualHeight + windowPadding))
            }
            
            tooltipDirection = chosenDirection == .above ? .above : .below
        } else {
            // Overlay visual bounds (620x620 with 60 padding)
            let visualMinX = overlayFrame.minX + 60
            let visualMinY = overlayFrame.minY + 60
            let visualMaxX = overlayFrame.maxX - 60
            let visualMaxY = overlayFrame.maxY - 60
            
            let spaceAbove = screenRect.maxY - visualMaxY - gap
            let spaceBelow = visualMinY - screenRect.minY - gap
            let spaceLeft = visualMinX - screenRect.minX - gap
            let spaceRight = screenRect.maxX - visualMaxX - gap
            
            let position = UserDefaults.standard.quickOverlayShortcutPosition
            let preferAbove = ["bottom", "bottomLeft", "bottomRight"].contains(position)
            
            var chosenDirection: Direction = preferAbove ? .above : .below
            
            // Try preferred vertical
            if chosenDirection == .above && spaceAbove < targetVisualHeight {
                if spaceBelow >= targetVisualHeight { chosenDirection = .below }
            } else if chosenDirection == .below && spaceBelow < targetVisualHeight {
                if spaceAbove >= targetVisualHeight { chosenDirection = .above }
            }
            
            // If still doesn't fit, check horizontal
            if (chosenDirection == .above && spaceAbove < targetVisualHeight) || (chosenDirection == .below && spaceBelow < targetVisualHeight) {
                let neededWidth = windowWidth
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
                newOrigin.x = visualMinX - gap - windowWidth + 60
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
        }
        
        // Ensure minimum height
        finalVisualHeight = max(finalVisualHeight, 50)
        
        let finalWindowHeight = finalVisualHeight + windowPadding
        
        let finalView = QuickOverlayTooltipView(
            text: text,
            maxVisualHeight: finalVisualHeight,
            sourceAppPath: sourceAppPath,
            filePath: filePath,
            fileSize: fileSize,
            isCompact: isCompact
        )
        let finalHosting = NSHostingView(rootView: finalView)
        window.contentView = finalHosting
        
        window.setFrame(NSRect(x: newOrigin.x, y: newOrigin.y, width: windowWidth, height: finalWindowHeight), display: true)
    }
}
