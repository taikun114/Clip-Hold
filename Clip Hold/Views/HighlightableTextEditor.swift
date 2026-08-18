import AppKit
import SwiftUI

/// エディタのテキスト操作とUndo/Redoを制御するコントローラー
@MainActor
final class EditorTextController: ObservableObject {
    weak var textView: NSTextView?
    
    /// エディタにフォーカス（First Responder）を設定します
    func focus() {
        guard let textView = textView, let window = textView.window else { return }
        window.makeFirstResponder(textView)
    }
    
    /// 指定範囲のテキストをUndo履歴付きで置換します
    func replace(range: NSRange, with replacement: String, actionName: String = "テキストの置き換え") {
        guard let textView = textView else { return }
        let currentLength = (textView.string as NSString).length
        guard range.location != NSNotFound, range.location + range.length <= currentLength else { return }
        
        textView.undoManager?.setActionName(actionName)
        if textView.shouldChangeText(in: range, replacementString: replacement) {
            textView.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()
            let newRange = NSRange(location: range.location, length: (replacement as NSString).length)
            textView.setSelectedRange(newRange)
            focus()
        }
    }
    
    /// 全文を一括で置換します（Undo対応・超高速）
    func replaceEntireText(with newText: String, actionName: String = "すべてのテキストを置き換え") {
        guard let textView = textView else { return }
        let currentLength = (textView.string as NSString).length
        let fullRange = NSRange(location: 0, length: currentLength)
        
        textView.undoManager?.setActionName(actionName)
        if textView.shouldChangeText(in: fullRange, replacementString: newText) {
            textView.replaceCharacters(in: fullRange, with: newText)
            textView.didChangeText()
            focus()
        }
    }
    
    /// 複数箇所のテキストを1つのUndoグループとして一括置換します
    func replaceMultiple(replacements: [(range: NSRange, text: String)], actionName: String = "すべてのテキストを置き換え") {
        guard let textView = textView, !replacements.isEmpty else { return }
        textView.undoManager?.beginUndoGrouping()
        textView.undoManager?.setActionName(actionName)
        
        textView.textStorage?.beginEditing()
        var anyChanged = false
        
        // 後ろから順に置換してインデックスのズレを防ぐ
        for item in replacements.sorted(by: { $0.range.location > $1.range.location }) {
            let currentLength = (textView.string as NSString).length
            guard item.range.location != NSNotFound, item.range.location + item.range.length <= currentLength else { continue }
            
            if textView.shouldChangeText(in: item.range, replacementString: item.text) {
                textView.replaceCharacters(in: item.range, with: item.text)
                anyChanged = true
            }
        }
        
        textView.textStorage?.endEditing()
        
        if anyChanged {
            textView.didChangeText()
        }
        
        textView.undoManager?.endUndoGrouping()
        focus()
    }
}

