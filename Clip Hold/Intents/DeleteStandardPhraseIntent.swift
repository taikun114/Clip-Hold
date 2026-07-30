import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct DeleteStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Standard Phrase"
    static let description = IntentDescription("Deletes a specific standard phrase based on its text.")
    
    // バックグラウンドで実行するため、アプリを開かないようにする
    static let openAppWhenRun: Bool = false
    

    @Parameter(title: "Preset", description: "The preset to delete the phrase from", default: nil, requestValueDialog: IntentDialog("どのプリセットから削除しますか？"))
    var preset: StandardPhrasePresetEntity?
    
    @Parameter(title: "Phrase", description: "The standard phrase to delete", requestValueDialog: IntentDialog("どの定型文を削除しますか？"), optionsProvider: DeletePhraseOptionsProvider())
    var phrase: StandardPhraseEntity
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let (deletedCount, presetName, deletedPhraseTitle) = await MainActor.run {
            var localDeletedCount = 0
            var localPresetName = "現在のプリセット"
            let title = phrase.title
            
            // バックグラウンドプロセスでの実行時に古いメモリキャッシュを使用しないよう、
            // 処理の直前にディスクから最新のデータを再読み込みする
            StandardPhrasePresetManager.shared.loadPresetsFromFileSystem()
            StandardPhraseManager.shared.loadStandardPhrases()
            
            if let presetEntity = preset, presetEntity.id != currentPresetDummyId {
                // 指定されたプリセットから削除
                localPresetName = presetEntity.name
                if var targetPreset = StandardPhrasePresetManager.shared.presets.first(where: { $0.id == presetEntity.id }) {
                    if targetPreset.phrases.contains(where: { $0.id == phrase.id }) {
                        targetPreset.phrases.removeAll(where: { $0.id == phrase.id })
                        StandardPhrasePresetManager.shared.updatePreset(targetPreset)
                        localDeletedCount = 1
                        SpotlightManager.shared.removeStandardPhrase(id: phrase.id)
                    }
                }
            } else {
                // 現在のプリセットから削除
                let manager = StandardPhraseManager.shared
                if manager.standardPhrases.contains(where: { $0.id == phrase.id }) {
                    manager.deletePhrase(id: phrase.id)
                    localDeletedCount = 1
                }
            }
            return (localDeletedCount, localPresetName, title)
        }
        
        // 別のプロセス（Siriバックグラウンド）で削除されたことをメインアプリに通知する
        DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("ClipHoldDidUpdatePhrasesInBackground"), object: nil, userInfo: nil, deliverImmediately: true)
        
        let dialogString: String
        if deletedCount > 0 {
            dialogString = "\(presetName)から定型文「\(deletedPhraseTitle)」を削除しました。"
        } else {
            dialogString = "\(presetName)に定型文「\(deletedPhraseTitle)」は見つかりませんでした。"
        }
        
        return .result(value: dialogString, dialog: IntentDialog(stringLiteral: dialogString))
    }
}
