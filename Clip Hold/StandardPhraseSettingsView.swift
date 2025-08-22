import SwiftUI
import UniformTypeIdentifiers

// MARK: - StandardPhraseSettingsView
struct StandardPhraseSettingsView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @StateObject private var presetManager = StandardPhrasePresetManager.shared

    @State private var showingAddPhraseSheet = false
    @State private var selectedPhrase: StandardPhrase?
    @State private var showingDeleteConfirmation = false
    @State private var phraseToDelete: StandardPhrase?
    @State private var showingClearAllPhrasesConfirmation = false

    @State private var selectedPhraseId: UUID? = nil
    
    // プリセット追加シート用の状態変数
    @State private var showingAddPresetSheet = false
    @State private var showingEditPresetSheet = false
    @State private var newPresetName = ""
    @State private var editingPreset: StandardPhrasePreset?
    @State private var selectedPresetId: UUID? = nil
    @State private var presetToDelete: StandardPhrasePreset?
    @State private var showingDeletePresetConfirmation = false
    
    var body: some View {
        Form {
            // MARK: - 定型文の管理セクション
            Section(header: Text("定型文の管理").font(.headline)) {
                StandardPhraseImportExportView()
                    .environmentObject(standardPhraseManager)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    Text("\(currentPhrases.count)個の定型文")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        showingClearAllPhrasesConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべての定型文を削除")
                        }
                        .if(!currentPhrases.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentPhrases.isEmpty)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            // MARK: - プリセットセクション
            Section(header: Text("プリセット").font(.headline)) {
                HStack {
                    Text("プリセット")
                    Spacer()
                    Picker("", selection: $presetManager.selectedPresetId) {
                        ForEach(presetManager.presets) { preset in
                            Text(preset.name)
                                .tag(preset.id as UUID?)
                        }
                        Divider()
                        Text("新規プリセット...")
                            .tag(nil as UUID?)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: presetManager.selectedPresetId) { _, newValue in
                        if newValue == nil {
                            showingAddPresetSheet = true
                            // 選択を元に戻す
                            if let currentSelectedId = presetManager.selectedPresetId {
                                presetManager.selectedPresetId = currentSelectedId
                            } else if let firstPreset = presetManager.presets.first {
                                presetManager.selectedPresetId = firstPreset.id
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                List(selection: $selectedPresetId) {
                    ForEach(presetManager.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text("\(preset.phrases.count)個の定型文")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .tag(preset.id)
                        .contentShape(Rectangle())
                    }
                    .onDelete(perform: deletePreset)
                    .onMove(perform: movePreset)
                }
                .listStyle(.plain)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 24)
                .contextMenu(forSelectionType: UUID.self) { selection in
                    if selection.count == 1 {
                        Button {
                            if let selectedId = selection.first {
                                if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                                    editingPreset = preset
                                    newPresetName = preset.name
                                    showingEditPresetSheet = true
                                }
                            }
                        } label: {
                            Label("編集...", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            if let selectedId = selection.first {
                                if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                                    presetToDelete = preset
                                    showingDeletePresetConfirmation = true
                                }
                            }
                        } label: {
                            Label("削除...", systemImage: "trash")
                        }
                    }
                } primaryAction: { selection in
                    if let selectedId = selection.first {
                        if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                            editingPreset = preset
                            newPresetName = preset.name
                            showingEditPresetSheet = true
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            Button(action: {
                                showingAddPresetSheet = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(x: 2.0, y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .help("新しいプリセットをリストに追加します。")
                            
                            Divider()
                                .frame(width: 1, height: 16)
                                .background(Color.gray.opacity(0.1))
                                .padding(.horizontal, 4)
                            
                            Button(action: {
                                if let selectedId = selectedPresetId {
                                    if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                                        presetToDelete = preset
                                        showingDeletePresetConfirmation = true
                                    }
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -0.5)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPresetId == nil)
                            .help("選択したプリセットをリストから削除します。")
                            
                            Spacer()
                            
                            Button(action: {
                                if let selectedId = selectedPresetId {
                                    if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                                        editingPreset = preset
                                        newPresetName = preset.name
                                        showingEditPresetSheet = true
                                    }
                                }
                            }) {
                                Image(systemName: "pencil")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPresetId == nil)
                            .help("選択したプリセットを編集します。")
                        }
                        .background(Rectangle().opacity(0.04))
                    }
                }
            }

            // MARK: - 定型文の設定セクション
            Section(header:
                VStack(alignment: .leading, spacing: 4) {
                    Text("定型文の設定")
                        .font(.headline)

                    Text("定型文の順番はドラッグアンドドロップで並び替えることができます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            ) {
                List(selection: $selectedPhraseId) {
                    ForEach(currentPhrases) { phrase in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(phrase.title)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text(phrase.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .tag(phrase.id)
                        .contentShape(Rectangle()) // これによりHStack全体がヒットテスト可能になる
                        .help(phrase.content)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("タイトル: \(phrase.title)、内容: \(phrase.content)")
                    }
                    .onMove(perform: movePhrase)
                    .onDelete { indexSet in
                        deletePhrase(atOffsets: indexSet)
                        selectedPhraseId = nil
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 24)
                .accessibilityLabel("定型文リスト")
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            Button(action: {
                                showingAddPhraseSheet = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(x: 2.0, y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .help("新しい定型文をリストに追加します。")

                            Divider()
                                .frame(width: 1, height: 16)
                                .background(Color.gray.opacity(0.1))
                                .padding(.horizontal, 4)

                            Button(action: {
                                if let selectedId = selectedPhraseId {
                                    if let phrase = currentPhrases.first(where: { $0.id == selectedId }) {
                                        phraseToDelete = phrase
                                        showingDeleteConfirmation = true
                                    }
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -0.5)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPhraseId == nil)
                            .help("選択した定型文をリストから削除します。")

                            Spacer()

                            Button(action: {
                                if let selectedId = selectedPhraseId {
                                    if let phrase = currentPhrases.first(where: { $0.id == selectedId }) {
                                        selectedPhrase = phrase
                                    }
                                }
                            }) {
                                Image(systemName: "pencil")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPhraseId == nil)
                            .help("選択した定型文を編集します。")
                        }
                        .background(Rectangle().opacity(0.04))
                    }
                }
                .contextMenu(forSelectionType: UUID.self) { selection in
                    if !selection.isEmpty {
                        Button {
                            if let firstSelectedId = selection.first {
                                if let phraseToEdit = currentPhrases.first(where: { $0.id == firstSelectedId }) {
                                    selectedPhrase = phraseToEdit
                                }
                            }
                        } label: {
                            Label("編集...", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            let phrasesToDelete = currentPhrases.filter { selection.contains($0.id) }
                            if let firstPhrase = phrasesToDelete.first {
                                phraseToDelete = firstPhrase
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Label("削除...", systemImage: "trash")
                        }
                    }
                } primaryAction: { selection in
                    if let firstSelectedId = selection.first {
                        if let phraseToEdit = currentPhrases.first(where: { $0.id == firstSelectedId }) {
                            selectedPhrase = phraseToEdit
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddPhraseSheet) {
            AddEditPhraseView(mode: .add) { newPhrase in
                addPhrase(newPhrase)
            }
            .environmentObject(standardPhraseManager)
        }
        .sheet(item: $selectedPhrase) { phrase in
            AddEditPhraseView(mode: .edit(phrase), phraseToEdit: phrase) { editedPhrase in
                updatePhrase(editedPhrase)
            }
            .environmentObject(standardPhraseManager)
        }
        .alert("定型文の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let phrase = phraseToDelete {
                    deletePhrase(id: phrase.id)
                    phraseToDelete = nil
                    selectedPhraseId = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                phraseToDelete = nil
            }
        } message: {
            Text("「\(phraseToDelete?.title ?? "この定型文")」を本当に削除しますか？")
        }
        .alert("プリセットの削除", isPresented: $showingDeletePresetConfirmation) {
            Button("削除", role: .destructive) {
                if let preset = presetToDelete {
                    deletePreset(id: preset.id)
                    presetToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                presetToDelete = nil
            }
        } message: {
            Text("「\(presetToDelete?.name ?? "このプリセット")」を本当に削除しますか？")
        }
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) {
                deleteAllPhrases()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("すべての定型文を本当に削除しますか？この操作は元に戻せません。")
        }
        .sheet(isPresented: $showingAddPresetSheet) {
            VStack(spacing: 10) {
                HStack {
                    Text("プリセット名を入力")
                        .font(.headline)
                    Spacer()
                }

                TextField("プリセット名", text: $newPresetName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !newPresetName.isEmpty {
                            addPreset(name: newPresetName)
                            newPresetName = ""
                        }
                    }

                Spacer()

                HStack {
                    Spacer()
                    Button("キャンセル", role: .cancel) {
                        showingAddPresetSheet = false
                        newPresetName = ""
                    }
                    .controlSize(.large)

                    Button("保存") {
                        addPreset(name: newPresetName)
                        newPresetName = ""
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.isEmpty)
                }
            }
            .padding()
            .frame(width: 300, height: 140)
        }
        .sheet(isPresented: $showingEditPresetSheet) {
            VStack(spacing: 10) {
                HStack {
                    Text("プリセット名を入力")
                        .font(.headline)
                    Spacer()
                }

                TextField("プリセット名", text: $newPresetName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !newPresetName.isEmpty, let preset = editingPreset {
                            updatePreset(preset, newName: newPresetName)
                            newPresetName = ""
                        }
                    }

                Spacer()

                HStack {
                    Spacer()
                    Button("キャンセル", role: .cancel) {
                        showingEditPresetSheet = false
                        newPresetName = ""
                    }
                    .controlSize(.large)

                    Button("保存") {
                        if let preset = editingPreset {
                            updatePreset(preset, newName: newPresetName)
                            newPresetName = ""
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(newPresetName.isEmpty)
                }
            }
            .padding()
            .frame(width: 300, height: 140)
        }
    }
}

// MARK: - Helper Methods
extension StandardPhraseSettingsView {
    private var currentPhrases: [StandardPhrase] {
        presetManager.selectedPreset?.phrases ?? []
    }
    
    private func addPhrase(_ phrase: StandardPhrase) {
        guard var selectedPreset = presetManager.selectedPreset else { return }
        selectedPreset.phrases.append(phrase)
        presetManager.updatePreset(selectedPreset)
    }
    
    private func updatePhrase(_ phrase: StandardPhrase) {
        guard var selectedPreset = presetManager.selectedPreset else { return }
        if let index = selectedPreset.phrases.firstIndex(where: { $0.id == phrase.id }) {
            selectedPreset.phrases[index] = phrase
            presetManager.updatePreset(selectedPreset)
        }
    }
    
    private func deletePhrase(id: UUID) {
        guard var selectedPreset = presetManager.selectedPreset else { return }
        selectedPreset.phrases.removeAll { $0.id == id }
        presetManager.updatePreset(selectedPreset)
    }
    
    private func deletePhrase(atOffsets indexSet: IndexSet) {
        guard var selectedPreset = presetManager.selectedPreset else { return }
        selectedPreset.phrases.remove(atOffsets: indexSet)
        presetManager.updatePreset(selectedPreset)
    }
    
    private func movePhrase(from source: IndexSet, to destination: Int) {
        guard var selectedPreset = presetManager.selectedPreset else { return }
        selectedPreset.phrases.move(fromOffsets: source, toOffset: destination)
        presetManager.updatePreset(selectedPreset)
    }
    
    private func deleteAllPhrases() {
        guard var selectedPreset = presetManager.selectedPreset else { return }
        selectedPreset.phrases = []
        presetManager.updatePreset(selectedPreset)
    }
    
    private func addPreset(name: String) {
        presetManager.addPreset(name: name)
        showingAddPresetSheet = false
    }
    
    private func updatePreset(_ preset: StandardPhrasePreset, newName: String) {
        guard let index = presetManager.presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presetManager.presets[index].name = newName
        presetManager.updatePreset(presetManager.presets[index])
        showingEditPresetSheet = false
    }
    
    private func deletePreset(id: UUID) {
        presetManager.deletePreset(id: id)
        selectedPresetId = nil
    }
    
    private func deletePreset(offsets: IndexSet) {
        presetManager.presets.remove(atOffsets: offsets)
        selectedPresetId = nil
    }
    
    private func movePreset(from source: IndexSet, to destination: Int) {
        presetManager.presets.move(fromOffsets: source, toOffset: destination)
        presetManager.savePresetIndex()
    }
}

#Preview {
    StandardPhraseSettingsView()
        .environmentObject(StandardPhraseManager.shared)
}
