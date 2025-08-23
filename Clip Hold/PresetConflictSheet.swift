import SwiftUI

struct PresetConflictSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let conflictingPresets: [StandardPhrasePreset]
    @State private var selectedAction: PresetConflictAction = .merge
    var onCompletion: (PresetConflictAction) -> Void
    
    enum PresetConflictAction {
        case merge, add, skip
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("重複したプリセット")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("次のプリセットがすでに存在しています。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            List(conflictingPresets, id: \.id) { preset in
                Text(preset.name)
            }
            .frame(height: 100)
            
            Text("操作を選択してください。")
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                RadioButtonGroup(
                    selectedAction: $selectedAction,
                    actions: [
                        (title: "統合する", action: .merge),
                        (title: "このまま追加する", action: .add),
                        (title: "スキップする", action: .skip)
                    ]
                )
            }
            
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
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600, minHeight: 350)
    }
}

struct RadioButtonGroup<T: Equatable>: View {
    @Binding var selectedAction: T
    let actions: [(title: String, action: T)]
    
    var body: some View {
        ForEach(actions.indices, id: \.self) { index in
            HStack {
                Button(action: {
                    selectedAction = actions[index].action
                }) {
                    HStack {
                        Image(systemName: selectedAction == actions[index].action ? "circle.fill" : "circle")
                            .foregroundColor(selectedAction == actions[index].action ? .accentColor : .secondary)
                        Text(actions[index].title)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
    }
}