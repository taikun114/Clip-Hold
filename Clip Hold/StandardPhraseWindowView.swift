import SwiftUI
import AppKit

private func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// 文字列を安全に切り詰めるヘルパー関数
private func truncateString(_ text: String?, maxLength: Int) -> String {
    guard let text = text else { return "" }
    if text.count > maxLength {
        return String(text.prefix(maxLength)) + "..."
    }
    return text
}

struct StandardPhraseItemRow: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @Environment(\.dismiss) var dismiss
    
    let phrase: StandardPhrase
    let index: Int
    @AppStorage("showLineNumbersInStandardPhraseWindow") var showLineNumber: Bool = false
    @Binding var phraseToDelete: StandardPhrase?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var selectedPhraseID: UUID?
    @AppStorage("preventStandardPhraseWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    @Environment(\.colorScheme) var colorScheme

    @Binding var showCopyConfirmation: Bool
    @Binding var showQRCodeSheet: Bool
    @Binding var selectedPhraseForQRCode: StandardPhrase?
    @Binding var phraseToEdit: StandardPhrase?

    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            if showLineNumber {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: lineNumberTextWidth, alignment: .trailing)
                    .padding(.trailing, trailingPaddingForLineNumber)
            }
            
            Image(systemName: "list.bullet.rectangle.portrait")
                .resizable()
                .scaledToFit()
                .padding(4)
                .frame(width: 30, height: 30)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                Text(phrase.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                Text(phrase.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
            
            Menu {
                Button {
                    copyToClipboard(phrase.content)
                    showCopyConfirmation = true
                } label: {
                    Label("コピー", systemImage: "document.on.document")
                }
                Divider()
                Button {
                    phraseToEdit = phrase // 編集対象のフレーズをセット
                } label: {
                    Label("編集...", systemImage: "pencil")
                }
                Button {
                    selectedPhraseForQRCode = phrase
                    showQRCodeSheet = true
                } label: {
                    Label("QRコードを表示...", systemImage: "qrcode")
                }
                Divider()
                Button(role: .destructive) {
                    phraseToDelete = phrase
                    showingDeleteConfirmation = true
                } label: {
                    Label("削除...", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundColor(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.leading, 2)
        .contentShape(Rectangle())
        .help(phrase.content)
    }
}

struct StandardPhraseWindowView: View {
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @Environment(\.dismiss) var dismiss

    @State private var searchText: String = ""
    @State private var filteredPhrases: [StandardPhrase] = []
    @State private var selectedPhraseID: UUID?
    @State private var phraseToDelete: StandardPhrase?
    @State private var showingDeleteConfirmation = false
    @State private var isLoading: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showCopyConfirmation: Bool = false
    @State private var currentCopyConfirmationTask: Task<Void, Never>? = nil
    @State private var showQRCodeSheet: Bool = false
    @State private var selectedPhraseForQRCode: StandardPhrase?
    @State private var phraseToEdit: StandardPhrase? = nil

    @AppStorage("showLineNumbersInStandardPhraseWindow") var showLineNumbers: Bool = false
    @AppStorage("preventStandardPhraseWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    @FocusState private var isSearchFieldFocused: Bool

    private var lineNumberTextWidth: CGFloat? {
        guard showLineNumbers, !filteredPhrases.isEmpty else { return nil }
        
        let maxIndex = filteredPhrases.count
        let numDigits = String(maxIndex).count

        let digitWidth: CGFloat = 7.0
        let periodWidth: CGFloat = 3.0
        let buffer: CGFloat = 1.0

        return CGFloat(numDigits) * digitWidth + periodWidth + buffer
    }

    private let trailingPaddingForLineNumber: CGFloat = 5

    private func performSearch(searchTerm: String) {
        let newFilteredPhrases: [StandardPhrase]
        if searchTerm.isEmpty {
            newFilteredPhrases = standardPhraseManager.standardPhrases
        } else {
            newFilteredPhrases = standardPhraseManager.standardPhrases.filter {
                $0.title.localizedCaseInsensitiveContains(searchTerm) ||
                $0.content.localizedCaseInsensitiveContains(searchTerm)
            }
        }
        self.filteredPhrases = newFilteredPhrases
    }

    private func movePhrases(from source: IndexSet, to destination: Int) {
        // 検索中の場合は並び替えを許可しない
        if searchText.isEmpty {
            standardPhraseManager.movePhrase(from: source, to: destination)
        }
    }

    var body: some View {
        ZStack { // ZStackでコンテンツとメッセージを重ねる
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .ignoresSafeArea()

            ZStack { // メインコンテンツを囲むZStack
                VStack(spacing: 0) {
                    HStack {
                        TextField(
                            "定型文を検索",
                            text: $searchText
                        )
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(.vertical, 8)
                        .padding(.leading, 30)
                        .padding(.trailing, 10)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(10)
                        .controlSize(.large)
                        .focused($isSearchFieldFocused)
                        .overlay(
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .offset(y: -1.0)
                                Spacer()
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(.trailing, 8)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 5)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        
                        searchTask = Task { @MainActor in
                            let initialDelayNanoseconds: UInt64 = 150_000_000
                            try? await Task.sleep(nanoseconds: initialDelayNanoseconds)

                            guard !Task.isCancelled else {
                                return
                            }
                            
                            isLoading = true

                            let remainingDebounceNanoseconds: UInt64 = 150_000_000
                            try? await Task.sleep(nanoseconds: remainingDebounceNanoseconds)

                            guard !Task.isCancelled else {
                                isLoading = false
                                return
                            }

                            performSearch(searchTerm: newValue)
                            isLoading = false
                        }
                    }
                    .onChange(of: standardPhraseManager.standardPhrases) { _, _ in
                        performSearch(searchTerm: searchText)
                    }
                    
                    Spacer(minLength: 0)
                    
                    ZStack {
                        if filteredPhrases.isEmpty && !isLoading {
                            VStack { // VStackで囲み、Spacerで中央に配置
                                Spacer()
                                Text("定型文はありません")
                                    .foregroundColor(.secondary)
                                    .font(.title2)
                                    .padding(.bottom, 20)
                                Spacer()
                            }
                        } else {
                            List(selection: $selectedPhraseID) {
                                if searchText.isEmpty {
                                    ForEach(filteredPhrases) { phrase in
                                        StandardPhraseItemRow(
                                            phrase: phrase,
                                            index: filteredPhrases.firstIndex(where: { $0.id == phrase.id }) ?? 0,
                                            showLineNumber: showLineNumbers,
                                            phraseToDelete: $phraseToDelete,
                                            showingDeleteConfirmation: $showingDeleteConfirmation,
                                            selectedPhraseID: $selectedPhraseID,
                                            showCopyConfirmation: $showCopyConfirmation,
                                            showQRCodeSheet: $showQRCodeSheet,
                                            selectedPhraseForQRCode: $selectedPhraseForQRCode,
                                            phraseToEdit: $phraseToEdit,
                                            lineNumberTextWidth: lineNumberTextWidth,
                                            trailingPaddingForLineNumber: trailingPaddingForLineNumber
                                        )
                                        .tag(phrase.id)
                                        .listRowBackground(Color.clear)
                                    }
                                    .onMove(perform: movePhrases)
                                } else {
                                    ForEach(filteredPhrases) { phrase in
                                        StandardPhraseItemRow(
                                            phrase: phrase,
                                            index: filteredPhrases.firstIndex(where: { $0.id == phrase.id }) ?? 0,
                                            showLineNumber: showLineNumbers,
                                            phraseToDelete: $phraseToDelete,
                                            showingDeleteConfirmation: $showingDeleteConfirmation,
                                            selectedPhraseID: $selectedPhraseID,
                                            showCopyConfirmation: $showCopyConfirmation,
                                            showQRCodeSheet: $showQRCodeSheet,
                                            selectedPhraseForQRCode: $selectedPhraseForQRCode,
                                            phraseToEdit: $phraseToEdit,
                                            lineNumberTextWidth: lineNumberTextWidth,
                                            trailingPaddingForLineNumber: trailingPaddingForLineNumber
                                        )
                                        .tag(phrase.id)
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                            .accessibilityLabel("定型文リスト")
                            .listStyle(.inset)
                            .scrollContentBackground(.hidden)
                            .blur(radius: isLoading ? 5 : 0)
                            .animation(.easeOut(duration: 0.1), value: isLoading)
                            .contextMenu(forSelectionType: StandardPhrase.ID.self, menu: { selectedIDs in
                                if let id = selectedIDs.first, let currentPhrase = filteredPhrases.first(where: { $0.id == id }) {
                                    Button {
                                        copyToClipboard(currentPhrase.content)
                                        showCopyConfirmation = true
                                        currentCopyConfirmationTask?.cancel()
                                        currentCopyConfirmationTask = Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                            guard !Task.isCancelled else { return }
                                            withAnimation {
                                                showCopyConfirmation = false
                                            }
                                        }
                                    } label: {
                                        Label("コピー", systemImage: "document.on.document")
                                    }
                                    Divider()
                                    Button {
                                        phraseToEdit = currentPhrase // 編集対象のフレーズをセット
                                    } label: {
                                        Label("編集...", systemImage: "pencil")
                                    }
                                    Button {
                                        selectedPhraseForQRCode = currentPhrase
                                        showQRCodeSheet = true
                                    } label: {
                                        Label("QRコードを表示...", systemImage: "qrcode")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        phraseToDelete = currentPhrase
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("削除...", systemImage: "trash")
                                    }
                                }
                            }, primaryAction: { selectedIDs in
                                if let id = selectedIDs.first, let currentPhrase = filteredPhrases.first(where: { $0.id == id }) {
                                    copyToClipboard(currentPhrase.content)
                                    showCopyConfirmation = true
                                    currentCopyConfirmationTask?.cancel()
                                    currentCopyConfirmationTask = Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                        guard !Task.isCancelled else { return }
                                        withAnimation {
                                            showCopyConfirmation = false
                                        }
                                    }
                                    if !preventWindowCloseOnDoubleClick {
                                        dismiss()
                                    }
                                }
                            })
                        }

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.clear)
                        }
                    }
                }
            } // メインコンテンツを囲むZStackの終わり

            // コピー確認メッセージ (元の場所で、このZStackの直下に配置)
            VStack {
                Spacer() // 下部に寄せる
                if showCopyConfirmation {
                    ZStack { // グラデーションとテキストを重ねるZStack
                        LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)]), startPoint: .top, endPoint: .bottom)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity) // 横幅を最大に
                        
                        Text("コピーしました！")
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 0)
                            .padding(.top, 15)
                    }
                    .frame(maxWidth: .infinity) // ZStack自体も横幅を最大に
                    .offset(y: 1) // 下にぴったりとくっつくように微調整
                    .transition(.opacity) // フェードイン/アウト
                    .onAppear {
                        // onAppearからはタイマー設定ロジックを削除。
                        // ここは単にビューの出現アニメーションに使用
                    }
                    .onDisappear {
                        // ビューが非表示になる際にタスクをキャンセル (念のため)
                        currentCopyConfirmationTask?.cancel()
                    }
                }
            }
            .animation(.easeOut(duration: 0.1), value: showCopyConfirmation)
            .allowsHitTesting(false) // クリックイベントを透過させる
        }
        .onExitCommand {
            dismiss()
        }
        .frame(minWidth: 300, idealWidth: 375, maxWidth: 900, minHeight: 300, idealHeight: 400, maxHeight: .infinity)
        .alert("定型文の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let phrase = phraseToDelete {
                    standardPhraseManager.deletePhrase(id: phrase.id)
                    phraseToDelete = nil
                    selectedPhraseID = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                phraseToDelete = nil
            }
        } message: {
            Text("「\(truncateString(phraseToDelete?.title, maxLength: 50))」を本当に削除しますか？")
        }
        .sheet(isPresented: $showQRCodeSheet) {
            if let phrase = selectedPhraseForQRCode {
                QRCodeView(text: phrase.content)
            }
        }
        .sheet(item: $phraseToEdit) { phrase in // phraseToEditがnilでない場合にシートが表示される
            AddEditPhraseView(mode: .edit(phrase)) // 編集モードで表示し、対象のフレーズを渡す
                .environmentObject(standardPhraseManager)
        }
        .onAppear {
            performSearch(searchTerm: searchText)
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "StandardPhraseWindow" }) {
                    print("StandardPhraseWindowView onAppear: Found standardPhraseWindow: \(window.identifier?.rawValue ?? "unknown")")
                    if let controller = window.windowController as? ClipHoldWindowController {
                        print("StandardPhraseWindowView onAppear: Found managed controller. Re-applying customizations.")
                        controller.applyWindowCustomizations(window: window)
                    } else {
                        print("StandardPhraseWindowView onAppear: No ClipHoldWindowController found for this window.")
                    }
                } else {
                    print("StandardPhraseWindowView onAppear: Static phrase window not found among NSApp.windows.")
                }
            }
        }
    }
}

#Preview {
    StandardPhraseWindowView()
        .environmentObject(StandardPhraseManager.shared)
}
