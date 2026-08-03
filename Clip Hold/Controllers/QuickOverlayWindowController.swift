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
    private var animationGeneration = 0
    private var hideAnimationDelegate: AnimationCompletionDelegate?
    
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
        panel.animationBehavior = .none
        
        super.init(window: panel)
        
        NotificationCenter.default.addObserver(self, selector: #selector(showOverlay), name: NSNotification.Name("QuickOverlayShouldShow"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideOverlay), name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func showOverlay() {
        guard let window = self.window, let type = QuickOverlayManager.shared.currentOverlayType else { return }
        animationGeneration += 1
        
        // Load the view
        let view = QuickOverlayView(type: type)
            .environmentObject(ClipboardManager.shared)
            .environmentObject(StandardPhraseManager.shared)
            .environmentObject(StandardPhrasePresetManager.shared)
            .environmentObject(DateReloader.shared)
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        window.contentView = hostingView
        
        positionWindow()
        
        // 表示アニメーション: 透明+105%スケールから不透明+100%スケールへ
        window.alphaValue = 1
        hostingView.layer?.removeAllAnimations()
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        configureAnimationLayer(for: hostingView)
        hostingView.layer?.opacity = 0
        hostingView.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1)
        let showOpacity = CABasicAnimation(keyPath: "opacity")
        showOpacity.fromValue = 0
        showOpacity.toValue = 1
        let showScale = CABasicAnimation(keyPath: "transform.scale")
        showScale.fromValue = 1.05
        showScale.toValue = 1.0
        let showAnimation = CAAnimationGroup()
        showAnimation.animations = [showOpacity, showScale]
        showAnimation.duration = 0.1
        showAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        hostingView.layer?.add(showAnimation, forKey: "showAnimation")
        hostingView.layer?.opacity = 1
        hostingView.layer?.transform = CATransform3DIdentity
    }
    
    @objc private func hideOverlay() {
        guard let window = self.window, let contentView = window.contentView else { return }
        animationGeneration += 1
        let currentGeneration = animationGeneration
        contentView.wantsLayer = true
        window.layoutIfNeeded()
        configureAnimationLayer(for: contentView)
        contentView.layer?.removeAllAnimations()
        
        contentView.layer?.opacity = 1
        contentView.layer?.transform = CATransform3DIdentity
        let hideScale = CABasicAnimation(keyPath: "transform.scale")
        hideScale.fromValue = 1.0
        hideScale.toValue = 1.05
        hideScale.duration = 0.1
        hideScale.timingFunction = CAMediaTimingFunction(name: .easeIn)
        contentView.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1)
        let animationDelegate = AnimationCompletionDelegate { [weak self, weak window] in
            guard let self, self.animationGeneration == currentGeneration else { return }
            window?.orderOut(nil)
            self.hideAnimationDelegate = nil
        }
        hideAnimationDelegate = animationDelegate
        hideScale.delegate = animationDelegate
        contentView.layer?.add(hideScale, forKey: "hideScale")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }
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

    private func configureAnimationLayer(for view: NSView) {
        guard let layer = view.layer else { return }

        // レイヤーの拡大縮小の基準点を、常にウインドウの中央へ固定する
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }
}

private final class AnimationCompletionDelegate: NSObject, CAAnimationDelegate {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard flag else { return }
        completion()
    }
}
