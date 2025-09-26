import SwiftUI

struct AddEditPresetView: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @Environment(\.dismiss) var dismiss

    @State private var presetName: String
    @State private var presetIcon: String
    @State private var presetColor: String

    var onDismiss: (() -> Void)? = nil
    private var isSheet: Bool = false
    private var editingPreset: StandardPhrasePreset? // 内部で保持

    init(isSheet: Bool = false, onDismiss: (() -> Void)? = nil, editingPreset: StandardPhrasePreset? = nil) {
        self.isSheet = isSheet
        self.onDismiss = onDismiss
        self.editingPreset = editingPreset

        _presetName = State(initialValue: editingPreset?.name ?? "")
        _presetIcon = State(initialValue: editingPreset?.icon ?? "list.bullet.rectangle.portrait")
        _presetColor = State(initialValue: editingPreset?.color ?? "accent")
    }

    var body: some View {
        PresetNameSheet(
            name: $presetName,
            icon: $presetIcon,
            color: $presetColor,
            editingPreset: editingPreset, // ここで渡す
            title: String(localized: editingPreset == nil ? "プリセットを追加" : "プリセットを編集"),
            onSave: { customColor in
                let iconToSave = presetIcon.isEmpty ? "list.bullet.rectangle.portrait" : presetIcon
                
                if let existingPreset = editingPreset {
                    // 編集モード
                    var updatedPreset = existingPreset
                    updatedPreset.name = presetName
                    updatedPreset.icon = iconToSave
                    updatedPreset.color = presetColor
                    updatedPreset.customColor = customColor
                    presetManager.updatePreset(updatedPreset)
                } else {
                    // 追加モード
                    let newPreset = StandardPhrasePreset(name: presetName, icon: iconToSave, color: presetColor, customColor: customColor)
                    presetManager.addPreset(preset: newPreset)
                }
                
                if isSheet {
                    dismiss()
                }
                onDismiss?()
            },
            onCancel: {
                if isSheet {
                    dismiss()
                }
                onDismiss?()
            }
        )
    }
}

#Preview {
    AddEditPresetView(editingPreset: nil) // 追加モードのプレビュー
        .environmentObject(StandardPhrasePresetManager.shared)
}