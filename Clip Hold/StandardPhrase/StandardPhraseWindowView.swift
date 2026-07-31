import SwiftUI
import AppKit

private func copyToClipboard(_ text: String, clipboardManager: ClipboardManager) {
    clipboardManager.isCopyingStandardPhrase = true
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

struct StandardPhraseItemRow<MenuContent: View>: View {
    let phrase: StandardPhrase
    let index: Int
    @AppStorage("hideNumbersInStandardPhrasesWindow") var hideNumbers: Bool = false
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    
    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat
    
    @ViewBuilder let menuItems: () -> MenuContent
    
    var body: some View {
        // isURLをbodyのトップレベルで定義
        let isURL: Bool = {
            guard !phrase.content.isEmpty,
                  let url = URL(string: phrase.content) else {
                return false
            }
            return url.scheme == "http" || url.scheme == "https"
        }()
        
        HStack(spacing: 8) {
            if !hideNumbers {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: lineNumberTextWidth, alignment: .trailing)
                    .padding(.trailing, trailingPaddingForLineNumber)
            }
            
            // アイコン表示ロジック
            if showColorCodeIcon, let color = ColorCodeParser.parseColor(from: phrase.content) {
                ColorCodeIconView(color: color)
            } else {
                Image(systemName: isURL ? "paperclip" : "list.bullet.rectangle.portrait")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text(phrase.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                Text(phrase.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            Menu {
                menuItems()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundStyle(.primary)
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
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @ViewBuilder
    private func standardPhraseMenuItems(for currentPhrase: StandardPhrase) -> some View {
        let isURL: Bool = {
            guard !currentPhrase.content.isEmpty,
                  let url = URL(string: currentPhrase.content) else {
                return false
            }
            return url.scheme == "http" || url.scheme == "https"
        }()
        
        SharedCopyMenuItem {
            copyToClipboard(currentPhrase.content, clipboardManager: clipboardManager)
            showCopyConfirmation = true
            currentCopyConfirmationTask?.cancel()
            currentCopyConfirmationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                showCopyConfirmation = false
            }
        }
        
        SharedEditAndCopyMenuItem {
            phraseToEditAndCopy = currentPhrase
            showingEditAndCopySheet = true
        }
        
        if isURL {
            SharedOpenLinkMenuItem(urlString: currentPhrase.content)
        }
        
        Divider()
        
        SharedEditMenuItem {
            phraseToEdit = currentPhrase
        }
        
        SharedMoveMenuItem {
            phraseToMove = currentPhrase
        }
        
        SharedDuplicateMenuItem {
            if let selectedPreset = presetManager.selectedPreset {
                presetManager.duplicate(phrase: currentPhrase, in: selectedPreset)
            }
        }
        
        SharedShowQRCodeMenuItem {
            selectedPhraseForQRCode = currentPhrase
            showQRCodeSheet = true
        }
        
        Divider()
        
        SharedDeleteMenuItem {
            phraseToDelete = currentPhrase
            showingDeleteConfirmation = true
        }
    }
    
    @StateObject var iconGenerator = PresetIconGenerator.shared
    
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
    @State private var phraseToEditAndCopy: StandardPhrase?
    @State private var showingEditAndCopySheet = false

    @State private var phraseToMove: StandardPhrase?
    @State private var destinationPresetId: UUID?
    
    @AppStorage("hideNumbersInStandardPhrasesWindow") var hideNumbers: Bool = false
    @AppStorage("closeWindowOnDoubleClickInStandardPhrasesWindow") var closeWindowOnDoubleClickInStandardPhrasesWindow: Bool = false
    
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isListFocused: Bool
    
    // 新規プリセット追加シート用の状態変数
    @State private var showingAddPresetSheet = false
    @State private var newPresetName = ""
    
    @State private var presetChangedForScroll: Bool = false
    @State private var searchTrigger: UUID = UUID()
    
    private var lineNumberTextWidth: CGFloat? {
        guard !hideNumbers, !filteredPhrases.isEmpty else { return nil }
        
        let maxIndex = filteredPhrases.count
        let numDigits = String(maxIndex).count
        
        let digitWidth: CGFloat = 7.0
        let periodWidth: CGFloat = 3.0
        let buffer: CGFloat = 1.0
        
        return CGFloat(numDigits) * digitWidth + periodWidth + buffer
    }
    
    private let trailingPaddingForLineNumber: CGFloat = 5
    
    private func performSearch(searchTerm: String) {
        let currentPhrases: [StandardPhrase]
        if presetManager.selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
            // 「プリセットがありません」が選択されている場合は空のリスト
            currentPhrases = []
        } else if let selectedPreset = presetManager.selectedPreset {
            // プリセットが選択されている場合はそのプリセットの定型文
            currentPhrases = selectedPreset.phrases
        } else {
            // プリセットが選択されていない場合はデフォルトの定型文
            currentPhrases = standardPhraseManager.standardPhrases
        }
        
        let newFilteredPhrases: [StandardPhrase]
        if searchTerm.isEmpty {
            newFilteredPhrases = currentPhrases
        } else {
            newFilteredPhrases = currentPhrases.filter {
                $0.title.localizedCaseInsensitiveContains(searchTerm) ||
                $0.content.localizedCaseInsensitiveContains(searchTerm)
            }
        }
        self.filteredPhrases = newFilteredPhrases
        
        if selectedPhraseID == nil || !newFilteredPhrases.contains(where: { $0.id == selectedPhraseID }) {
            selectedPhraseID = newFilteredPhrases.first?.id
        }
        
        // 明示的にリストへフォーカスを移す（検索中でない場合）
        if !isSearchFieldFocused {
            isListFocused = true
        }
    }
    
    private func movePhrases(from source: IndexSet, to destination: Int) {
        // 検索中の場合は並び替えを許可しない
        if searchText.isEmpty {
            // プリセットが選択されている場合、プリセットの定型文を更新
            if let selectedPreset = presetManager.selectedPreset {
                var updatedPreset = selectedPreset
                updatedPreset.phrases.move(fromOffsets: source, toOffset: destination)
                presetManager.updatePreset(updatedPreset)
            } else {
                // プリセットが選択されていない場合、標準の定型文マネージャーを使用
                standardPhraseManager.movePhrase(from: source, to: destination)
            }
        }
    }
    
    private func handleSearchSubmit() {
        isListFocused = true
    }
    
    var body: some View {
        ZStack { // ZStackでコンテンツとメッセージを重ねる
            SharedWindowBackground()
            
            ZStack { // メインコンテンツを囲むZStack
                VStack(spacing: 0) {
                    HStack {
                        SharedSearchField(
                            placeholder: "定型文を検索",
                            searchText: $searchText,
                            isSearchFieldFocused: $isSearchFieldFocused
                        )
                        .onSubmit(of: .text) {
                            handleSearchSubmit()
                        }
                        
                        // プリセット選択メニューを追加
                        Menu {
                            SharedPresetMenuContent(
                                title: "プリセット",
                                selectedPresetId: Binding(
                                    get: { presetManager.selectedPresetId },
                                    set: { newValue in
                                        if let newValue = newValue {
                                            presetManager.selectedPresetId = newValue
                                            presetManager.saveSelectedPresetId()
                                        }
                                    }
                                ),
                                onNewPresetAction: {
                                    showingAddPresetSheet = true
                                }
                            )
                        } label: {
                            if let selectedPreset = presetManager.selectedPreset,
                               let icon = iconGenerator.iconCache[selectedPreset.id] {
                                Image(nsImage: icon)
                            } else {
                                Image(systemName: "star.square")
                                    .imageScale(.large)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 48)
                        .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 5)
                    .onAppear {
                        if presetManager.presets.isEmpty {
                            // プリセットがない場合は、特別なUUIDを設定
                            presetManager.selectedPresetId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                        } else if presetManager.selectedPresetId == nil || presetManager.selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                            presetManager.selectedPresetId = presetManager.presets.first?.id
                        }
                    }
                    .onReceive(presetManager.presetAddedSubject) { _ in
                        if presetManager.presets.isEmpty {
                            presetManager.selectedPresetId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                        } else if presetManager.selectedPresetId == nil || presetManager.selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                            presetManager.selectedPresetId = presetManager.presets.first?.id
                        }
                    }
                    .onReceive(presetManager.$presets) { presets in
                        if presets.isEmpty {
                            presetManager.selectedPresetId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
                        } else if presetManager.selectedPresetId == nil || presetManager.selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" || !presets.contains(where: { $0.id == presetManager.selectedPresetId }) {
                            presetManager.selectedPresetId = presets.first?.id
                        }
                    }
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
                            searchTrigger = UUID()
                        }
                    }
                    .onChange(of: standardPhraseManager.standardPhrases) { _, _ in
                        performSearch(searchTerm: searchText)
                    }
                    .onChange(of: presetManager.selectedPreset?.phrases) { _, _ in
                        performSearch(searchTerm: searchText)
                    }
                    .onChange(of: presetManager.selectedPresetId) { _, _ in
                        presetChangedForScroll = true
                    }
                    
                    Spacer(minLength: 0)
                    
                    ZStack {
                        if filteredPhrases.isEmpty && !isLoading {
                                SharedEmptyListView(message: "定型文はありません")
                        } else {
                            ScrollViewReader { proxy in
                                List(selection: $selectedPhraseID) {
                                    if searchText.isEmpty {
                                        ForEach(filteredPhrases) { phrase in
                                            StandardPhraseItemRow(
                                                phrase: phrase,
                                                index: filteredPhrases.firstIndex(where: { $0.id == phrase.id }) ?? 0,
                                                lineNumberTextWidth: lineNumberTextWidth,
                                                trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                                                menuItems: {
                                                    standardPhraseMenuItems(for: phrase)
                                                }
                                            )
                                            .tag(phrase.id)
                                            .listRowBackground(Color.clear)
                                            .draggable(phrase.content) // テキストをドラッグ可能にする
                                        }
                                        .onMove(perform: movePhrases)
                                    } else {
                                        ForEach(filteredPhrases) { phrase in
                                            StandardPhraseItemRow(
                                                phrase: phrase,
                                                index: filteredPhrases.firstIndex(where: { $0.id == phrase.id }) ?? 0,
                                                lineNumberTextWidth: lineNumberTextWidth,
                                                trailingPaddingForLineNumber: trailingPaddingForLineNumber,
                                                menuItems: {
                                                    standardPhraseMenuItems(for: phrase)
                                                }
                                            )
                                            .tag(phrase.id)
                                            .listRowBackground(Color.clear)
                                            .draggable(phrase.content) // テキストをドラッグ可能にする
                                        }
                                    }
                                }
                                .onChange(of: searchTrigger) { _, _ in
                                    if let firstId = filteredPhrases.first?.id {
                                        Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 100_000_000)
                                            proxy.scrollTo(firstId)
                                        }
                                    }
                                }
                                .onChange(of: filteredPhrases) { _, newValue in
                                    if presetChangedForScroll {
                                        if let firstId = newValue.first?.id {
                                            Task { @MainActor in
                                                try? await Task.sleep(nanoseconds: 100_000_000)
                                                proxy.scrollTo(firstId)
                                            }
                                        }
                                        presetChangedForScroll = false
                                    }
                                    
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 10_000_000)
                                        if selectedPhraseID == nil || !newValue.contains(where: { $0.id == selectedPhraseID }) {
                                            selectedPhraseID = newValue.first?.id
                                        }
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
                                    standardPhraseMenuItems(for: currentPhrase)
                                }
                            }, primaryAction: { selectedIDs in
                                if let id = selectedIDs.first, let currentPhrase = filteredPhrases.first(where: { $0.id == id }) {
                                    copyToClipboard(currentPhrase.content, clipboardManager: clipboardManager)
                                    showCopyConfirmation = true
                                    currentCopyConfirmationTask?.cancel()
                                    currentCopyConfirmationTask = Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                        guard !Task.isCancelled else { return }
                                        showCopyConfirmation = false
                                    }
                                    if closeWindowOnDoubleClickInStandardPhrasesWindow {
                                        dismiss()
                                    }
                                }
                            })
                            .focused($isListFocused)
                            .defaultFocus($isListFocused, true)
                        }
                        
                        if isLoading {
                            SharedLoadingView()
                        }
                    }
                }
            } // メインコンテンツを囲むZStackの終わり
            
            // コピー確認メッセージ (元の場所で、このZStackの直下に配置)
            SharedCopyConfirmationView(showCopyConfirmation: showCopyConfirmation)
        }
        .onKeyPress { press in
            guard press.modifiers.isEmpty || press.modifiers == .shift else { return .ignored }
            
            // バックスペースキーの処理
            if press.key == .delete || press.key == .deleteForward || press.characters == "\u{7F}" || press.characters == "\u{08}" {
                if !isSearchFieldFocused {
                    if !searchText.isEmpty {
                        searchText.removeLast()
                        isSearchFieldFocused = true
                        
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            if let window = NSApp.keyWindow,
                               let textView = window.firstResponder as? NSTextView {
                                let length = textView.string.count
                                textView.setSelectedRange(NSRange(location: length, length: 0))
                            }
                        }
                        return .handled
                    }
                }
                return .ignored
            }
            
            let ignoredKeys: Set<KeyEquivalent> = [.return, .tab, .escape, .space, .upArrow, .downArrow, .leftArrow, .rightArrow, .home, .end, .pageUp, .pageDown, .clear]
            if ignoredKeys.contains(press.key) {
                return .ignored
            }
            guard let char = press.characters.first, !press.characters.isEmpty else { return .ignored }
            
            // 制御文字の入力を無視
            if let scalar = char.unicodeScalars.first, CharacterSet.controlCharacters.contains(scalar) {
                return .ignored
            }
            
            if !isSearchFieldFocused {
                searchText.append(char)
                isSearchFieldFocused = true
                
                // 検索欄にフォーカスが移った後、文字が全選択されるのを防ぐためカーソルを末尾に移動させる
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    if let window = NSApp.keyWindow,
                       let textView = window.firstResponder as? NSTextView {
                        let length = textView.string.count
                        textView.setSelectedRange(NSRange(location: length, length: 0))
                    }
                }
                
                return .handled
            }
            return .ignored
        }
        .frame(minWidth: 300, idealWidth: 375, maxWidth: 900, minHeight: 300, idealHeight: 400, maxHeight: .infinity)
        .alert("定型文の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let phrase = phraseToDelete {
                    // プリセットが選択されている場合はプリセットから削除、そうでなければデフォルトから削除
                    if var selectedPreset = presetManager.selectedPreset {
                        selectedPreset.phrases.removeAll { $0.id == phrase.id }
                        presetManager.updatePreset(selectedPreset)
                    } else {
                        standardPhraseManager.deletePhrase(id: phrase.id)
                    }
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
        .sheet(item: $selectedPhraseForQRCode) { phrase in
            QRCodeView(text: phrase.content)
        }
        .sheet(item: $phraseToEdit) { phrase in
            AddEditPhraseView(mode: .edit(phrase), presetManager: presetManager, isSheet: true)
                .environmentObject(standardPhraseManager)
                .environmentObject(presetManager)
        }
        .sheet(item: $phraseToEditAndCopy) { phrase in
            EditHistoryItemView(content: phrase.content, onCopy: { editedContent in
                copyToClipboard(editedContent, clipboardManager: clipboardManager)
                showCopyConfirmation = true
                currentCopyConfirmationTask?.cancel()
                currentCopyConfirmationTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    showCopyConfirmation = false
                }
            }, isSheet: true)
        }
        .sheet(isPresented: $showingAddPresetSheet) {
            AddEditPresetView(isSheet: true, editingPreset: nil)
        }
        .sheet(item: $phraseToMove) { phrase in
            if let sourceId = presetManager.selectedPresetId {
                MovePhrasePresetSelectionSheet(presetManager: presetManager, sourcePresetId: sourceId, selectedPresetId: $destinationPresetId) {
                    if let destinationId = destinationPresetId {
                        presetManager.move(phrase: phrase, to: destinationId)
                    }
                }
            }
        }
        .onAppear {
            performSearch(searchTerm: searchText)
            
            // ウインドウ表示時は必ずリストにフォーカスを当てる
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                isListFocused = true
            }
        }
        .onDisappear {
            currentCopyConfirmationTask?.cancel()
        }
    }
}

#Preview {
    StandardPhraseWindowView()
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(StandardPhrasePresetManager.shared)
        .environmentObject(ClipboardManager.shared)
}
