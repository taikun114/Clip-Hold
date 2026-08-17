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
    private var expandAnimationDelegate: AnimationCompletionDelegate?
    
    private init() {
        // Creates a transparent, borderless panel
        let panel = ActivePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating // 通常ウィンドウの上、メニューバーの下に表示するレベル
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.animationBehavior = .none
        
        super.init(window: panel)
        
        NotificationCenter.default.addObserver(self, selector: #selector(showOverlay), name: NSNotification.Name("QuickOverlayShouldShow"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showPeekOverlay), name: NSNotification.Name("QuickOverlayShouldShowPeek"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(expandPeekOverlay(_:)), name: NSNotification.Name("QuickOverlayShouldExpandPeek"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideOverlay), name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// キー押下開始時（遅延時間待機中）に呼び出して、ビューの構築とレイアウト計算を事前に完了させておく
    func prepareOverlay(type: QuickOverlayType) {
        guard let window = self.window else { return }
        
        // 連打された場合など、既に同じタイプでビューが準備されているなら何もしない
        if currentPreparedType == type, window.contentView != nil {
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
        rootContainerView.autoresizingMask = [.width, .height]
        rootContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let animationContainerView = NSView(frame: rootContainerView.bounds)
        animationContainerView.wantsLayer = true
        animationContainerView.autoresizingMask = [.width, .height]
        animationContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        animationContainerView.layer?.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.layer?.position = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.identifier = NSUserInterfaceItemIdentifier("AnimationContainer")
        rootContainerView.addSubview(animationContainerView)
        
        hostingView.frame = animationContainerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        animationContainerView.addSubview(hostingView)
        
        window.contentView = rootContainerView
        rootContainerView.layoutSubtreeIfNeeded()
    }
    
    /// スクリーンエッジ接触時のピーク（24px覗き見）表示アニメーション
    @objc private func showPeekOverlay() {
        guard let window = self.window, let type = QuickOverlayManager.shared.currentOverlayType else { return }
        animationGeneration += 1
        
        window.level = .floating // メニューバーの下に潜り込ませる
        
        if currentPreparedType != type || window.contentView == nil {
            prepareOverlay(type: type)
        }
        
        guard let rootContainer = window.contentView,
              let animationContainerView = rootContainer.subviews.first(where: { $0.identifier?.rawValue == "AnimationContainer" }) else { return }
        
        positionWindow()
        
        window.alphaValue = 0
        animationContainerView.layer?.removeAllAnimations()
        
        window.orderFrontRegardless()
        window.displayIfNeeded()
        
        let mode = QuickOverlayManager.shared.presentationMode
        let outTx: CGFloat
        let outTy: CGFloat
        let peekTx: CGFloat
        let peekTy: CGFloat
        
        if case .screenEdge(let edge, _, _, let edgeInset) = mode {
            let offset: CGFloat = 476.0 // メニューバーやDockの縁から24px顔を出す
            let outOffset = 500.0 + edgeInset
            switch edge.edgeSide {
            case .top:
                outTx = 0.0; outTy = outOffset
                peekTx = 0.0; peekTy = offset
            case .bottom:
                outTx = 0.0; outTy = -outOffset
                peekTx = 0.0; peekTy = -offset
            case .left:
                outTx = -outOffset; outTy = 0.0
                peekTx = -offset; peekTy = 0.0
            case .right:
                outTx = outOffset; outTy = 0.0
                peekTx = offset; peekTy = 0.0
            }
        } else {
            outTx = 0.0; outTy = 0.0
            peekTx = 0.0; peekTy = 0.0
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animationContainerView.layer?.setValue(1.0, forKeyPath: "transform.scale")
        animationContainerView.layer?.setValue(peekTx, forKeyPath: "transform.translation.x")
        animationContainerView.layer?.setValue(peekTy, forKeyPath: "transform.translation.y")
        CATransaction.commit()
        
        let txAnim = CABasicAnimation(keyPath: "transform.translation.x")
        txAnim.fromValue = outTx
        txAnim.toValue = peekTx
        
        let tyAnim = CABasicAnimation(keyPath: "transform.translation.y")
        tyAnim.fromValue = outTy
        tyAnim.toValue = peekTy
        
        let group = CAAnimationGroup()
        group.animations = [txAnim, tyAnim]
        group.duration = 0.18
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        animationContainerView.layer?.add(group, forKey: "peekAnimation")
        
        let peekGeneration = animationGeneration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self, weak animationContainerView] in
            guard let self, self.animationGeneration == peekGeneration,
                  let animationContainerView = animationContainerView else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            animationContainerView.layer?.setValue(peekTx, forKeyPath: "transform.translation.x")
            animationContainerView.layer?.setValue(peekTy, forKeyPath: "transform.translation.y")
            CATransaction.commit()
            animationContainerView.layer?.removeAllAnimations()
        })
    }
    
    /// ピーク状態から完全表示（フルオープン）への展開アニメーション
    @objc private func expandPeekOverlay(_ notification: NSNotification) {
        guard let window = self.window,
              let rootContainer = window.contentView,
              let animationContainerView = rootContainer.subviews.first(where: { $0.identifier?.rawValue == "AnimationContainer" }) else { return }
        animationGeneration += 1
        
        // @Publishedプロパティ更新前に通知のuserInfoから取得する
        let mode: QuickOverlayPresentationMode
        if let userInfoMode = notification.userInfo?["mode"] as? QuickOverlayPresentationMode {
            mode = userInfoMode
        } else {
            mode = QuickOverlayManager.shared.presentationMode
        }
        let txValues: [CGFloat]
        let tyValues: [CGFloat]
        
        if case .screenEdge(let edge, _, _, _) = mode {
            let offset: CGFloat = 476.0
            switch edge.edgeSide {
            case .top:
                txValues = [0.0, 0.0, 0.0]
                tyValues = [offset, -4.0, 0.0]
            case .bottom:
                txValues = [0.0, 0.0, 0.0]
                tyValues = [-offset, 4.0, 0.0]
            case .left:
                txValues = [-offset, 4.0, 0.0]
                tyValues = [0.0, 0.0, 0.0]
            case .right:
                txValues = [offset, -4.0, 0.0]
                tyValues = [0.0, 0.0, 0.0]
            }
        } else {
            txValues = [0.0, 0.0, 0.0]
            tyValues = [0.0, 0.0, 0.0]
        }
        
        // アニメーションオブジェクトをトランザクション外で事前に作成する
        let keyTimes: [NSNumber] = [0.0, 0.52, 1.0]
        let timingFuncs = [
            CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0),
            CAMediaTimingFunction(controlPoints: 0.25, 1.0, 0.5, 1.0)
        ]
        
        let txAnim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        txAnim.values = txValues
        txAnim.keyTimes = keyTimes
        txAnim.timingFunctions = timingFuncs
        
        let tyAnim = CAKeyframeAnimation(keyPath: "transform.translation.y")
        tyAnim.values = tyValues
        tyAnim.keyTimes = keyTimes
        tyAnim.timingFunctions = timingFuncs
        
        let animDuration: TimeInterval = 0.38
        
        let group = CAAnimationGroup()
        group.animations = [txAnim, tyAnim]
        group.duration = animDuration
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        let expandGeneration = animationGeneration
        let animDelegate = AnimationCompletionDelegate { [weak self, weak animationContainerView] in
            guard let self, self.animationGeneration == expandGeneration,
                  let animationContainerView = animationContainerView else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            animationContainerView.layer?.setValue(0.0, forKeyPath: "transform.translation.x")
            animationContainerView.layer?.setValue(0.0, forKeyPath: "transform.translation.y")
            CATransaction.commit()
            animationContainerView.layer?.removeAllAnimations()
            self.expandAnimationDelegate = nil
        }
        self.expandAnimationDelegate = animDelegate
        group.delegate = animDelegate
        
        // window.makeKey()はウィンドウサーバーとの通信が発生するため、
        // CAアニメーション開始前に完了させておく
        window.level = .floating
        window.makeKey()
        
        // モデル値をアニメーションの最終位置ではなく開始位置（ピーク位置）に設定する。
        // macOS 14ではCATransaction内でもモデル値が1フレーム描画される場合があるが、
        // 開始位置にしておけばピーク位置からの自然な連続表示になり、ちらつきが発生しない。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animationContainerView.layer?.removeAllAnimations()
        animationContainerView.layer?.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.layer?.position = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.layer?.setValue(txValues[0], forKeyPath: "transform.translation.x")
        animationContainerView.layer?.setValue(tyValues[0], forKeyPath: "transform.translation.y")
        animationContainerView.layer?.setValue(1.0, forKeyPath: "transform.scale")
        animationContainerView.layer?.add(group, forKey: "expandAnimation")
        CATransaction.commit()
    }
    
    @objc private func showOverlay() {
        guard let window = self.window, let type = QuickOverlayManager.shared.currentOverlayType else { return }
        animationGeneration += 1
        let currentGeneration = animationGeneration
        
        // 事前準備がまだ行われていない場合は準備する
        if currentPreparedType != type || window.contentView == nil {
            prepareOverlay(type: type)
        }
        
        guard let rootContainer = window.contentView,
              let animationContainerView = rootContainer.subviews.first(where: { $0.identifier?.rawValue == "AnimationContainer" }) else { return }
        
        positionWindow()
        
        animationContainerView.layer?.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.layer?.position = CGPoint(x: 0.0, y: 0.0)
        
        window.alphaValue = 0 // Initially invisible
        animationContainerView.layer?.removeAllAnimations()
        
        window.level = .floating // メニューバーの下に潜り込ませる
        
        let mode = QuickOverlayManager.shared.presentationMode
        
        let txFrom: CGFloat
        let tyFrom: CGFloat
        let scaleFrom: CGFloat
        let animDuration: TimeInterval
        let timingFunc: CAMediaTimingFunction
        
        switch mode {
        case .screenEdge(let edge, _, _, _):
            scaleFrom = 1.0
            animDuration = 0.26
            timingFunc = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            switch edge.edgeSide {
            case .top:
                txFrom = 0.0
                tyFrom = 80.0
            case .bottom:
                txFrom = 0.0
                tyFrom = -80.0
            case .left:
                txFrom = -80.0
                tyFrom = 0.0
            case .right:
                txFrom = 80.0
                tyFrom = 0.0
            }
        case .shortcut:
            scaleFrom = 1.05
            // 左下(0,0)アンカーでスケールする際、中心を不動に保つための補正移動量: (1.0 - S) * (W / 2)
            let halfWidth = rootContainer.bounds.width / 2.0
            let halfHeight = rootContainer.bounds.height / 2.0
            txFrom = (1.0 - scaleFrom) * halfWidth
            tyFrom = (1.0 - scaleFrom) * halfHeight
            animDuration = 0.15
            timingFunc = CAMediaTimingFunction(name: .easeOut)
        }
        
        // 1. モデル値をアニメーションの「開始値」に設定する（開始時のフラッシュを防ぐ）
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animationContainerView.layer?.setValue(scaleFrom, forKeyPath: "transform.scale")
        animationContainerView.layer?.setValue(txFrom, forKeyPath: "transform.translation.x")
        animationContainerView.layer?.setValue(tyFrom, forKeyPath: "transform.translation.y")
        CATransaction.commit()
        
        // 2. アニメーションを作成
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = scaleFrom
        scaleAnim.toValue = 1.0
        
        let txAnim = CABasicAnimation(keyPath: "transform.translation.x")
        txAnim.fromValue = txFrom
        txAnim.toValue = 0.0
        
        let tyAnim = CABasicAnimation(keyPath: "transform.translation.y")
        tyAnim.fromValue = tyFrom
        tyAnim.toValue = 0.0
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnim, txAnim, tyAnim]
        group.duration = animDuration
        group.timingFunction = timingFunc
        // アニメーション完了後も最終状態を維持する（モデル値更新時のフラッシュを防ぐ）
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        animationContainerView.layer?.add(group, forKey: "showAnimation")
        
        window.orderFrontRegardless()
        window.makeKey()
        
        // 3. ウインドウのフェードインと同時に実行し、完了後にモデル値を「終了値」へ更新する
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animDuration
            context.timingFunction = timingFunc
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self, weak animationContainerView] in
            guard let self, self.animationGeneration == currentGeneration,
                  let animationContainerView = animationContainerView else { return }
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
        
        // 中断時のガタつきを防ぐため、現在画面上に描画されている presentation レイヤーから進行状態を取得する
        let presentationLayer = animationContainerView.layer?.presentation()
        let currentScale = (presentationLayer?.value(forKeyPath: "transform.scale") as? CGFloat) ?? 1.0
        let currentTx = (presentationLayer?.value(forKeyPath: "transform.translation.x") as? CGFloat) ?? 0.0
        let currentTy = (presentationLayer?.value(forKeyPath: "transform.translation.y") as? CGFloat) ?? 0.0
        let currentOpacity = presentationLayer?.opacity ?? Float(window.alphaValue)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animationContainerView.layer?.removeAllAnimations()
        animationContainerView.layer?.anchorPoint = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.layer?.position = CGPoint(x: 0.0, y: 0.0)
        animationContainerView.layer?.setValue(currentScale, forKeyPath: "transform.scale")
        animationContainerView.layer?.setValue(currentTx, forKeyPath: "transform.translation.x")
        animationContainerView.layer?.setValue(currentTy, forKeyPath: "transform.translation.y")
        animationContainerView.layer?.opacity = currentOpacity
        CATransaction.commit()
        
        let mode = QuickOverlayManager.shared.presentationMode
        let txTo: CGFloat
        let tyTo: CGFloat
        let scaleTo: CGFloat
        let animDuration: TimeInterval
        let timingFunc: CAMediaTimingFunction
        
        switch mode {
        case .screenEdge(let edge, _, let isPeeking, let edgeInset):
            scaleTo = 1.0
            animDuration = 0.16
            timingFunc = CAMediaTimingFunction(controlPoints: 0.7, 0.0, 0.84, 0.0)
            if isPeeking {
                // ピーク中から画面外へ引っ込める
                let outOffset = 500.0 + edgeInset
                switch edge.edgeSide {
                case .top: txTo = 0.0; tyTo = outOffset
                case .bottom: txTo = 0.0; tyTo = -outOffset
                case .left: txTo = -outOffset; tyTo = 0.0
                case .right: txTo = outOffset; tyTo = 0.0
                }
            } else {
                // フルオープンから画面外へ引っ込める
                switch edge.edgeSide {
                case .top: txTo = 0.0; tyTo = 80.0
                case .bottom: txTo = 0.0; tyTo = -80.0
                case .left: txTo = -80.0; tyTo = 0.0
                case .right: txTo = 80.0; tyTo = 0.0
                }
            }
        case .shortcut:
            scaleTo = 1.05
            // 左下(0,0)アンカーでスケールする際、中心を不動に保つための補正移動量: (1.0 - S) * (W / 2)
            let halfWidth = rootContainer.bounds.width / 2.0
            let halfHeight = rootContainer.bounds.height / 2.0
            txTo = (1.0 - scaleTo) * halfWidth
            tyTo = (1.0 - scaleTo) * halfHeight
            animDuration = 0.12
            timingFunc = CAMediaTimingFunction(name: .easeIn)
        }
        
        // 2. アニメーションを作成（現在の途中値から目的値へスムーズに補間）
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = currentScale
        scaleAnim.toValue = scaleTo
        
        let txAnim = CABasicAnimation(keyPath: "transform.translation.x")
        txAnim.fromValue = currentTx
        txAnim.toValue = txTo
        
        let tyAnim = CABasicAnimation(keyPath: "transform.translation.y")
        tyAnim.fromValue = currentTy
        tyAnim.toValue = tyTo
        
        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = currentOpacity
        opacityAnim.toValue = 0.0
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnim, txAnim, tyAnim, opacityAnim]
        group.duration = animDuration
        group.timingFunction = timingFunc
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        // 3. アニメーション完了後にウインドウを破棄する
        let hideDelegate = AnimationCompletionDelegate { [weak self, weak window, weak animationContainerView] in
            guard let self, self.animationGeneration == currentGeneration else { return }
            
            if let animationContainerView = animationContainerView {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                animationContainerView.layer?.setValue(scaleTo, forKeyPath: "transform.scale")
                animationContainerView.layer?.setValue(txTo, forKeyPath: "transform.translation.x")
                animationContainerView.layer?.setValue(tyTo, forKeyPath: "transform.translation.y")
                animationContainerView.layer?.opacity = 1.0
                CATransaction.commit()
                animationContainerView.layer?.removeAllAnimations()
            }
            
            window?.orderOut(nil)
            window?.contentView = nil
            self.currentPreparedType = nil
            self.hideAnimationDelegate = nil
        }
        self.hideAnimationDelegate = hideDelegate
        group.delegate = hideDelegate
        
        animationContainerView.layer?.add(group, forKey: "hideAnimation")
    }
    
    /// オーバーレイの視覚的な表示領域（シャドウのパディングを除いた500x500の領域）
    var visualFrame: NSRect? {
        guard let window = self.window, window.isVisible else { return nil }
        return window.frame.insetBy(dx: 60, dy: 60)
    }
    
    private func positionWindow(animated: Bool = false) {
        guard let window = self.window else { return }
        
        // マウスカーソルが存在するディスプレイを取得する（見つからない場合は現在のメインディスプレイ）
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame.insetBy(dx: -10, dy: -10), false) }) ?? NSScreen.main
        guard let screen = screen else { return }
        
        let screenRect = screen.visibleFrame // メニューバーやDockの内側領域
        
        var newOrigin = NSPoint(x: 0, y: 0)
        
        switch QuickOverlayManager.shared.presentationMode {
        case .screenEdge(let edge, let edgeMouseLoc, _, let edgeInset):
            let visualWidth: CGFloat = 500
            let visualHeight: CGFloat = 500
            let cornerMargin: CGFloat = 100.0 // ホットコーナー除外エリアのマージン
            
            var targetWidth = visualWidth + 120
            var targetHeight = visualHeight + 120
            
            switch edge.edgeSide {
            case .top:
                targetHeight += edgeInset
                let originY = screenRect.maxY - visualHeight - 60
                var visualX = edgeMouseLoc.x - (visualWidth / 2.0)
                let minX = max(screenRect.minX, screen.frame.minX + cornerMargin)
                let maxX = min(screenRect.maxX, screen.frame.maxX - cornerMargin) - visualWidth
                if minX <= maxX {
                    visualX = min(max(visualX, minX), maxX)
                } else {
                    if visualX < screenRect.minX { visualX = screenRect.minX }
                    if visualX + visualWidth > screenRect.maxX { visualX = screenRect.maxX - visualWidth }
                }
                let originX = visualX - 60
                newOrigin = NSPoint(x: originX, y: originY)
                
            case .bottom:
                targetHeight += edgeInset
                let originY = (screenRect.minY - edgeInset) - 60
                var visualX = edgeMouseLoc.x - (visualWidth / 2.0)
                let minX = max(screenRect.minX, screen.frame.minX + cornerMargin)
                let maxX = min(screenRect.maxX, screen.frame.maxX - cornerMargin) - visualWidth
                if minX <= maxX {
                    visualX = min(max(visualX, minX), maxX)
                } else {
                    if visualX < screenRect.minX { visualX = screenRect.minX }
                    if visualX + visualWidth > screenRect.maxX { visualX = screenRect.maxX - visualWidth }
                }
                let originX = visualX - 60
                newOrigin = NSPoint(x: originX, y: originY)
                
            case .left:
                targetWidth += edgeInset
                let originX = (screenRect.minX - edgeInset) - 60
                var visualY = edgeMouseLoc.y - (visualHeight / 2.0)
                let minY = max(screenRect.minY, screen.frame.minY + cornerMargin)
                let maxY = min(screenRect.maxY, screen.frame.maxY - cornerMargin) - visualHeight
                if minY <= maxY {
                    visualY = min(max(visualY, minY), maxY)
                } else {
                    if visualY < screenRect.minY { visualY = screenRect.minY }
                    if visualY + visualHeight > screenRect.maxY { visualY = screenRect.maxY - visualHeight }
                }
                let originY = visualY - 60
                newOrigin = NSPoint(x: originX, y: originY)
                
            case .right:
                targetWidth += edgeInset
                let originX = screenRect.maxX - visualWidth - 60
                var visualY = edgeMouseLoc.y - (visualHeight / 2.0)
                let minY = max(screenRect.minY, screen.frame.minY + cornerMargin)
                let maxY = min(screenRect.maxY, screen.frame.maxY - cornerMargin) - visualHeight
                if minY <= maxY {
                    visualY = min(max(visualY, minY), maxY)
                } else {
                    if visualY < screenRect.minY { visualY = screenRect.minY }
                    if visualY + visualHeight > screenRect.maxY { visualY = screenRect.maxY - visualHeight }
                }
                let originY = visualY - 60
                newOrigin = NSPoint(x: originX, y: originY)
            }
            
            window.setFrame(NSRect(origin: newOrigin, size: NSSize(width: targetWidth, height: targetHeight)), display: true)
            return
            
        case .shortcut:
            let targetSize = NSSize(width: 620, height: 620)
            let position = UserDefaults.standard.quickOverlayShortcutPosition
            let visualPadding: CGFloat = 16
            let padding: CGFloat = visualPadding - 60
            
            switch position {
            case "cursor":
                let visualWidth: CGFloat = 500
                let visualHeight: CGFloat = 500
                
                // 視覚的な左端をカーソル位置に（右に余裕がなければ右端をカーソル位置に）
                var x = mouseLocation.x - 60
                if screenRect.maxX - mouseLocation.x < visualWidth + visualPadding {
                    x = mouseLocation.x - targetSize.width + 60
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
                var y = mouseLocation.y - targetSize.height + 60
                
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
                newOrigin.x = screenRect.midX - (targetSize.width / 2)
                newOrigin.y = screenRect.maxY - targetSize.height - padding
            case "topRight":
                newOrigin.x = screenRect.maxX - targetSize.width - padding
                newOrigin.y = screenRect.maxY - targetSize.height - padding
            case "right":
                newOrigin.x = screenRect.maxX - targetSize.width - padding
                newOrigin.y = screenRect.midY - (targetSize.height / 2)
            case "bottomRight":
                newOrigin.x = screenRect.maxX - targetSize.width - padding
                newOrigin.y = screenRect.minY + padding
            case "bottom":
                newOrigin.x = screenRect.midX - (targetSize.width / 2)
                newOrigin.y = screenRect.minY + padding
            case "bottomLeft":
                newOrigin.x = screenRect.minX + padding
                newOrigin.y = screenRect.minY + padding
            case "left":
                newOrigin.x = screenRect.minX + padding
                newOrigin.y = screenRect.midY - (targetSize.height / 2)
            case "topLeft":
                newOrigin.x = screenRect.minX + padding
                newOrigin.y = screenRect.maxY - targetSize.height - padding
            default: // center
                newOrigin.x = screenRect.midX - (targetSize.width / 2)
                newOrigin.y = screenRect.midY - (targetSize.height / 2)
            }
            
            if animated {
                window.animator().setFrame(NSRect(origin: newOrigin, size: targetSize), display: true)
            } else {
                window.setFrame(NSRect(origin: newOrigin, size: targetSize), display: true)
            }
        }
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
