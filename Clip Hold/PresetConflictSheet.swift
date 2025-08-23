import SwiftUI

struct PresetConflictSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let conflictingPresets: [StandardPhrasePreset]
    @State private var selectedAction: PresetConflictAction = .merge
    var onCompletion: (PresetConflictAction) -> Void
    
    enum PresetConflictAction: String, CaseIterable {
        case merge = "統合する"
        case add = "このまま追加する"
        case skip = "スキップする"
    }
    
    var body: some View {
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
                    Text(action.rawValue)
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
                
                Button("続ける") {
                    onCompletion(selectedAction)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(minWidth: 100, maxWidth: 300, minHeight: 200, maxHeight: 600)
    }
}

#Preview {
    PresetConflictSheet(
        conflictingPresets: [
            StandardPhrasePreset(name: "デフォルト"),
            StandardPhrasePreset(name: "プリセット1")
        ],
        onCompletion: { _ in }
    )
}
