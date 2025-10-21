import Foundation
import SwiftUI
import Combine

@MainActor
class StandardPhrasePresetManager: ObservableObject {
    static let shared = StandardPhrasePresetManager()
    
    @Published var presets: [StandardPhrasePreset] = [] {
        didSet {
            // 「プリセットなし」が選択されている状態でプリセットが利用可能になった場合、最初のプリセットを選択
            if selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" && !presets.isEmpty {
                selectedPresetId = presets.first?.id
                saveSelectedPresetId()
            }
        }
    }
    @Published var selectedPresetId: UUID?
    
    let presetAddedSubject = PassthroughSubject<Void, Never>()
    
    private let presetDirectoryName = "standardPhrasesPreset"
    private let presetIndexFileName = "presetIndex.json"
    private let defaultPresetFileName = "default"
    private let defaultPresetId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private let userDeletedDefaultPresetKey = "UserDeletedDefaultPreset"
    
    private init() {
        loadPresetsFromFileSystem()
    }
    
    private func didUserDeleteDefaultPreset() -> Bool {
        return UserDefaults.standard.bool(forKey: userDeletedDefaultPresetKey)
    }
    
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
        if didUserDeleteDefaultPreset() || presets.contains(where: { $0.id == defaultPresetId }) {
            return
        }
        
        let standardPhraseManager = StandardPhraseManager.shared
        let defaultPreset = StandardPhrasePreset(
            id: defaultPresetId,
            name: "Default", // ローカライズされない名前
            phrases: standardPhraseManager.standardPhrases,
            icon: "star.fill",
            color: "accent",
            customColor: nil
        )
        presets.append(defaultPreset)
        selectedPresetId = defaultPreset.id
        savePresetToFile(defaultPreset)
        savePresetIndex()
        saveSelectedPresetId()
    }
    
    private func loadPresetsFromFileSystem() {
        // アイコンキャッシュをクリア
        PresetIconGenerator.shared.clearCache()

        guard let presetDirectory = getPresetDirectory() else {
            presets = []
            return
        }
        
        // プリセットディレクトリが存在することを確認
        if !FileManager.default.fileExists(atPath: presetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: presetDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating preset directory: \(error.localizedDescription)")
                presets = []
                return
            }
        }
        
        // まずインデックスから読み込みを試行
        if !loadPresetIndex() {
            // インデックスの読み込みに失敗した場合、ファイルシステムから再構築
            rebuildPresetIndexFromFileSystem()
        }
        
        // 各プリセットのフレーズを読み込む
        for preset in presets {
            loadPresetPhrases(for: preset.id)
        }

        // すべて読み込んだプリセットのアイコンを生成
        for preset in presets {
            let _ = PresetIconGenerator.shared.generateIcon(for: preset)
        }
        
        // 読み込み/再構築後にプリセットが存在しない場合、デフォルトを作成
        if presets.isEmpty && !didUserDeleteDefaultPreset() {
            createDefaultPreset()
        }
        
        // 選択されたプリセットIDを読み込む
        loadSelectedPresetId()
        
        // プリセットが存在する場合、いずれかが選択されていることを確認
        // selectedPresetIdがnilか、選択されたプリセットが存在しない場合のみデフォルトのプリセットを設定
        var selectedPresetWasUpdated = false
        if selectedPresetId == nil || !presets.contains(where: { $0.id == selectedPresetId }) {
            // まずデフォルトのプリセットを選択してみる
            if let defaultPreset = presets.first(where: { $0.id == defaultPresetId }) {
                selectedPresetId = defaultPreset.id
            } else {
                // デフォルトのプリセットが存在しない場合、利用可能な最初のプリセットを選択
                selectedPresetId = presets.first?.id
            }
            saveSelectedPresetId()
            selectedPresetWasUpdated = true
        } else if selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" && !presets.isEmpty {
            // 「プリセットなし」が選択されている状態でプリセットが利用可能になった場合、最初のプリセットを選択
            selectedPresetId = presets.first?.id
            saveSelectedPresetId()
            selectedPresetWasUpdated = true
        }
        
        // selectedPresetIdが更新された場合、ビューに通知
        if selectedPresetWasUpdated {
            presetAddedSubject.send()
        }
    }
    
    private func rebuildPresetIndexFromFileSystem() {
        guard let presetDirectory = getPresetDirectory() else { return }
        
        var newPresets: [StandardPhrasePreset] = []
        
        do {
            let presetFiles = try FileManager.default.contentsOfDirectory(at: presetDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent != presetIndexFileName }
            
            var presetCounter = 1
            for fileURL in presetFiles {
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                
                if fileName == defaultPresetFileName {
                    if !didUserDeleteDefaultPreset() {
                        let preset = StandardPhrasePreset(id: defaultPresetId, name: "Default", phrases: [], icon: "star.fill", color: "accent", customColor: nil)
                        newPresets.insert(preset, at: 0) // デフォルトが最初に来るようにする
                    }
                } else if let uuid = UUID(uuidString: fileName) {
                    // ここではカスタムカラーを読み込めないため、nilを設定
                    let presetName = "Preset \(presetCounter)"
                    let preset = StandardPhrasePreset(id: uuid, name: presetName, phrases: [], icon: "list.bullet.rectangle.portrait", color: "accent", customColor: nil)
                    newPresets.append(preset)
                    presetCounter += 1
                }
            }
            
            presets = newPresets
            savePresetIndex()
            print("Rebuilt index with \(newPresets.count) presets")
            
        } catch {
            print("Error rebuilding preset index from file system: \(error.localizedDescription)")
        }
    }
    
    private func loadPresetIndex() -> Bool {
        guard let presetDirectory = getPresetDirectory() else { return false }
        let indexFileURL = presetDirectory.appendingPathComponent(presetIndexFileName)
        
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else { return false }
        
        do {
            let data = try Data(contentsOf: indexFileURL)
            
            // カスタムデコーダーを使用してPresetInfoをデコード
            let decoder = JSONDecoder()
            let presetInfos = try decoder.decode([PresetInfo].self, from: data)
            
            var loadedPresets: [StandardPhrasePreset] = []
            for presetInfo in presetInfos {
                // 自己修復：実際のプリセットファイルが存在するか確認
                let fileName = presetInfo.id == defaultPresetId ? defaultPresetFileName : presetInfo.id.uuidString
                let presetFileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
                if FileManager.default.fileExists(atPath: presetFileURL.path) {
                    var presetColor = presetInfo.color
                    if presetInfo.customColor != nil {
                        presetColor = "custom"
                    }
                    loadedPresets.append(StandardPhrasePreset(id: presetInfo.id, name: presetInfo.name, phrases: [], icon: presetInfo.icon, color: presetColor, customColor: presetInfo.customColor))
                } else if presetInfo.id == defaultPresetId && didUserDeleteDefaultPreset() {
                    // デフォルトのプリセットファイルがなく、ユーザーが削除した場合は何もしない
                    continue
                }
            }
            
            self.presets = loadedPresets
            return true
        } catch {
            print("Error loading preset index: \(error.localizedDescription)")
            return false
        }
    }
    
    private func loadPresetPhrases(for presetId: UUID) {
        guard let presetDirectory = getPresetDirectory(),
              let presetIndex = presets.firstIndex(where: { $0.id == presetId }) else {
            return
        }
        
        let fileName = presetId == defaultPresetId ? defaultPresetFileName : presetId.uuidString
        let fileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let phrases = try JSONDecoder().decode([StandardPhrase].self, from: data)
            presets[presetIndex].phrases = phrases
        } catch {
            print("Error loading phrases for preset \(presetId): \(error.localizedDescription)")
        }
    }
    
    private func savePresetToFile(_ preset: StandardPhrasePreset) {
        guard let presetDirectory = getPresetDirectory() else {
            return
        }
        
        let fileName = preset.id == defaultPresetId ? defaultPresetFileName : preset.id.uuidString
        let fileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(preset.phrases)
            try data.write(to: fileURL)
            print("Saved preset with \(preset.phrases.count) phrases for preset \(preset.id)")
        } catch {
            print("Error saving preset to file: \(error.localizedDescription)")
        }
    }
    
    func savePresetIndex() {
        guard let presetDirectory = getPresetDirectory() else {
            return
        }
        let indexFileURL = presetDirectory.appendingPathComponent(presetIndexFileName)
        
        let presetInfos = presets.map { PresetInfo(id: $0.id, name: $0.name, icon: $0.icon, color: $0.color, customColor: $0.customColor) }
        
        do {
            let data = try JSONEncoder().encode(presetInfos)
            try data.write(to: indexFileURL)
        } catch {
            print("Error saving preset index: \(error.localizedDescription)")
        }
    }
    
    private func deletePresetFile(id: UUID) {
        guard let presetDirectory = getPresetDirectory() else {
            return
        }
        let fileName = id == defaultPresetId ? defaultPresetFileName : id.uuidString
        let fileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Error deleting preset file: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadSelectedPresetId() {
        if let selectedIdData = UserDefaults.standard.data(forKey: "SelectedStandardPhrasePresetId"),
           let selectedId = try? JSONDecoder().decode(UUID.self, from: selectedIdData) {
            if presets.contains(where: { $0.id == selectedId }) {
                self.selectedPresetId = selectedId
            }
        }
    }
    
    func saveSelectedPresetId() {
        // FFFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF は保存しない
        if let selectedPresetId = selectedPresetId,
           selectedPresetId.uuidString != "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
           let encodedId = try? JSONEncoder().encode(selectedPresetId) {
            UserDefaults.standard.set(encodedId, forKey: "SelectedStandardPhrasePresetId")
        } else {
            UserDefaults.standard.removeObject(forKey: "SelectedStandardPhrasePresetId")
        }
    }
    
    func addPreset(name: String, icon: String? = nil, color: String? = nil, customColor: PresetCustomColor? = nil) {
        let iconToUse = icon?.isEmpty ?? true ? "list.bullet.rectangle.portrait" : icon!
        let newPreset = StandardPhrasePreset(name: name, icon: iconToUse, color: color, customColor: customColor)
        presets.append(newPreset)
        // 「プリセットなし」が選択されていた場合、新しいプリセットを選択
        if selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
            selectedPresetId = newPreset.id
        }
        savePresetToFile(newPreset)
        savePresetIndex()
        saveSelectedPresetId()
        let _ = PresetIconGenerator.shared.generateIcon(for: newPreset)
        presetAddedSubject.send()
    }
    
    func addPreset(preset: StandardPhrasePreset) {
        // アイコンが空文字列の場合、デフォルトアイコンに設定
        let iconToUse = preset.icon.isEmpty ? (preset.id.uuidString == "00000000-0000-0000-0000-000000000000" ? "star.fill" : "list.bullet.rectangle.portrait") : preset.icon
        let presetWithValidIcon = StandardPhrasePreset(id: preset.id, name: preset.name, phrases: preset.phrases, icon: iconToUse, color: preset.color, customColor: preset.customColor)
        
        presets.append(presetWithValidIcon)
        // 新しく追加したプリセットを選択状態にする
        selectedPresetId = presetWithValidIcon.id
        savePresetToFile(presetWithValidIcon)
        savePresetIndex()
        saveSelectedPresetId()
        let _ = PresetIconGenerator.shared.generateIcon(for: presetWithValidIcon)
        presetAddedSubject.send()
    }
    
    func addPresetWithId(_ id: UUID, name: String, icon: String? = nil, color: String? = nil, customColor: PresetCustomColor? = nil) {
        // 既に同じIDのプリセットが存在する場合は追加しない
        if presets.contains(where: { $0.id == id }) {
            return
        }
        let iconToUse = icon?.isEmpty ?? true ? (id.uuidString == "00000000-0000-0000-0000-000000000000" ? "star.fill" : "list.bullet.rectangle.portrait") : icon!
        let newPreset = StandardPhrasePreset(id: id, name: name, icon: iconToUse, color: color, customColor: customColor)
        presets.append(newPreset)
        // 「プリセットなし」が選択されていた場合、新しいプリセットを選択
        if selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
            selectedPresetId = newPreset.id
        }
        savePresetToFile(newPreset)
        savePresetIndex()
        saveSelectedPresetId()
        let _ = PresetIconGenerator.shared.generateIcon(for: newPreset)
        presetAddedSubject.send()
    }
    
    func deletePreset(id: UUID) {
        if id == defaultPresetId {
            setUserDeletedDefaultPreset()
        }
        
        // プリセットに割り当てられたアプリの割り当てを解除
        PresetAppAssignmentManager.shared.clearAssignments(for: id)
        
        presets.removeAll { $0.id == id }
        deletePresetFile(id: id)
        
        if selectedPresetId == id {
            selectedPresetId = presets.first?.id
        }
        
        savePresetIndex()
        saveSelectedPresetId()
        
        // 他のプリセットにも影響がないか確認し、存在しないプリセットへの割り当てをクリーンアップ
        cleanupInvalidAssignments()
        
        // ビューに通知してselectedPresetIdを更新
        presetAddedSubject.send()
        PresetIconGenerator.shared.removeIcon(for: id)
    }
    
    func updatePreset(_ preset: StandardPhrasePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            // アイコンが空文字列の場合、元のアイコンに設定
            let iconToUse = preset.icon.isEmpty ? presets[index].icon : preset.icon
            var presetWithValidIcon = preset
            presetWithValidIcon.icon = iconToUse
            
            presets[index] = presetWithValidIcon
            savePresetToFile(presetWithValidIcon)
            savePresetIndex()
            presetAddedSubject.send()
            PresetIconGenerator.shared.updateIcon(for: presetWithValidIcon)
        }
    }
    
    func duplicatePreset(_ preset: StandardPhrasePreset) {
        // 新しいIDで、ただし同じ内容の新しいプリセットを作成
        let newPreset = StandardPhrasePreset(
            id: UUID(), // 新しいID
            name: preset.name, // 同じ名前を維持
            phrases: preset.phrases, // フレーズをコピー
            icon: preset.icon,
            color: preset.color,
            customColor: preset.customColor
        )
        
        // 新しいプリセットを配列に追加
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets.insert(newPreset, at: index + 1)
        } else {
            presets.append(newPreset)
        }
        
        // 新しいプリセットを保存してインデックスを更新
        savePresetToFile(newPreset)
        savePresetIndex()
        
        // ビューに通知
        let _ = PresetIconGenerator.shared.generateIcon(for: newPreset)
        presetAddedSubject.send()
    }
    
    func duplicate(phrase: StandardPhrase, in preset: StandardPhrasePreset) {
        let newPhrase = StandardPhrase(title: phrase.title, content: phrase.content)
        if let presetIndex = presets.firstIndex(where: { $0.id == preset.id }) {
            if let phraseIndex = presets[presetIndex].phrases.firstIndex(where: { $0.id == phrase.id }) {
                presets[presetIndex].phrases.insert(newPhrase, at: phraseIndex + 1)
            } else {
                presets[presetIndex].phrases.append(newPhrase) // フォールバック
            }
            updatePreset(presets[presetIndex])
        }
    }

    func move(phrase: StandardPhrase, to destinationPresetId: UUID) {
        guard let sourcePresetId = selectedPresetId,
              sourcePresetId != destinationPresetId,
              var sourcePreset = presets.first(where: { $0.id == sourcePresetId }),
              var destinationPreset = presets.first(where: { $0.id == destinationPresetId })
        else {
            return
        }

        // 元の場所から削除
        sourcePreset.phrases.removeAll { $0.id == phrase.id }

        // 移動先に追加
        destinationPreset.phrases.append(phrase)

        // 両方のプリセットを更新
        updatePreset(sourcePreset)
        updatePreset(destinationPreset)
    }
    
    /// 存在しないプリセットへのアプリ割り当てをクリーンアップする
    private func cleanupInvalidAssignments() {
        let validPresetIds = Set(presets.map { $0.id })
        let assignmentManager = PresetAppAssignmentManager.shared
        
        for (presetId, _) in assignmentManager.assignments {
            if !validPresetIds.contains(presetId) {
                assignmentManager.clearAssignments(for: presetId)
            }
        }
    }
    
    var selectedPreset: StandardPhrasePreset? {
        guard let selectedPresetId = selectedPresetId else { return nil }
        return presets.first { $0.id == selectedPresetId }
    }
    
    func deleteAllPresets() {
        var userDeletedDefault = false
        for preset in presets {
            // デフォルトプリセットの場合、削除されたことを表すフラグを設定
            if preset.id == defaultPresetId {
                userDeletedDefault = true
            }
            
            // プリセットに割り当てられたアプリの割り当てを解除
            PresetAppAssignmentManager.shared.clearAssignments(for: preset.id)
            
            deletePresetFile(id: preset.id)
            PresetIconGenerator.shared.removeIcon(for: preset.id)
        }
        
        if userDeletedDefault {
            setUserDeletedDefaultPreset()
        }
        
        presets.removeAll()
        selectedPresetId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        
        savePresetIndex()
        saveSelectedPresetId()
        
        // デフォルトプリセットは再作成しない
        
        // ビューに通知してselectedPresetIdを更新
        presetAddedSubject.send()
    }
}

// プリセット情報をインデックスファイルに保存するため
struct PresetInfo: Codable {
    let id: UUID
    let name: String
    let icon: String?
    let color: String?
    let customColor: PresetCustomColor?
}