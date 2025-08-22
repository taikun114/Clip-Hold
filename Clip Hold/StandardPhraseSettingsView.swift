import SwiftUI
import UniformTypeIdentifiers

// MARK: - StandardPhraseSettingsView
struct StandardPhraseSettingsView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager

    @State private var showingAddPhraseSheet = false
    @State private var selectedPhrase: StandardPhrase?
    @State private var showingDeleteConfirmation = false
    @State private var phraseToDelete: StandardPhrase?
    @State private var showingClearAllPhrasesConfirmation = false

    @State private var selectedPhraseId: UUID? = nil

    var body: some View {
        Form {
            // MARK: - 定型文の管理セクション
            Section(header: Text("定型文の管理").font(.headline)) {
                StandardPhraseImportExportView()
                    .environmentObject(standardPhraseManager)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                HStack {
                    Text("\(standardPhraseManager.standardPhrases.count)個の定型文")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: {
                        showingClearAllPhrasesConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("すべての定型文を削除")
                        }
                        .if(!standardPhraseManager.standardPhrases.isEmpty) { view in
                            view.foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(standardPhraseManager.standardPhrases.isEmpty)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            // MARK: - 定型文の設定セクション
            Section(header:
                VStack(alignment: .leading, spacing: 4) {
                    Text("定型文の設定")
                        .font(.headline)

                    Text("定型文の順番はドラッグアンドドロップで並び替えることができます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            ) {
                List(selection: $selectedPhraseId) {
                    ForEach(standardPhraseManager.standardPhrases) { phrase in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(phrase.title)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text(phrase.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .tag(phrase.id)
                        .contentShape(Rectangle()) // これによりHStack全体がヒットテスト可能になる
                        .help(phrase.content)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("タイトル: \(phrase.title)、内容: \(phrase.content)")
                    }
                    .onMove(perform: standardPhraseManager.movePhrase)
                    .onDelete { indexSet in
                        standardPhraseManager.deletePhrase(atOffsets: indexSet)
                        selectedPhraseId = nil
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 24)
                .accessibilityLabel("定型文リスト")
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            Button(action: {
                                showingAddPhraseSheet = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(x: 2.0, y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .help("新しい定型文をリストに追加します。")

                            Divider()
                                .frame(width: 1, height: 16)
                                .background(Color.gray.opacity(0.1))
                                .padding(.horizontal, 4)

                            Button(action: {
                                if let selectedId = selectedPhraseId {
                                    if let phrase = standardPhraseManager.standardPhrases.first(where: { $0.id == selectedId }) {
                                        phraseToDelete = phrase
                                        showingDeleteConfirmation = true
                                    }
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -0.5)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPhraseId == nil)
                            .help("選択した定型文をリストから削除します。")

                            Spacer()

                            Button(action: {
                                if let selectedId = selectedPhraseId {
                                    if let phrase = standardPhraseManager.standardPhrases.first(where: { $0.id == selectedId }) {
                                        selectedPhrase = phrase
                                    }
                                }
                            }) {
                                Image(systemName: "pencil")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 24, height: 24)
                                    .offset(y: -1.0)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPhraseId == nil)
                            .help("選択した定型文を編集します。")
                        }
                        .background(Rectangle().opacity(0.04))
                    }
                }
                .contextMenu(forSelectionType: UUID.self) { selection in
                    if !selection.isEmpty {
                        Button("編集") {
                            if let firstSelectedId = selection.first {
                                if let phraseToEdit = standardPhraseManager.standardPhrases.first(where: { $0.id == firstSelectedId }) {
                                    selectedPhrase = phraseToEdit
                                }
                            }
                        }
                        Button("削除", role: .destructive) {
                            let phrasesToDelete = standardPhraseManager.standardPhrases.filter { selection.contains($0.id) }
                            if let firstPhrase = phrasesToDelete.first {
                                phraseToDelete = firstPhrase
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                } primaryAction: { selection in
                    if let firstSelectedId = selection.first {
                        if let phraseToEdit = standardPhraseManager.standardPhrases.first(where: { $0.id == firstSelectedId }) {
                            selectedPhrase = phraseToEdit
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddPhraseSheet) {
            AddEditPhraseView(mode: .add)
                .environmentObject(standardPhraseManager)
        }
        .sheet(item: $selectedPhrase) { phrase in
            AddEditPhraseView(mode: .edit(phrase), phraseToEdit: phrase)
                .environmentObject(standardPhraseManager)
        }
        .alert("定型文の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let phrase = phraseToDelete {
                    standardPhraseManager.deletePhrase(id: phrase.id)
                    phraseToDelete = nil
                    selectedPhraseId = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                phraseToDelete = nil
            }
        } message: {
            Text("「\(phraseToDelete?.title ?? "この定型文")」を本当に削除しますか？")
        }
        .alert("すべての定型文を削除", isPresented: $showingClearAllPhrasesConfirmation) {
            Button("削除", role: .destructive) {
                standardPhraseManager.deleteAllPhrases()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("すべての定型文を本当に削除しますか？この操作は元に戻せません。")
        }
    }
}

#Preview {
    StandardPhraseSettingsView()
        .environmentObject(StandardPhraseManager.shared)
}
