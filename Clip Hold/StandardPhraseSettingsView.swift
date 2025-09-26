import SwiftUI
import UniformTypeIdentifiers
import SFSymbolsPicker


// MARK: - StandardPhraseSettingsView
struct StandardPhraseSettingsView: View {
    @StateObject private var presetManager = StandardPhrasePresetManager.shared
    @StateObject private var assignmentManager = PresetAppAssignmentManager.shared
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @StateObject var iconGenerator = PresetIconGenerator.shared
    
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
        .environmentObject(iconGenerator)
    }
}

// MARK: - PresetSettingsSection
private struct PresetSettingsSection: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @StateObject private var iconGenerator = PresetIconGenerator.shared
    
    @State private var selectedPresetId: UUID? = nil
    @State private var showingAddPresetSheet = false
    @State private var newPresetName = ""
    @State private var newPresetIcon = "list.bullet.rectangle.portrait"
    @State private var newPresetColor = "accent"
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
                        // アイコン表示
                        if let icon = iconGenerator.iconCache[preset.id] {
                            Image(nsImage: icon)
                        } else {
                            // Fallback to manual drawing if icon not found (should not happen)
                            ZStack {
                                Circle()
                                    .fill(getColor(from: preset.color, customColor: preset.customColor))
                                    .frame(width: 20, height: 20)
                                Image(systemName: preset.icon)
                                    .foregroundColor(getSymbolColor(forPresetColor: preset.color, customColor: preset.customColor))
                                    .font(.system(size: 10))
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text(preset.truncatedDisplayName(maxLength: 50))
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
                    .help(Text(preset.displayName))
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
                            newPresetIcon = preset.icon
                            newPresetColor = preset.color
                        }
                    } label: { Label("編集...", systemImage: "pencil") }
                        .disabled(isDefaultPreset(id: selectedId))
                    Button {
                        if let preset = presetManager.presets.first(where: { $0.id == selectedId }) {
                            presetManager.duplicatePreset(preset)
                        }
                    } label: { Label("複製", systemImage: "plus.square.on.square") }
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
                        newPresetIcon = preset.icon
                        newPresetColor = preset.color
                    }
                }
            }
            .overlay(alignment: .bottom) { bottomToolbar }
        }
        .sheet(isPresented: $showingAddPresetSheet) { addPresetSheet }
        .sheet(item: $editingPreset) { preset in
            PresetNameSheet(
                name: $newPresetName,
                icon: $newPresetIcon,
                color: $newPresetColor,
                editingPreset: preset,
                title: String(localized: "プリセット名を編集")
            ) { customColor in
                updatePreset(preset, newName: newPresetName, newIcon: newPresetIcon, newColor: newPresetColor, customColor: customColor)
                newPresetName = ""
                newPresetIcon = "list.bullet.rectangle.portrait"
                newPresetColor = "accent"
                editingPreset = nil // シートを閉じる
            } onCancel: {
                newPresetName = ""
                newPresetIcon = "list.bullet.rectangle.portrait"
                newPresetColor = "accent"
                editingPreset = nil // シートを閉じる
            }
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
                let phraseCount = preset.phrases.count
                Text("「\(preset.truncatedDisplayName(maxLength: 30))」を本当に削除しますか？このプリセットに含まれる\(phraseCount)個の定型文も削除されます。この操作は元に戻せません。")
            } else {
                Text("このプリセットを本当に削除しますか？")
            }
        }
    }
    
    private func getSymbolColor(forPresetColor colorName: String, customColor: PresetCustomColor?) -> Color {
        if colorName == "custom", let custom = customColor {
            return Color(hex: custom.icon)
        } else if colorName == "yellow" || colorName == "green" {
            return .black
        } else {
            return .white
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
                        newPresetIcon = preset.icon
                        newPresetColor = preset.color
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
        PresetNameSheet(
            name: $newPresetName,
            icon: $newPresetIcon,
            color: $newPresetColor,
            title: String(localized: "プリセット名を入力")
        ) { customColor in
            addPreset(name: newPresetName, icon: newPresetIcon, color: newPresetColor, customColor: customColor)
            newPresetName = ""
            newPresetIcon = "list.bullet.rectangle.portrait"
            newPresetColor = "accent"
            showingAddPresetSheet = false
        } onCancel: {
            showingAddPresetSheet = false
            newPresetName = ""
            newPresetIcon = "list.bullet.rectangle.portrait"
            newPresetColor = "accent"
        }
    }
    

    

    
    private func isDefaultPreset(id: UUID?) -> Bool {
        id?.uuidString == "00000000-0000-0000-0000-000000000000"
    }
    
    private func addPreset(name: String, icon: String, color: String, customColor: PresetCustomColor?) {
        presetManager.addPreset(name: name, icon: icon, color: color, customColor: customColor)
    }
    
    private func updatePreset(_ preset: StandardPhrasePreset, newName: String, newIcon: String, newColor: String, customColor: PresetCustomColor?) {
        var updatedPreset = preset
        updatedPreset.name = newName
        updatedPreset.icon = newIcon
        updatedPreset.color = newColor
        updatedPreset.customColor = customColor
        presetManager.updatePreset(updatedPreset)
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
    
    private func getColor(from colorName: String, customColor: PresetCustomColor?) -> Color {
        if colorName == "custom", let custom = customColor {
            return Color(hex: custom.background)
        }
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .accentColor
        }
    }
}

