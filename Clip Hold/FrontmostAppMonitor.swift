
import AppKit
import Combine

@MainActor
class FrontmostAppMonitor {
    static let shared = FrontmostAppMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var previousPresetId: UUID? = nil

    private init() {}

    func startMonitoring() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { notification -> String? in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return nil
                }
                return app.bundleIdentifier
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bundleIdentifier in
                self?.handleAppActivation(bundleIdentifier: bundleIdentifier)
            }
            .store(in: &cancellables)
    }

    private func handleAppActivation(bundleIdentifier: String) {
        let presetManager = StandardPhrasePresetManager.shared
        let assignmentManager = PresetAppAssignmentManager.shared

        if let assignedPresetId = assignmentManager.getPresetId(for: bundleIdentifier) {
            // アプリにプリセットが割り当てられている場合
            if presetManager.selectedPresetId != assignedPresetId {
                // 現在のプリセットが割り当てられたプリセットと異なる場合のみ処理
                if previousPresetId == nil {
                    // 直前のプリセットが保存されていない場合、現在のプリセットを保存
                    previousPresetId = presetManager.selectedPresetId
                }
                // 割り当てられたプリセットに切り替え
                presetManager.selectedPresetId = assignedPresetId
            }
        } else {
            // アプリにプリセットが割り当てられていない場合
            if let previousId = previousPresetId {
                // 保存されている直前のプリセットに戻す
                if presetManager.selectedPresetId != previousId {
                    presetManager.selectedPresetId = previousId
                }
                // 直前のプリセット情報をクリア
                previousPresetId = nil
            }
        }
    }
}
