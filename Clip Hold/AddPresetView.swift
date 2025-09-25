import SwiftUI
import SFSymbolsPicker


struct AddPresetView: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    
    @State private var presetName: String = ""
    @State private var presetIcon: String = "list.bullet.rectangle.portrait"
    @State private var presetColor: String = "accent"
    @State private var showingIconPicker = false
    @State private var previousPresetIcon: String = ""
    @Environment(\.dismiss) var dismiss
    
    var onDismiss: (() -> Void)? = nil
    private var isSheet: Bool = false
    
    init(isSheet: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.isSheet = isSheet
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(String(localized: "プリセット名を入力")).font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    // アイコン選択ボタンと入力フィールド
                    HStack {
                        SFSymbolsPicker(selection: $presetIcon, prompt: String(localized: "シンボルを検索")) {
                            ZStack {
                                Circle()
                                    .fill(getColor(from: presetColor))
                                    .frame(width: 30, height: 30)
                                Image(systemName: presetIcon.isEmpty ? previousPresetIcon : presetIcon)
                                    .foregroundColor(getSymbolColor(forPresetColor: presetColor))
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(.plain)
                        
                        TextField("プリセット名", text: $presetName).onSubmit(addPreset)
                    }
                    
                    // カラーピッカー
                    HStack {
                        Text("Color:")
                        Spacer()
                        HStack(spacing: 5) {
                            ForEach(getColorOptions(), id: \.self) { colorName in
                                Button(action: {
                                    presetColor = colorName
                                }) {
                                    Circle()
                                        .fill(getColor(from: colorName))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(presetColor == colorName ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(Text(localizedColorName(for: colorName)))
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("キャンセル", role: .cancel, action: {
                    dismiss()
                    onDismiss?()
                }).controlSize(.large)
                Spacer()
                Button("保存", action: addPreset).controlSize(.large).buttonStyle(.borderedProminent).disabled(presetName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 180)
        .onAppear {
            previousPresetIcon = presetIcon // ここを追加
        }
        .onExitCommand {
            dismiss()
            onDismiss?()
        }
    }
    
    private func addPreset() {
        let newPreset = StandardPhrasePreset(name: presetName, icon: presetIcon, color: presetColor)
        presetManager.addPreset(preset: newPreset)
        dismiss()
        onDismiss?()
    }
    
    private func getSymbolColor(forPresetColor colorName: String) -> Color {
        if colorName == "yellow" || colorName == "green" {
            return .black
        } else {
            return .white
        }
    }
    
    private func getColor(from colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .accentColor // アクセントカラー
        }
    }
    
    private func getColorOptions() -> [String] {
        return ["accent", "red", "orange", "yellow", "green", "blue", "purple", "pink"]
    }
    
    private func localizedColorName(for colorName: String) -> String {
        switch colorName {
        case "red": return "赤"
        case "orange": return "オレンジ"
        case "yellow": return "黄"
        case "green": return "緑"
        case "blue": return "青"
        case "purple": return "紫"
        case "pink": return "ピンク"
        default: return "アクセント"
        }
    }
}

#Preview {
    AddPresetView()
        .environmentObject(StandardPhrasePresetManager.shared)
}