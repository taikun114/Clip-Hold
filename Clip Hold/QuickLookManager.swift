import Quartz
import SwiftUI
import AppKit

class QuickLookManager: NSObject, QLPreviewPanelDelegate, QLPreviewPanelDataSource {
    private var panel: QLPreviewPanel?
    var quickLookURL: URL? // Quick Lookパネルに表示するファイルのURL
    private var sourceView: NSView?

    // Quick Lookパネルを表示するメソッド
    func showQuickLook(for url: URL, sourceView: NSView) {
        if QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
            return
        }
        
        self.quickLookURL = url
        self.sourceView = sourceView
        
        if panel == nil {
            panel = QLPreviewPanel.shared()
            panel?.delegate = self
            panel?.dataSource = self
        }
        
        panel?.makeKeyAndOrderFront(nil)
    }

    // Quick Lookパネルを非表示にするメソッド
    func hideQuickLook() {
        if QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        }
    }

    // MARK: - QLPreviewPanelDataSource
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return quickLookURL == nil ? 0 : 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index == 0, let url = quickLookURL else {
            return nil
        }
        return url as QLPreviewItem
    }

    // MARK: - QLPreviewPanelDelegate

    // アニメーションの開始位置のフレームを返す
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameFor previewItem: QLPreviewItem!) -> NSRect {
        guard let sourceView = self.sourceView, let window = sourceView.window else {
            return .zero
        }
        
        // sourceViewを画面座標系に変換
        let screenFrame = sourceView.convert(sourceView.bounds, to: nil)
        
        // ウィンドウの座標系を考慮
        return window.convertToScreen(screenFrame)
    }
}
