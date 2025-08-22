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
        self.standardPhrases = try JSONDecoder().decode([StandardPhrase].self, from: data)
        self.presetData = nil
        self.isLegacyFormat = true
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
                let gotAccess = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if gotAccess {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let data = try Data(contentsOf: selectedURL)
                    let decoder = JSONDecoder()
                    let importedPhrases = try decoder.decode([StandardPhrase].self, from: data)

                    let (conflicts, nonConflicts) = standardPhraseManager.checkConflicts(with: importedPhrases)

                    if !conflicts.isEmpty {
                        importConflicts = conflicts
                        nonConflictingPhrasesToImport = nonConflicts
                        showingImportConflictSheet = true
                    } else {
                        standardPhraseManager.addImportedPhrases(importedPhrases)
                    }

                } catch {
                    importError = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                }
            case .failure(let error):
                importError = "ファイルの選択に失敗しました: \(error.localizedDescription)"
            }
        }
        .alert("インポートエラー", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "不明なエラーが発生しました。")
        }
        .sheet(isPresented: $showingImportConflictSheet) {
            ImportConflictSheet(
                conflicts: $importConflicts,
                nonConflictingPhrases: $nonConflictingPhrasesToImport
            ) { finalPhrasesToImport in
                standardPhraseManager.addImportedPhrases(finalPhrasesToImport)
                importConflicts.removeAll() // シートを閉じたらクリア
                nonConflictingPhrasesToImport.removeAll() // シートを閉じたらクリア
            }
            .environmentObject(standardPhraseManager)
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
