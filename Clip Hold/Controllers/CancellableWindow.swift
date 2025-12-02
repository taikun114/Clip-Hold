import AppKit

class CancellableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        // エスケープキーが押されたときにウィンドウを閉じる
        self.close()
    }
}
