import Testing
import KeyboardShortcuts
@testable import Clip_Hold

struct KeyboardShortcutsTests {

    @Test func testKeyboardShortcutInitialValues() async throws {
        // 各ショートカットの初期値（initialShortcut）が正しく設定されているかを検証
        #expect(KeyboardShortcuts.Name.showAllStandardPhrases.initialShortcut == KeyboardShortcuts.Shortcut(.v, modifiers: [.control, .command]))
        #expect(KeyboardShortcuts.Name.showAllCopyHistory.initialShortcut == KeyboardShortcuts.Shortcut(.v, modifiers: [.option, .command]))
        #expect(KeyboardShortcuts.Name.addSNewtandardPhrase.initialShortcut == KeyboardShortcuts.Shortcut(.a, modifiers: [.control, .command]))
        #expect(KeyboardShortcuts.Name.addStandardPhraseFromClipboard.initialShortcut == KeyboardShortcuts.Shortcut(.c, modifiers: [.control, .command]))
        #expect(KeyboardShortcuts.Name.addNewPreset.initialShortcut == KeyboardShortcuts.Shortcut(.n, modifiers: [.control, .command]))
        #expect(KeyboardShortcuts.Name.nextPreset.initialShortcut == KeyboardShortcuts.Shortcut(.p, modifiers: [.control, .command]))
        #expect(KeyboardShortcuts.Name.previousPreset.initialShortcut == KeyboardShortcuts.Shortcut(.p, modifiers: [.shift, .control, .command]))
        #expect(KeyboardShortcuts.Name.toggleClipboardMonitoring.initialShortcut == KeyboardShortcuts.Shortcut(.m, modifiers: [.option, .command]))
    }

}
