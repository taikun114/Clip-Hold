
import SwiftUI
import UniformTypeIdentifiers

// MARK: - StandardPhraseSettingsView
struct StandardPhraseSettingsView: View {
    @StateObject private var presetManager = StandardPhrasePresetManager.shared
    @StateObject private var assignmentManager = PresetAppAssignmentManager.shared
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager

    var body: some View {
        Form {
            PresetSettingsSection()
            PresetAssignmentSection()
            PhraseSettingsSection()
            PhraseManagementSection()
        }
        .formStyle(.grouped)
        .environmentObject(presetManager)
        .environmentObject(assignmentManager)
        .environmentObject(standardPhraseManager)
    }
}

// MARK: - PresetSettingsSection
private struct PresetSettingsSection: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    
    @State private var selectedPresetId: UUID? = nil
    @State private var showingAddPresetSheet = false
    @State private var showingEditPresetSheet = false
    @State private var newPresetName = ""
    @State private var editingPreset: StandardPhrasePreset?
    @State private var presetToDelete: StandardPhrasePreset?
    @State private var showingDeletePresetConfirmation = false
    @AppStorage("sendNotificationOnPresetChange") private var sendNotificationOnPresetChange: Bool = true

    var body: some View {
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
                    } label: { Label("編集...", systemImage: "pencil") }
                    .disabled(isDefaultPreset(id: selectedId))
                    Divider()
                    Button(role: .destructive) {
                        if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                            presetToDelete = preset
                            showingDeletePresetConfirmation = true
                        }
                    } label: { Label("削除...", systemImage: "trash") }
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
            .overlay(alignment: .bottom) { bottomToolbar }
        }
        .sheet(isPresented: $showingAddPresetSheet) { addPresetSheet }
        .sheet(isPresented: $showingEditPresetSheet) { editPresetSheet }
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
    }

    private var bottomToolbar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button(action: { showingAddPresetSheet = true }) {
                    Image(systemName: "plus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: 2.0, y: -1.0)
                }
                .buttonStyle(.borderless)
                .help(Text("新しいプリセットをリストに追加します。"))
                divider
                Button(action: {
                    if let selectedId = selectedPresetId, let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                        presetToDelete = preset
                        showingDeletePresetConfirmation = true
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -0.5)
                }
                .buttonStyle(.borderless)
                .disabled(selectedPresetId == nil)
                .help(Text("選択したプリセットをリストから削除します。"))
                Spacer()
                Button(action: {
                    if let selectedId = selectedPresetId, let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                        editingPreset = preset
                        newPresetName = preset.name
                        showingEditPresetSheet = true
                    }
                }) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -0.5)
                }
                .buttonStyle(.borderless)
                .disabled(selectedPresetId == nil || isDefaultPreset(id: selectedPresetId))
                .help(Text("選択したプリセットを編集します。"))
            }
            .background(Rectangle().opacity(0.04))
        }
    }
    
    private var divider: some View {
        Divider()
            .frame(width: 1, height: 16)
            .background(Color.gray.opacity(0.1))
            .padding(.horizontal, 4)
    }

    private var addPresetSheet: some View {
        PresetNameSheet(name: $newPresetName, title: String(localized: "プリセット名を入力")) {
            addPreset(name: newPresetName)
            newPresetName = ""
            showingAddPresetSheet = false
        } onCancel: {
            showingAddPresetSheet = false
            newPresetName = ""
        }
    }

    private var editPresetSheet: some View {
        PresetNameSheet(name: $newPresetName, title: String(localized: "プリセット名を編集")) {
            if let preset = editingPreset {
                updatePreset(preset, newName: newPresetName)
                newPresetName = ""
                showingEditPresetSheet = false
            }
        } onCancel: {
            showingEditPresetSheet = false
            newPresetName = ""
        }
    }
    
    private func displayName(for preset: StandardPhrasePreset) -> String {
        isDefaultPreset(id: preset.id) ? String(localized: "Default") : preset.name
    }

    private func isDefaultPreset(id: UUID?) -> Bool {
        id?.uuidString == "00000000-0000-0000-0000-000000000000"
    }

    private func addPreset(name: String) {
        presetManager.addPreset(name: name)
    }

    private func updatePreset(_ preset: StandardPhrasePreset, newName: String) {
        guard let index = presetManager.presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presetManager.presets[index].name = newName
        presetManager.updatePreset(presetManager.presets[index])
    }

    private func deletePreset(id: UUID) {
        presetManager.deletePreset(id: id)
        selectedPresetId = nil
    }

    private func deletePreset(offsets: IndexSet) {
        let idsToDelete = offsets.map { presetManager.presets[$0].id }
        idsToDelete.forEach { presetManager.deletePreset(id: $0) }
        selectedPresetId = nil
    }

    private func movePreset(from source: IndexSet, to destination: Int) {
        presetManager.presets.move(fromOffsets: source, toOffset: destination)
        presetManager.savePresetIndex()
    }
}

