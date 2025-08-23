import Foundation
import SwiftUI
import Combine

class StandardPhraseManager: ObservableObject {
    static let shared = StandardPhraseManager()

    @Published var standardPhrases: [StandardPhrase] = [] {
        didSet {
            saveStandardPhrases()
        }
    }

    private let phrasesFileName = "standardPhrases.json"
    private let presetDirectoryName = "standardPhrasesPreset"

    private init() {
        migrateToPresetDirectory()
        loadStandardPhrases()
        print("StandardPhraseManager: Initialized with phrase count: \(standardPhrases.count)")
    }

    // MARK: - Migration to Preset Directory
    private func migrateToPresetDirectory() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("StandardPhraseManager: Could not find Application Support directory (migration).")
            return
        }

        let appSpecificDirectory = directory.appendingPathComponent("ClipHold")
        let oldFileURL = appSpecificDirectory.appendingPathComponent(phrasesFileName)
        let presetDirectory = appSpecificDirectory.appendingPathComponent(presetDirectoryName)

        // プリセットディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: presetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: presetDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("StandardPhraseManager: Error creating preset directory: \(error.localizedDescription)")
                return
            }
        }

        // 既存のstandardPhrases.jsonファイルがあれば、default.jsonとしてリネーム
        if FileManager.default.fileExists(atPath: oldFileURL.path) {
            let defaultFileURL = presetDirectory.appendingPathComponent("default.json")
            do {
                try FileManager.default.moveItem(at: oldFileURL, to: defaultFileURL)
                print("StandardPhraseManager: Migrated standardPhrases.json to default.json in preset directory.")
            } catch {
                print("StandardPhraseManager: Error migrating standardPhrases.json: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistence (ファイルシステムに保存)
    private func saveStandardPhrases() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("StandardPhraseManager: Could not find Application Support directory (save).")
            return
        }

        // アプリ固有のサブディレクトリとプリセットディレクトリを取得
        let appSpecificDirectory = directory.appendingPathComponent("ClipHold")
        let presetDirectory = appSpecificDirectory.appendingPathComponent(presetDirectoryName)

        // プリセットディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: presetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: presetDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("StandardPhraseManager: Error creating preset directory: \(error.localizedDescription)")
                return
            }
        }

        // デフォルトプリセットとして保存 (UUIDは固定)
        let defaultPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let fileURL = presetDirectory.appendingPathComponent("\(defaultPresetId.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // 可読性のために整形 (Optional)
            
            let data = try encoder.encode(standardPhrases)
            try data.write(to: fileURL)
        } catch {
            print("StandardPhraseManager: Error saving standard phrases to file: \(error.localizedDescription)")
        }
    }

    // MARK: - Loading (ファイルシステムからロード)
    private func loadStandardPhrases() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("StandardPhraseManager: Could not find Application Support directory (load).")
            return
        }
        
        let appSpecificDirectory = directory.appendingPathComponent("ClipHold")
        let presetDirectory = appSpecificDirectory.appendingPathComponent(presetDirectoryName)
        
        // プリセットディレクトリが存在しない場合は早期リターン
        guard FileManager.default.fileExists(atPath: presetDirectory.path) else {
            print("StandardPhraseManager: Preset directory not found, starting with empty phrases.")
            return
        }
        
        // デフォルトプリセットファイルをロード
        let defaultPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let fileURL = presetDirectory.appendingPathComponent("\(defaultPresetId.uuidString).json")
        
        // ファイルが存在しない場合は早期リターン
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("StandardPhraseManager: Default preset file not found, starting with empty phrases.")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            
            self.standardPhrases = try decoder.decode([StandardPhrase].self, from: data)
            print("StandardPhraseManager: Standard phrases loaded from file. Count: \(standardPhrases.count), Size: \(data.count) bytes.")
        } catch {
            print("StandardPhraseManager: Error loading standard phrases from file: \(error.localizedDescription)")
        }
    }

    func addPhrase(title: String, content: String) {
        let newPhrase = StandardPhrase(title: title, content: content)
        standardPhrases.append(newPhrase)
    }

    func updatePhrase(id: UUID, newTitle: String, newContent: String) {
        if let index = standardPhrases.firstIndex(where: { $0.id == id }) {
            var phrase = standardPhrases[index]
            phrase.title = newTitle
            phrase.content = newContent
            standardPhrases[index] = phrase
        }
    }

    func deletePhrase(id: UUID) {
        standardPhrases.removeAll { $0.id == id }
    }

    func deletePhrase(atOffsets offsets: IndexSet) {
        standardPhrases.remove(atOffsets: offsets)
    }

    func movePhrase(from source: IndexSet, to destination: Int) {
        standardPhrases.move(fromOffsets: source, toOffset: destination)
    }

    func deleteAllPhrases() {
        standardPhrases.removeAll()
    }

    @MainActor func checkConflicts(with importedPhrases: [StandardPhrase], inPresetId presetId: UUID? = nil) -> (conflicts: [StandardPhraseDuplicate], nonConflicts: [StandardPhrase]) {
        var conflicts: [StandardPhraseDuplicate] = []
        var nonConflicts: [StandardPhrase] = []
        
        // チェック対象の定型文リストを決定
        let targetPhrases: [StandardPhrase]
        if let presetId = presetId, 
           let preset = StandardPhrasePresetManager.shared.presets.first(where: { $0.id == presetId }) {
            targetPhrases = preset.phrases
        } else {
            targetPhrases = standardPhrases
        }
        
        for importedPhrase in importedPhrases {
            // タイトルまたは内容が一致する既存の定型文を探す
            let existingPhraseWithTitle = targetPhrases.first { $0.title == importedPhrase.title }
            let existingPhraseWithContent = targetPhrases.first { $0.content == importedPhrase.content }
            
            if existingPhraseWithTitle != nil || existingPhraseWithContent != nil {
                // 既存の定型文と競合している場合
                let duplicate = StandardPhraseDuplicate(
                    existingPhrase: existingPhraseWithTitle ?? existingPhraseWithContent!,
                    newPhrase: importedPhrase
                )
                conflicts.append(duplicate)
            } else {
                // 競合していない場合はそのまま追加
                nonConflicts.append(importedPhrase)
            }
        }
        
        return (conflicts, nonConflicts)
    }

    @MainActor func addImportedPhrases(_ phrasesToAdd: [StandardPhrase], toPresetId presetId: UUID? = nil) {
        if let presetId = presetId {
            // 指定されたプリセットに定型文を追加
            if var preset = StandardPhrasePresetManager.shared.presets.first(where: { $0.id == presetId }) {
                preset.phrases.append(contentsOf: phrasesToAdd)
                StandardPhrasePresetManager.shared.updatePreset(preset)
            }
        } else {
            // デフォルトの動作: 全定型文リストに追加
            standardPhrases.append(contentsOf: phrasesToAdd)
            print("インポートされたフレーズを追加しました。現在の定型文数: \(self.standardPhrases.count)")
        }
    }
}
