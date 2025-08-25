import SwiftUI
import Foundation

// プリセット情報を持つ場合の競合解決シート用のデータ構造
struct PresetConflictInfo {
    let preset: StandardPhrasePreset
    var conflicts: [StandardPhraseDuplicate]
    let nonConflictingPhrases: [StandardPhrase]
}

struct ImportConflictSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager

    // プリセットごとの競合情報を保持する配列
    @Binding var presetConflicts: [PresetConflictInfo]
    
    // 現在処理中のプリセットのインデックス
    @Binding var currentPresetIndex: Int
    
    // 現在処理中のプリセットの競合情報
    private var currentPresetConflict: PresetConflictInfo? {
        guard currentPresetIndex < presetConflicts.count else { return nil }
        return presetConflicts[currentPresetIndex]
    }
    
    // 現在処理中の競合のインデックス
    @State private var currentConflictIndex: Int = 0
    
    // resolvedPhrasesToImport には、ユーザーが「インポート」または「このまま追加」を選択したフレーズが追加される。
    // これらは常に新しいIDを持つべき。
    @State private var resolvedPhrasesToImport: [StandardPhrase] = []
    
    // すべてのプリセットの処理が完了したときに呼ばれるクロージャ
    var onAllPresetsCompleted: ([PresetConflictInfo]) -> Void

    private var currentConflict: Binding<StandardPhraseDuplicate>? {
        guard let currentPreset = currentPresetConflict,
              currentConflictIndex < currentPreset.conflicts.count else { return nil }
        return $presetConflicts[currentPresetIndex].conflicts[currentConflictIndex]
    }

    private var isConflictUnresolved: Bool {
        if let conflict = currentConflict?.wrappedValue {
            return conflict.hasTitleConflict || conflict.hasContentConflict
        }
        return false
    }
    
    // 現在処理中のプリセットの競合配列
    private var currentConflicts: [StandardPhraseDuplicate] {
        return currentPresetConflict?.conflicts ?? []
    }
    
    // 現在処理中のプリセットの非競合フレーズ配列
    private var currentNonConflictingPhrases: [StandardPhrase] {
        return currentPresetConflict?.nonConflictingPhrases ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // タイトル: プリセットが複数ある場合は追加のカウンターを表示
            if let currentPreset = currentPresetConflict {
                let presetCountText = presetConflicts.count > 1 ? " (\(currentPresetIndex + 1)/\(presetConflicts.count))" : ""
                Text("「\(currentPreset.preset.name)」のインポートの競合 (\(currentConflictIndex + 1)/\(currentConflicts.count))\(presetCountText)")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text("以下の定型文は既存の項目とタイトルまたは内容が重複しています。\nタイトルまたは内容のどちらかを編集してください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let conflictBinding = currentConflict {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("既存: ")
                            .font(.headline)
                        Text("タイトル: **\(conflictBinding.wrappedValue.existingPhrase.title)**")
                            .font(.subheadline)
                        Text("内容: \(conflictBinding.wrappedValue.existingPhrase.content)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading) {
                            Text("新しいタイトル:")
                            TextField("新しいタイトル", text: conflictBinding.newPhrase.title)
                                .textFieldStyle(.roundedBorder)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(conflictBinding.wrappedValue.hasTitleConflict ? Color.orange : Color.clear, lineWidth: 1)
                                )
                                .disabled(conflictBinding.wrappedValue.useContentAsTitle)

                            Toggle(isOn: conflictBinding.useContentAsTitle) { // Bindingとして渡す
                                Text("タイトルにコンテンツを使用する")
                            }
                            .onChange(of: conflictBinding.wrappedValue.useContentAsTitle) { _, newValue in
                                if newValue {
                                    conflictBinding.newPhrase.title.wrappedValue = conflictBinding.newPhrase.content.wrappedValue
                                }
                            }
                            .toggleStyle(.checkbox)

                            Text("新しい内容:")
                            TextEditor(text: conflictBinding.newPhrase.content)
                                .frame(minHeight: 60, maxHeight: 150)
                                .border(Color.gray.opacity(0.5), width: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(conflictBinding.wrappedValue.hasContentConflict ? Color.orange : Color.clear, lineWidth: 1)
                                )
                                .onChange(of: conflictBinding.wrappedValue.newPhrase.content) { _, newValue in
                                    if conflictBinding.wrappedValue.useContentAsTitle {
                                        conflictBinding.newPhrase.title.wrappedValue = newValue
                                    }
                                }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                Spacer()
                Text("すべての競合を処理しました。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // MARK: - ボタン配置
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                Button("すべてスキップ") {
                    // 現在のプリセットの処理を完了し、次のプリセットに進む
                    completeCurrentPreset()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("スキップ") {
                    goToNextConflict()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    if let currentConflictValue = currentConflict?.wrappedValue {
                        // 要望の仕様に合わせるため、詳細なチェックを行う
                        // - ローカルの定型文と同じIDで同じコンテンツの場合、新しいIDを割り振って同じコンテンツを重複保存
                        // - 同じコンテンツでIDが異なる場合はIDはそのまま(新しいIDを割り振らずに)追加
                        
                        let newPhraseContent = currentConflictValue.newPhrase.content
                        let newPhraseId = currentConflictValue.newPhrase.id
                        
                        // 現在処理中のプリセットの既存の定型文リストを取得
                        let existingPhrasesInPreset = presetConflicts[currentPresetIndex].preset.phrases
                        
                        // コンテンツが一致する既存の定型文を探す
                        let existingPhraseWithSameContent = existingPhrasesInPreset.first { $0.content == newPhraseContent }
                        
                        let newPhrase: StandardPhrase
                        if let existingPhrase = existingPhraseWithSameContent {
                            // コンテンツが一致する定型文が見つかった場合
                            if existingPhrase.id == newPhraseId {
                                // IDも一致する場合は、新しいUUIDを生成して追加
                                newPhrase = StandardPhrase(id: UUID(), title: currentConflictValue.newPhrase.title, content: newPhraseContent)
                            } else {
                                // IDが一致しない場合は、元のIDを保持して追加
                                newPhrase = StandardPhrase(id: newPhraseId, title: currentConflictValue.newPhrase.title, content: newPhraseContent)
                            }
                        } else {
                            // コンテンツが一致する定型文が見つからない場合は、新しいUUIDを生成して追加
                            // (このケースは「このまま追加」では発生しないはずだが、念のため)
                            newPhrase = StandardPhrase(id: UUID(), title: currentConflictValue.newPhrase.title, content: newPhraseContent)
                        }
                        
                        resolvedPhrasesToImport.append(newPhrase)
                    }
                    goToNextConflict()
                } label: {
                    Text(isConflictUnresolved ? "このまま追加" : "インポート")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(minWidth: 500, idealWidth: 600, maxWidth: 800, minHeight: 400)
    }

    private func goToNextConflict() {
        if currentConflictIndex < currentConflicts.count - 1 {
            currentConflictIndex += 1
        } else {
            // 現在のプリセットの処理を完了し、次のプリセットに進む
            completeCurrentPreset()
        }
    }
    
    // 現在のプリセットの処理を完了し、次のプリセットに進む
    private func completeCurrentPreset() {
        // 現在のプリセットの結果を更新
        if currentPresetIndex < presetConflicts.count {
            let allPhrasesToImport = resolvedPhrasesToImport + currentNonConflictingPhrases
            let updatedNonConflictingPhrases = allPhrasesToImport
            
            // プリセットの競合情報を更新
            presetConflicts[currentPresetIndex] = PresetConflictInfo(
                preset: presetConflicts[currentPresetIndex].preset,
                conflicts: presetConflicts[currentPresetIndex].conflicts,
                nonConflictingPhrases: updatedNonConflictingPhrases
            )
        }
        
        // 次のプリセットに進む
        moveToNextPreset()
    }
    
    // 次のプリセットに進む
    private func moveToNextPreset() {
        // 状態をリセット
        currentConflictIndex = 0
        resolvedPhrasesToImport.removeAll()
        
        // 次のプリセットに進む
        if currentPresetIndex < presetConflicts.count - 1 {
            currentPresetIndex += 1
        } else {
            // すべてのプリセットの処理が完了したので、コールバックを呼び出す
            onAllPresetsCompleted(presetConflicts)
            dismiss()
        }
    }
}
