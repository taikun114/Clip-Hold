import SwiftUI

struct EditHistoryItemView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State var content: String
    var title: String = String(localized: "項目を変更してコピー")
    var onCopy: (String) -> Void
    var isSheet: Bool = false
    
    @ObservedObject var modifierMonitor = ModifierKeyMonitor.shared
    @AppStorage("quickPaste") var quickPaste: Bool = false
    @AppStorage("quickPasteToPreviousApp") var quickPasteToPreviousApp: Bool = false
    
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .focused($isContentFocused)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorSchemeContrast == .increased ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
                )
            Spacer()
            HStack {
                Button("キャンセル") {
                    if isSheet {
                        dismiss()
                    } else {
                        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
                    }
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                Button(quickPaste && quickPasteToPreviousApp && modifierMonitor.isOptionKeyPressed ? "クイックペーストせずにコピー" : "コピー") {
                    onCopy(content)
                    if isSheet {
                        dismiss()
                    } else {
                        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(content.isEmpty)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 310)
        .onAppear {
            isContentFocused = true
        }
    }
}

struct EditHistoryItemView_Previews: PreviewProvider {
    static var previews: some View {
        EditHistoryItemView(content: "これは編集する履歴アイテムの内容です。") { _ in }
    }
}