// MARK: - PresetAssignmentSection
private struct PresetAssignmentSection: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @EnvironmentObject var assignmentManager: PresetAppAssignmentManager

    @State private var selectedPresetForAssignmentId: UUID? = StandardPhrasePresetManager.shared.presets.first?.id
    @State private var isShowingAddAppPopover: Bool = false
    @State private var showingFinderPanel = false
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var selectedAssignedAppId: String? = nil
    @State private var showingClearAssignmentsConfirmation = false
    
    // アラート表示用の状態変数
    @State private var showingAssignmentConflictAlert = false
    @State private var conflictingBundleIdentifier: String = ""
    @State private var conflictingPresetId: UUID?
    @State private var targetPresetId: UUID?

    private var assignedApps: [String] {
        guard let presetId = selectedPresetForAssignmentId else { return [] }
        return assignmentManager.getAssignments(for: presetId).sorted { id1, id2 in
            appName(for: id1).localizedCaseInsensitiveCompare(appName(for: id2)) == .orderedAscending
        }
    }

    var body: some View {
        Section(header:
            VStack(alignment: .leading, spacing: 4) {
                Text("プリセットの割り当て")
                    .font(.headline)
                Text("プリセットをアプリに割り当てると、そのアプリが最前面の時は、自動で選択されたプリセットに切り替わるようになります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        ) {
            Picker("割り当てるプリセット", selection: $selectedPresetForAssignmentId) {
                ForEach(presetManager.presets) { preset in
                    Text(displayName(for: preset)).tag(preset.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            List(selection: $selectedAssignedAppId) {
                ForEach(assignedApps, id: \.self) { bundleIdentifier in
                    AppRowView(bundleIdentifier: bundleIdentifier)
                        .tag(bundleIdentifier)
                }
                .onDelete(perform: deleteAssignedApp)
            }
            .listStyle(.plain)
            .frame(minHeight: 100)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 24)
            .overlay(alignment: .bottom) { bottomToolbar }
        }
        .onAppear {
            if selectedPresetForAssignmentId == nil {
                selectedPresetForAssignmentId = presetManager.presets.first?.id
            }
        }
        .background(
            AppSelectionImporterView(isPresented: $showingFinderPanel) { bundleIdentifier in
                if let presetId = selectedPresetForAssignmentId {
                    handleAppAssignment(for: presetId, bundleIdentifier: bundleIdentifier)
                }
            } onSelectionCancelled: { }
            .frame(width: 0, height: 0).clipped()
        )
        .alert("すべての割り当てを削除", isPresented: $showingClearAssignmentsConfirmation) {
            Button("削除", role: .destructive) { clearAllAssignments() }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このプリセットに割り当てられているすべてのアプリをリストから削除しますか？")
        }
        .alert("すでに割り当てられたアプリ", isPresented: $showingAssignmentConflictAlert) {
            Button("キャンセル", role: .cancel) {
                // 何もしない
            }
            Button("割り当てる") {
                if let presetId = targetPresetId, let bundleId = conflictingBundleIdentifier.isEmpty ? nil : conflictingBundleIdentifier {
                    assignmentManager.removeAssignment(for: bundleId)
                    assignmentManager.addAssignment(for: presetId, bundleIdentifier: bundleId)
                }
            }
            .keyboardShortcut(.defaultAction) // プライマリアクションとして設定
        } message: {
            if let bundleId = conflictingBundleIdentifier.isEmpty ? nil : conflictingBundleIdentifier,
               let presetId = conflictingPresetId,
               let preset = presetManager.presets.first(where: { $0.id == presetId }) {
                // ローカライズされたアプリ名を取得
                let appName = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }?.localizedName ?? self.appName(for: bundleId)
                Text("「\(appName)」は別のプリセット「\(displayName(for: preset))」にすでに割り当てられています。このアプリを割り当てると、「\(displayName(for: preset))」から割り当てが解除されます。アプリを割り当ててもよろしいですか？")
            } else {
                Text("このアプリは既に別のプリセットに割り当てられています。上書きしてもよろしいですか？")
            }
        }
    }

    private var bottomToolbar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button(action: {
                    runningApplications = NSWorkspace.shared.runningApplications
                    isShowingAddAppPopover = true
                }) {
                    Image(systemName: "plus").font(.body).fontWeight(.medium).frame(width: 24, height: 24).offset(x: 2.0, y: -1.0)
                }
                .buttonStyle(.borderless)
                .help(Text("割り当てるアプリを追加します。"))
                .popover(isPresented: $isShowingAddAppPopover, arrowEdge: .leading) {
                    AppSelectionPopoverView(
                        runningApplications: $runningApplications,
                        assignedApps: assignedApps,
                        onAppSelected: { bundleIdentifier in
                            if let presetId = selectedPresetForAssignmentId {
                                handleAppAssignment(for: presetId, bundleIdentifier: bundleIdentifier)
                            }
                            isShowingAddAppPopover = false
                        },
                        onSelectFromFinder: {
                            showingFinderPanel = true
                            isShowingAddAppPopover = false
                        }
                    )
                }

                Divider().frame(width: 1, height: 16).background(Color.gray.opacity(0.1)).padding(.horizontal, 4)

                Button(action: {
                    if let selectedId = selectedAssignedAppId {
                        deleteAssignedApp(bundleIdentifier: selectedId)
                    }
                }) {
                    Image(systemName: "minus").font(.body).fontWeight(.medium).frame(width: 24, height: 24).offset(y: -0.5)
                }
                .buttonStyle(.borderless)
                .disabled(selectedAssignedAppId == nil)
                .help(Text("選択したアプリをリストから削除します。"))
                
                Spacer()

                Button(action: {
                    showingClearAssignmentsConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: -2.0, y: -2.0)
                        .if(!assignedApps.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                }
                .buttonStyle(.borderless)
                .disabled(assignedApps.isEmpty)
                .help(Text("このプリセットのすべての割り当てを削除します。"))
            }
            .background(Rectangle().opacity(0.04))
        }
    }
    
    private func displayName(for preset: StandardPhrasePreset) -> String {
        preset.id.uuidString == "00000000-0000-0000-0000-000000000000" ? String(localized: "Default") : preset.name
    }

    private func appName(for bundleIdentifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: url),
           let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return bundleIdentifier
    }

    private func handleAppAssignment(for presetId: UUID, bundleIdentifier: String) {
        // 既に他のプリセットに割り当てられているか確認
        if let existingPresetId = assignmentManager.getPresetId(for: bundleIdentifier),
           existingPresetId != presetId {
            // 割り当てが存在し、異なるプリセットへの割り当ての場合はアラートを表示
            conflictingBundleIdentifier = bundleIdentifier
            conflictingPresetId = existingPresetId
            targetPresetId = presetId
            showingAssignmentConflictAlert = true
        } else {
            // 新規割り当てまたは同じプリセットへの再割り当ての場合はそのまま追加
            assignmentManager.addAssignment(for: presetId, bundleIdentifier: bundleIdentifier)
        }
    }

    private func deleteAssignedApp(at offsets: IndexSet) {
        guard let presetId = selectedPresetForAssignmentId else { return }
        offsets.map { assignedApps[$0] }.forEach {
            assignmentManager.removeAssignment(for: presetId, bundleIdentifier: $0)
        }
        selectedAssignedAppId = nil
    }

    private func deleteAssignedApp(bundleIdentifier: String) {
        guard let presetId = selectedPresetForAssignmentId else { return }
        assignmentManager.removeAssignment(for: presetId, bundleIdentifier: bundleIdentifier)
        selectedAssignedAppId = nil
    }

    private func clearAllAssignments() {
        guard let presetId = selectedPresetForAssignmentId else { return }
        assignmentManager.clearAssignments(for: presetId)
    }
}

