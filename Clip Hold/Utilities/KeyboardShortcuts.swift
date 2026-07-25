import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showAllStandardPhrases = Self("showAllStandardPhrases", initial: .init(.v, modifiers: [.control, .command]))
    static let showAllCopyHistory = Self("showAllCopyHistory", initial: .init(.v, modifiers: [.option, .command]))
    
    static let addSNewtandardPhrase = Self("addSNewtandardPhrase", initial: .init(.a, modifiers: [.control, .command]))
    static let addStandardPhraseFromClipboard = Self("addStandardPhraseFromClipboard", initial: .init(.c, modifiers: [.control, .command]))
    static let addNewPreset = Self("addNewPreset", initial: .init(.n, modifiers: [.control, .command]))
    static let nextPreset = Self("nextPreset", initial: .init(.p, modifiers: [.control, .command]))
    static let previousPreset = Self("previousPreset", initial: .init(.p, modifiers: [.shift, .control, .command]))
    
    static let toggleClipboardMonitoring = Self("toggleClipboardMonitoring", initial: .init(.m, modifiers: [.option, .command]))
    
    static let copyStandardPhrase1 = Self("copyStandardPhrase1", initial: .init(.one, modifiers: [.control, .command]))
    static let copyStandardPhrase2 = Self("copyStandardPhrase2", initial: .init(.two, modifiers: [.control, .command]))
    static let copyStandardPhrase3 = Self("copyStandardPhrase3", initial: .init(.three, modifiers: [.control, .command]))
    static let copyStandardPhrase4 = Self("copyStandardPhrase4", initial: .init(.four, modifiers: [.control, .command]))
    static let copyStandardPhrase5 = Self("copyStandardPhrase5", initial: .init(.five, modifiers: [.control, .command]))
    static let copyStandardPhrase6 = Self("copyStandardPhrase6", initial: .init(.six, modifiers: [.control, .command]))
    static let copyStandardPhrase7 = Self("copyStandardPhrase7", initial: .init(.seven, modifiers: [.control, .command]))
    static let copyStandardPhrase8 = Self("copyStandardPhrase8", initial: .init(.eight, modifiers: [.control, .command]))
    static let copyStandardPhrase9 = Self("copyStandardPhrase9", initial: .init(.nine, modifiers: [.control, .command]))
    static let copyStandardPhrase10 = Self("copyStandardPhrase10", initial: .init(.zero, modifiers: [.control, .command]))
    
    static var allStandardPhraseCopyShortcuts: [KeyboardShortcuts.Name] {
        return [
            .copyStandardPhrase1, .copyStandardPhrase2, .copyStandardPhrase3,
            .copyStandardPhrase4, .copyStandardPhrase5, .copyStandardPhrase6,
            .copyStandardPhrase7, .copyStandardPhrase8, .copyStandardPhrase9,
            .copyStandardPhrase10
        ]
    }
    
    static let copyPinnedHistoryItem = Self("copyPinnedHistoryItem", initial: .init(.p, modifiers: [.option, .command]))
    static let copyClipboardHistory1 = Self("copyClipboardHistory1", initial: .init(.one, modifiers: [.option, .command]))
    static let copyClipboardHistory2 = Self("copyClipboardHistory2", initial: .init(.two, modifiers: [.option, .command]))
    static let copyClipboardHistory3 = Self("copyClipboardHistory3", initial: .init(.three, modifiers: [.option, .command]))
    static let copyClipboardHistory4 = Self("copyClipboardHistory4", initial: .init(.four, modifiers: [.option, .command]))
    static let copyClipboardHistory5 = Self("copyClipboardHistory5", initial: .init(.five, modifiers: [.option, .command]))
    static let copyClipboardHistory6 = Self("copyClipboardHistory6", initial: .init(.six, modifiers: [.option, .command]))
    static let copyClipboardHistory7 = Self("copyClipboardHistory7", initial: .init(.seven, modifiers: [.option, .command]))
    static let copyClipboardHistory8 = Self("copyClipboardHistory8", initial: .init(.eight, modifiers: [.option, .command]))
    static let copyClipboardHistory9 = Self("copyClipboardHistory9", initial: .init(.nine, modifiers: [.option, .command]))
    static let copyClipboardHistory10 = Self("copyClipboardHistory10", initial: .init(.zero, modifiers: [.option, .command]))
    static let editAndCopyLatestHistory = Self("editAndCopyLatestHistory", initial: .init(.e, modifiers: [.option, .command]))
    static let newCopy = Self("newCopy", initial: .init(.a, modifiers: [.option, .command]))
    
    static var allClipboardHistoryCopyShortcuts: [KeyboardShortcuts.Name] {
        return [
            .copyClipboardHistory1, .copyClipboardHistory2, .copyClipboardHistory3,
            .copyClipboardHistory4, .copyClipboardHistory5, .copyClipboardHistory6,
            .copyClipboardHistory7, .copyClipboardHistory8, .copyClipboardHistory9,
            .copyClipboardHistory10
        ]
    }
}