/// 検索・正規表現のマッチ箇所をハイライト表示可能なテキストエディタ
struct HighlightableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var matches: [NSRange]
    var currentMatchIndex: Int?
    var controller: EditorTextController?
    var onCommandF: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = CustomEditorTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        
        textView.delegate = context.coordinator
        textView.onCommandF = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onCommandF?()
        }
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        controller?.textView = textView
        
        // 初期テキスト設定
        textView.string = text
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomEditorTextView else { return }
        controller?.textView = textView
        
        // テキストの同期（外部からの変更時のみ）
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        
        // ハイライトの適用
        context.coordinator.updateHighlights(
            textView: textView,
            matches: matches,
            currentMatchIndex: currentMatchIndex
        )
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightableTextEditor
        weak var textView: CustomEditorTextView?
        private var lastAppliedMatches: [NSRange] = []
        private var lastAppliedCurrentIndex: Int?
        
        init(_ parent: HighlightableTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
        
        func updateHighlights(textView: CustomEditorTextView, matches: [NSRange], currentMatchIndex: Int?) {
            guard let layoutManager = textView.layoutManager else { return }
            let textLength = (textView.string as NSString).length
            
            let fullRange = NSRange(location: 0, length: textLength)
            if textLength > 0 {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
                layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
            }
            
            var zeroWidthMatches: [(range: NSRange, isCurrent: Bool)] = []
            
            // 各マッチ箇所にハイライトを付与
            for (index, range) in matches.enumerated() {
                // 有効範囲チェック
                guard range.location != NSNotFound,
                      range.location + range.length <= textLength else {
                    continue
                }
                
                let isCurrent = (index == currentMatchIndex)
                
                if range.length == 0 {
                    // 0文字幅（^, $, ゼロ幅アサーション等）のマッチ
                    zeroWidthMatches.append((range: range, isCurrent: isCurrent))
                } else {
                    if isCurrent {
                        // 現在選択中のマッチ（濃いアクセントカラー + 白文字）
                        layoutManager.addTemporaryAttribute(
                            .backgroundColor,
                            value: NSColor.controlAccentColor,
                            forCharacterRange: range
                        )
                        layoutManager.addTemporaryAttribute(
                            .foregroundColor,
                            value: NSColor.white,
                            forCharacterRange: range
                        )
                    } else {
                        // その他のマッチ（薄いアクセントカラー）
                        layoutManager.addTemporaryAttribute(
                            .backgroundColor,
                            value: NSColor.controlAccentColor.withAlphaComponent(0.35),
                            forCharacterRange: range
                        )
                    }
                }
            }
            
            textView.zeroWidthMatches = zeroWidthMatches
            
            // 現在のマッチ箇所が変わったらスクロール
            if let currentIndex = currentMatchIndex,
               currentIndex >= 0,
               currentIndex < matches.count {
                let currentRange = matches[currentIndex]
                if currentRange.location != NSNotFound,
                   currentRange.location + currentRange.length <= textLength {
                    if lastAppliedCurrentIndex != currentIndex || lastAppliedMatches != matches {
                        textView.scrollRangeToVisible(currentRange)
                    }
                }
            }
            
            lastAppliedMatches = matches
            lastAppliedCurrentIndex = currentMatchIndex
        }
    }
}

class CustomEditorTextView: NSTextView {
    var onCommandF: (() -> Void)?
    var zeroWidthMatches: [(range: NSRange, isCurrent: Bool)] = [] {
        didSet {
            needsDisplay = true
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // ⌘F (Command + F) の検出
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
            onCommandF?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !zeroWidthMatches.isEmpty,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return }
        
        let textLength = (string as NSString).length
        
        NSGraphicsContext.saveGraphicsState()
        
        for match in zeroWidthMatches {
            let location = match.range.location
            guard location != NSNotFound, location <= textLength else { continue }
            
            var markerRect: NSRect
            let markerWidth: CGFloat = 3.0
            
            if textLength == 0 {
                let defaultHeight = font?.boundingRectForFont.height ?? 16
                markerRect = NSRect(
                    x: textContainerOrigin.x,
                    y: textContainerOrigin.y + 2,
                    width: markerWidth,
                    height: defaultHeight
                )
            } else if location < textLength {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: location)
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                let x = lineRect.origin.x + glyphLocation.x + textContainerOrigin.x
                let y = lineRect.origin.y + textContainerOrigin.y
                markerRect = NSRect(x: max(0, x - markerWidth / 2), y: y, width: markerWidth, height: lineRect.height)
            } else {
                // location == textLength（行末・テキスト末尾）
                let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: textLength - 1)
                let lastGlyphBounds = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyphIndex, length: 1), in: textContainer)
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
                let x = lastGlyphBounds.maxX + textContainerOrigin.x
                let y = lineRect.origin.y + textContainerOrigin.y
                markerRect = NSRect(x: max(0, x - markerWidth / 2), y: y, width: markerWidth, height: lineRect.height)
            }
            
            let color = match.isCurrent ? NSColor.controlAccentColor : NSColor.controlAccentColor.withAlphaComponent(0.4)
            color.setFill()
            let path = NSBezierPath(roundedRect: markerRect, xRadius: 1.5, yRadius: 1.5)
            path.fill()
        }
        
        NSGraphicsContext.restoreGraphicsState()
    }
}
