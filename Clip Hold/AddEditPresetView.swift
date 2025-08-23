import SwiftUI

struct AddEditPresetView: View {
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    
    @State private var presetName: String = ""
    @Environment(\.dismiss) var dismiss
    
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("プリセット名を入力")
                    .font(.headline)
                Spacer()
            }

            TextField("プリセット名", text: $presetName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    if !presetName.isEmpty {
                        addPreset()
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
        .frame(width: 300, height: 140)
        .onAppear {
            // ウィンドウを前面に表示
            if let window = NSApp.mainWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func addPreset() {
        presetManager.addPreset(name: presetName)
        dismiss()
        onDismiss?()
    }
}

#Preview {
    AddEditPresetView()
        .environmentObject(StandardPhrasePresetManager.shared)
}