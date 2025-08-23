import Foundation
import SwiftUI

@MainActor
class StandardPhrasePresetManager: ObservableObject {
    static let shared = StandardPhrasePresetManager()
    
    @Published var presets: [StandardPhrasePreset] = []
    @Published var selectedPresetId: UUID?
    
    private let presetDirectoryName = "standardPhrasesPreset"
    private let presetIndexFileName = "presetIndex.json"
    private let defaultPresetFileName = "default"
    private let defaultPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private let userDeletedDefaultPresetKey = "UserDeletedDefaultPreset" // ユーザーがデフォルトプリセットを削除したことを記録するキー
    
    private init() {
        loadPresetsFromFileSystem()
        // 初回起動時にデフォルトプリセットを作成（ただしユーザーが削除していない場合のみ）
        if presets.isEmpty && !didUserDeleteDefaultPreset() {
            createDefaultPreset()
        }
        // 選択されたプリセットがなければ最初のものを選択
        if selectedPresetId == nil, let firstPreset = presets.first {
            selectedPresetId = firstPreset.id
        }
    }
    
    // ユーザーがデフォルトプリセットを削除したかどうかを確認するメソッド
    private func didUserDeleteDefaultPreset() -> Bool {
        return UserDefaults.standard.bool(forKey: userDeletedDefaultPresetKey)
    }
    
    // ユーザーがデフォルトプリセットを削除したことを記録するメソッド
    private func setUserDeletedDefaultPreset() {
        UserDefaults.standard.set(true, forKey: userDeletedDefaultPresetKey)
    }
    
