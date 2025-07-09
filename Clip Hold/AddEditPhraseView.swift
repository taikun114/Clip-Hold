import SwiftUI

struct AddEditPhraseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager

    enum Mode: Equatable {
        case add
        case edit(StandardPhrase)
    }

    let mode: Mode
    @State var phraseToEdit: StandardPhrase // editモードの場合の元のphraseを保持

    @State private var title: String
    @State private var content: String
    @State private var useContentAsTitle: Bool = false

    init(mode: Mode, phraseToEdit: StandardPhrase? = nil, initialContent: String? = nil) {
        self.mode = mode
        _phraseToEdit = State(initialValue: phraseToEdit ?? StandardPhrase(title: "", content: ""))

        switch mode {
        case .add:
            _title = State(initialValue: "")
            // MARK: initialContentがあればそれをコンテンツとして使用
            _content = State(initialValue: initialContent ?? "")
            _useContentAsTitle = State(initialValue: false)
        case .edit(let phrase):
            _title = State(initialValue: phrase.title)
            _content = State(initialValue: phrase.content)
            _useContentAsTitle = State(initialValue: phrase.title == phrase.content)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(mode == .add ? "新しい定型文を追加" : "定型文を編集")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            TextField("タイトル", text: $title)
                .textFieldStyle(.roundedBorder)
                .disabled(useContentAsTitle)

            Toggle(isOn: $useContentAsTitle) {
                Text("タイトルにコンテンツを使用する")
            }
            .onChange(of: useContentAsTitle) {
                if useContentAsTitle {
                    title = content
                }
            }

            TextEditor(text: $content)
                .frame(minHeight: 100, maxHeight: 300)
                .border(Color.gray.opacity(0.5), width: 1)
                .onChange(of: content) {
                    if useContentAsTitle {
                        title = content
                    }
                }

            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Spacer()
                Button(mode == .add ? "追加" : "保存") {
                    let finalTitle: String
                    if useContentAsTitle {
                        finalTitle = content
                    } else {
                        finalTitle = title
                    }

                    if case .add = mode {
                        standardPhraseManager.addPhrase(title: finalTitle, content: content)
                    } else if case .edit(let originalPhrase) = mode {
                        standardPhraseManager.updatePhrase(id: originalPhrase.id, newTitle: finalTitle, newContent: content)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(content.isEmpty || (!useContentAsTitle && title.isEmpty))
                .controlSize(.large)

            }
        }
        .padding() // ここで全体にパディングが適用される
        .frame(minWidth: 400, minHeight: 350)
    }
}


// MARK: - Preview Provider
struct AddEditPhraseView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditPhraseView(mode: .add)
            .environmentObject(StandardPhraseManager.shared)

        AddEditPhraseView(mode: .edit(StandardPhrase(title: "既存の定型文のタイトル", content: "これは既存の定型文の内容です。")))
            .environmentObject(StandardPhraseManager.shared)
    }
}

// MARK: - Color Extension for Placeholder Text
extension Color {
    static var placeholderText: Color {
        #if os(macOS)
        return Color(NSColor.placeholderTextColor)
        #else
        return Color(.placeholderText)
        #endif
    }
}
