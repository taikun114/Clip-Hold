import SwiftUI
import SymbolPicker

struct AddEditPresetView: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    
    @State private var presetName: String = ""
    @State private var presetIcon: String = "list.bullet.rectangle.portrait"
    @State private var presetColor: String = "accent"
    @State private var showingIconPicker = false
    @Environment(\.dismiss) var dismiss
    @FocusState private var isPresetNameFieldFocused: Bool
    
    var onDismiss: (() -> Void)? = nil
    private var isSheet: Bool = false
    
    init(isSheet: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.isSheet = isSheet
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(String(localized: "プリセット名を入力"))
                    .font(.headline)
                Spacer()
            }

            HStack {
                // アイコン選択ボタン
                Button(action: {
                    showingIconPicker = true
                }) {
                    ZStack {
                        Circle()
                            .fill(getColor(from: presetColor))
                            .frame(width: 30, height: 30)
                        Image(systemName: presetIcon)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }
                    .popover(isPresented: $showingIconPicker) {
                        SymbolPicker(symbol: $presetIcon)
                            .frame(width: 400, height: 400)
                    }
                }
                
                TextField("プリセット名", text: $presetName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isPresetNameFieldFocused)
                .onSubmit {
                    if !presetName.isEmpty {
                        addPreset()
                    }
                }
            }

            // カラーピッカーセクション
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
                                        .stroke(presetColor == colorName ? Color.black : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
            
            Spacer()

            HStack {
                Button("キャンセル", role: .cancel) {
                    dismiss()
                    onDismiss?()
                }
                .controlSize(.large)

                Spacer()
                Button("保存") {
                    addPreset()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(presetName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 200)
        .onAppear {
            // ウィンドウを前面に表示
            if let window = NSApp.mainWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            
            // テキストフィールドにフォーカスを当てる
            DispatchQueue.main.async {
                isPresetNameFieldFocused = true
            }
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
}

#Preview {
    AddEditPresetView()
        .environmentObject(StandardPhrasePresetManager.shared)
}