    private func getPresetDirectory() -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return directory.appendingPathComponent("ClipHold").appendingPathComponent(presetDirectoryName)
    }
    
    private func createDefaultPreset() {
        // ユーザーがデフォルトプリセットを削除している場合は作成しない
        if didUserDeleteDefaultPreset() {
            return
        }
        
        // 既にデフォルトプリセットが存在する場合は作成しない
        if presets.contains(where: { $0.id == defaultPresetId }) {
            return
        }
        
        // StandardPhraseManagerから既存の定型文を取得
        let standardPhraseManager = StandardPhraseManager.shared
        let defaultPreset = StandardPhrasePreset(
            id: defaultPresetId,
            name: String(localized: "デフォルト"),
            phrases: standardPhraseManager.standardPhrases
        )
        presets.append(defaultPreset)
        selectedPresetId = defaultPreset.id
        savePresetToFile(defaultPreset)
        savePresetIndex()
        saveSelectedPresetId()
    }
    
    private func createDefaultPresetIfNeeded() {
        // ユーザーがデフォルトプリセットを削除している場合は作成しない
        if didUserDeleteDefaultPreset() {
            return
        }
        
        // 既にデフォルトプリセットが存在する場合は作成しない
        if presets.contains(where: { $0.id == defaultPresetId }) {
            return
        }
        
        // StandardPhraseManagerから既存の定型文を取得
        let standardPhraseManager = StandardPhraseManager.shared
        let defaultPreset = StandardPhrasePreset(
            id: defaultPresetId,
            name: String(localized: "デフォルト"),
            phrases: standardPhraseManager.standardPhrases
        )
        presets.append(defaultPreset)
        savePresetToFile(defaultPreset)
        savePresetIndex()
    }
    
    private func loadPresetsFromFileSystem() {
        guard let presetDirectory = getPresetDirectory() else {
            presets = []
            return
        }
        
        // プリセットディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: presetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: presetDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating preset directory: \(error.localizedDescription)")
                presets = []
                return
            }
        }
        
        // プリセットフォルダ内のファイルをスキャン
        let presetFiles: [URL]
        do {
            presetFiles = try FileManager.default.contentsOfDirectory(at: presetDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != presetIndexFileName }
        } catch {
            print("Error scanning preset directory: \(error.localizedDescription)")
            presets = []
            return
        }
        
        print("Found \(presetFiles.count) preset files")
        
        // presetIndex.jsonをロード、なければ作成
        var indexLoaded = loadPresetIndex()
        print("Index loaded: \(indexLoaded), Presets count: \(presets.count)")
        
        // インデックスが空またはファイル数と一致しない場合、再構築
        if !indexLoaded || presets.isEmpty || presets.count != presetFiles.count {
            print("Rebuilding preset index")
            rebuildPresetIndex(from: presetFiles, in: presetDirectory)
            indexLoaded = true
        }
        
        // デフォルトプリセットファイルが存在する場合
        let defaultFileURL = presetDirectory.appendingPathComponent(defaultPresetFileName).appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: defaultFileURL.path) {
            loadDefaultPreset(from: defaultFileURL)
        } else {
            // デフォルトプリセットがなければ作成
            createDefaultPresetIfNeeded()
        }
        
        // 各プリセットファイルをロード
        for preset in presets {
            let fileURL = presetDirectory.appendingPathComponent(preset.id.uuidString).appendingPathExtension("json")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                loadPresetPhrases(from: fileURL, for: preset.id)
            }
        }
        
        // 選択されたプリセットIDも保存されている場合、復元する
        if let selectedIdData = UserDefaults.standard.data(forKey: "SelectedStandardPhrasePresetId"),
           let selectedId = try? JSONDecoder().decode(UUID.self, from: selectedIdData) {
            // 選択されたプリセットIDが存在するか確認
            if presets.contains(where: { $0.id == selectedId }) {
                selectedPresetId = selectedId
            } else {
                // 存在しない場合はデフォルトプリセットを選択
                selectedPresetId = defaultPresetId
            }
        } else {
            // 保存された選択がない場合はデフォルトプリセットを選択
            selectedPresetId = defaultPresetId
        }
        
        // プリセットが空っぽだった場合は最初のものを選択
        if selectedPresetId == nil, let firstPreset = presets.first {
            selectedPresetId = firstPreset.id
        }
        
        print("Final presets count: \(presets.count)")
    }
    
    private func rebuildPresetIndex(from presetFiles: [URL], in presetDirectory: URL) {
        var newPresets: [StandardPhrasePreset] = []
        
        // デフォルトプリセットを最初に追加（ただしユーザーが削除していない場合のみ）
        if !didUserDeleteDefaultPreset() {
            let defaultPreset = StandardPhrasePreset(id: defaultPresetId, name: String(localized: "デフォルト"), phrases: [])
            newPresets.append(defaultPreset)
        }
        
        // 他のプリセットファイルを処理
        var presetIndex = 1 // デフォルトを除いたインデックス
        for fileURL in presetFiles {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            
            // defaultファイルの場合はスキップ
            if fileName == defaultPresetFileName {
                continue
            }
            
            // UUIDとして解析できるか確認
            if let uuid = UUID(uuidString: fileName) {
                // プリセット名を「プリセット1」「プリセット2」のように設定
                let presetName = String(localized: "プリセット\(presetIndex)")
                let preset = StandardPhrasePreset(id: uuid, name: presetName, phrases: [])
                newPresets.append(preset)
                print("Added preset: \(presetName) with ID: \(uuid)")
                presetIndex += 1
            } else {
                // UUIDとして解析できない場合は、新しいUUIDを割り当ててファイル名を変更
                let newUUID = UUID()
                let newFileName = newUUID.uuidString
                let newFileURL = presetDirectory.appendingPathComponent(newFileName).appendingPathExtension("json")
                
                do {
                    try FileManager.default.moveItem(at: fileURL, to: newFileURL)
                    let presetName = String(localized: "プリセット\(presetIndex)")
                    let preset = StandardPhrasePreset(id: newUUID, name: presetName, phrases: [])
                    newPresets.append(preset)
                    print("Renamed and added preset: \(presetName) with new ID: \(newUUID)")
                    presetIndex += 1
                } catch {
                    print("Error renaming file: \(error.localizedDescription)")
                }
            }
        }
        
        presets = newPresets
        savePresetIndex()
        print("Rebuilt index with \(newPresets.count) presets")
    }
    
    private func loadPresetIndex() -> Bool {
        guard let presetDirectory = getPresetDirectory() else { return false }
        let indexFileURL = presetDirectory.appendingPathComponent(presetIndexFileName)
        
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else { return false }
        
        do {
            let data = try Data(contentsOf: indexFileURL)
            let decoder = JSONDecoder()
            let presetInfos = try decoder.decode([PresetInfo].self, from: data)
            
            presets = presetInfos.map { presetInfo in
                StandardPhrasePreset(id: presetInfo.id, name: presetInfo.name, phrases: [])
            }
            return true
        } catch {
            print("Error loading preset index: \(error.localizedDescription)")
            return false
        }
    }
    
    private func loadDefaultPreset(from fileURL: URL) {
        // ユーザーがデフォルトプリセットを削除している場合はロードしない
        if didUserDeleteDefaultPreset() {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let phrases = try decoder.decode([StandardPhrase].self, from: data)
            
            // 既にデフォルトプリセットが存在する場合は更新
            if let defaultPresetIndex = presets.firstIndex(where: { $0.id == defaultPresetId }) {
                presets[defaultPresetIndex].phrases = phrases
            } else {
                // インデックスにデフォルトプリセットがない場合は新規作成（これは起こらないはず）
                let defaultPreset = StandardPhrasePreset(id: defaultPresetId, name: String(localized: "デフォルト"), phrases: phrases)
                presets.append(defaultPreset)
            }
        } catch {
            print("Error loading default preset: \(error.localizedDescription)")
        }
    }
    
    private func loadPresetPhrases(from fileURL: URL, for presetId: UUID) {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let phrases = try decoder.decode([StandardPhrase].self, from: data)
            
            if let presetIndex = presets.firstIndex(where: { $0.id == presetId }) {
                presets[presetIndex].phrases = phrases
            }
        } catch {
            print("Error loading preset phrases: \(error.localizedDescription)")
        }
    }
    
    private func savePresetToFile(_ preset: StandardPhrasePreset) {
        guard let presetDirectory = getPresetDirectory() else { return }
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: presetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: presetDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating preset directory: \(error.localizedDescription)")
                return
            }
        }
        
        let fileName = preset.id.uuidString == defaultPresetId.uuidString ? defaultPresetFileName : preset.id.uuidString
        let fileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(preset.phrases)
            try data.write(to: fileURL)
        } catch {
            print("Error saving preset to file: \(error.localizedDescription)")
        }
    }
    
    func savePresetIndex() {
        guard let presetDirectory = getPresetDirectory() else { return }
        let indexFileURL = presetDirectory.appendingPathComponent(presetIndexFileName)
        
        let presetInfos = presets.map { preset in
            PresetInfo(id: preset.id, name: preset.name)
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(presetInfos)
            try data.write(to: indexFileURL)
        } catch {
            print("Error saving preset index: \(error.localizedDescription)")
        }
    }
    
    private func deletePresetFile(id: UUID) {
        guard let presetDirectory = getPresetDirectory() else { return }
        let fileName = id.uuidString == defaultPresetId.uuidString ? defaultPresetFileName : id.uuidString
        let fileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // デフォルトプリセットが削除された場合、ユーザーが削除したことを記録
            if id == defaultPresetId {
                setUserDeletedDefaultPreset()
            }
        } catch {
            print("Error deleting preset file: \(error.localizedDescription)")
        }
    }
    
    private func saveSelectedPresetId() {
        if let selectedPresetId = selectedPresetId,
           let encodedId = try? JSONEncoder().encode(selectedPresetId) {
            UserDefaults.standard.set(encodedId, forKey: "SelectedStandardPhrasePresetId")
        }
    }
    
    func addPreset(name: String) {
        let newPreset = StandardPhrasePreset(name: name)
        presets.append(newPreset)
        selectedPresetId = newPreset.id
        savePresetToFile(newPreset)
        savePresetIndex()
        saveSelectedPresetId()
    }
    
    func deletePreset(id: UUID) {
        // デフォルトプリセットが削除される場合は、ユーザーが削除したことを記録
        if id == defaultPresetId {
            setUserDeletedDefaultPreset()
        }
        
        presets.removeAll { $0.id == id }
        deletePresetFile(id: id)
        savePresetIndex()
        // 削除されたプリセットが選択されていたら、別のプリセットを選択する
        if selectedPresetId == id, let firstPreset = presets.first {
            selectedPresetId = firstPreset.id
        } else if selectedPresetId == id {
            selectedPresetId = nil
        }
        saveSelectedPresetId()
    }
    
    func updatePreset(_ preset: StandardPhrasePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresetToFile(preset)
            savePresetIndex()
        }
    }
    
    var selectedPreset: StandardPhrasePreset? {
        guard let selectedPresetId = selectedPresetId else { return nil }
        return presets.first { $0.id == selectedPresetId }
    }
}

// プリセットのIDと名前を保持するための構造体
struct PresetInfo: Codable {
    let id: UUID
    let name: String
}
