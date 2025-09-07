import Foundation
import SwiftUI
import Combine

@MainActor
class StandardPhrasePresetManager: ObservableObject {
    static let shared = StandardPhrasePresetManager()
    
    @Published var presets: [StandardPhrasePreset] = []
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
            name: "Default", // Non-localized name
            phrases: standardPhraseManager.standardPhrases
        )
        presets.append(defaultPreset)
        selectedPresetId = defaultPreset.id
        savePresetToFile(defaultPreset)
        savePresetIndex()
        saveSelectedPresetId()
    }
    
    private func loadPresetsFromFileSystem() {
        guard let presetDirectory = getPresetDirectory() else {
            presets = []
            return
        }
        
        // Ensure preset directory exists
        if !FileManager.default.fileExists(atPath: presetDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: presetDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating preset directory: \(error.localizedDescription)")
                presets = []
                return
            }
        }
        
        // Try to load from index first
        if !loadPresetIndex() {
            // If index fails, rebuild from file system
            rebuildPresetIndexFromFileSystem()
        }
        
        // Load phrases for each preset
        for preset in presets {
            loadPresetPhrases(for: preset.id)
        }
        
        // If no presets exist after loading/rebuilding, create the default one
        if presets.isEmpty && !didUserDeleteDefaultPreset() {
            createDefaultPreset()
        }
        
        // Load selected preset ID
        loadSelectedPresetId()
        
        // Ensure a preset is selected if any exist
        // Only set a default preset if selectedPresetId is nil or the selected preset doesn't exist
        if selectedPresetId == nil || !presets.contains(where: { $0.id == selectedPresetId }) {
            // Try to select the default preset first
            if let defaultPreset = presets.first(where: { $0.id == defaultPresetId }) {
                selectedPresetId = defaultPreset.id
            } else {
                // If default preset doesn't exist, select the first available preset
                selectedPresetId = presets.first?.id
            }
            saveSelectedPresetId()
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
                        let preset = StandardPhrasePreset(id: defaultPresetId, name: "Default", phrases: [])
                        newPresets.insert(preset, at: 0) // Ensure default is first
                    }
                } else if let uuid = UUID(uuidString: fileName) {
                    let presetName = "Preset \(presetCounter)"
                    let preset = StandardPhrasePreset(id: uuid, name: presetName, phrases: [])
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
            let presetInfos = try JSONDecoder().decode([PresetInfo].self, from: data)
            
            var loadedPresets: [StandardPhrasePreset] = []
            for presetInfo in presetInfos {
                // Self-healing: check if the actual preset file exists
                let fileName = presetInfo.id == defaultPresetId ? defaultPresetFileName : presetInfo.id.uuidString
                let presetFileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
                if FileManager.default.fileExists(atPath: presetFileURL.path) {
                    loadedPresets.append(StandardPhrasePreset(id: presetInfo.id, name: presetInfo.name, phrases: []))
                } else if presetInfo.id == defaultPresetId && didUserDeleteDefaultPreset() {
                    // If default preset file is missing and user deleted it, do nothing
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
              let presetIndex = presets.firstIndex(where: { $0.id == presetId }) else { return }
        
        let fileName = presetId == defaultPresetId ? defaultPresetFileName : presetId.uuidString
        let fileURL = presetDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let phrases = try JSONDecoder().decode([StandardPhrase].self, from: data)
            presets[presetIndex].phrases = phrases
        } catch {
            print("Error loading phrases for preset \(presetId): \(error.localizedDescription)")
        }
    }
    
    private func savePresetToFile(_ preset: StandardPhrasePreset) {
        guard let presetDirectory = getPresetDirectory() else { return }
        
        let fileName = preset.id == defaultPresetId ? defaultPresetFileName : preset.id.uuidString
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
        
        let presetInfos = presets.map { PresetInfo(id: $0.id, name: $0.name) }
        
        do {
            let data = try JSONEncoder().encode(presetInfos)
            try data.write(to: indexFileURL)
        } catch {
            print("Error saving preset index: \(error.localizedDescription)")
        }
    }
    
    private func deletePresetFile(id: UUID) {
        guard let presetDirectory = getPresetDirectory() else { return }
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
        if let selectedPresetId = selectedPresetId,
           let encodedId = try? JSONEncoder().encode(selectedPresetId) {
            UserDefaults.standard.set(encodedId, forKey: "SelectedStandardPhrasePresetId")
        } else {
            UserDefaults.standard.removeObject(forKey: "SelectedStandardPhrasePresetId")
        }
    }
    
    func addPreset(name: String) {
        let newPreset = StandardPhrasePreset(name: name)
        presets.append(newPreset)
        selectedPresetId = newPreset.id
        savePresetToFile(newPreset)
        savePresetIndex()
        saveSelectedPresetId()
        presetAddedSubject.send()
    }
    
    func addPresetWithId(_ id: UUID, name: String) {
        // 既に同じIDのプリセットが存在する場合は追加しない
        if presets.contains(where: { $0.id == id }) {
            return
        }
        
        let newPreset = StandardPhrasePreset(id: id, name: name)
        presets.append(newPreset)
        selectedPresetId = newPreset.id
        savePresetToFile(newPreset)
        savePresetIndex()
        saveSelectedPresetId()
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
    }
    
    func updatePreset(_ preset: StandardPhrasePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresetToFile(preset)
            savePresetIndex()
        }
    }
    
    func duplicatePreset(_ preset: StandardPhrasePreset) {
        // Create a new preset with a new ID, but same content
        let newPreset = StandardPhrasePreset(
            id: UUID(), // New ID
            name: preset.name, // Keep the same name
            phrases: preset.phrases // Copy phrases
        )
        
        // Add the new preset to the array
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets.insert(newPreset, at: index + 1)
        } else {
            presets.append(newPreset)
        }
        
        // Save the new preset and update the index
        savePresetToFile(newPreset)
        savePresetIndex()
    }
    
    func duplicate(phrase: StandardPhrase, in preset: StandardPhrasePreset) {
        let newPhrase = StandardPhrase(title: phrase.title, content: phrase.content)
        if let presetIndex = presets.firstIndex(where: { $0.id == preset.id }) {
            if let phraseIndex = presets[presetIndex].phrases.firstIndex(where: { $0.id == phrase.id }) {
                presets[presetIndex].phrases.insert(newPhrase, at: phraseIndex + 1)
            } else {
                presets[presetIndex].phrases.append(newPhrase) // Fallback
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

        // Remove from source
        sourcePreset.phrases.removeAll { $0.id == phrase.id }

        // Add to destination
        destinationPreset.phrases.append(phrase)

        // Update both presets
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
        }
        
        if userDeletedDefault {
            setUserDeletedDefaultPreset()
        }
        
        presets.removeAll()
        selectedPresetId = nil
        
        savePresetIndex()
        saveSelectedPresetId()
        
        // デフォルトプリセットは再作成しない
    }
}

// For storing preset info in the index file
struct PresetInfo: Codable {
    let id: UUID
    let name: String
}
