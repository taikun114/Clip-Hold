import AppKit
import SwiftUI

class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen ?? NSScreen.main else { return frameRect }
        
        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 60 // SwiftUI view's shadow padding
        
        var newRect = frameRect
        
        // 1. 上方向の制限: 見えるアラートの上端(maxY - padding)がメニューバーの下端(visibleFrame.maxY)で止まるようにする
        let maxWindowY = visibleFrame.maxY + padding
        if newRect.maxY > maxWindowY {
            newRect.origin.y = maxWindowY - newRect.height
        }
        
        // 2. 下方向の制限: 見えるアラートの上端が、Dockの裏に隠れず少し(32pt)残るようにする
        let minWindowTopY = visibleFrame.minY + padding + 32
        if newRect.maxY < minWindowTopY {
            newRect.origin.y = minWindowTopY - newRect.height
        }
        
        // マルチディスプレイ間を移動できるように、左右の制限はすべてのスクリーンの全体領域を基準にする
        let globalMaxX = NSScreen.screens.map { $0.visibleFrame.maxX }.max() ?? visibleFrame.maxX
        let globalMinX = NSScreen.screens.map { $0.visibleFrame.minX }.min() ?? visibleFrame.minX
        
        // 3. 右方向の制限: 見えるアラートの左端が、全体画面の右端に少し(40pt)残るようにする
        let maxWindowLeftX = globalMaxX - padding - 40
        if newRect.minX > maxWindowLeftX {
            newRect.origin.x = maxWindowLeftX
        }
        
        // 4. 左方向の制限: 見えるアラートの右端が、全体画面の左端に少し(40pt)残るようにする
        let minWindowRightX = globalMinX + padding + 40
        if newRect.maxX < minWindowRightX {
            newRect.origin.x = minWindowRightX - newRect.width
        }
        
        return newRect
    }
}

class LargeFileAlertWindowController: NSWindowController {
    static let shared = LargeFileAlertWindowController()
    
    // 現在表示中のアラートのViewModel
    var currentViewModel: LargeFileAlertViewModel?
    
    private init() {
        // Create an invisible, borderless window
        let panel = FocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
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
        panel.isMovableByWindowBackground = false // 独自ドラッグ実装に任せるため無効化
        panel.animationBehavior = .alertPanel
        
        // Center it
        panel.center()
        
        super.init(window: panel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showAlert(title: String, message: String, buttons: [LargeFileAlertButton]) {
        Task { @MainActor [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // 既に表示中で、ViewModelが存在する場合は内容だけ更新する
            if let existingViewModel = self.currentViewModel, window.isVisible {
                existingViewModel.title = title
                existingViewModel.message = message
                existingViewModel.buttons = buttons
                return
            }
            
            let viewModel = LargeFileAlertViewModel(title: title, message: message, buttons: buttons)
            self.currentViewModel = viewModel
            let alertView = LargeFileAlertView(viewModel: viewModel)
            
            let hostingController = NSHostingController(rootView: alertView)
            // Ensure background remains transparent
            hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
            hostingController.view.wantsLayer = true
            
            window.contentViewController = hostingController
            
            // Yield to allow SwiftUI layout to complete
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // ユーザーのカーソルがあるディスプレイを取得し、その中央に配置する
            let mouseLocation = NSEvent.mouseLocation
            let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? window.screen ?? NSScreen.main
            
            if let targetScreen = currentScreen {
                // window.center() に正しいスクリーンを認識させるため、一度ターゲットスクリーン内に配置する
                window.setFrameOrigin(targetScreen.visibleFrame.origin)
            }
            window.center()
            
            NSApp.activate(ignoringOtherApps: true)
            self.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func closeWindow() {
        self.currentViewModel = nil
        self.close()
    }
}