// MARK: - PhraseSettingsSection
private struct PhraseSettingsSection: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager

    @State private var selectedPhraseId: UUID? = nil
    @State private var showingAddPhraseSheet = false
    @State private var selectedPhrase: StandardPhrase?
    @State private var phraseToDelete: StandardPhrase?
    @State private var showingDeleteConfirmation = false
    @State private var showingClearAllPhrasesConfirmation = false

    private var currentPhrases: [StandardPhrase] {
        presetManager.selectedPreset?.phrases ?? []
    }

    var body: some View {
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
                presetPicker
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            List(selection: $selectedPhraseId) {
                ForEach(currentPhrases) { phrase in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(phrase.title).font(.headline).lineLimit(1)
                            Text(phrase.content).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .tag(phrase.id)
                    .contentShape(Rectangle())
                    .help(phrase.content)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(format: NSLocalizedString("タイトル: %@、内容: %@", comment: ""), phrase.title, phrase.content))
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
            .overlay(alignment: .bottom) { bottomToolbar }
            .contextMenu(forSelectionType: UUID.self) { selection in
                contextMenuItems(for: selection)
            } primaryAction: { selection in
                if let id = selection.first, let phrase = currentPhrases.first(where: { $0.id == id }) {
                    selectedPhrase = phrase
                }
            }
        }
        .sheet(isPresented: $showingAddPhraseSheet) { addSheet }
        .sheet(item: $selectedPhrase) { phrase in editSheet(for: phrase) }
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) { deleteAllPhrases() }
        } message: {
            if let preset = presetManager.selectedPreset {
                Text("プリセット「\(displayName(for: preset))」からすべての定型文を本当に削除しますか？この操作は元に戻せません。")
            } else {
                Text("選択されているプリセットからすべての定型文を本当に削除しますか？この操作は元に戻せません。")
            }
        }
        .alert("定型文の削除", isPresented: $showingDeleteConfirmation, presenting: phraseToDelete) { phrase in
            Button("削除", role: .destructive) {
                deletePhrase(id: phrase.id)
                phraseToDelete = nil
                selectedPhraseId = nil
            }
        } message: { phrase in
            Text("「\(phrase.title)」を本当に削除しますか？")
        }
    }
    
    private var presetPicker: some View {
        Picker("", selection: Binding(
            get: { presetManager.selectedPresetId ?? UUID() },
            set: { newValue in
                if presetManager.presets.contains(where: { $0.id == newValue }) {
                    presetManager.selectedPresetId = newValue
                }
            }
        )) {
            ForEach(presetManager.presets) { preset in
                Text(displayName(for: preset)).tag(preset.id)
            }
        }
        .pickerStyle(.menu)
    }

    private var bottomToolbar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Button(action: { showingAddPhraseSheet = true }) {
                    Image(systemName: "plus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: 2.0, y: -1.0)
                }
                .buttonStyle(.borderless)
                .help(Text("新しい定型文をリストに追加します。"))
                divider
                Button(action: {
                    if let id = selectedPhraseId, let phrase = currentPhrases.first(where: { $0.id == id }) {
                        phraseToDelete = phrase
                        showingDeleteConfirmation = true
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -0.5)
                }
                .buttonStyle(.borderless)
                .disabled(selectedPhraseId == nil)
                .help(Text("選択した定型文をリストから削除します。"))
                Spacer()
                Button(action: {
                    if let id = selectedPhraseId, let phrase = currentPhrases.first(where: { $0.id == id }) {
                        selectedPhrase = phrase
                    }
                }) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(y: -0.5)
                }
                .buttonStyle(.borderless)
                .disabled(selectedPhraseId == nil)
                .help(Text("選択した定型文を編集します。"))
                
                Divider()
                    .frame(width: 1, height: 16)
                    .background(Color.gray.opacity(0.1))
                    .padding(.horizontal, 4)
                
                Button(action: {
                    showingClearAllPhrasesConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .offset(x: -2.0, y: -2.0)
                        .if(!currentPhrases.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                }
                .buttonStyle(.borderless)
                .disabled(currentPhrases.isEmpty)
                .help(Text("このプリセットのすべての定型文を削除します。"))
            }
            .background(Rectangle().opacity(0.04))
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for selection: Set<UUID>) -> some View {
        if !selection.isEmpty {
            Button("編集...") {
                if let id = selection.first, let phrase = currentPhrases.first(where: { $0.id == id }) {
                    selectedPhrase = phrase
                }
            }
            Divider()
            Button("削除...", role: .destructive) {
                if let id = selection.first, let phrase = currentPhrases.first(where: { $0.id == id }) {
                    phraseToDelete = phrase
                    showingDeleteConfirmation = true
                }
            }
        }
    }

    private var addSheet: some View {
        AddEditPhraseView(mode: .add) { newPhrase in
            addPhrase(newPhrase)
        }
        .environmentObject(standardPhraseManager)
        .environmentObject(presetManager)
    }

    private func editSheet(for phrase: StandardPhrase) -> some View {
        AddEditPhraseView(mode: .edit(phrase), phraseToEdit: phrase) { editedPhrase in
            updatePhrase(editedPhrase)
        }
        .environmentObject(standardPhraseManager)
        .environmentObject(presetManager)
    }
    
    private func button(icon: String, help: Text, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body).fontWeight(.medium).frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless).help(help).disabled(disabled)
    }
    
    private var divider: some View {
        Divider().frame(width: 1, height: 16).background(Color.gray.opacity(0.1)).padding(.horizontal, 4)
    }
    
    private func displayName(for preset: StandardPhrasePreset) -> String {
        preset.id.uuidString == "00000000-0000-0000-0000-000000000000" ? String(localized: "Default") : preset.name
    }

    private func addPhrase(_ phrase: StandardPhrase) {
        guard var p = presetManager.selectedPreset else { return }
        p.phrases.append(phrase)
        presetManager.updatePreset(p)
    }

    private func updatePhrase(_ phrase: StandardPhrase) {
        guard var p = presetManager.selectedPreset, let i = p.phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        p.phrases[i] = phrase
        presetManager.updatePreset(p)
    }

    private func deletePhrase(id: UUID) {
        guard var p = presetManager.selectedPreset else { return }
        p.phrases.removeAll { $0.id == id }
        presetManager.updatePreset(p)
    }

    private func deletePhrase(atOffsets indexSet: IndexSet) {
        guard var p = presetManager.selectedPreset else { return }
        p.phrases.remove(atOffsets: indexSet)
        presetManager.updatePreset(p)
    }

    private func movePhrase(from source: IndexSet, to destination: Int) {
        guard var p = presetManager.selectedPreset else { return }
        p.phrases.move(fromOffsets: source, toOffset: destination)
        presetManager.updatePreset(p)
    }
    
    private func deleteAllPhrases() {
        guard var p = presetManager.selectedPreset else { return }
        p.phrases = []
        presetManager.updatePreset(p)
    }
}

