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
    @StateObject private var presetManager = StandardPhrasePresetManager.shared

    @State private var showingFileExporter = false
    @State private var showingFileImporter = false
    @State private var importError: String? = nil
    @State private var showingImportConflictSheet = false
    @State private var importConflicts: [StandardPhraseDuplicate] = []
    @State private var nonConflictingPhrasesToImport: [StandardPhrase] = []
    @State private var currentSelectedURL: URL? = nil // 追加: 現在選択されているURLを保持
    @State private var targetPresetIdForConflictResolution: UUID? // 追加: 競合解決用のプリセットID
    
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
    
    // すべてのプリセットが空かどうかを判定する計算プロパティ
    private var areAllPresetsEmpty: Bool {
        return presetManager.presets.allSatisfy { $0.phrases.isEmpty }
    }
    
    // 選択可能なプリセットのリスト
    private var exportablePresets: [StandardPhrasePreset] {
        return presetManager.presets
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
            .help("すべての定型文をJSONファイルとして書き出します。") // エクスポートボタンのツールチップ
        }
        .sheet(isPresented: $showingExportSheet) {
            VStack(alignment: .leading, spacing: 10) {
                Text("定型文のエクスポート")
                    .font(.headline)
                
                Text("エクスポートしたいプリセットを選択")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("プリセットを選択", selection: $selectedExportPresetId) {
                    Text("すべて")
                        .tag(nil as UUID?)
                    
                    Divider()
                    
                    ForEach(exportablePresets) { preset in
                        Text(preset.name)
                            .tag(preset.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                
                Toggle("旧バージョンで使用できるようにする", isOn: $useLegacyFormat)
                    .help("有効にすると、プリセット情報なしで定型文のみをエクスポートします。")
                Spacer()

                HStack {
                    Spacer()
                    Button("キャンセル") {
                        showingExportSheet = false
                        selectedExportPresetId = nil
                        useLegacyFormat = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                    
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
            defaultFilename: "Clip Hold Standard Phrases.json"
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
                conflicts: $importConflicts,
                nonConflictingPhrases: $nonConflictingPhrasesToImport
            ) { finalPhrasesToImport in
                if let presetId = targetPresetIdForConflictResolution {
                    standardPhraseManager.addImportedPhrases(finalPhrasesToImport, toPresetId: presetId)
                }
                importConflicts.removeAll() // シートを閉じたらクリア
                nonConflictingPhrasesToImport.removeAll() // シートを閉じたらクリア
                targetPresetIdForConflictResolution = nil // リセット
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
    
    // MARK: - レガシーフォーマットインポート処理
    private func handleLegacyFormatImport(_ phrases: [StandardPhrase]) {
        // プリセット選択シートを表示
        showingImportPresetSelectionSheet = true
        selectedImportPresetId = presetManager.selectedPresetId
    }
    
    // MARK: - プリセット選択後の処理
    private func processImportIntoPreset(presetId: UUID) {
        targetPresetIdForConflictResolution = presetId
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
                importConflicts = conflicts
                nonConflictingPhrasesToImport = nonConflicts
                showingImportConflictSheet = true
            } else {
                // 競合がなければ直接追加
                standardPhraseManager.addImportedPhrases(nonConflicts, toPresetId: presetId)
            }
        } catch {
            importError = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - プリセットフォーマットインポート処理
    private func handlePresetFormatImport(_ presets: [StandardPhrasePreset]) {
        presetsToImport = presets
        var conflicts: [StandardPhrasePreset] = []
        
        // 既存のプリセットと比較して競合をチェック
        for preset in presets {
            if presetManager.presets.first(where: { $0.name == preset.name && $0.id != preset.id }) != nil {
                conflicts.append(preset)
            }
        }
        
        if !conflicts.isEmpty {
            // 競合がある場合は競合シートを表示
            conflictingPresets = conflicts
            showingPresetConflictSheet = true
        } else {
            // 競合がなければそのまま統合
            processPresetImportWithAction(.merge)
        }
    }
    
    // MARK: - プリセット競合後の処理
    private func processPresetImportWithAction(_ action: PresetConflictSheet.PresetConflictAction, individualActions: [UUID: PresetConflictSheet.PresetConflictAction] = [:]) {
        switch action {
        case .merge:
            for preset in presetsToImport {
                if let existingPreset = presetManager.presets.first(where: { $0.name == preset.name && $0.id != preset.id }) {
                    // 既存のプリセットに定型文を統合
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
                    // 新しいプリセットとして追加
                    presetManager.addPreset(name: preset.name)
                    // 追加されたプリセットのIDを取得して、定型文を追加
                    if let addedPreset = presetManager.presets.first(where: { $0.name == preset.name }) {
                        standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                    }
                }
            }
        case .add:
            // プリセットをそのまま追加 (名前が同じでも新しいIDで保存)
            for preset in presetsToImport {
                // 既存のプリセット名と重複しないように新しい名前を生成
                var newPresetName = preset.name
                var counter = 1
                while presetManager.presets.contains(where: { $0.name == newPresetName }) {
                    newPresetName = "\(preset.name) (\(counter))"
                    counter += 1
                }
                
                presetManager.addPreset(name: newPresetName)
                // 追加されたプリセットのIDを取得して、定型文を追加
                if let addedPreset = presetManager.presets.first(where: { $0.name == newPresetName }) {
                    standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                }
            }
        case .skip:
            // 競合するプリセットを除いて追加
            for preset in presetsToImport {
                if !conflictingPresets.contains(where: { $0.name == preset.name }) {
                    presetManager.addPreset(name: preset.name)
                    // 追加されたプリセットのIDを取得して、定型文を追加
                    if let addedPreset = presetManager.presets.first(where: { $0.name == preset.name }) {
                        standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                    }
                } else {
                    // 競合するプリセットはスキップ
                    continue
                }
            }
        case .resolveIndividually:
            // 個別に解決
            for preset in presetsToImport {
                if let individualAction = individualActions[preset.id] {
                    switch individualAction {
                    case .merge:
                        if let existingPreset = presetManager.presets.first(where: { $0.name == preset.name && $0.id != preset.id }) {
                            // 既存のプリセットに定型文を統合
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
                            // 新しいプリセットとして追加
                            presetManager.addPreset(name: preset.name)
                            // 追加されたプリセットのIDを取得して、定型文を追加
                            if let addedPreset = presetManager.presets.first(where: { $0.name == preset.name }) {
                                standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                            }
                        }
                    case .add:
                        // プリセットをそのまま追加 (名前が同じでも新しいIDで保存)
                        // 既存のプリセット名と重複しないように新しい名前を生成
                        var newPresetName = preset.name
                        var counter = 1
                        while presetManager.presets.contains(where: { $0.name == newPresetName }) {
                            newPresetName = "\(preset.name) (\(counter))"
                            counter += 1
                        }
                        
                        presetManager.addPreset(name: newPresetName)
                        // 追加されたプリセットのIDを取得して、定型文を追加
                        if let addedPreset = presetManager.presets.first(where: { $0.name == newPresetName }) {
                            standardPhraseManager.addImportedPhrases(preset.phrases, toPresetId: addedPreset.id)
                        }
                    case .skip:
                        // プリセットをスキップ
                        continue
                    case .resolveIndividually:
                        // このケースは発生しないはず
                        break
                    }
                }
            }
        }
        
        // 状態をリセット
        presetsToImport.removeAll()
        conflictingPresets.removeAll()
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
