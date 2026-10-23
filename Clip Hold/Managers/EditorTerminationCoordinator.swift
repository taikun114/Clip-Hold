import AppKit

@MainActor
final class EditorTerminationCoordinator {
    static let shared = EditorTerminationCoordinator()

    private struct Editor {
        let hasChanges: () -> Bool
        let confirmDiscard: (@escaping (Bool) -> Void) -> Void
    }

    private var editors: [UUID: Editor] = [:]
    private var pendingEditorIDs: [UUID] = []
    private var confirmingEditorID: UUID?
    private var terminationReply: ((Bool) -> Void)?

    func register(id: UUID, hasChanges: @escaping () -> Bool, confirmDiscard: @escaping (@escaping (Bool) -> Void) -> Void) {
        editors[id] = Editor(hasChanges: hasChanges, confirmDiscard: confirmDiscard)
    }

    func unregister(id: UUID) {
        editors.removeValue(forKey: id)
        if confirmingEditorID == id {
            finishTermination(allowed: false)
        }
    }

    func requestTermination(reply: @escaping (Bool) -> Void) -> NSApplication.TerminateReply {
        guard terminationReply == nil else { return .terminateLater }
        pendingEditorIDs = editors.keys.filter { editors[$0]?.hasChanges() == true }
        guard !pendingEditorIDs.isEmpty else { return .terminateNow }

        terminationReply = reply
#if DEBUG
        print("EditorTerminationCoordinator: 編集内容の破棄確認のため終了を保留します。")
#endif
        // applicationShouldTerminateが戻ってから終了確認を開始する。
        Task { @MainActor in
            self.confirmNextEditor()
        }
        return .terminateLater
    }

    private func confirmNextEditor() {
        guard terminationReply != nil else { return }
        while !pendingEditorIDs.isEmpty {
            let id = pendingEditorIDs.removeFirst()
            guard let editor = editors[id], editor.hasChanges() else { continue }
            confirmingEditorID = id
            editor.confirmDiscard { [weak self] allowed in
                guard let self, self.confirmingEditorID == id else { return }
                self.confirmingEditorID = nil
                if allowed {
                    self.confirmNextEditor()
                } else {
                    self.finishTermination(allowed: false)
                }
            }
            return
        }
        finishTermination(allowed: true)
    }

    private func finishTermination(allowed: Bool) {
        let reply = terminationReply
        terminationReply = nil
        confirmingEditorID = nil
        pendingEditorIDs.removeAll()
#if DEBUG
        print("EditorTerminationCoordinator: 終了確認の結果: \(allowed)")
#endif
        reply?(allowed)
    }
}
