import SwiftUI

struct PresetConflictSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let conflictingPresets: [StandardPhrasePreset]
    @State private var selectedAction: PresetConflictAction = .merge
    @State private var showIndividualResolution = false
    @State private var currentPresetIndex = 0
    @State private var individualActions: [UUID: PresetConflictAction] = [:]
    var onCompletion: (PresetConflictAction, [UUID: PresetConflictAction]) -> Void
    
    enum PresetConflictAction: String, CaseIterable {
        case merge = "統合する"
        case add = "このまま追加する"
        case skip = "スキップする"
        case resolveIndividually = "一つ一つ解決する"
    }
    
    var body: some View {
        Group {
            if showIndividualResolution {
                individualResolutionView
            } else {
                mainView
            }
        }
        .padding()
        .frame(minWidth: 100, maxWidth: 300, minHeight: 200, maxHeight: 600)
    }
    
    private var mainView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("重複したプリセット")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("次のプリセットがすでに存在しています。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(conflictingPresets, id: \.id) { preset in
                    HStack(alignment: .top) {
                        Text("-")
                            .font(.body)
                        Text(preset.name)
                            .font(.body)
                    }
                }
            }
            .padding(.leading, 10)
            
            Text("続けるには操作を選択してください。")
                .font(.subheadline)
            
            Picker("", selection: $selectedAction) {
                ForEach(PresetConflictAction.allCases, id: \.self) { action in
                    Text(LocalizedStringKey(action.rawValue))
                        .tag(action)
                }
            }
            .pickerStyle(.radioGroup)
            
            Spacer()
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
                
                Button(selectedAction == .resolveIndividually ? "次へ" : "続ける") {
                    if selectedAction == .resolveIndividually {
                        showIndividualResolution = true
                    } else {
                        onCompletion(selectedAction, [:])
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
    }
    
    private var individualResolutionView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("\"\(conflictingPresets[currentPresetIndex].name)\"の操作を選択してください。")
                .font(.headline)
                .fontWeight(.bold)
            
            Picker("", selection: Binding(
                get: {
                    individualActions[conflictingPresets[currentPresetIndex].id] ?? .merge
                },
                set: { newValue in
                    individualActions[conflictingPresets[currentPresetIndex].id] = newValue
                }
            )) {
                ForEach([PresetConflictAction.merge, .add, .skip], id: \.self) { action in
                    Text(LocalizedStringKey(action.rawValue))
                        .tag(action)
                }
            }
            .pickerStyle(.radioGroup)
            
            Spacer()
            
            HStack {
                Button("戻る") {
                    if currentPresetIndex > 0 {
                        currentPresetIndex -= 1
                    } else {
                        showIndividualResolution = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
                
                if currentPresetIndex < conflictingPresets.count - 1 {
                    Button("次へ") {
                        currentPresetIndex += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("完了") {
                        onCompletion(.resolveIndividually, individualActions)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            }
        }
    }
}

#Preview {
    PresetConflictSheet(
        conflictingPresets: [
            StandardPhrasePreset(name: "デフォルト"),
            StandardPhrasePreset(name: "プリセット1")
        ],
        onCompletion: { _, _ in }
    )
}
