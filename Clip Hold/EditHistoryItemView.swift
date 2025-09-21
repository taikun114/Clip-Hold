import SwiftUI

struct EditHistoryItemView: View {
    @Environment(\.dismiss) var dismiss
    @State var content: String
    var onCopy: (String) -> Void
    
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("履歴を編集")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            TextEditor(text: $content)
                .frame(minHeight: 100, maxHeight: 300)
                .scrollContentBackground(.hidden)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .focused($isContentFocused)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            Spacer()
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                Button("コピー") {
                    onCopy(content)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
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
