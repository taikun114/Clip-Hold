import Foundation

/// コピーとオーバーレイの非表示が両方完了した後に、貼り付けを一度だけ実行する。
@MainActor
final class QuickOverlayPasteRequest {
    static let notificationKey = "QuickOverlayPasteRequest"

    private var isCopyComplete = false
    private var isOverlayClosed = false
    private var paste: (() -> Void)?

    init(paste: @escaping () -> Void) {
        self.paste = paste
    }

    static func prepareForCopy(
        shouldPaste: Bool,
        prepareOverlay: (QuickOverlayPasteRequest) -> Void,
        paste: @escaping () -> Void
    ) -> QuickOverlayPasteRequest {
        let request = QuickOverlayPasteRequest(paste: paste)
        if shouldPaste {
            prepareOverlay(request)
        } else {
            request.cancel()
        }
        return request
    }

    func copyDidComplete() {
        isCopyComplete = true
        performPasteIfReady()
    }

    func overlayDidClose() {
        isOverlayClosed = true
        performPasteIfReady()
    }

    func cancel() {
        paste = nil
    }

    private func performPasteIfReady() {
        guard isCopyComplete, isOverlayClosed, let paste else { return }
        self.paste = nil
        paste()
    }
}
