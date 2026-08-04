import AppKit
import SwiftUI
import Combine

class QuickOverlayManager: ObservableObject {
    static let shared = QuickOverlayManager()
    
    @Published var isOverlayVisible: Bool = false
    @Published var currentOverlayType: QuickOverlayType? = nil
    
    // For copying/pasting when released
    @Published var hoveredItemId: UUID? = nil
    @Published var hoveredPhraseId: UUID? = nil
    @Published var hoveredAction: QuickOverlaySelection? = nil
    // 履歴アイテムをリッチテキストではなく標準テキスト（プレーンテキスト）としてコピーするかどうか
    @Published var hoveredCopyAsStandardText: Bool = false
    
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    private var delayTask: Task<Void, Never>?
    
    private init() {
        setupMonitors()
    }
    
    deinit {
        removeMonitors()
    }
    
    private func setupMonitors() {
        let mask: NSEvent.EventTypeMask = .flagsChanged
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event: event)
            }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event: event)
            }
            return event
        }
    }
    
    private func removeMonitors() {
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
    }
    
    @MainActor
    private func handleMouseClick(event: NSEvent) -> NSEvent? {
        guard UserDefaults.standard.isQuickOverlayEnabled else { return event }
        
        // This is a placeholder for actual click handling logic if implemented
        return event
    }
    @MainActor
    private func handleFlagsChanged(event: NSEvent) {
        guard UserDefaults.standard.isQuickOverlayEnabled else { return }
        
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let rawFlags = Int(flags.rawValue)
        
        let historyMods = UserDefaults.standard.historyQuickOverlayModifiers
        let phraseMods = UserDefaults.standard.standardPhraseQuickOverlayModifiers
        
        // Check if modifiers are released or changed
        if isOverlayVisible {
            let matchesCurrent = (currentOverlayType == .history && rawFlags == historyMods) ||
                                 (currentOverlayType == .standardPhrase && rawFlags == phraseMods)
            
            if !matchesCurrent {
                // Key released or changed -> Close and perform action
                executeActionAndClose()
            }
        } else {
            // Check if we should start the timer
            if rawFlags == historyMods && historyMods != 0 {
                startDelayTask(for: .history)
            } else if rawFlags == phraseMods && phraseMods != 0 {
                startDelayTask(for: .standardPhrase)
            } else {
                cancelDelayTask()
            }
        }
    }
    
    private func startDelayTask(for type: QuickOverlayType) {
        cancelDelayTask() // Ensure no existing task
        
        let delay = UserDefaults.standard.quickOverlayDelay
        let nanoseconds = UInt64(delay * 1_000_000_000)
        
        delayTask = Task {
            do {
                if nanoseconds > 0 {
                    try await Task.sleep(nanoseconds: nanoseconds)
                }
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.currentOverlayType = type
                    self.hoveredItemId = nil
                    self.hoveredPhraseId = nil
                    self.hoveredAction = nil
                    self.isOverlayVisible = true
                    
                    // Tell WindowController to show
                    NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayShouldShow"), object: nil)
                }
            } catch {
                // Cancelled
            }
        }
    }
    
    private func cancelDelayTask() {
        delayTask?.cancel()
        delayTask = nil
    }
    
    @MainActor
    private func executeActionAndClose() {
        isOverlayVisible = false
        cancelDelayTask()
        
        // Hide window immediately
        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
        
        // Execute copy/paste if an item is selected
        if let type = currentOverlayType {
            if let action = hoveredAction {
                if let delegate = NSApp.delegate as? AppDelegate {
                    Task { @MainActor in
                        if action == .add {
                            if type == .history {
                                delegate.showNewCopyWindow()
                            } else {
                                delegate.showAddPhraseWindow(withContent: "")
                            }
                        } else if action == .openWindow {
                            if type == .history {
                                delegate.showHistoryWindow()
                            } else {
                                delegate.showStandardPhraseWindow()
                            }
                        } else if action == .addPreset {
                            delegate.showAddPresetWindow()
                        }
                    }
                }
            } else {
                var itemToCopy: ClipboardItem? = nil
                var copyAsStandardText = false
                
                if type == .history {
                    if let itemId = hoveredItemId {
                        if let item = ClipboardManager.shared.clipboardHistory.first(where: { $0.id == itemId }) {
                            itemToCopy = item
                            copyAsStandardText = hoveredCopyAsStandardText
                        }
                    }
                } else {
                    if let phraseId = hoveredPhraseId {
                        // まずデフォルトの定型文を検索
                        if let phrase = StandardPhraseManager.shared.standardPhrases.first(where: { $0.id == phraseId }) {
                            itemToCopy = ClipboardItem(text: phrase.content, date: Date())
                        } else {
                            // 見つからない場合はプリセットから検索
                            for preset in StandardPhrasePresetManager.shared.presets {
                                if let phrase = preset.phrases.first(where: { $0.id == phraseId }) {
                                    itemToCopy = ClipboardItem(text: phrase.content, date: Date())
                                    break
                                }
                            }
                        }
                    }
                }
                
                if let item = itemToCopy {
                    let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
                    let textOnlyQuickPaste = UserDefaults.standard.bool(forKey: "textOnlyQuickPaste")
                    let shouldPaste = currentQuickPaste && !(type == .history && textOnlyQuickPaste && item.filePath != nil)
                    
                    // 標準テキストとしてコピーする場合は、リッチテキストを含まないプレーンテキストのアイテムを作成する
                    let itemToUse: ClipboardItem
                    if type == .history && copyAsStandardText {
                        itemToUse = ClipboardItem(text: item.text, date: item.date, qrCodeContent: item.qrCodeContent, sourceAppPath: item.sourceAppPath)
                    } else {
                        itemToUse = item
                    }
                    
                    ClipboardManager.shared.copyItemToClipboard(itemToUse) {
                        guard shouldPaste else { return }
                        Task { @MainActor in
                            // オーバーレイが非表示になり、キーウインドウ状態が解除された後に送信する
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            ClipHoldApp.performPaste()
                        }
                    }
                }
            }
        }
        
        resetSelectionState()
    }
    
    /// 履歴アイテムを標準テキスト（プレーンテキスト）としてコピーし、オーバーレイを閉じる。
    /// オーバーレイのeraserボタンをクリックした際に使用する。
    @MainActor
    func copyItemAsStandardTextAndClose(itemID: UUID) {
        guard let item = ClipboardManager.shared.clipboardHistory.first(where: { $0.id == itemID }) else {
            isOverlayVisible = false
            cancelDelayTask()
            NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
            resetSelectionState()
            return
        }
        
        let plainItem = ClipboardItem(text: item.text, date: item.date, qrCodeContent: item.qrCodeContent, sourceAppPath: item.sourceAppPath)
        
        isOverlayVisible = false
        cancelDelayTask()
        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayShouldHide"), object: nil)
        
        let currentQuickPaste = UserDefaults.standard.bool(forKey: "quickPaste")
        let shouldPaste = currentQuickPaste
        
        ClipboardManager.shared.copyItemToClipboard(plainItem) {
            guard shouldPaste else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                ClipHoldApp.performPaste()
            }
        }
        
        resetSelectionState()
    }
    
    private func resetSelectionState() {
        currentOverlayType = nil
        hoveredItemId = nil
        hoveredPhraseId = nil
        hoveredAction = nil
        hoveredCopyAsStandardText = false
    }
}
