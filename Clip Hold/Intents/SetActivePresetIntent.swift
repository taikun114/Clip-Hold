import Foundation
import AppIntents
import AppKit
import UserNotifications

@available(macOS 14.0, *)
struct SetActivePresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Active Preset"
    static let description = IntentDescription("Sets the active standard phrase preset.")
    
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "プリセット", optionsProvider: SetActivePresetOptionsProvider())
    var preset: StandardPhrasePresetEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set preset to \(\.$preset)")
    }
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let presetManager = StandardPhrasePresetManager.shared
            var targetPresetId = preset.id
            
            if targetPresetId == nextPresetDummyId {
                if let currentIndex = presetManager.presets.firstIndex(where: { $0.id == presetManager.selectedPresetId }) {
                    let nextIndex = (currentIndex + 1) % presetManager.presets.count
                    targetPresetId = presetManager.presets[nextIndex].id
                } else if let first = presetManager.presets.first {
                    targetPresetId = first.id
                }
            } else if targetPresetId == previousPresetDummyId {
                if let currentIndex = presetManager.presets.firstIndex(where: { $0.id == presetManager.selectedPresetId }) {
                    let previousIndex = (currentIndex - 1 + presetManager.presets.count) % presetManager.presets.count
                    targetPresetId = presetManager.presets[previousIndex].id
                } else if let last = presetManager.presets.last {
                    targetPresetId = last.id
                }
            }
            
            if presetManager.presets.contains(where: { $0.id == targetPresetId }) {
                presetManager.selectedPresetId = targetPresetId
                presetManager.saveSelectedPresetId()
                
                // 通知設定がオンの場合、通知を送信
                if UserDefaults.standard.bool(forKey: "sendNotificationOnPresetChange") {
                    if let selectedPreset = presetManager.presets.first(where: { $0.id == targetPresetId }) {
                        let notificationCenter = UNUserNotificationCenter.current()
                        let content = UNMutableNotificationContent()
                        content.title = selectedPreset.displayName
                        content.body = String(localized: "「\(selectedPreset.displayName)」に切り替わりました。")
                        content.sound = nil // 音なし
                        
                        // Add attachment
                        if let bigIcon = PresetIconGenerator.shared.bigIconCache[selectedPreset.id],
                           let attachment = bigIcon.createNotificationAttachment(identifier: "presetIcon") {
                            content.attachments = [attachment]
                        }
                        
                        let request = UNNotificationRequest(identifier: "PresetChangeNotification", content: content, trigger: nil)
                        notificationCenter.add(request) { error in
                            if let error = error {
                                print("Failed to send notification: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        
        return .result()
    }
}
