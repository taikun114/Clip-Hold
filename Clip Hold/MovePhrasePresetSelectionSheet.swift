import SwiftUI

struct MovePhrasePresetSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var presetManager: StandardPhrasePresetManager
    
    let sourcePresetId: UUID
    @Binding var selectedPresetId: UUID?
    var onConfirm: () -> Void
    
    private func displayName(for preset: StandardPhrasePreset) -> String {
        if preset.name == "Default" {
            return String(localized: "Default")
        }
        return preset.name
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("別のプリセットに移動")
                .font(.headline)
            
            Text("この定型文を移動したいプリセットを選択")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("プリセットを選択", selection: $selectedPresetId) {
                ForEach(presetManager.presets) { preset in
                    Text(displayName(for: preset))
                        .tag(preset.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Spacer()
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                
                Spacer()
                
                Button("移動") {
                    onConfirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(selectedPresetId == nil || selectedPresetId == sourcePresetId)
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 300, minHeight: 150, maxHeight: 200)
        .onAppear {
            // Pre-select the source preset
            selectedPresetId = sourcePresetId
        }
    }
}
