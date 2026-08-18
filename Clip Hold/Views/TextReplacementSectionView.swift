import SwiftUI

/// テキスト置換（検索・正規表現・履歴・オプション）を提供するセクションビュー
struct TextReplacementSectionView: View {
    @Binding var content: String
    @Binding var isExpanded: Bool
    @Binding var matches: [NSRange]
    @Binding var currentMatchIndex: Int
    var editorController: EditorTextController? = nil
    
    @FocusState.Binding var isFindFieldFocused: Bool
    
    @StateObject private var historyManager = TextReplacementHistoryManager.shared
    
    @State private var mode: TextReplacementMode = .standard
    @State private var findText: String = ""
    @State private var replaceText: String = ""
    
    // 検索オプション（大文字小文字無視がデフォルトON、単語単位一致はデフォルトOFF）
    @State private var standardOptions = StandardSearchOptions(ignoreCase: true, matchWholeWord: false)
    
    // 正規表現オプション（すべてデフォルトOFF）
    @State private var regexOptions = RegexSearchOptions(ignoreCase: false, multiline: false, dotMatchesLineSeparators: false)
    
    private enum ReplacingState {
        case idle
        case single
        case all
    }
    
    @State private var showingOptionsPopover: Bool = false
    @State private var showingHistoryPopover: Bool = false
    @State private var showingClearConfirmationAlert: Bool = false
    @State private var replacingState: ReplacingState = .idle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 折りたたみヘッダー
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
                if isExpanded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        isFindFieldFocused = true
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("テキスト置換")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 1行目: 置換モード切替と置換履歴ボタン
                    HStack {
                        Text("置換モード:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("置換モード", selection: $mode) {
                            Text("検索").tag(TextReplacementMode.standard)
                            Text("正規表現").tag(TextReplacementMode.regularExpression)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 140)
                        
                        Spacer()
                        
                        // 置換履歴ボタン
                        Button {
                            showingHistoryPopover = true
                        } label: {
                            Label("置換履歴", systemImage: "clock")
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $showingHistoryPopover, arrowEdge: .trailing) {
                            historyPopoverView
                        }
                    }
                    
