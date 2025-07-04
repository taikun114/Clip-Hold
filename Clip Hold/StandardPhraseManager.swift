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

    private init() {
        loadStandardPhrases()
        print("StandardPhraseManager: Initialized with phrase count: \(standardPhrases.count)")
    }

    // MARK: - Persistence (ファイルシステムに保存)
    private func saveStandardPhrases() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("StandardPhraseManager: Could not find Application Support directory (save).")
            return
        }

        // アプリ固有のサブディレクトリを作成 (ClipboardManager と同じ場所)
        let appSpecificDirectory = directory.appendingPathComponent("ClipHold")
        let fileURL = appSpecificDirectory.appendingPathComponent(phrasesFileName)

        do {
            // ディレクトリが存在しない場合は作成
            if !FileManager.default.fileExists(atPath: appSpecificDirectory.path) {
                try FileManager.default.createDirectory(at: appSpecificDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
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
        let fileURL = appSpecificDirectory.appendingPathComponent(phrasesFileName)
        
        // ファイルが存在しない場合は早期リターン (初回起動時やファイルがない場合)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("StandardPhraseManager: Standard phrases file not found, starting with empty phrases.")
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

    func checkConflicts(with importedPhrases: [StandardPhrase]) -> (conflicting: [StandardPhraseDuplicate], nonConflicting: [StandardPhrase]) {
        var conflicting: [StandardPhraseDuplicate] = []
        var nonConflicting: [StandardPhrase] = []

        for importedPhrase in importedPhrases {
            if let existingPhrase = standardPhrases.first(where: {
                $0.title == importedPhrase.title || $0.content == importedPhrase.content
            }) {
                conflicting.append(StandardPhraseDuplicate(existingPhrase: existingPhrase, newPhrase: importedPhrase))
            } else {
                nonConflicting.append(importedPhrase)
            }
        }
        print("インポートフレーズを競合と非競合に分割しました。競合: \(conflicting.count), 非競合: \(nonConflicting.count)")
        return (conflicting, nonConflicting)
    }

    func addImportedPhrases(_ phrasesToAdd: [StandardPhrase]) {
        standardPhrases.append(contentsOf: phrasesToAdd)
        print("インポートされたフレーズを追加しました。現在の定型文数: \(self.standardPhrases.count)")
    }
}
