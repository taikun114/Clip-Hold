import SwiftUI

struct SharedPresetPicker: View {
    @ObservedObject var presetManager = StandardPhrasePresetManager.shared
    @ObservedObject var iconGenerator = PresetIconGenerator.shared
    
    let title: LocalizedStringKey
    @Binding var selectedPresetId: UUID?
    let onNewPresetSelected: () -> Void
    
    private let newPresetUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let noPresetsUUID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    
    var body: some View {
        Picker(title, selection: Binding(
            get: {
                if presetManager.presets.isEmpty {
                    return noPresetsUUID
                }
                return selectedPresetId ?? noPresetsUUID
            },
            set: { (newValue: UUID?) in
                if newValue == noPresetsUUID {
                    if let firstPreset = presetManager.presets.first {
                        selectedPresetId = firstPreset.id
                    } else {
                        selectedPresetId = nil
                    }
                } else if newValue == newPresetUUID {
                    onNewPresetSelected()
                } else if presetManager.presets.contains(where: { $0.id == newValue }) {
                    selectedPresetId = newValue
                }
            }
        )) {
            ForEach(presetManager.presets) { preset in
                Label {
                    Text(preset.truncatedDisplayName(maxLength: 50))
                } icon: {
                    if let iconImage = iconGenerator.miniIconCache[preset.id] {
                        Image(nsImage: iconImage)
                    } else {
                        Image(systemName: "star.fill")
                    }
                }
                .tag(preset.id as UUID?)
            }
            
            if presetManager.presets.isEmpty {
                Text("プリセットがありません")
                    .tag(noPresetsUUID as UUID?)
            }
            
            Divider()
            Label("新規プリセット...", systemImage: "plus")
                .forceIconOnMacOS27()
                .tag(newPresetUUID as UUID?)
        }
        .labelStyle(.titleAndIcon)
        .flexiblePickerSizing()
    }
}
