import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct PhraseDocument: FileDocument {
    var standardPhrases: [StandardPhrase]
    var presetData: [StandardPhrasePreset]?
    var isLegacyFormat: Bool

    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    init(standardPhrases: [StandardPhrase] = [], presetData: [StandardPhrasePreset]? = nil, isLegacyFormat: Bool = false) {
        self.standardPhrases = standardPhrases
        self.presetData = presetData
        self.isLegacyFormat = isLegacyFormat
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // ファイルの内容を一度解析して、プリセットフォーマットかどうかを判断
        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // 最初の要素に 'id', 'name', 'phrases' があるか確認
            if let firstItem = jsonObject.first,
               firstItem["id"] != nil,
               firstItem["name"] != nil,
               firstItem["phrases"] != nil {
                // プリセットフォーマット
                let decoder = JSONDecoder()
                let presets = try decoder.decode([StandardPhrasePreset].self, from: data)
                self.presetData = presets
                self.standardPhrases = []
                self.isLegacyFormat = false
            } else {
                // レガシーフォーマット (定型文の配列のみ)
                let decoder = JSONDecoder()
                self.standardPhrases = try decoder.decode([StandardPhrase].self, from: data)
                self.presetData = nil
                self.isLegacyFormat = true
            }
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        let data: Data
        if isLegacyFormat {
            // レガシーフォーマット: 定型文の配列のみ
            data = try encoder.encode(standardPhrases)
        } else if let presetData = presetData {
            // プリセットフォーマット: プリセットの配列
            data = try encoder.encode(presetData)
        } else {
            // デフォルト: 定型文の配列のみ
            data = try encoder.encode(standardPhrases)
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}

extension StandardPhraseManager {
    func exportPhrasesAsDocument() -> PhraseDocument {
        return PhraseDocument(standardPhrases: self.standardPhrases)
    }
}

// MARK: - インポート/エクスポート機能を提供するView
struct StandardPhraseImportExportView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var iconGenerator: PresetIconGenerator
    @StateObject private var presetManager = StandardPhrasePresetManager.shared

    @State private var showingFileExporter = false
    @State private var showingFileImporter = false
    @State private var importError: String? = nil
    @State private var showingImportConflictSheet = false
    // プリセットごとの競合情報を保持する配列
    @State private var presetConflicts: [PresetConflictInfo] = []
    // 現在処理中のプリセットのインデックス
    @State private var currentPresetIndexForConflictResolution: Int = 0
    @State private var currentSelectedURL: URL? = nil // 追加: 現在選択されているURLを保持
    
    // プリセット選択シート用の状態変数
    @State private var showingImportPresetSelectionSheet = false
    @State private var selectedImportPresetId: UUID? = nil
    
    // プリセット競合シート用の状態変数
    @State private var showingPresetConflictSheet = false
    @State private var conflictingPresets: [StandardPhrasePreset] = []
    @State private var presetImportAction: PresetConflictSheet.PresetConflictAction = .merge
    @State private var presetsToImport: [StandardPhrasePreset] = []
    
    // エクスポートシート用の状態変数
    @State private var showingExportSheet = false
    @State private var selectedExportPresetId: UUID?
    @State private var useLegacyFormat = false
    
    // インポート前の選択プリセットIDを保持
    @State private var presetIdBeforeImport: UUID? = nil
    
    // すべてのプリセットが空かどうかを判定する計算プロパティ
    private var areAllPresetsEmpty: Bool {
        return presetManager.presets.allSatisfy { $0.phrases.isEmpty }
    }
    
    // 選択可能なプリセットのリスト
    private var exportablePresets: [StandardPhrasePreset] {
        return presetManager.presets
    }
    
    private func isDefaultPreset(id: UUID?) -> Bool {
        id?.uuidString == "00000000-0000-0000-0000-000000000000"
    }
    

    
    var body: some View {
        HStack {
            Text("定型文")
            Spacer()
            Button {
                showingFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("インポート")
                }
            }
            .buttonStyle(.bordered)
            .help("書き出した定型文のJSONファイルを読み込みます。") // インポートボタンのツールチップ

            Button {
                showingExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("エクスポート")
                }
            }
            .buttonStyle(.bordered)
            .disabled(areAllPresetsEmpty)
            .help("すべて、または特定のプリセットの定型文をJSONファイルとして書き出します。") // エクスポートボタンのツールチップ
        }
        .sheet(isPresented: $showingExportSheet) {
            VStack(alignment: .leading, spacing: 10) {
                Text("定型文のエクスポート")
                    .font(.headline)
                
                Text("エクスポートしたいプリセットを選択")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("プリセットを選択", selection: $selectedExportPresetId) {
                    Label {
                        Text("すべて")
                    } icon: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                    }
                    .tag(nil as UUID?)
                    
                    Divider()
                    
                    ForEach(exportablePresets) { preset in
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
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .labelStyle(.titleAndIcon)
                
                Toggle("旧バージョンで使用できるようにする", isOn: $useLegacyFormat)
                    .help("有効にすると、プリセット情報なしで定型文のみをエクスポートします。")
                Spacer()

                HStack {
                    Button("キャンセル") {
                        showingExportSheet = false
                        selectedExportPresetId = nil
                        useLegacyFormat = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    
                    Spacer()
                    Button("エクスポート") {
                        showingExportSheet = false
                        showingFileExporter = true
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(width: 350, height: 190)
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: createExportDocument(),
            contentType: .json,
            defaultFilename: getExportFileName()
        ) { result in
            switch result {
            case .success(let url):
                print("エクスポート成功: \(url)")
            case .failure(let error):
                print("エクスポート失敗: \(error.localizedDescription)")
            }
            
            // エクスポート後に状態をリセット
            selectedExportPresetId = nil
            useLegacyFormat = false
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                // インポート開始前に現在の選択を保存
                presetIdBeforeImport = presetManager.selectedPresetId
                
                guard let selectedURL = urls.first else { return }
                currentSelectedURL = selectedURL // 追加: 選択されたURLを保持
                let gotAccess = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if gotAccess {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }
                handleImport(from: selectedURL)
            case .failure(let error):
                importError = "ファイルの選択に失敗しました: \(error.localizedDescription)"
            }
        }
        .alert("インポートエラー", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "不明なエラーが発生しました。")
        }
        .sheet(isPresented: $showingImportPresetSelectionSheet) {
            ImportPresetSelectionSheet(
                presetManager: presetManager,
                selectedPresetId: $selectedImportPresetId
            ) { shouldCreateNewPreset in
                if let presetId = selectedImportPresetId {
                    // プリセット選択後の処理
                    processImportIntoPreset(presetId: presetId)
                } else if shouldCreateNewPreset {
                    // 新規プリセットが作成された場合の処理
                    // 既にprocessImportIntoPresetはImportPresetSelectionSheet内で呼ばれているため、ここでは何もしない
                }
            }
        }
        .sheet(isPresented: $showingPresetConflictSheet) {
            PresetConflictSheet(
                conflictingPresets: conflictingPresets,
                onCompletion: { action, individualActions in
                    presetImportAction = action
                    processPresetImportWithAction(action, individualActions: individualActions)
                }
            )
        }
        .sheet(isPresented: $showingImportConflictSheet) {
            ImportConflictSheet(
                presetConflicts: $presetConflicts,
                currentPresetIndex: $currentPresetIndexForConflictResolution
            ) { completedPresetConflicts in
                // すべてのプリセットの競合解決が完了した後の処理
                for presetConflict in completedPresetConflicts {
                    standardPhraseManager.addImportedPhrases(
                        presetConflict.nonConflictingPhrases, 
                        toPresetId: presetConflict.preset.id
                    )
                }
                // 状態をリセット
                presetConflicts.removeAll()
                currentPresetIndexForConflictResolution = 0
                
                restoreSelectionAfterImport()
            }
            .environmentObject(standardPhraseManager)
        }
    }
    
    // MARK: - インポート処理
    private func handleImport(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // ファイルの内容を一度解析して、プリセットフォーマットかどうかを判断
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // 最初の要素に 'id', 'name', 'phrases' があるか確認
                if let firstItem = jsonObject.first,
                   firstItem["id"] != nil,
                   firstItem["name"] != nil,
                   firstItem["phrases"] != nil {
                    // プリセットフォーマット
                    let presets = try decoder.decode([StandardPhrasePreset].self, from: data)
                    handlePresetFormatImport(presets)
                } else {
                    // レガシーフォーマット (定型文の配列のみ)
                    let phrases = try decoder.decode([StandardPhrase].self, from: data)
                    handleLegacyFormatImport(phrases)
                }
            } else {
                importError = "無効なファイル形式です。"
            }
        } catch {
            importError = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    private func restoreSelectionAfterImport() {
        if let presetId = presetIdBeforeImport, presetId.uuidString != "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
            presetManager.selectedPresetId = presetId
            presetManager.saveSelectedPresetId()
        }
        presetIdBeforeImport = nil
    }
    
    // MARK: - レガシーフォーマットインポート処理
    private func handleLegacyFormatImport(_ phrases: [StandardPhrase]) {
        // プリセット選択シートを表示
        showingImportPresetSelectionSheet = true
        selectedImportPresetId = presetManager.selectedPresetId
        // インポートする定型文を一時保存 (ID保持のため)
        // nonConflictingPhrasesToImport は不要になったので削除
    }
    
    // MARK: - プリセット選択後の処理
    private func processImportIntoPreset(presetId: UUID) {
        // targetPresetIdForConflictResolution は不要になったので削除
        // 保持しているURLを使用して処理を続行
        guard let selectedURL = currentSelectedURL else { return }
        
        // セキュリティスコープ付きリソースへのアクセスを開始
        let gotAccess = selectedURL.startAccessingSecurityScopedResource()
        defer {
            // 処理が完了したらアクセスを終了
            if gotAccess {
                selectedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: selectedURL)
            let decoder = JSONDecoder()
            let importedPhrases = try decoder.decode([StandardPhrase].self, from: data)
            
            // 競合チェック
            let (conflicts, nonConflicts) = standardPhraseManager.checkConflicts(with: importedPhrases, inPresetId: presetId)
            
            if !conflicts.isEmpty {
                // 新しい方式で競合を処理
                let conflictInfo = PresetConflictInfo(
                    preset: StandardPhrasePreset(id: presetId, name: presetManager.presets.first(where: { $0.id == presetId })?.name ?? "Unknown", phrases: []),
                    conflicts: conflicts,
                    nonConflictingPhrases: nonConflicts
                )
                presetConflicts = [conflictInfo]
                currentPresetIndexForConflictResolution = 0
                showingImportConflictSheet = true
            } else {
                // 競合がなければ直接追加
                standardPhraseManager.addImportedPhrases(importedPhrases, toPresetId: presetId)
                
                restoreSelectionAfterImport()
            }
        } catch {
            importError = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - プリセットフォーマットインポート処理
    private func handlePresetFormatImport(_ presets: [StandardPhrasePreset]) {
        presetsToImport = presets
        var conflicts: [StandardPhrasePreset] = []
        var nonConflictingPresets: [StandardPhrasePreset] = []
        
        // 既存のプリセットと比較して競合をチェック
        for preset in presets {
            // IDが一致するプリセットを探す
            let existingPresetWithId = presetManager.presets.first(where: { $0.id == preset.id })
            
            // 名前が一致するプリセットを探す
            let existingPresetWithName = presetManager.presets.first(where: { $0.name == preset.name && $0.id != preset.id })
            
            if existingPresetWithId != nil || existingPresetWithName != nil {
                conflicts.append(preset)
            } else {
                nonConflictingPresets.append(preset)
            }
        }
        
        // 競合しないプリセットを先に追加
        for preset in nonConflictingPresets {
            presetManager.addPresetWithId(preset.id, name: preset.name)
            if let addedPreset = presetManager.presets.first(where: { $0.id == preset.id }) {
                standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
            }
        }
        
        if !conflicts.isEmpty {
            // 競合がある場合は競合シートを表示
            conflictingPresets = conflicts
            showingPresetConflictSheet = true
        }
        // 競合がない場合は何もしない（すでに非競合のプリセットは追加済み）
        
        restoreSelectionAfterImport()
    }
    
    // MARK: - プリセット競合後の処理
    private func processPresetImportWithAction(_ action: PresetConflictSheet.PresetConflictAction, individualActions: [UUID: PresetConflictSheet.PresetConflictAction] = [:]) {
        switch action {
        case .merge:
            for preset in presetsToImport {
                // IDが一致するプリセットを探す
                if let existingPreset = presetManager.presets.first(where: { $0.id == preset.id }) {
                    // IDが一致するプリセットが存在する場合、定型文を統合
                    var mergedPhrases = existingPreset.phrases
                    
                    // 新しい定型文のみを追加 (内容が一致するものは除外)
                    for newPhrase in preset.phrases {
                        // 同じIDの定型文が既に存在するかチェック
                        if let existingIndex = mergedPhrases.firstIndex(where: { $0.id == newPhrase.id }) {
                            // IDが一致する定型文が存在する場合
                            let existingPhrase = mergedPhrases[existingIndex]
                            
                            // IDとコンテンツの両方が一致する場合はスキップ
                            if existingPhrase.content != newPhrase.content {
                                // IDが一致するがコンテンツが異なる場合は、新しいUUIDを割り当てて追加
                                let phraseWithNewId = StandardPhrase(id: UUID(), title: newPhrase.title, content: newPhrase.content)
                                mergedPhrases.append(phraseWithNewId)
                            }
                        } else {
                            // 同じIDの定型文が存在しない場合は追加
                            mergedPhrases.append(newPhrase)
                        }
                    }
                    
                    // 更新されたプリセットを保存
                    var updatedPreset = existingPreset
                    updatedPreset.phrases = mergedPhrases
                    presetManager.updatePreset(updatedPreset)
                } 
                // 名前が一致するプリセットを探す（IDが異なる場合）
                else if let existingPreset = presetManager.presets.first(where: { $0.name == preset.name && $0.id != preset.id }) {
                    // 名前が一致する既存のプリセットに定型文を統合
                    var mergedPhrases = existingPreset.phrases
                    
                    // 新しい定型文のみを追加 (内容が一致するものは除外)
                    for newPhrase in preset.phrases {
                        if !mergedPhrases.contains(where: { $0.title == newPhrase.title && $0.content == newPhrase.content }) {
                            mergedPhrases.append(newPhrase)
                        }
                    }
                    
                    // 更新されたプリセットを保存
                    var updatedPreset = existingPreset
                    updatedPreset.phrases = mergedPhrases
                    presetManager.updatePreset(updatedPreset)
                } else {
                    // 新しいプリセットとして追加 (元のIDを保持)
                    presetManager.addPresetWithId(preset.id, name: preset.name)
                    // 追加されたプリセットのIDを取得して、定型文を追加
                    if let addedPreset = presetManager.presets.first(where: { $0.id == preset.id }) {
                        standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                    }
                }
            }
        case .add:
            // プリセットをそのまま追加 (新しいIDを割り当て、名前を変更)
            for preset in presetsToImport {
                // 新しいUUIDを生成
                let newId = UUID()
                
                // デフォルトプリセットの判定と名前変更
                let defaultPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                let defaultPresetName = String(localized: "Default")
                var newPresetName = preset.name
                if preset.id == defaultPresetId {
                    newPresetName = defaultPresetName
                }
                
                // 新しいIDと名前でプリセットを追加
                presetManager.addPresetWithId(newId, name: newPresetName)
                // 追加されたプリセットのIDを取得して、定型文を追加
                if let addedPreset = presetManager.presets.first(where: { $0.id == newId }) {
                    standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                }
            }
        case .skip:
            // 競合するプリセットを除いて追加
            for preset in presetsToImport {
                // IDが一致するプリセットはスキップ
                if presetManager.presets.contains(where: { $0.id == preset.id }) {
                    continue
                }
                
                // 名前が一致するプリセットもスキップ
                if conflictingPresets.contains(where: { $0.name == preset.name }) {
                    continue
                }
                
                presetManager.addPresetWithId(preset.id, name: preset.name)
                // 追加されたプリセットのIDを取得して、定型文を追加
                if let addedPreset = presetManager.presets.first(where: { $0.id == preset.id }) {
                    standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                }
            }
        case .resolveIndividually:
            // 個別に解決
            var presetsNeedingConflictResolution: [StandardPhrasePreset] = []
            
            for preset in presetsToImport {
                if let individualAction = individualActions[preset.id] {
                    switch individualAction {
                    case .merge:
                        if let existingPreset = presetManager.presets.first(where: { $0.id == preset.id }) {
                            // IDが一致するプリセットが存在する場合、定型文を統合
                            var mergedPhrases = existingPreset.phrases
                            
                            // 新しい定型文のみを追加 (内容が一致するものは除外)
                            for newPhrase in preset.phrases {
                                // 同じIDの定型文が既に存在するかチェック
                                if let existingIndex = mergedPhrases.firstIndex(where: { $0.id == newPhrase.id }) {
                                    // IDが一致する定型文が存在する場合
                                    let existingPhrase = mergedPhrases[existingIndex]
                                    
                                    // IDとコンテンツの両方が一致する場合はスキップ
                                    if existingPhrase.content != newPhrase.content {
                                        // IDが一致するがコンテンツが異なる場合は、新しいUUIDを割り当てて追加
                                        let phraseWithNewId = StandardPhrase(id: UUID(), title: newPhrase.title, content: newPhrase.content)
                                        mergedPhrases.append(phraseWithNewId)
                                    }
                                } else {
                                    // 同じIDの定型文が存在しない場合は追加
                                    mergedPhrases.append(newPhrase)
                                }
                            }
                            
                            // 更新されたプリセットを保存
                            var updatedPreset = existingPreset
                            updatedPreset.phrases = mergedPhrases
                            presetManager.updatePreset(updatedPreset)
                        } 
                        // 名前が一致するプリセットを探す（IDが異なる場合）
                        else if let existingPreset = presetManager.presets.first(where: { $0.name == preset.name && $0.id != preset.id }) {
                            // 名前が一致する既存のプリセットに定型文を統合
                            var mergedPhrases = existingPreset.phrases
                            
                            // 新しい定型文のみを追加 (内容が一致するものは除外)
                            for newPhrase in preset.phrases {
                                if !mergedPhrases.contains(where: { $0.title == newPhrase.title && $0.content == newPhrase.content }) {
                                    mergedPhrases.append(newPhrase)
                                }
                            }
                            
                            // 更新されたプリセットを保存
                            var updatedPreset = existingPreset
                            updatedPreset.phrases = mergedPhrases
                            presetManager.updatePreset(updatedPreset)
                        } else {
                            // 新しいプリセットとして追加 (元のIDを保持)
                            presetManager.addPresetWithId(preset.id, name: preset.name)
                            // 追加されたプリセットのIDを取得して、定型文を追加
                            if let addedPreset = presetManager.presets.first(where: { $0.id == preset.id }) {
                                standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                            }
                        }
                    case .add:
                        // プリセットをそのまま追加 (新しいIDを割り当て、名前を変更)
                        // 新しいUUIDを生成
                        let newId = UUID()
                        
                        // デフォルトプリセットの判定と名前変更
                        let defaultPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                        let defaultPresetName = String(localized: "Default")
                        var newPresetName = preset.name
                        if preset.id == defaultPresetId {
                            newPresetName = defaultPresetName
                        }
                        
                        // 新しいIDと名前でプリセットを追加
                        presetManager.addPresetWithId(newId, name: newPresetName)
                        // 追加されたプリセットのIDを取得して、定型文を追加
                        if let addedPreset = presetManager.presets.first(where: { $0.id == newId }) {
                            standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                        }
                    case .skip:
                        // プリセットをスキップ
                        continue
                    case .resolveIndividually:
                        // このプリセットは個別に競合解決する必要がある
                        presetsNeedingConflictResolution.append(preset)
                        // プリセットを追加 (元のIDを保持)
                        presetManager.addPresetWithId(preset.id, name: preset.name)
                    }
                }
            }
            
            // 競合解決が必要なプリセットがある場合、ImportConflictSheetを表示
            if !presetsNeedingConflictResolution.isEmpty {
                presetConflicts.removeAll()
                
                // 各プリセットについて競合チェックを行う
                for preset in presetsNeedingConflictResolution {
                    let (conflicts, nonConflicts) = standardPhraseManager.checkConflicts(with: preset.phrases, inPresetId: preset.id)
                    let conflictInfo = PresetConflictInfo(
                        preset: preset,
                        conflicts: conflicts,
                        nonConflictingPhrases: nonConflicts
                    )
                    presetConflicts.append(conflictInfo)
                }
                
                // 最初のプリセットの競合解決を開始
                currentPresetIndexForConflictResolution = 0
                showingImportConflictSheet = true
            }
        }
        
        // 状態をリセット (競合解決が必要な場合はリセットしない)
        if presetConflicts.isEmpty {
            presetsToImport.removeAll()
            conflictingPresets.removeAll()
        }
        
        restoreSelectionAfterImport()
    }
    
    // エクスポートファイル名を生成するメソッド
    private func getExportFileName() -> String {
        if useLegacyFormat {
            if let presetId = selectedExportPresetId,
               let preset = presetManager.presets.first(where: { $0.id == presetId }) {
                // 特定のプリセットをエクスポートする場合
                return "Clip Hold Standard Phrases \(preset.name).json"
            } else {
                // すべてのプリセットをエクスポートする場合
                return "Clip Hold All Standard Phrases.json"
            }
        } else {
            if let presetId = selectedExportPresetId,
               let preset = presetManager.presets.first(where: { $0.id == presetId }) {
                // 特定のプリセットをエクスポートする場合
                return "Clip Hold Standard Phrases \(preset.name).json"
            } else {
                // すべてのプリセットをエクスポートする場合
                return "Clip Hold All Standard Phrases.json"
            }
        }
    }
    
    // エクスポートドキュメントを作成するメソッド
    private func createExportDocument() -> PhraseDocument {
        if useLegacyFormat {
            // レガシーフォーマット: 選択されたプリセットまたはすべての定型文をマージ
            let phrases: [StandardPhrase]
            if let presetId = selectedExportPresetId, 
               let preset = presetManager.presets.first(where: { $0.id == presetId }) {
                phrases = preset.phrases
            } else {
                // すべてのプリセットの定型文をマージ
                phrases = presetManager.presets.flatMap { $0.phrases }
            }
            return PhraseDocument(standardPhrases: phrases, isLegacyFormat: true)
        } else {
            // プリセットフォーマット
            if let presetId = selectedExportPresetId,
               let preset = presetManager.presets.first(where: { $0.id == presetId }) {
                // 単一プリセットをエクスポート
                return PhraseDocument(presetData: [preset], isLegacyFormat: false)
            } else {
                // すべてのプリセットをエクスポート
                return PhraseDocument(presetData: presetManager.presets, isLegacyFormat: false)
            }
        }
    }
}
