import SwiftUI

struct PresetConflictSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let conflictingPresets: [StandardPhrasePreset]
    @State private var selectedAction: PresetConflictAction = .merge
    @State private var showIndividualResolution = false
    @State private var currentPresetIndex = 0
    @State private var individualActions: [UUID: PresetConflictAction] = [:]
    var onCompletion: (PresetConflictAction, [UUID: PresetConflictAction]) -> Void
    
    enum PresetConflictAction: CaseIterable {
        case merge
        case add
        case skip
        case resolveIndividually
        
        var localizedString: LocalizedStringKey {
            switch self {
            case .merge:
                return LocalizedStringKey("統合する")
            case .add:
                return LocalizedStringKey("このまま追加する")
            case .skip:
                return LocalizedStringKey("スキップする")
            case .resolveIndividually:
                return LocalizedStringKey("一つ一つ解決する")
            }
        }
    }
    
    private func displayName(for preset: StandardPhrasePreset) -> String {
        if preset.id.uuidString == "00000000-0000-0000-0000-000000000000" {
            return String(localized: "Default")
        }
        return preset.name
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
                        Text(displayName(for: preset))
                            .font(.body)
                    }
                }
            }
            .padding(.leading, 10)
            
            Text("続けるには操作を選択してください。")
                .font(.subheadline)
            
            Picker("", selection: $selectedAction) {
                ForEach(PresetConflictAction.allCases, id: \.self) { action in
                    Text(action.localizedString)
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
                
                // メインビューのボタン: resolveIndividuallyの場合は「次へ」、それ以外は「完了」
                Button(selectedAction == .resolveIndividually ? "次へ" : "完了") {
                    if selectedAction == .resolveIndividually {
                        showIndividualResolution = true
                        currentPresetIndex = 0 // 個別解決ビューに移行する際にインデックスをリセット
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
            // タイトル: プリセットが2つ以上ある場合はカウンターを表示
            Text("\"\(displayName(for: conflictingPresets[currentPresetIndex]))\"の操作を選択してください。\(conflictingPresets.count > 1 ? "(\(currentPresetIndex + 1)/\(conflictingPresets.count))" : "")")
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
                // 個別解決ビューにも「一つ一つ解決する」オプションを追加
                ForEach([PresetConflictAction.merge, .add, .skip, .resolveIndividually], id: \.self) { action in
                    Text(action.localizedString)
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
                
                // 個別解決ビューのボタン:
                // - 最後のプリセットでresolveIndividuallyが選択されている場合は「続ける」
                // - 最後のプリセットでresolveIndividually以外が選択されている場合は「完了」
                // - それ以外は「次へ」
                if currentPresetIndex < conflictingPresets.count - 1 {
                    Button("次へ") {
                        currentPresetIndex += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    let currentAction = individualActions[conflictingPresets[currentPresetIndex].id] ?? .merge
                    Button(currentAction == .resolveIndividually ? "続ける" : "完了") {
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
            StandardPhrasePreset(name: "Default"),
            StandardPhrasePreset(name: "Preset 1")
        ],
        onCompletion: { _, _ in } 
    )
}
