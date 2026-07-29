import Foundation
import AppIntents

@available(macOS 14.0, *)
struct ClipHoldAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .navy }
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: CopyStandardPhraseIntent(),
                phrases: [
                    "Copy standard phrase in \(.applicationName)"
                ],
                shortTitle: "Copy Standard Phrase",
                systemImageName: "text.quote"
            ),
            AppShortcut(
                intent: CopyClipboardItemIntent(),
                phrases: [
                    "Copy history item in \(.applicationName)",
                    "Copy history in \(.applicationName)"
                ],
                shortTitle: "Copy History Item",
                systemImageName: "doc.on.doc"
            ),
            AppShortcut(
                intent: CopyStandardPhraseByIndexIntent(),
                phrases: [
                    "Copy standard phrase by index in \(.applicationName)",
                    "Copy \(\.$index) standard phrase in \(.applicationName)"
                ],
                shortTitle: "Copy Standard Phrase by Index",
                systemImageName: "text.quote"
            ),
            AppShortcut(
                intent: CopyClipboardItemByIndexIntent(),
                phrases: [
                    "Copy history item by index in \(.applicationName)",
                    "Copy \(\.$index) history item in \(.applicationName)",
                    "Copy \(\.$index) history in \(.applicationName)"
                ],
                shortTitle: "Copy History Item by Index",
                systemImageName: "doc.on.doc"
            ),
            AppShortcut(
                intent: AddStandardPhraseIntent(),
                phrases: [
                    "Add standard phrase in \(.applicationName)",
                    "Add new standard phrase in \(.applicationName)",
                    "Create standard phrase in \(.applicationName)",
                    "Create new standard phrase in \(.applicationName)",
                    "Add standard phrase to \(\.$preset) in \(.applicationName)",
                    "Add new standard phrase to \(\.$preset) in \(.applicationName)",
                    "Create standard phrase in \(\.$preset) in \(.applicationName)",
                    "Create new standard phrase in \(\.$preset) in \(.applicationName)"
                ],
                shortTitle: "Add Standard Phrase",
                systemImageName: "plus.rectangle.on.rectangle"
            )
        ]
    }
}