// MARK: - PhraseManagementSection
private struct PhraseManagementSection: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    
    @State private var showingClearAllPhrasesConfirmation = false
    @State private var showingClearAllPresetsConfirmation = false

    private var allPhrasesCount: Int {
        presetManager.presets.reduce(0) { count, preset in
            count + preset.phrases.count
        }
    }

    var body: some View {
        Section(header: Text("定型文の管理").font(.headline)) {
            StandardPhraseImportExportView()
                .environmentObject(standardPhraseManager)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            HStack {
                Text("\(allPhrasesCount)個の定型文").foregroundStyle(.secondary)
                Spacer()
                Button(action: {
                    showingClearAllPhrasesConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("すべての定型文を削除")
                    }
                    .if(allPhrasesCount > 0) { view in
                        view.foregroundStyle(.red)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(allPhrasesCount == 0)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            HStack {
                Text("\(presetManager.presets.count)個のプリセット").foregroundStyle(.secondary)
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
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) { deleteAllPhrasesFromAllPresets() }
        } message: {
            Text("すべてのプリセットから定型文を削除しますか？この操作は元に戻せません。")
        }
        .alert("すべてのプリセットを削除", isPresented: $showingClearAllPresetsConfirmation) {
            Button("削除", role: .destructive) { presetManager.deleteAllPresets() }
        } message: {
            Text("すべてのプリセットを本当に削除しますか？この操作は元に戻せません。")
        }
    }
    
    private func displayName(for preset: StandardPhrasePreset?) -> String {
        guard let preset = preset else { return ""
        }
        return preset.id.uuidString == "00000000-0000-0000-0000-000000000000" ? String(localized: "Default") : preset.name
    }

    private func deleteAllPhrases() {
        guard var p = presetManager.selectedPreset else { return }
        p.phrases = []
        presetManager.updatePreset(p)
    }
    
    private func deleteAllPhrasesFromAllPresets() {
        for i in presetManager.presets.indices {
            presetManager.presets[i].phrases = []
            presetManager.updatePreset(presetManager.presets[i])
        }
    }
}

// MARK: - Reusable Components
private struct PresetNameSheet: View {
    @Binding var name: String
    var title: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            TextField("プリセット名", text: $name).onSubmit(onSave)
            Spacer()
            HStack {
                Button("キャンセル", role: .cancel, action: onCancel).controlSize(.large)
                Spacer()
                Button("保存", action: onSave).controlSize(.large).buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 140)
    }
}

private struct AppRowView: View {
    let bundleIdentifier: String

    var body: some View {
        HStack {
            // bundleIdentifier から NSRunningApplication を取得するロジックを追加
            let runningApp = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleIdentifier }
            
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                // localizedName が利用できる場合はそれを使い、そうでない場合は従来の appName 関数を使う
                if let localizedName = runningApp?.localizedName {
                    Text(localizedName)
                } else {
                    Text(appName(for: bundleIdentifier))
                }
            } else {
                Image(systemName: "questionmark.app").resizable().frame(width: 16, height: 16)
                // localizedName が利用できる場合はそれを使い、そうでない場合は従来の appName 関数を使う
                if let localizedName = runningApp?.localizedName {
                    Text(localizedName)
                } else {
                    Text(appName(for: bundleIdentifier))
                }
            }
        }
    }

    private func appName(for bundleIdentifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: url),
           let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return bundleIdentifier
    }
}

