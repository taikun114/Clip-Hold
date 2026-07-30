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
                    "Copy standard phrase in \(.applicationName)",
                    "Copy standard phrase from \(\.$preset) in \(.applicationName)"
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
                    "Copy standard phrase by index in \(.applicationName)"
                ],
                shortTitle: "Copy Standard Phrase by Index",
                systemImageName: "text.quote"
            ),
            AppShortcut(
                intent: CopyClipboardItemByIndexIntent(),
                phrases: [
                    "Copy history item by index in \(.applicationName)"
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
            ),
            AppShortcut(
                intent: DeleteStandardPhraseIntent(),
                phrases: [
                    "Delete standard phrase in \(.applicationName)",
                    "Remove standard phrase in \(.applicationName)",
                    "Delete standard phrase from \(\.$preset) in \(.applicationName)",
                    "Remove standard phrase from \(\.$preset) in \(.applicationName)"
                ],
                shortTitle: "Delete Standard Phrase",
                systemImageName: "trash"
            ),
            AppShortcut(
                intent: GetStandardPhraseCountIntent(),
                phrases: [
                    "Get standard phrase count in \(.applicationName)",
                    "Get standard phrase count from \(\.$preset) in \(.applicationName)",
                    "Count standard phrase in \(.applicationName)",
                    "Count standard phrase from \(\.$preset) in \(.applicationName)"
                ],
                shortTitle: "Get Standard Phrase Count",
                systemImageName: "number"
            ),
            AppShortcut(
                intent: GetClipboardItemCountIntent(),
                phrases: [
                    "Get history item count in \(.applicationName)",
                    "Count history item in \(.applicationName)"
                ],
                shortTitle: "Get History Item Count",
                systemImageName: "number"
            )
        ]
    }
}
