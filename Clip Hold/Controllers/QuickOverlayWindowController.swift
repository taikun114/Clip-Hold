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
    private var currentPreparedType: QuickOverlayType? = nil
    private var hideAnimationDelegate: AnimationCompletionDelegate?
    
    private init() {
        // Creates a transparent, borderless panel
        let panel = ActivePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .statusBar // 通常ウィンドウやアラートより上に表示するレベル
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
    
    /// キー押下開始時（遅延時間待機中）に呼び出して、ビューの構築とレイアウト計算を事前に完了させておく
    func prepareOverlay(type: QuickOverlayType) {
        guard let window = self.window else { return }
        
        // 連打された場合など、既に同じタイプでビューが準備されているなら再生成を行わず位置のみ更新する
        if currentPreparedType == type, window.contentView != nil {
            positionWindow()
            return
        }
        
        currentPreparedType = type
        
        // ビューを生成してセット
        let view = QuickOverlayView(type: type)
            .environmentObject(ClipboardManager.shared)
            .environmentObject(StandardPhraseManager.shared)
            .environmentObject(StandardPhrasePresetManager.shared)
            .environmentObject(DateReloader.shared)
        
        let hostingView = NSHostingView(rootView: view)
        
        let rootContainerView = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 620))
        rootContainerView.wantsLayer = true
        rootContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let animationContainerView = NSView(frame: rootContainerView.bounds)
        animationContainerView.wantsLayer = true
        animationContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        animationContainerView.identifier = NSUserInterfaceItemIdentifier("AnimationContainer")
        rootContainerView.addSubview(animationContainerView)
        
        hostingView.frame = animationContainerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        animationContainerView.addSubview(hostingView)
        
        window.contentView = rootContainerView
        
        positionWindow()
        rootContainerView.layoutSubtreeIfNeeded()
    }
    
    @objc private func showOverlay() {
        guard let window = self.window, let type = QuickOverlayManager.shared.currentOverlayType else { return }
        animationGeneration += 1
        
        // 事前準備がまだ行われていない場合は準備する
        if currentPreparedType != type || window.contentView == nil {
            prepareOverlay(type: type)
        }
        
        guard let rootContainer = window.contentView,
              let animationContainerView = rootContainer.subviews.first(where: { $0.identifier?.rawValue == "AnimationContainer" }) else { return }
        
        positionWindow()
        
        window.alphaValue = 0 // Initially invisible
        animationContainerView.layer?.removeAllAnimations()
        
        window.orderFrontRegardless()
        window.makeKey()
        window.displayIfNeeded()
        
        let w = animationContainerView.bounds.width
        let h = animationContainerView.bounds.height
        
        let txFrom: CGFloat = (1.0 - 1.05) * (w / 2.0)
        let tyFrom: CGFloat = (1.0 - 1.05) * (h / 2.0)
        
        // 1. モデル値をアニメーションの「開始値」に設定する（開始時のフラッシュを防ぐ）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animationContainerView.layer?.setValue(1.05, forKeyPath: "transform.scale")
        animationContainerView.layer?.setValue(txFrom, forKeyPath: "transform.translation.x")
        animationContainerView.layer?.setValue(tyFrom, forKeyPath: "transform.translation.y")
        CATransaction.commit()
        
        // 2. アニメーションを作成
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.05
        scaleAnim.toValue = 1.0
        
        let txAnim = CABasicAnimation(keyPath: "transform.translation.x")
        txAnim.fromValue = txFrom
        txAnim.toValue = 0.0
        
        let tyAnim = CABasicAnimation(keyPath: "transform.translation.y")
        tyAnim.fromValue = tyFrom
        tyAnim.toValue = 0.0
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnim, txAnim, tyAnim]
        group.duration = 0.1
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        // アニメーション完了後も最終状態を維持する（モデル値更新時のフラッシュを防ぐ）
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        animationContainerView.layer?.add(group, forKey: "showScale")
        
        // 3. ウインドウのフェードインと同時に実行し、完了後にモデル値を「終了値」へ更新する
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }, completionHandler: { [weak animationContainerView] in
            guard let animationContainerView = animationContainerView else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            animationContainerView.layer?.setValue(1.0, forKeyPath: "transform.scale")
            animationContainerView.layer?.setValue(0.0, forKeyPath: "transform.translation.x")
            animationContainerView.layer?.setValue(0.0, forKeyPath: "transform.translation.y")
            CATransaction.commit()
            animationContainerView.layer?.removeAllAnimations()
        })
    }
    
    @objc private func hideOverlay() {
        guard let window = self.window, 
              let rootContainer = window.contentView,
              let animationContainerView = rootContainer.subviews.first(where: { $0.identifier?.rawValue == "AnimationContainer" }) else { return }
        animationGeneration += 1
        let currentGeneration = animationGeneration
        
        animationContainerView.layer?.removeAllAnimations()
        
        let w = animationContainerView.bounds.width
        let h = animationContainerView.bounds.height
        
        let txTo: CGFloat = (1.0 - 1.05) * (w / 2.0)
        let tyTo: CGFloat = (1.0 - 1.05) * (h / 2.0)
        
        // 1. モデル値をアニメーションの「開始値」に設定する
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animationContainerView.layer?.setValue(1.0, forKeyPath: "transform.scale")
        animationContainerView.layer?.setValue(0.0, forKeyPath: "transform.translation.x")
        animationContainerView.layer?.setValue(0.0, forKeyPath: "transform.translation.y")
        CATransaction.commit()
        
        // 2. アニメーションを作成
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 1.05
        
        let txAnim = CABasicAnimation(keyPath: "transform.translation.x")
        txAnim.fromValue = 0.0
        txAnim.toValue = txTo
        
        let tyAnim = CABasicAnimation(keyPath: "transform.translation.y")
        tyAnim.fromValue = 0.0
        tyAnim.toValue = tyTo
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnim, txAnim, tyAnim]
        group.duration = 0.1
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
        // アニメーション完了後も最終状態を維持する
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        animationContainerView.layer?.add(group, forKey: "hideScale")

        // 3. ウインドウのフェードアウトと同時に実行し、完了後に破棄する
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak window, weak animationContainerView] in
            guard let self, self.animationGeneration == currentGeneration else { return }
            
            // モデル値を最終状態に更新
            if let animationContainerView = animationContainerView {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                animationContainerView.layer?.setValue(1.05, forKeyPath: "transform.scale")
                animationContainerView.layer?.setValue(txTo, forKeyPath: "transform.translation.x")
                animationContainerView.layer?.setValue(tyTo, forKeyPath: "transform.translation.y")
                CATransaction.commit()
                animationContainerView.layer?.removeAllAnimations()
            }
            
            window?.orderOut(nil)
            window?.contentView = nil 
            self.currentPreparedType = nil
        })
    }
    
    private func positionWindow() {
        guard let window = self.window else { return }
        
        // マウスカーソルが存在するディスプレイを取得する（見つからない場合は現在のメインディスプレイ）
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let screen = screen else { return }
        
        let position = UserDefaults.standard.quickOverlayShortcutPosition
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
