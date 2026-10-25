import Foundation

/// 表示待ちの要求を識別し、取り消し後に古い処理が表示を再開しないようにする。
struct QuickOverlayShortcutRequestState {
    struct Request: Equatable {
        let id = UUID()
        let modifiers: Int
    }

    private(set) var current: Request?

    mutating func begin(modifiers: Int) -> Request {
        let request = Request(modifiers: modifiers)
        current = request
        return request
    }

    mutating func cancel() {
        current = nil
    }

    func canPresent(_ request: Request, currentModifiers: Int, isEnabled: Bool) -> Bool {
        isEnabled && request.modifiers != 0 && current == request && request.modifiers == currentModifiers
    }
}
