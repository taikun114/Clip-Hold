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

    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    init(standardPhrases: [StandardPhrase] = []) {
        self.standardPhrases = standardPhrases
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.standardPhrases = try JSONDecoder().decode([StandardPhrase].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(standardPhrases)
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

    @State private var showingFileExporter = false
    @State private var showingFileImporter = false
    @State private var importError: String? = nil
    @State private var showingImportConflictSheet = false
    @State private var importConflicts: [StandardPhraseDuplicate] = []
    @State private var nonConflictingPhrasesToImport: [StandardPhrase] = []

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
                showingFileExporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("エクスポート")
                }
            }
            .buttonStyle(.bordered)
            .disabled(standardPhraseManager.standardPhrases.isEmpty)
            .help("すべての定型文をJSONファイルとして書き出します。") // エクスポートボタンのツールチップ
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: standardPhraseManager.exportPhrasesAsDocument(),
            contentType: .json,
            defaultFilename: "Clip Hold Standard Phrases.json"
        ) { result in
            switch result {
            case .success(let url):
                print("エクスポート成功: \(url)")
            case .failure(let error):
                print("エクスポート失敗: \(error.localizedDescription)")
            }
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
}
