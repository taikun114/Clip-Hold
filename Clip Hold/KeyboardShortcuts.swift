import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showAllStandardPhrases = Self("showAllStandardPhrases", default: .init(.v, modifiers: [.control, .command]))
    static let showAllCopyHistory = Self("showAllCopyHistory", default: .init(.v, modifiers: [.option, .command]))

    static let addStandardPhraseFromClipboard = Self("addStandardPhraseFromClipboard", default: .init(.a, modifiers: [.control, .command]))

    static let toggleClipboardMonitoring = Self("toggleClipboardMonitoring", default: .init(.m, modifiers: [.option, .command]))

    static let copyStandardPhrase1 = Self("copyStandardPhrase1", default: .init(.one, modifiers: [.control, .command]))
    static let copyStandardPhrase2 = Self("copyStandardPhrase2", default: .init(.two, modifiers: [.control, .command]))
    static let copyStandardPhrase3 = Self("copyStandardPhrase3", default: .init(.three, modifiers: [.control, .command]))
    static let copyStandardPhrase4 = Self("copyStandardPhrase4", default: .init(.four, modifiers: [.control, .command]))
    static let copyStandardPhrase5 = Self("copyStandardPhrase5", default: .init(.five, modifiers: [.control, .command]))
    static let copyStandardPhrase6 = Self("copyStandardPhrase6", default: .init(.six, modifiers: [.control, .command]))
    static let copyStandardPhrase7 = Self("copyStandardPhrase7", default: .init(.seven, modifiers: [.control, .command]))
    static let copyStandardPhrase8 = Self("copyStandardPhrase8", default: .init(.eight, modifiers: [.control, .command]))
    static let copyStandardPhrase9 = Self("copyStandardPhrase9", default: .init(.nine, modifiers: [.control, .command]))
    static let copyStandardPhrase10 = Self("copyStandardPhrase10", default: .init(.zero, modifiers: [.control, .command]))

    static var allStandardPhraseCopyShortcuts: [KeyboardShortcuts.Name] {
        return [
            .copyStandardPhrase1, .copyStandardPhrase2, .copyStandardPhrase3,
            .copyStandardPhrase4, .copyStandardPhrase5, .copyStandardPhrase6,
            .copyStandardPhrase7, .copyStandardPhrase8, .copyStandardPhrase9,
            .copyStandardPhrase10
        ]
    }
    
    static let copyClipboardHistory1 = Self("copyClipboardHistory1", default: .init(.one, modifiers: [.option, .command]))
    static let copyClipboardHistory2 = Self("copyClipboardHistory2", default: .init(.two, modifiers: [.option, .command]))
    static let copyClipboardHistory3 = Self("copyClipboardHistory3", default: .init(.three, modifiers: [.option, .command]))
    static let copyClipboardHistory4 = Self("copyClipboardHistory4", default: .init(.four, modifiers: [.option, .command]))
    static let copyClipboardHistory5 = Self("copyClipboardHistory5", default: .init(.five, modifiers: [.option, .command]))
    static let copyClipboardHistory6 = Self("copyClipboardHistory6", default: .init(.six, modifiers: [.option, .command]))
    static let copyClipboardHistory7 = Self("copyClipboardHistory7", default: .init(.seven, modifiers: [.option, .command]))
    static let copyClipboardHistory8 = Self("copyClipboardHistory8", default: .init(.eight, modifiers: [.option, .command]))
    static let copyClipboardHistory9 = Self("copyClipboardHistory9", default: .init(.nine, modifiers: [.option, .command]))
    static let copyClipboardHistory10 = Self("copyClipboardHistory10", default: .init(.zero, modifiers: [.option, .command]))

    static var allClipboardHistoryCopyShortcuts: [KeyboardShortcuts.Name] {
        return [
            .copyClipboardHistory1, .copyClipboardHistory2, .copyClipboardHistory3,
            .copyClipboardHistory4, .copyClipboardHistory5, .copyClipboardHistory6,
            .copyClipboardHistory7, .copyClipboardHistory8, .copyClipboardHistory9,
            .copyClipboardHistory10
        ]
    }
}
