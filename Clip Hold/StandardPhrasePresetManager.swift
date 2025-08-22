import Foundation
import SwiftUI

@MainActor
class StandardPhrasePresetManager: ObservableObject {
    static let shared = StandardPhrasePresetManager()
    
    @Published var presets: [StandardPhrasePreset] = []
    @Published var selectedPresetId: UUID?
    
    private let userDefaultsKey = "StandardPhrasePresets"
    
    private init() {
        loadPresets()
        // 初回起動時にデフォルトプリセットを作成
        if presets.isEmpty {
            createDefaultPreset()
        }
        // 選択されたプリセットがなければ最初のものを選択
        if selectedPresetId == nil, let firstPreset = presets.first {
            selectedPresetId = firstPreset.id
        }
    }
    
    private func createDefaultPreset() {
        // StandardPhraseManagerから既存の定型文を取得
        let standardPhraseManager = StandardPhraseManager.shared
        let defaultPreset = StandardPhrasePreset(
            id: UUID(),
            name: String(localized: "デフォルト"),
            phrases: standardPhraseManager.standardPhrases
        )
        presets.append(defaultPreset)
        selectedPresetId = defaultPreset.id
        savePresets()
    }
    
    func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decodedPresets = try? JSONDecoder().decode([StandardPhrasePreset].self, from: data) else {
            presets = []
            return
        }
        presets = decodedPresets
        
        // 選択されたプリセットIDも保存されている場合、復元する
        if let selectedIdData = UserDefaults.standard.data(forKey: "SelectedStandardPhrasePresetId"),
           let selectedId = try? JSONDecoder().decode(UUID.self, from: selectedIdData) {
            selectedPresetId = selectedId
        }
    }
    
    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
        
        // 選択されたプリセットIDも保存
        if let selectedPresetId = selectedPresetId,
           let encodedId = try? JSONEncoder().encode(selectedPresetId) {
            UserDefaults.standard.set(encodedId, forKey: "SelectedStandardPhrasePresetId")
        }
    }
    
    func addPreset(name: String) {
        let newPreset = StandardPhrasePreset(name: name)
        presets.append(newPreset)
        selectedPresetId = newPreset.id
        savePresets()
    }
    
    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        // 削除されたプリセットが選択されていたら、別のプリセットを選択する
        if selectedPresetId == id, let firstPreset = presets.first {
            selectedPresetId = firstPreset.id
        } else if selectedPresetId == id {
            selectedPresetId = nil
        }
        savePresets()
    }
    
    func updatePreset(_ preset: StandardPhrasePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }
    
    var selectedPreset: StandardPhrasePreset? {
        guard let selectedPresetId = selectedPresetId else { return nil }
        return presets.first { $0.id == selectedPresetId }
    }
}
