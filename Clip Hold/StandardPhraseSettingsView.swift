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
    @State private var showingClearAllPresetsConfirmation = false

    @State private var selectedPhraseId: UUID? = nil
    
    // プリセット追加シート用の状態変数
    @State private var showingAddPresetSheet = false
    @State private var showingEditPresetSheet = false
    @State private var newPresetName = ""
    @State private var editingPreset: StandardPhrasePreset?
    @State private var selectedPresetId: UUID? = nil
    @State private var presetToDelete: StandardPhrasePreset?
    @State private var showingDeletePresetConfirmation = false
    
    // プリセット巡回時の通知設定
    @AppStorage("sendNotificationOnPresetChange") private var sendNotificationOnPresetChange: Bool = false
    
    var body: some View {
        Form {
            // MARK: - プリセットセクション
            Section(header:
                VStack(alignment: .leading, spacing: 4) {
                    Text("プリセットの設定")
                        .font(.headline)

                    Text("プリセットの順番はドラッグアンドドロップで並び替えることができます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            ) {
                Toggle("ショートカットキーで切り替えたときに通知を送信する", isOn: $sendNotificationOnPresetChange)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                List(selection: $selectedPresetId) {
                    ForEach(presetManager.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(displayName(for: preset))
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
                    if let selectedId = selection.first {
                        Button {
                            if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                                editingPreset = preset
                                newPresetName = preset.name
                                showingEditPresetSheet = true
                            }
                        } label: {
                            Label("編集...", systemImage: "pencil")
                        }
                        .disabled(isDefaultPreset(id: selectedId))
                        Divider()
                        Button(role: .destructive) {
                            if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                                presetToDelete = preset
                                showingDeletePresetConfirmation = true
                            }
                        } label: {
                            Label("削除...", systemImage: "trash")
                        }
                    }
                } primaryAction: { selection in
                    if let selectedId = selection.first, !isDefaultPreset(id: selectedId) {
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
                            .disabled(selectedPresetId == nil || isDefaultPreset(id: selectedPresetId))
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
                HStack {
                    Text("プリセット")
                    Spacer()
                    Picker("", selection: Binding(
                        get: {
                            // プリセットが空の場合、特別なUUIDを返す
                            if presetManager.presets.isEmpty {
                                return UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                            }
                            return presetManager.selectedPresetId
                        },
                        set: { newValue in
                            // UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")は「プリセットがありません」のタグ
                            if newValue?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                                // プリセットがない場合は何もしない
                                // 選択を元に戻す
                                if let firstPreset = presetManager.presets.first {
                                    presetManager.selectedPresetId = firstPreset.id
                                } else {
                                    // まだプリセットがない場合はnilのまま
                                    presetManager.selectedPresetId = nil
                                }
                            } else if newValue == nil {
                                showingAddPresetSheet = true
                                // 選択を元に戻す
                                if let currentSelectedId = presetManager.selectedPresetId {
                                    presetManager.selectedPresetId = currentSelectedId
                                } else if let firstPreset = presetManager.presets.first {
                                    presetManager.selectedPresetId = firstPreset.id
                                }
                            } else {
                                presetManager.selectedPresetId = newValue
                            }
                        }
                    )) {
                        ForEach(presetManager.presets) { preset in
                            Text(displayName(for: preset))
                                .tag(preset.id as UUID?)
                        }
                        
                        // プリセットがない場合の項目
                        if presetManager.presets.isEmpty {
                            Text("プリセットがありません")
                                .tag(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") as UUID?)
                        }
                        
                        Divider()
                        Text("新規プリセット...")
                            .tag(nil as UUID?)
                    }
                    .pickerStyle(.menu)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
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
                
                HStack {
                    Text("\(presetManager.presets.count)個のプリセット")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        showingClearAllPresetsConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべてのプリセットを削除")
                        }
                        .if(!presetManager.presets.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(presetManager.presets.isEmpty)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddPhraseSheet) {
            AddEditPhraseView(mode: .add) { newPhrase in
                addPhrase(newPhrase)
            }
            .environmentObject(standardPhraseManager)
            .environmentObject(presetManager)
        }
        .sheet(item: $selectedPhrase) { phrase in
            AddEditPhraseView(mode: .edit(phrase), phraseToEdit: phrase) { editedPhrase in
                updatePhrase(editedPhrase)
            }
            .environmentObject(standardPhraseManager)
            .environmentObject(presetManager)
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
            if let preset = presetToDelete {
                Text("「\(displayName(for: preset))」を本当に削除しますか？")
            } else {
                Text("このプリセットを本当に削除しますか？")
            }
        }
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) {
                deleteAllPhrases()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            if let preset = presetManager.selectedPreset {
                Text("プリセット「\(displayName(for: preset))」からすべての定型文を本当に削除しますか？この操作は元に戻せません。")
            } else {
                Text("選択されているプリセットからすべての定型文を本当に削除しますか？この操作は元に戻せません。")
            }
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
                    Button("キャンセル", role: .cancel) {
                        showingAddPresetSheet = false
                        newPresetName = ""
                    }
                    .controlSize(.large)

                    Spacer()
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
                    Button("キャンセル", role: .cancel) {
                        showingEditPresetSheet = false
                        newPresetName = ""
                    }
                    .controlSize(.large)

                    Spacer()
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
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) {
                deleteAllPhrases()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            if let preset = presetManager.selectedPreset {
                Text("プリセット「\(displayName(for: preset))」からすべての定型文を本当に削除しますか？この操作は元に戻せません。")
            } else {
                Text("選択されているプリセットからすべての定型文を本当に削除しますか？この操作は元に戻せません。")
            }
        }
        .alert("すべてのプリセットを削除", isPresented: $showingClearAllPresetsConfirmation) {
            Button("削除", role: .destructive) {
                presetManager.deleteAllPresets()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("すべてのプリセットを本当に削除しますか？この操作は元に戻せません。")
        }
    }
}

// MARK: - Helper Methods
extension StandardPhraseSettingsView {
    private func displayName(for preset: StandardPhrasePreset) -> String {
        if preset.id.uuidString == "00000000-0000-0000-0000-000000000000" {
            return String(localized: "Default")
        }
        return preset.name
    }
    
    private func isDefaultPreset(id: UUID?) -> Bool {
        guard let id = id else { return false }
        return id.uuidString == "00000000-0000-0000-0000-000000000000"
    }
    
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
        let idsToDelete = offsets.map { presetManager.presets[$0].id }
        for id in idsToDelete {
            presetManager.deletePreset(id: id)
        }
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
