import SwiftUI
import Foundation

struct ImportConflictSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager

    @Binding var conflicts: [StandardPhraseDuplicate]
    @Binding var nonConflictingPhrases: [StandardPhrase] // 競合しなかったフレーズ

    var onCompletion: ([StandardPhrase]) -> Void // このクロージャが、順序を維持したまま追加されるフレーズのリストを受け取る

    @State private var currentIndex: Int = 0
    // resolvedPhrasesToImport には、ユーザーが「インポート」または「このまま追加」を選択したフレーズが追加される。
    // これらは常に新しいIDを持つべき。
    @State private var resolvedPhrasesToImport: [StandardPhrase] = []

    private var currentConflict: Binding<StandardPhraseDuplicate>? {
        guard currentIndex < conflicts.count else { return nil }
        return $conflicts[currentIndex]
    }

    private var isConflictUnresolved: Bool {
        if let conflict = currentConflict?.wrappedValue {
            return conflict.hasTitleConflict || conflict.hasContentConflict
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("インポートの競合 (\(currentIndex + 1) / \(conflicts.count))")
                .font(.headline)
                .fontWeight(.bold)

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
                    // MARK: - 修正: resolvedPhrasesToImport は新しいID、nonConflictingPhrases は元のIDを保持
                    let allPhrasesToImport = resolvedPhrasesToImport.map { phrase in
                        let newPhrase = StandardPhrase(id: UUID(), title: phrase.title, content: phrase.content) // 常に新しいID
                        return newPhrase
                    } + nonConflictingPhrases // nonConflictingPhrasesは元のIDを保持

                    onCompletion(allPhrasesToImport)
                    dismiss()
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
                        let newPhrase = StandardPhrase(id: UUID(), title: currentConflictValue.newPhrase.title, content: currentConflictValue.newPhrase.content) // 新しいIDを生成
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
        if currentIndex < conflicts.count - 1 {
            currentIndex += 1
        } else {
            let allPhrasesToImport = resolvedPhrasesToImport.map { phrase in
                let newPhrase = StandardPhrase(id: UUID(), title: phrase.title, content: phrase.content) // resolvedPhrasesToImportは常に新しいID
                return newPhrase
            } + nonConflictingPhrases // nonConflictingPhrasesは元のIDを保持

            onCompletion(allPhrasesToImport)
            dismiss()
        }
    }
}
