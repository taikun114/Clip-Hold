import Foundation
import AppIntents
import AppKit

@available(macOS 14.0, *)
struct AddStandardPhraseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Standard Phrase"
    static let description = IntentDescription("Creates a new standard phrase from the provided text.")
    
    // バックグラウンドで実行するため、アプリを開かないようにする
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Text", description: "The content of the standard phrase", requestValueDialog: IntentDialog("追加するテキストは何ですか？"))
    var text: String
    
    @Parameter(title: "Preset", description: "The preset to add the phrase to", default: nil, requestValueDialog: IntentDialog("どのプリセットに追加しますか？"))
    var preset: StandardPhrasePresetEntity?
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // カスタムタイトルオフ時と同様に、テキスト全体をタイトルとして使用
        let actualTitle = text
        let newPhrase = StandardPhrase(title: actualTitle, content: text)
        
        await MainActor.run {
            // バックグラウンドプロセスでの実行時に古いメモリキャッシュを使用しないよう、
            // 追加処理の直前にディスクから最新のデータを再読み込みする
            StandardPhrasePresetManager.shared.loadPresetsFromFileSystem()
            StandardPhraseManager.shared.loadStandardPhrases()
            
            if let presetEntity = preset, presetEntity.id != currentPresetDummyId {
                // 指定されたプリセットが存在するか確認して追加
                if var targetPreset = StandardPhrasePresetManager.shared.presets.first(where: { $0.id == presetEntity.id }) {
                    targetPreset.phrases.append(newPhrase)
                    StandardPhrasePresetManager.shared.updatePreset(targetPreset)
                } else {
                    // フォールバックとして現在のプリセットに追加
                    StandardPhraseManager.shared.addPhrase(title: actualTitle, content: text)
                }
            } else {
                // 現在のプリセットに追加
                StandardPhraseManager.shared.addPhrase(title: actualTitle, content: text)
            }
        }
        // 別のプロセス（Siriバックグラウンド）で追加されたことをメインアプリに通知する
        DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("ClipHoldDidAddPhraseInBackground"), object: nil, userInfo: nil, deliverImmediately: true)
        
        let presetName = preset?.name ?? "現在のプリセット"
        let dialogString = "\(presetName)に定型文「\(text)」を追加しました。"
        
        return .result(value: dialogString, dialog: IntentDialog(stringLiteral: dialogString))
    }
}