private struct AppSelectionPopoverView: View {
    @Binding var runningApplications: [NSRunningApplication]
    let assignedApps: [String]
    let onAppSelected: (String) -> Void
    let onSelectFromFinder: () -> Void
    
    @State private var showAllRunningApps: Bool = false

    private var filteredApps: [NSRunningApplication] {
        let unassigned = runningApplications.filter { !assignedApps.contains($0.bundleIdentifier ?? "") }
        return showAllRunningApps ? unassigned : unassigned.filter { $0.activationPolicy == .regular }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("実行中のアプリから追加").font(.headline)
                Spacer()
                Toggle(isOn: $showAllRunningApps) { Text("すべてのプロセスを表示") }.toggleStyle(.checkbox).font(.subheadline)
            }
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(filteredApps.sorted(by: { ($0.localizedName ?? "") < ($1.localizedName ?? "") }), id: \.self) { app in
                        Button(action: { onAppSelected(app.bundleIdentifier ?? "") }) {
                            HStack {
                                Image(nsImage: app.icon ?? NSImage()).resizable().frame(width: 16, height: 16)
                                Text(app.localizedName ?? "不明なアプリ")
                                Spacer()
                                Text(String(describing: app.processIdentifier))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).padding(.vertical, 4)
                        .help("PID: \(String(describing: app.processIdentifier))")
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 200)
            
            Divider().padding(.vertical, 4)

            Button(action: onSelectFromFinder) {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Finderで選択...")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.vertical, 4)
        }
        .padding()
        .frame(minWidth: 280, maxWidth: 400)
    }
}

#Preview {
    StandardPhraseSettingsView()
        .environmentObject(StandardPhraseManager.shared)
}
