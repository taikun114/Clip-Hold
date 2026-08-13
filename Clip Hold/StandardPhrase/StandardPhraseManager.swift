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
        
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("ClipHoldDidUpdatePhrasesInBackground"), object: nil, queue: .main) { [weak self] _ in
            self?.loadStandardPhrases()
        }
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
        
        // デフォルトプリセットとして保存
        let defaultFileURL = presetDirectory.appendingPathComponent("default.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // 可読性のために整形 (Optional)
            
            let data = try encoder.encode(standardPhrases)
            try data.write(to: defaultFileURL)
        } catch {
            print("StandardPhraseManager: Error saving standard phrases to file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Loading (ファイルシステムからロード)
    func loadStandardPhrases() {
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
        let defaultFileURL = presetDirectory.appendingPathComponent("default.json")
        
        // ファイルが存在しない場合は早期リターン
        guard FileManager.default.fileExists(atPath: fileURL.path) || FileManager.default.fileExists(atPath: defaultFileURL.path) else {
            print("StandardPhraseManager: Default preset file not found, starting with empty phrases.")
            return
        }
        
        // 存在する方のファイルURLを使用
        let actualFileURL = FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : defaultFileURL
        
        do {
            let data = try Data(contentsOf: actualFileURL)
            let decoder = JSONDecoder()
            
            self.standardPhrases = try decoder.decode([StandardPhrase].self, from: data)
            print("StandardPhraseManager: Standard phrases loaded from file. Count: \(standardPhrases.count), Size: \(data.count) bytes.")
        } catch {
            print("StandardPhraseManager: Error loading standard phrases from file: \(error.localizedDescription)")
        }
    }
    
    func addPhrase(title: String, content: String) {
        guard !ClipboardManager.shared.isExporting else { return }
        let newPhrase = StandardPhrase(title: title, content: content)
        standardPhrases.append(newPhrase)
        SpotlightManager.shared.indexStandardPhrase(newPhrase)
    }
    
    func updatePhrase(id: UUID, newTitle: String, newContent: String) {
        guard !ClipboardManager.shared.isExporting else { return }
        if let index = standardPhrases.firstIndex(where: { $0.id == id }) {
            var phrase = standardPhrases[index]
            phrase.title = newTitle
            phrase.content = newContent
            standardPhrases[index] = phrase
            SpotlightManager.shared.indexStandardPhrase(phrase)
        }
    }
    
    func deletePhrase(id: UUID) {
        guard !ClipboardManager.shared.isExporting else { return }
        standardPhrases.removeAll { $0.id == id }
        SpotlightManager.shared.removeStandardPhrase(id: id)
    }
    
    func deletePhrase(atOffsets offsets: IndexSet) {
        guard !ClipboardManager.shared.isExporting else { return }
        // Spotlightから削除
        for index in offsets {
            let phrase = standardPhrases[index]
            SpotlightManager.shared.removeStandardPhrase(id: phrase.id)
        }
        standardPhrases.remove(atOffsets: offsets)
    }
    
    func movePhrase(from source: IndexSet, to destination: Int) {
        guard !ClipboardManager.shared.isExporting else { return }
        standardPhrases.move(fromOffsets: source, toOffset: destination)
    }
    
    func deleteAllPhrases() {
        guard !ClipboardManager.shared.isExporting else { return }
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
            
            // IDが一致する既存の定型文を探す
            let existingPhraseWithId = targetPhrases.first { $0.id == importedPhrase.id }
            
            // IDが一致する場合も重複として処理
            if existingPhraseWithId != nil || existingPhraseWithTitle != nil || existingPhraseWithContent != nil {
                // 既存の定型文と競合している場合
                let existingPhrase = existingPhraseWithId ?? existingPhraseWithTitle ?? existingPhraseWithContent!
                var duplicate = StandardPhraseDuplicate(
                    existingPhrase: existingPhrase,
                    newPhrase: importedPhrase
                )
                // カスタムタイトルを使用するかどうかの初期値を設定
                duplicate.setInitialUseCustomTitle()
                conflicts.append(duplicate)
            } else {
                // 競合していない場合はそのまま追加
                nonConflicts.append(importedPhrase)
            }
        }
        
        return (conflicts, nonConflicts)
    }
    
    @MainActor func addImportedPhrases(_ phrasesToAdd: [StandardPhrase], toPresetId presetId: UUID? = nil) {
        guard !ClipboardManager.shared.isExporting else { return }
        if let presetId = presetId {
            // 指定されたプリセットに定型文を追加
            if var preset = StandardPhrasePresetManager.shared.presets.first(where: { $0.id == presetId }) {
                var updatedPhrases = preset.phrases
                var addedPhrases: [StandardPhrase] = []
                
                for newPhrase in phrasesToAdd {
                    // 同じIDの定型文が既に存在するかチェック
                    if let existingIndex = updatedPhrases.firstIndex(where: { $0.id == newPhrase.id }) {
                        // IDが一致する定型文が存在する場合
                        let existingPhrase = updatedPhrases[existingIndex]
                        
                        // IDとコンテンツの両方が一致する場合はスキップ
                        if existingPhrase.content == newPhrase.content {
                            continue
                        } else {
                            // IDが一致するがコンテンツが異なる場合は、新しいUUIDを割り当てて追加
                            let phraseWithNewId = StandardPhrase(id: UUID(), title: newPhrase.title, content: newPhrase.content)
                            updatedPhrases.append(phraseWithNewId)
                            addedPhrases.append(phraseWithNewId)
                        }
                    } else {
                        // 同じIDの定型文が存在しない場合は追加
                        updatedPhrases.append(newPhrase)
                        addedPhrases.append(newPhrase)
                    }
                }
                
                preset.phrases = updatedPhrases
                StandardPhrasePresetManager.shared.updatePreset(preset)
                
                // 新しく追加された定型文をSpotlightにインデックス登録
                if !addedPhrases.isEmpty {
                    let capturedPreset = preset
                    let capturedPhrases = addedPhrases
                    Task {
                        await SpotlightManager.shared.indexStandardPhrases(capturedPhrases, inPreset: capturedPreset)
                    }
                }
            }
        } else {
            // デフォルトの動作: 全定型文リストに追加
            var updatedPhrases = standardPhrases
            var addedPhrases: [StandardPhrase] = []
            
            for newPhrase in phrasesToAdd {
                // 同じIDの定型文が既に存在するかチェック
                if let existingIndex = updatedPhrases.firstIndex(where: { $0.id == newPhrase.id }) {
                    // IDが一致する定型文が存在する場合
                    let existingPhrase = updatedPhrases[existingIndex]
                    
                    // IDとコンテンツの両方が一致する場合はスキップ
                    if existingPhrase.content == newPhrase.content {
                        continue
                    } else {
                        // IDが一致するがコンテンツが異なる場合は、新しいUUIDを割り当てて追加
                        let phraseWithNewId = StandardPhrase(id: UUID(), title: newPhrase.title, content: newPhrase.content)
                        updatedPhrases.append(phraseWithNewId)
                        addedPhrases.append(phraseWithNewId)
                    }
                } else {
                    // 同じIDの定型文が存在しない場合は追加
                    updatedPhrases.append(newPhrase)
                    addedPhrases.append(newPhrase)
                }
            }
            
            standardPhrases = updatedPhrases
            print("Added imported phrases. Current standard phrases count: \(self.standardPhrases.count)")
            
            // 新しく追加された定型文をSpotlightにインデックス登録（プリセットなしのためアイコンはnil）
            if !addedPhrases.isEmpty {
                let capturedPhrases = addedPhrases
                Task {
                    await SpotlightManager.shared.indexStandardPhrases(capturedPhrases, inPreset: nil)
                }
            }
        }
    }
}
