import SwiftUI

struct AddEditPhraseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager

    enum Mode: Equatable {
        case add
        case edit(StandardPhrase)
    }

    let mode: Mode
    var onSave: ((StandardPhrase) -> Void)? // コールバック追加
    @State var phraseToEdit: StandardPhrase // editモードの場合の元のphraseを保持

    @State private var title: String
    @State private var content: String
    @State private var useContentAsTitle: Bool = false
    @State private var selectedPresetId: UUID? = nil
    @State private var showingAddPresetSheet = false
    @State private var newPresetName = ""

    init(mode: Mode, phraseToEdit: StandardPhrase? = nil, initialContent: String? = nil, presetManager: StandardPhrasePresetManager, onSave: ((StandardPhrase) -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        _phraseToEdit = State(initialValue: phraseToEdit ?? StandardPhrase(title: "", content: ""))

        switch mode {
        case .add:
            _title = State(initialValue: "")
            // MARK: initialContentがあればそれをコンテンツとして使用
            _content = State(initialValue: initialContent ?? "")
            _useContentAsTitle = State(initialValue: false)
            _selectedPresetId = State(initialValue: presetManager.selectedPresetId)
        case .edit(let phrase):
            _title = State(initialValue: phrase.title)
            _content = State(initialValue: phrase.content)
            _useContentAsTitle = State(initialValue: phrase.title == phrase.content)
            _selectedPresetId = State(initialValue: presetManager.selectedPresetId)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mode == .add ? "新しい定型文を追加" : "定型文を編集")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            TextField("タイトル", text: $title)
                .textFieldStyle(.roundedBorder)
                .disabled(useContentAsTitle)

            Toggle(isOn: $useContentAsTitle) {
                Text("タイトルにコンテンツを使用する")
            }
            .onChange(of: useContentAsTitle) {
                if useContentAsTitle {
                    title = content
                }
            }

            TextEditor(text: $content)
                .frame(minHeight: 100, maxHeight: 300)
                .border(Color.gray.opacity(0.5), width: 1)
                .onChange(of: content) {
                    if useContentAsTitle {
                        title = content
                    }
                }

            // プリセット選択ピッカー (追加モードでのみ表示)
            if case .add = mode {
                Picker("保存先のプリセット:", selection: $selectedPresetId) {
                    ForEach(presetManager.presets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                    Divider()
                    Text("新規プリセット...").tag(Optional.some(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
                }
                .padding(.vertical, 10)
                .pickerStyle(.menu)
                .onChange(of: selectedPresetId) { _, newValue in
                    // 新規プリセット...が選択された場合、シートを表示
                    let newPresetUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                    if newValue == newPresetUUID {
                        showingAddPresetSheet = true
                        // ピッカーの選択を元に戻す
                        selectedPresetId = presetManager.selectedPresetId
                    }
                }
            }

            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Spacer()
                Button(mode == .add ? "追加" : "保存") {
                    let finalTitle: String
                    if useContentAsTitle {
                        finalTitle = content
                    } else {
                        finalTitle = title
                    }

                    let phrase = StandardPhrase(title: finalTitle, content: content)
                    
                    if case .add = mode {
                        if let onSave = onSave {
                            onSave(phrase)
                        } else {
                            // プリセットが選択されている場合はプリセットに追加、そうでなければデフォルトに追加
                            if let selectedPresetId = selectedPresetId,
                               var selectedPreset = presetManager.presets.first(where: { $0.id == selectedPresetId }) {
                                selectedPreset.phrases.append(phrase)
                                presetManager.updatePreset(selectedPreset)
                            } else {
                                standardPhraseManager.addPhrase(title: finalTitle, content: content)
                            }
                        }
                    } else if case .edit(let originalPhrase) = mode {
                        let updatedPhrase = StandardPhrase(id: originalPhrase.id, title: finalTitle, content: content)
                        if let onSave = onSave {
                            onSave(updatedPhrase)
                        } else {
                            // プリセットが選択されている場合はプリセットを更新、そうでなければデフォルトを更新
                            if let selectedPresetId = selectedPresetId,
                               var selectedPreset = presetManager.presets.first(where: { $0.id == selectedPresetId }),
                               let index = selectedPreset.phrases.firstIndex(where: { $0.id == originalPhrase.id }) {
                                selectedPreset.phrases[index] = updatedPhrase
                                presetManager.updatePreset(selectedPreset)
                            } else {
                                standardPhraseManager.updatePhrase(id: originalPhrase.id, newTitle: finalTitle, newContent: content)
                            }
                        }
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(content.isEmpty || (!useContentAsTitle && title.isEmpty))
                .controlSize(.large)

            }
        }
        .padding() // ここで全体にパディングが適用される
        .frame(minWidth: 400, minHeight: 350)
        .sheet(isPresented: $showingAddPresetSheet) {
            // プリセット追加画面（シート）を表示
            AddEditPresetView { 
                // シートが閉じられたときの処理
                showingAddPresetSheet = false
            }
        }
        .onAppear {
            // selectedPresetId を初期化
            selectedPresetId = presetManager.selectedPresetId ?? presetManager.presets.first?.id
        }
    }
}


// MARK: - Preview Provider
struct AddEditPhraseView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditPhraseView(mode: .add, presetManager: StandardPhrasePresetManager.shared)
            .environmentObject(StandardPhraseManager.shared)
            .environmentObject(StandardPhrasePresetManager.shared)

        AddEditPhraseView(mode: .edit(StandardPhrase(title: "既存の定型文のタイトル", content: "これは既存の定型文の内容です。")), presetManager: StandardPhrasePresetManager.shared)
            .environmentObject(StandardPhraseManager.shared)
            .environmentObject(StandardPhrasePresetManager.shared)
    }
}

// MARK: - Color Extension for Placeholder Text
extension Color {
    static var placeholderText: Color {
        #if os(macOS)
        return Color(NSColor.placeholderTextColor)
        #else
        return Color(.placeholderText)
        #endif
    }
}
