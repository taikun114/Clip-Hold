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
        if selectedPresetId == nil || !presets.contains(where: { $0.id == selectedPresetId }) {
            selectedPresetId = presets.first?.id
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
    
    private func saveSelectedPresetId() {
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
    }
    
    func deletePreset(id: UUID) {
        if id == defaultPresetId {
            setUserDeletedDefaultPreset()
        }
        
        presets.removeAll { $0.id == id }
        deletePresetFile(id: id)
        
        if selectedPresetId == id {
            selectedPresetId = presets.first?.id
        }
        
        savePresetIndex()
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
    
    func deleteAllPresets() {
        for preset in presets {
            deletePresetFile(id: preset.id)
        }
        
        presets.removeAll()
        selectedPresetId = nil
        
        savePresetIndex()
        saveSelectedPresetId()
        
        // Re-create default preset unless user explicitly deleted it before
        createDefaultPreset()
    }
}

// For storing preset info in the index file
struct PresetInfo: Codable {
    let id: UUID
    let name: String
}
