import SwiftUI

struct ChangeItemAndCopyDraft {
    let originalContent: String
    var content: String

    init(content: String) {
        originalContent = content
        self.content = content
    }

    var hasChanges: Bool {
        content != originalContent
    }
}

struct ChangeItemAndCopyView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var draft: ChangeItemAndCopyDraft
    @State private var showDiscardConfirmation = false
    @State private var terminationEditorID = UUID()
    @State private var terminationReply: ((Bool) -> Void)?
    var title: String = String(localized: "項目を変更してコピー")
    var onCopy: (String) -> Void
    var isSheet: Bool = false
    
    @ObservedObject var modifierMonitor = ModifierKeyMonitor.shared
    @AppStorage("quickPaste") var quickPaste: Bool = false
    @AppStorage("quickPasteToPreviousApp") var quickPasteToPreviousApp: Bool = false
    
    @FocusState private var isContentFocused: Bool
    @FocusState private var isFindFieldFocused: Bool
    
    @StateObject private var editorController = EditorTextController()
    
    @State private var isReplacementSectionExpanded: Bool = false
    @State private var matches: [NSRange] = []
    @State private var currentMatchIndex: Int = 0
    @State private var hostWindow: NSWindow?

    init(content: String, title: String = String(localized: "項目を変更してコピー"), onCopy: @escaping (String) -> Void, isSheet: Bool = false) {
        _draft = State(initialValue: ChangeItemAndCopyDraft(content: content))
        self.title = title
        self.onCopy = onCopy
        self.isSheet = isSheet
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HighlightableTextEditor(
                text: $draft.content,
                matches: matches,
                currentMatchIndex: matches.isEmpty ? nil : currentMatchIndex,
                controller: editorController,
                onCommandF: {
                    openReplacementSection()
                }
            )
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 100)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colorSchemeContrast == .increased ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // テキスト置換セクション
            TextReplacementSectionView(
                content: $draft.content,
                isExpanded: $isReplacementSectionExpanded,
                matches: $matches,
                currentMatchIndex: $currentMatchIndex,
                editorController: editorController,
                isFindFieldFocused: $isFindFieldFocused
            )
            
            HStack {
                Button("キャンセル") {
                    requestCancel()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                Button(quickPaste && quickPasteToPreviousApp && modifierMonitor.isOptionKeyPressed ? "クイックペーストせずにコピー" : "コピー") {
                    onCopy(draft.content)
                    closeEditor()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(draft.content.isEmpty)
                .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(minWidth: 420, minHeight: isSheet ? (isReplacementSectionExpanded ? 440 : 330) : 330)
        .background {
            // ウィンドウ参照の取得
            WindowAccessorView { window in
                self.hostWindow = window
                if !isSheet, let controller = window.windowController as? ClipHoldStandardWindowController {
                    controller.shouldCloseHandler = {
                        canCloseEditor()
                    }
                }
            }
            
            // グローバルな ⌘F ショートカットハンドラー
            Button("") {
                openReplacementSection()
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .allowsHitTesting(false)
        }
        .onChange(of: isReplacementSectionExpanded) { _, expanded in
            adjustWindowSize(expanded: expanded)
        }
        .onAppear {
            EditorTerminationCoordinator.shared.register(id: terminationEditorID, hasChanges: {
                draft.hasChanges
            }, confirmDiscard: { reply in
                terminationReply = reply
                let window = hostWindow?.sheetParent ?? hostWindow
                window?.deminiaturize(nil)
                window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                showDiscardConfirmation = true
            })
        }
        .onDisappear {
            replyToTermination(allowed: false)
            EditorTerminationCoordinator.shared.unregister(id: terminationEditorID)
        }
        .alert("変更を破棄しますか？", isPresented: $showDiscardConfirmation) {
            Button("キャンセル", role: .cancel) {
                replyToTermination(allowed: false)
            }
            Button("破棄", role: .destructive) {
                replyToTermination(allowed: true)
                closeEditor()
            }
            .keyboardShortcut("d", modifiers: .command)
        } message: {
            Text("内容が変更されています。破棄してもよろしいですか？この操作は元に戻せません。")
        }
    }

    private func requestCancel() {
        if canCloseEditor() {
            closeEditor()
        }
    }

    private func replyToTermination(allowed: Bool) {
        let reply = terminationReply
        terminationReply = nil
        reply?(allowed)
    }

    private func canCloseEditor() -> Bool {
        if draft.hasChanges {
            showDiscardConfirmation = true
            return false
        }
        return true
    }

    private func closeEditor() {
        if isSheet {
            dismiss()
        } else {
            // アラートの終了処理中は閉じるボタンが無効なため、対象ウィンドウを直接閉じる。
            hostWindow?.close()
        }
    }
    
    private func openReplacementSection() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isReplacementSectionExpanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            isFindFieldFocused = true
        }
    }
    
    /// ウィンドウサイズをコンテンツに合わせて自動調整（コンテンツの高さ分だけ正確に伸縮）
    private func adjustWindowSize(expanded: Bool) {
        guard !isSheet, let window = hostWindow else { return }
        
        let sectionContentHeight: CGFloat = 96
        let currentFrame = window.frame
        let heightDelta = expanded ? sectionContentHeight : -sectionContentHeight
        
        let newHeight = max(330, currentFrame.height + heightDelta)
        let actualDelta = newHeight - currentFrame.height
        
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y - actualDelta,
            width: max(currentFrame.width, 420),
            height: newHeight
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true)
        }
    }
}

/// ウィンドウインスタンスを取得するためのヘルパービュー
private struct WindowAccessorView: NSViewRepresentable {
    var onWindowFound: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.onWindowFound(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                self.onWindowFound(window)
            }
        }
    }
}

struct ChangeItemAndCopyView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeItemAndCopyView(content: "これは編集する履歴アイテムの内容です。") { _ in }
    }
}