// MARK: - PresetAssignmentSection
private struct PresetAssignmentSection: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @EnvironmentObject var assignmentManager: PresetAppAssignmentManager
    @StateObject var iconGenerator = PresetIconGenerator.shared
    
    @State private var selectedPresetForAssignmentId: UUID? = StandardPhrasePresetManager.shared.presets.first?.id
    @State private var isShowingAddAppPopover: Bool = false
    @State private var showingFinderPanel = false
    @State private var showingInvalidAppAlert = false
    @State private var runningApplications: [NSRunningApplication] = []
    @State private var selectedAssignedAppId: String? = nil
    @State private var showingClearAssignmentsConfirmation = false
    @AppStorage("excludeStandardPhraseWindowFromPresetSwitching") private var excludeStandardPhraseWindowFromPresetSwitching: Bool = false
    
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
            HStack {
                VStack(alignment: .leading) {
                    Text("Clip Holdのウィンドウを除外")
                    Text("Clip Holdのウィンドウ（定型文ウィンドウなど）をフォーカスしたときに、プリセットが切り替わらないようにします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(isOn: $excludeStandardPhraseWindowFromPresetSwitching) {
                    Text("Clip Holdのウィンドウを除外")
                    Text("Clip Holdのウィンドウ（定型文ウィンドウなど）をフォーカスしたときに、プリセットが切り替わらないようにします。")
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            Picker("割り当てるプリセット", selection: Binding(
                get: {
                    // プリセットが空の場合、特別なUUIDを返す
                    if presetManager.presets.isEmpty {
                        return UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                    }
                    return selectedPresetForAssignmentId
                },
                set: { newValue in
                    // UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")は「プリセットがありません」のタグ
                    if newValue?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                        // プリセットがない場合は何もしない
                        // 選択を元に戻す
                        if let firstPreset = presetManager.presets.first {
                            selectedPresetForAssignmentId = firstPreset.id
                        } else {
                            // まだプリセットがない場合はnilのまま
                            selectedPresetForAssignmentId = nil
                        }
                    } else {
                        selectedPresetForAssignmentId = newValue
                    }
                }
            )) {
                ForEach(presetManager.presets) { preset in
                    Label {
                        Text(preset.truncatedDisplayName(maxLength: 50))
                    } icon: {
                        if let iconImage = iconGenerator.miniIconCache[preset.id] { // Use miniIconCache
                            Image(nsImage: iconImage)
                        } else {
                            Image(systemName: "star.fill") // Fallback
                        }
                    }
                    .tag(preset.id as UUID?)
                }
                
                // プリセットがない場合の項目
                if presetManager.presets.isEmpty {
                    Text("プリセットがありません")
                        .tag(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") as UUID?)
                }
            }
            .pickerStyle(.menu)
            .labelStyle(.titleAndIcon)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .onChange(of: selectedPresetForAssignmentId) { _, _ in
                selectedAssignedAppId = nil
            }
            
            List(selection: $selectedAssignedAppId) {
                ForEach(assignedApps, id: \.self) { bundleIdentifier in
                    AppRowView(bundleIdentifier: bundleIdentifier)
                        .contextMenu { contextMenuItems(for: bundleIdentifier) }
                }
                .onDelete(perform: deleteAssignedApp)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard let selectedPresetId = selectedPresetForAssignmentId,
                      selectedPresetId.uuidString != "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" else {
                    return false
                }
                
                let group = DispatchGroup()
                var invalidItemsCount = 0
                let lock = NSLock()
                
                for provider in providers {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                        defer { group.leave() }
                        
                        guard let urlData = urlData as? Data,
                              let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                            lock.lock()
                            invalidItemsCount += 1
                            lock.unlock()
                            return
                        }
                        
                        if url.pathExtension == "app" || FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                            guard let bundle = Bundle(url: url),
                                  let bundleIdentifier = bundle.bundleIdentifier else {
                                lock.lock()
                                invalidItemsCount += 1
                                lock.unlock()
                                return
                            }
                            
                            DispatchQueue.main.async {
                                handleAppAssignment(for: selectedPresetId, bundleIdentifier: bundleIdentifier)
                            }
                        } else {
                            lock.lock()
                            invalidItemsCount += 1
                            lock.unlock()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    if invalidItemsCount > 0 {
                        showingInvalidAppAlert = true
                    }
                }
                
                return true
            }
            .listStyle(.plain)
            .frame(minHeight: 100)
            .scrollContentBackground(.hidden)
            .padding(.bottom, 24)
            .overlay(alignment: .bottom) { bottomToolbar }
        }
        .onAppear {
            if presetManager.presets.isEmpty {
                // プリセットがない場合は、特別なUUIDを設定
                selectedPresetForAssignmentId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
            } else if selectedPresetForAssignmentId == nil || selectedPresetForAssignmentId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                selectedPresetForAssignmentId = presetManager.presets.first?.id
            }
        }
        .onReceive(presetManager.presetAddedSubject) { _ in
            if presetManager.presets.isEmpty {
                selectedPresetForAssignmentId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
            } else if selectedPresetForAssignmentId == nil || selectedPresetForAssignmentId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                selectedPresetForAssignmentId = presetManager.presets.first?.id
            }
        }
        .onReceive(presetManager.$presets) { presets in
            let selectionExists = presets.contains(where: { $0.id == selectedPresetForAssignmentId })
            
            if presets.isEmpty {
                // プリセットが空になったら、選択を「なし」状態にする
                selectedPresetForAssignmentId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
            } else if !selectionExists {
                // 選択中のプリセットが存在しない（削除されたか、初期状態）場合、最初のプリセットを選択する
                selectedPresetForAssignmentId = presets.first?.id
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
        .alert("アプリではありません", isPresented: $showingInvalidAppAlert) {
            Button("OK") { }
        } message: {
            Text("割り当てるプリセットにはアプリのみ追加することができます。")
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
                Text("「\(appName)」は別のプリセット「\(preset.truncatedDisplayName(maxLength: 30))」にすでに割り当てられています。このアプリを割り当てると、「\(preset.truncatedDisplayName(maxLength: 30))」から割り当てが解除されます。アプリを割り当ててもよろしいですか？")
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
                .disabled(presetManager.presets.isEmpty) // プリセットがない場合は無効化
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
    
    private func contextMenuItems(for bundleIdentifier: String) -> some View {
        Button(role: .destructive) {
            deleteAssignedApp(bundleIdentifier: bundleIdentifier)
        } label: {
            Label("削除", systemImage: "trash")
        }
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
    @StateObject var iconGenerator = PresetIconGenerator.shared
    
    @State private var selectedPhraseId: UUID? = nil
    @State private var showingAddPhraseSheet = false
    @State private var selectedPhrase: StandardPhrase?
    @State private var phraseToDelete: StandardPhrase?
    @State private var showingDeleteConfirmation = false
    @State private var showingClearAllPhrasesConfirmation = false
    @State private var showingAddPresetSheet = false
    @State private var newPresetName = ""
    @State private var newPresetIconForPhraseSection = "list.bullet.rectangle.portrait"
    @State private var newPresetColorForPhraseSection = "accent"
    @State private var showingMoveSheet = false
    @State private var phraseToMove: StandardPhrase?
    @State private var destinationPresetId: UUID?
    
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
        .sheet(isPresented: $showingAddPresetSheet) { addPresetSheet }
        .sheet(isPresented: $showingMoveSheet) {
            if let sourceId = presetManager.selectedPresetId {
                MovePhrasePresetSelectionSheet(presetManager: StandardPhrasePresetManager.shared, sourcePresetId: sourceId, selectedPresetId: $destinationPresetId) {
                    if let phrase = phraseToMove, let destinationId = destinationPresetId {
                        presetManager.move(phrase: phrase, to: destinationId)
                    }
                }
            }
        }
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) { deleteAllPhrases() }
        } message: {
            if let preset = presetManager.selectedPreset {
                Text("プリセット「\(preset.truncatedDisplayName(maxLength: 30))」からすべての定型文を本当に削除しますか？この操作は元に戻せません。")
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
            get: {
                // プリセットが空の場合、特別なUUIDを返す
                if presetManager.presets.isEmpty {
                    return UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                }
                return presetManager.selectedPresetId ?? UUID()
            },
            set: { newValue in
                let newPresetUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                
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
                } else if newValue == newPresetUUID {
                    showingAddPresetSheet = true
                } else if presetManager.presets.contains(where: { $0.id == newValue }) {
                    presetManager.selectedPresetId = newValue
                    presetManager.saveSelectedPresetId()
                }
            }
        )) {
            ForEach(presetManager.presets) { preset in
                Label {
                    Text(preset.truncatedDisplayName(maxLength: 50))
                } icon: {
                    if let iconImage = iconGenerator.miniIconCache[preset.id] { // Use miniIconCache
                        Image(nsImage: iconImage)
                    } else {
                        Image(systemName: "star.fill") // Fallback
                    }
                }
                .tag(preset.id)
            }
            
            // プリセットがない場合の項目
            if presetManager.presets.isEmpty {
                Text("プリセットがありません")
                    .tag(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!)
            }
            
            Divider()
            Text("新規プリセット...").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        }
        .pickerStyle(.menu)
        .labelStyle(.titleAndIcon)
    }
    
    private var addPresetSheet: some View {
        PresetNameSheet(
            name: $newPresetName,
            icon: $newPresetIconForPhraseSection,
            color: $newPresetColorForPhraseSection,
            title: String(localized: "プリセット名を入力")
        ) { customColor in
            addPreset(name: newPresetName, icon: newPresetIconForPhraseSection, color: newPresetColorForPhraseSection, customColor: customColor)
            newPresetName = ""
            newPresetIconForPhraseSection = "list.bullet.rectangle.portrait"
            newPresetColorForPhraseSection = "accent"
            showingAddPresetSheet = false
        } onCancel: {
            showingAddPresetSheet = false
            newPresetName = ""
            newPresetIconForPhraseSection = "list.bullet.rectangle.portrait"
            newPresetColorForPhraseSection = "accent"
        }
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
                .disabled(presetManager.presets.isEmpty) // プリセットがない場合は無効化
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
            Button {
                if let id = selection.first, let phrase = currentPhrases.first(where: { $0.id == id }) {
                    selectedPhrase = phrase
                }
            } label: {
                Label("編集...", systemImage: "pencil")
            }
            Button {
                if let id = selection.first, let phrase = currentPhrases.first(where: { $0.id == id }) {
                    phraseToMove = phrase
                    showingMoveSheet = true
                }
            } label: {
                Label("別のプリセットに移動...", systemImage: "folder")
            }
            Button {
                if let id = selection.first,
                   let phrase = currentPhrases.first(where: { $0.id == id }),
                   let selectedPreset = presetManager.selectedPreset {
                    presetManager.duplicate(phrase: phrase, in: selectedPreset)
                }
            } label: {
                Label("複製", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(role: .destructive) {
                if let id = selection.first, let phrase = currentPhrases.first(where: { $0.id == id }) {
                    phraseToDelete = phrase
                    showingDeleteConfirmation = true
                }
            } label: {
                Label("削除...", systemImage: "trash")
            }
        }
    }
    
    private var addSheet: some View {
        AddEditPhraseView(mode: .add, presetManager: presetManager, isSheet: true) { newPhrase in
            addPhrase(newPhrase)
        }
        .environmentObject(standardPhraseManager)
        .environmentObject(presetManager)
    }
    
    private func editSheet(for phrase: StandardPhrase) -> some View {
        AddEditPhraseView(mode: .edit(phrase), phraseToEdit: phrase, presetManager: presetManager, isSheet: true) { editedPhrase in
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
    
    private func addPreset(name: String, icon: String, color: String, customColor: PresetCustomColor?) {
        presetManager.addPreset(name: name, icon: icon, color: color, customColor: customColor)
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

func localizedColorName(for colorName: String) -> String {
    switch colorName {
    case "accent": return String(localized: "アクセントカラー")
    case "red": return String(localized: "レッド")
    case "orange": return String(localized: "オレンジ")
    case "yellow": return String(localized: "イエロー")
    case "green": return String(localized: "グリーン")
    case "blue": return String(localized: "ブルー")
    case "purple": return String(localized: "パープル")
    case "pink": return String(localized: "ピンク")
    case "custom": return String(localized: "カスタム")
    default: return ""
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

// MARK: - Reusable Components
struct PresetNameSheet: View {
    @Binding var name: String
    @Binding var icon: String
    @Binding var color: String
    var editingPreset: StandardPhrasePreset? = nil
    
    @State private var showingIconPicker = false
    @State private var previousIcon: String = ""
    @State private var showingColorPicker = false
    @State private var customBackgroundColor: Color
    @State private var customIconColor: Color
    var title: String
    var onSave: (PresetCustomColor?) -> Void
    var onCancel: () -> Void
    
    init(
        name: Binding<String>,
        icon: Binding<String>,
        color: Binding<String>,
        editingPreset: StandardPhrasePreset? = nil,
        title: String,
        onSave: @escaping (PresetCustomColor?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._name = name
        self._icon = icon
        self._color = color
        self.editingPreset = editingPreset
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        
        if let preset = editingPreset, preset.color == "custom", let custom = preset.customColor {
            _customBackgroundColor = State(initialValue: Color(hex: custom.background))
            _customIconColor = State(initialValue: Color(hex: custom.icon))
        } else {
            _customBackgroundColor = State(initialValue: .blue)
            _customIconColor = State(initialValue: .white)
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    // アイコン選択ボタンと入力フィールド
                    HStack {
                        SFSymbolsPicker(selection: $icon, prompt: String(localized: "シンボルを検索")) {
                            ZStack {
                                Circle()
                                    .fill(color == "custom" ? customBackgroundColor : getColor(from: color))
                                    .frame(width: 30, height: 30)
                                Image(systemName: icon.isEmpty ? previousIcon : icon)
                                    .foregroundColor(getSymbolColor(forPresetColor: color))
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(.plain)
                        .onChange(of: icon) { oldValue, newValue in
                            if newValue.isEmpty {
                                icon = previousIcon
                            } else {
                                previousIcon = newValue
                            }
                        }
                        
                        TextField("プリセット名", text: $name).onSubmit {
                            let customColorData = self.color == "custom" ? PresetCustomColor(background: customBackgroundColor.toHex() ?? "#0000FF", icon: customIconColor.toHex() ?? "#FFFFFF") : nil
                            onSave(customColorData)
                        }
                    }
                    
                    // カラーピッカー
                    HStack {
                        Text("Color:")
                        Spacer()
                        HStack(spacing: 5) {
                            ForEach(getColorOptions(), id: \.self) { colorName in
                                if colorName == "custom" {
                                    Button(action: {
                                        showingColorPicker = true
                                        color = "custom"
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(color == "custom" ? customBackgroundColor : .gray)
                                                .frame(width: 20, height: 20)
                                            Image(systemName: "paintpalette")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(color == colorName ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .help(Text(localizedColorName(for: colorName)))
                                    .popover(isPresented: $showingColorPicker) {
                                        VStack {
                                            HStack {
                                                Text("背景色").font(.headline)
                                                Spacer()
                                                ColorPicker("", selection: $customBackgroundColor, supportsOpacity: false)
                                                    .labelsHidden()
                                            }
                                            
                                            HStack {
                                                Text("アイコン色").font(.headline)
                                                Spacer()
                                                ColorPicker("", selection: $customIconColor, supportsOpacity: false)
                                                    .labelsHidden()
                                            }
                                        }
                                        .padding()
                                        .frame(width: 250)
                                        .onChange(of: customBackgroundColor) { _, _ in color = "custom" }
                                        .onChange(of: customIconColor) { _, _ in color = "custom" }
                                    }
                                } else {
                                    Button(action: {
                                        color = colorName
                                    }) {
                                        Circle()
                                            .fill(getColor(from: colorName))
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Circle()
                                                    .stroke(color == colorName ? Color.primary : Color.clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .help(Text(localizedColorName(for: colorName)))
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("キャンセル", role: .cancel, action: onCancel).controlSize(.large)
                Spacer()
                Button("保存", action: {
                    let customColorData = self.color == "custom" ? PresetCustomColor(background: customBackgroundColor.toHex() ?? "#0000FF", icon: customIconColor.toHex() ?? "#FFFFFF") : nil
                    onSave(customColorData)
                }).controlSize(.large).buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 180)
        .onAppear {
            previousIcon = icon
        }
        .onExitCommand(perform: onCancel)
    }
    
    private func getSymbolColor(forPresetColor colorName: String) -> Color {
        if colorName == "custom" {
            return customIconColor
        } else if colorName == "yellow" || colorName == "green" {
            return .black
        } else {
            return .white
        }
    }
    
    private func getColor(from colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "custom": return .gray // Placeholder, should be replaced by customBackgroundColor
        default: return .accentColor
        }
    }
    
    private func getColorOptions() -> [String] {
        return ["accent", "red", "orange", "yellow", "green", "blue", "purple", "pink", "custom"]
    }
}