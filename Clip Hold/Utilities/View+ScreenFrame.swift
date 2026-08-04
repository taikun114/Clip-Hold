import SwiftUI
import AppKit

/// ビューのフレームをスクリーン座標で取得するためのビュー。
/// カーソル位置に依存せず、ボタン等の固定位置にツールチップを表示する場合などに使用する。
struct ScreenFrameReader: NSViewRepresentable {
    var onFrameChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ScreenFrameReaderNSView {
        let view = ScreenFrameReaderNSView()
        view.onFrameChange = onFrameChange
        return view
    }

    func updateNSView(_ nsView: ScreenFrameReaderNSView, context: Context) {
        nsView.onFrameChange = onFrameChange
        nsView.reportFrame()
    }
}

final class ScreenFrameReaderNSView: NSView {
    var onFrameChange: ((CGRect) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportFrame()
    }

    override func layout() {
        super.layout()
        reportFrame()
    }

    func reportFrame() {
        guard let window = self.window else { return }
        let frameInWindow = self.convert(self.bounds, to: nil)
        let originInScreen = window.convertPoint(toScreen: frameInWindow.origin)
        let frameInScreen = CGRect(
            x: originInScreen.x,
            y: originInScreen.y,
            width: frameInWindow.width,
            height: frameInWindow.height
        )
        Task { @MainActor in
            self.onFrameChange?(frameInScreen)
        }
    }
}
