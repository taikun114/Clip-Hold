import SwiftUI

struct SharedPresetMenuContent: View {
    @ObservedObject var presetManager = StandardPhrasePresetManager.shared
    @ObservedObject var iconGenerator = PresetIconGenerator.shared
    
    let title: LocalizedStringKey
    
    @Binding var selectedPresetId: UUID?
    let onNewPresetAction: () -> Void
    
    private let noPresetsUUID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    
    var body: some View {
        Picker(title, selection: Binding(
            get: {
                if presetManager.presets.isEmpty {
                    return noPresetsUUID
                }
                return selectedPresetId ?? presetManager.selectedPresetId ?? noPresetsUUID
            },
            set: { (newValue: UUID?) in
                if presetManager.presets.contains(where: { $0.id == newValue }) {
                    selectedPresetId = newValue
                }
            }
        )) {
            ForEach(presetManager.presets) { preset in
                Label {
                    Text(preset.truncatedDisplayName(maxLength: 50))
                } icon: {
                    if let iconImage = iconGenerator.iconCache[preset.id] {
                        Image(nsImage: iconImage)
                    } else {
                        Image(systemName: "star.fill")
                    }
                }
                .tag(preset.id as UUID?)
            }
            
            if presetManager.presets.isEmpty {
                Text(String(localized: "プリセットがありません"))
                    .tag(noPresetsUUID as UUID?)
            }
        }
        .pickerStyle(.inline)
        .labelStyle(.titleAndIcon)
        
        Divider()
        
        Button {
            onNewPresetAction()
        } label: {
            Label("新規プリセット...", systemImage: "plus")
                .forceIconOnMacOS27()
        }
        .applyKeyboardShortcut(for: .addNewPreset)
    }
}
