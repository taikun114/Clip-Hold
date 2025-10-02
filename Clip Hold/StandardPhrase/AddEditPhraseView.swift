import SwiftUI

struct AddEditPhraseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @StateObject var iconGenerator = PresetIconGenerator.shared

    enum Mode: Equatable {
        case add
        case edit(StandardPhrase)
    }

    let mode: Mode
    var onSave: ((StandardPhrase) -> Void)?
    @State var phraseToEdit: StandardPhrase

    @State private var title: String
    @State private var content: String
    @State private var useCustomTitle: Bool = false
    @State private var selectedPresetId: UUID? = nil
    private func isDefaultPreset(id: UUID?) -> Bool {
        id?.uuidString == "00000000-0000-0000-0000-000000000000"
    }
    

    @State private var showingAddPresetSheet = false
    @State private var newPresetName = ""
    private var isSheet: Bool = false
    @FocusState private var isContentFocused: Bool

    private let noPresetsUUID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    private let newPresetUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init(mode: Mode, phraseToEdit: StandardPhrase? = nil, initialContent: String? = nil, presetManager: StandardPhrasePresetManager, isSheet: Bool = false, onSave: ((StandardPhrase) -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        _phraseToEdit = State(initialValue: phraseToEdit ?? StandardPhrase(title: "", content: ""))

        switch mode {
        case .add:
            _title = State(initialValue: "")
            // MARK: initialContentがあればそれをコンテンツとして使用
            _content = State(initialValue: initialContent ?? "")
            _useCustomTitle = State(initialValue: false)
            if presetManager.presets.isEmpty {
                _selectedPresetId = State(initialValue: noPresetsUUID)
            } else {
                _selectedPresetId = State(initialValue: presetManager.selectedPresetId)
            }
        case .edit(let phrase):
            _title = State(initialValue: phrase.title)
            _content = State(initialValue: phrase.content)
            _useCustomTitle = State(initialValue: phrase.title != phrase.content)
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
                .disabled(!useCustomTitle)

            Toggle(isOn: $useCustomTitle) {
                Text("カスタムタイトルを使用する")
            }
            .onChange(of: useCustomTitle) {
                if !useCustomTitle {
                    title = content
                }
            }

            if !showingAddPresetSheet {
                TextEditor(text: $content)
                    .frame(minHeight: 100, maxHeight: 300)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .focused($isContentFocused)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: content) {
                        if !useCustomTitle {
                            title = content
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(minHeight: 100, maxHeight: 300)
                    .padding(.vertical, 8)
            }

            // プリセット選択ピッカー (追加モードでのみ表示)
            if case .add = mode {
                Picker("保存先のプリセット:", selection: $selectedPresetId) {
                    if presetManager.presets.isEmpty {
                        Text("プリセットがありません").tag(noPresetsUUID as UUID?)
                    }
                    ForEach(presetManager.presets) { preset in
                        Label {
                            Text(preset.truncatedDisplayName(maxLength: 50))
                        } icon: {
                                                if let iconImage = iconGenerator.miniIconCache[preset.id] { // Use miniIconCache
                                                    Image(nsImage: iconImage)
                                                } else {
                                                    Image(systemName: "star.fill") // Fallback
                                                }                        }
                        .tag(preset.id as UUID?)
                    }
                    Divider()
                    Text("新規プリセット...").tag(newPresetUUID as UUID?)
                }
                .pickerStyle(.menu)
                .labelStyle(.titleAndIcon)
                .onChange(of: selectedPresetId) { _, newValue in
                    // 新規プリセット...が選択された場合、シートを表示
                    if newValue == newPresetUUID {
                        isContentFocused = false
                        showingAddPresetSheet = true
                        // ピッカーの選択を元に戻す
                        if presetManager.presets.isEmpty {
                            selectedPresetId = noPresetsUUID
                        } else {
                            selectedPresetId = presetManager.selectedPresetId
                        }
                    }
                }
                .padding(.top, 10)
            }

            Spacer()
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Spacer()
                Button(mode == .add ? "追加" : "保存") {
                    let finalTitle: String
                    if useCustomTitle {
                        finalTitle = title
                    } else {
                        finalTitle = content
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
                .disabled(content.isEmpty || (useCustomTitle && title.isEmpty) || selectedPresetId == noPresetsUUID)
                .controlSize(.large)
            }
        }
        .padding() // ここで全体にパディングが適用される
        .frame(minWidth: 400, minHeight: 350)
        .onAppear {
            isContentFocused = true
        }
        .sheet(isPresented: $showingAddPresetSheet) {
            // プリセット追加画面（シート）を表示
            AddEditPresetView(onDismiss: {
                showingAddPresetSheet = false
            }, editingPreset: nil)
        }
        .onChange(of: showingAddPresetSheet) { _, isShowing in
            if !isShowing {
                isContentFocused = true
            }
        }
        .onReceive(presetManager.presetAddedSubject) { _ in
            if selectedPresetId == noPresetsUUID {
                selectedPresetId = presetManager.presets.first?.id
            }
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
