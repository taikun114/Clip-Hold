import SwiftUI

struct ImportPresetSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var presetManager: StandardPhrasePresetManager
    
    @Binding var selectedPresetId: UUID?
    var onConfirm: (_ shouldCreateNewPreset: Bool) -> Void
    
    // 新規プリセット作成用の状態変数
    @State private var newPresetName = ""
    @State private var showCreatePresetView = false
    
    var body: some View {
        Group {
            if showCreatePresetView {
                // 新規プリセット作成ビュー
                VStack(alignment: .leading, spacing: 10) {
                    Text("新規プリセットの作成")
                        .font(.headline)
                    
                    TextField("プリセット名", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                    
                    Spacer()
                    
                    HStack {
                        Button("戻る") {
                            withAnimation {
                                showCreatePresetView = false
                            }
                        }
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.large)
                        
                        Spacer()
                        
                        Button("作成") {
                            // 新規プリセットを作成
                            presetManager.addPreset(name: newPresetName)
                            
                            // 作成されたプリセットのIDを取得
                            if let createdPreset = presetManager.presets.first(where: { $0.name == newPresetName }) {
                                selectedPresetId = createdPreset.id
                                onConfirm(true)
                            }
                            
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                        .disabled(newPresetName.isEmpty)
                    }
                }
                .padding()
                .frame(width: 300, height: 150)
            } else {
                // プリセット選択ビュー
                VStack(alignment: .leading, spacing: 10) {
                    Text("定型文のインポート")
                        .font(.headline)
                    
                    Text("この定型文をインポートしたいプリセットを選択")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Picker("プリセットを選択", selection: $selectedPresetId) {
                        ForEach(presetManager.presets) { preset in
                            Text(preset.name)
                                .tag(preset.id as UUID?)
                        }
                        
                        Divider()
                        
                        Text("新規プリセットを作成")
                            .tag(nil as UUID?)
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
                        
                        Button(selectedPresetId == nil ? "次へ" : "インポート") {
                            // 新規プリセットを作成するかどうかを判断
                            if selectedPresetId == nil {
                                // 新規プリセット作成ビューに切り替え
                                withAnimation {
                                    showCreatePresetView = true
                                }
                            } else {
                                // 既存のプリセットを使用
                                onConfirm(false)
                                dismiss()
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                    }
                }
                .padding()
                .frame(width: 300, height: 170)
            }
        }
        .animation(.default, value: showCreatePresetView)
    }
}