                    // 2行目: 検索欄・置換欄・オプションボタン
                    HStack(spacing: 8) {
                        // 検索入力欄
                        TextField(mode == .standard ? "検索" : "正規表現", text: $findText)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .focused($isFindFieldFocused)
                        
                        // 置き換え入力欄
                        TextField("置き換え", text: $replaceText)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                        
                        // オプションボタン
                        Button {
                            showingOptionsPopover = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("置換オプション")
                        .popover(isPresented: $showingOptionsPopover, arrowEdge: .trailing) {
                            optionsPopoverView
                        }
                    }
                    
                    // 3行目: ナビゲーション・カウンター・置換実行ボタン
                    HStack(spacing: 8) {
                        // ナビゲーションボタングループ
                        ControlGroup {
                            Button {
                                goToPreviousMatch()
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(matches.isEmpty)
                            .help("前の一致へ移動")
                            
                            Button {
                                goToNextMatch()
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(matches.isEmpty)
                            .help("次の一致へ移動")
                        }
                        .fixedSize()
                        
                        // マッチ件数表示
                        Text(matches.isEmpty ? "0/0" : "\(currentMatchIndex + 1)/\(matches.count)")
                            .font(.callout.monospacedDigit())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        Spacer()
                        
                        // 単一置換ボタン
                        Button {
                            replaceCurrent()
                        } label: {
                            Text("置き換え")
                                .opacity(replacingState == .single ? 0 : 1)
                                .overlay {
                                    if replacingState == .single {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                        }
                        .buttonStyle(.bordered)
                        .disabled(matches.isEmpty || replacingState != .idle)
                        
                        // 全置換ボタン
                        Button {
                            replaceAll()
                        } label: {
                            Text("すべて置き換え")
                                .opacity(replacingState == .all ? 0 : 1)
                                .overlay {
                                    if replacingState == .all {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                        }
                        .buttonStyle(.bordered)
                        .disabled(matches.isEmpty || replacingState != .idle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            }
        }
        .onChange(of: content) { _, _ in
            updateMatches()
        }
        .onChange(of: findText) { _, _ in
            updateMatches()
        }
        .onChange(of: mode) { _, _ in
            updateMatches()
        }
        .onChange(of: standardOptions) { _, _ in
            updateMatches()
        }
        .onChange(of: regexOptions) { _, _ in
            updateMatches()
        }
    }
    
    // MARK: - オプションポップオーバー
    
    private var optionsPopoverView: some View {
        Form {
            Section {
                if mode == .standard {
                    Toggle("大文字・小文字を無視", isOn: $standardOptions.ignoreCase)
                    
                    Toggle("単語単位で一致", isOn: $standardOptions.matchWholeWord)
                } else {
                    Toggle(isOn: $regexOptions.ignoreCase) {
                        HStack(spacing: 2) {
                            Text("大文字・小文字を無視 ")
                            Text("(i)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    Toggle(isOn: $regexOptions.multiline) {
                        HStack(spacing: 2) {
                            Text("行ごとに検索 ")
                            Text("(m)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    Toggle(isOn: $regexOptions.dotMatchesLineSeparators) {
                        HStack(spacing: 2) {
                            Text("ドットが改行にも一致 ")
                            Text("(s)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            } header: {
                Text(mode == .standard ? "置き換えオプション" : "正規表現オプション")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - 置換履歴ポップオーバー
    
    private var historyPopoverView: some View {
        Group {
            if #available(macOS 26, *) {
                historyFormView
                    .safeAreaBar(edge: .bottom) {
                        clearButtonRow
                            .padding()
                    }
            } else {
                VStack(spacing: 0) {
                    historyFormView
                    
                    clearButtonRow
                        .padding()
                }
            }
        }
        .frame(width: 450)
        .frame(maxHeight: 500)
        .alert("すべての履歴をクリア", isPresented: $showingClearConfirmationAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("クリア", role: .destructive) {
                historyManager.clearHistory()
            }
        } message: {
            Text("すべての履歴をクリアしてもよろしいですか？この操作は元に戻せません。")
        }
    }
    
    private var historyFormView: some View {
        Form {
            Section {
                if historyManager.items.isEmpty {
                    Text("履歴はありません")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(historyManager.items) { item in
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.mode == .standard ? "検索モード" : "正規表現モード")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 6) {
                                    Text(visibleWhitespaceAttributedString(for: item.findText))
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .help(item.findText)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    if item.replaceText.isEmpty {
                                        Text("削除")
                                            .font(.body)
                                            .foregroundStyle(.tertiary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .help(String(localized: "削除"))
                                    } else {
                                        Text(visibleWhitespaceAttributedString(for: item.replaceText))
                                            .font(.system(.body, design: .monospaced))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .help(item.replaceText)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Button("セット") {
                                    applyHistoryItem(item)
                                    showingHistoryPopover = false
                                }
                                .buttonStyle(.bordered)
                                
                                Button(role: .destructive) {
                                    historyManager.removeItem(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .help("この履歴を削除")
                            }
                        }
                    }
                }
            } header: {
                Text("置換履歴")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }
    
    private var clearButtonRow: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                showingClearConfirmationAlert = true
            } label: {
                Label("履歴をクリア…", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(historyManager.items.isEmpty)
        }
    }
    
    // MARK: - ロジック & アクション
    
    private func updateMatches() {
        guard !findText.isEmpty, !content.isEmpty else {
            matches = []
            currentMatchIndex = 0
            return
        }
        
        let foundMatches = TextReplacementEngine.findMatches(
            in: content,
            findText: findText,
            mode: mode,
            standardOptions: standardOptions,
            regexOptions: regexOptions
        )
        
        matches = foundMatches
        if foundMatches.isEmpty {
            currentMatchIndex = 0
        } else if currentMatchIndex >= foundMatches.count {
            currentMatchIndex = max(0, foundMatches.count - 1)
        }
    }
    
    private func goToPreviousMatch() {
        guard !matches.isEmpty else { return }
        if currentMatchIndex > 0 {
            currentMatchIndex -= 1
        } else {
            currentMatchIndex = matches.count - 1
        }
    }
    
    private func goToNextMatch() {
        guard !matches.isEmpty else { return }
        if currentMatchIndex < matches.count - 1 {
            currentMatchIndex += 1
        } else {
            currentMatchIndex = 0
        }
    }
    
    private func replaceCurrent() {
        guard !matches.isEmpty, currentMatchIndex < matches.count, replacingState == .idle else { return }
        let targetRange = matches[currentMatchIndex]
        
        // 履歴の記録
        historyManager.addHistory(
            mode: mode,
            findText: findText,
            replaceText: replaceText,
            standardOptions: standardOptions,
            regexOptions: regexOptions
        )
        
        replacingState = .single
        isFindFieldFocused = false
        
        Task {
            let currentContent = content
            let currentFind = findText
            let currentReplace = replaceText
            let currentMode = mode
            let currentReg = regexOptions
            
            // バックグラウンドで置換文字列を計算
            let expandedReplacement = await Task.detached(priority: .userInitiated) {
                TextReplacementEngine.replacementString(
                    for: targetRange,
                    in: currentContent,
                    findText: currentFind,
                    replaceText: currentReplace,
                    mode: currentMode,
                    regexOptions: currentReg
                )
            }.value
            
            if let controller = editorController, controller.textView != nil {
                controller.replace(range: targetRange, with: expandedReplacement)
            } else {
                let newContent = await Task.detached(priority: .userInitiated) {
                    TextReplacementEngine.replaceSingle(
                        in: currentContent,
                        matchRange: targetRange,
                        findText: currentFind,
                        replaceText: currentReplace,
                        mode: currentMode,
                        regexOptions: currentReg
                    )
                }.value
                content = newContent
            }
            
            replacingState = .idle
        }
    }
    
    private func replaceAll() {
        guard !matches.isEmpty, replacingState == .idle else { return }
        
        // 履歴の記録
        historyManager.addHistory(
            mode: mode,
            findText: findText,
            replaceText: replaceText,
            standardOptions: standardOptions,
            regexOptions: regexOptions
        )
        
        replacingState = .all
        isFindFieldFocused = false
        
        Task {
            let currentContent = content
            let currentFind = findText
            let currentReplace = replaceText
            let currentMode = mode
            let currentStd = standardOptions
            let currentReg = regexOptions
            
            // バックグラウンドスレッドで置換後の文字列を高速計算
            let (newContent, count) = await Task.detached(priority: .userInitiated) {
                TextReplacementEngine.replaceAll(
                    in: currentContent,
                    findText: currentFind,
                    replaceText: currentReplace,
                    mode: currentMode,
                    standardOptions: currentStd,
                    regexOptions: currentReg
                )
            }.value
            
            if count > 0 {
                if let controller = editorController, controller.textView != nil {
                    controller.replaceEntireText(with: newContent)
                } else {
                    content = newContent
                }
            }
            
            replacingState = .idle
        }
    }
    
    private func applyHistoryItem(_ item: TextReplacementHistoryItem) {
        mode = item.mode
        findText = item.findText
        replaceText = item.replaceText
        if let std = item.standardOptions {
            standardOptions = std
        }
        if let reg = item.regexOptions {
            regexOptions = reg
        }
        updateMatches()
    }
    
    /// 空白・改行文字をターシャリーカラーの記号（半角: ␣, 全角: □, 改行: ↵）で可視化した AttributedString を生成
    private func visibleWhitespaceAttributedString(for text: String) -> AttributedString {
        var result = AttributedString()
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        for char in normalized {
            switch char {
            case " ": // 半角スペース (U+0020)
                var attr = AttributedString("␣")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\u{3000}": // 全角スペース (U+3000)
                var attr = AttributedString("□")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            case "\n": // 改行 (LF)
                var attr = AttributedString("↵")
                attr.foregroundColor = .tertiaryLabelColor
                result.append(attr)
            default:
                let attr = AttributedString(String(char))
                result.append(attr)
            }
        }
        return result
    }
}
