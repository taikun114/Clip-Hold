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
                intent: SetClipboardMonitoringStateIntent(),
                phrases: [
                    "Set monitoring state in \(.applicationName)",
                    "Toggle monitoring state in \(.applicationName)"
                ],
                shortTitle: "Set Monitoring State",
                systemImageName: "playpause"
            ),
            AppShortcut(
                intent: SetActivePresetIntent(),
                phrases: [
                    "Set active preset to \(\.$preset) in \(.applicationName)"
                ],
                shortTitle: "Set Active Preset",
                systemImageName: "rectangle.stack"
            ),
            AppShortcut(
                intent: ShowHistoryWindowIntent(),
                phrases: [
                    "Show history window in \(.applicationName)",
                    "Open history window in \(.applicationName)"
                ],
                shortTitle: "Show History Window",
                systemImageName: "clock.arrow.circlepath"
            ),
            AppShortcut(
                intent: ShowStandardPhraseWindowIntent(),
                phrases: [
                    "Show standard phrase window in \(.applicationName)",
                    "Open standard phrase window in \(.applicationName)"
                ],
                shortTitle: "Show Standard Phrase Window",
                systemImageName: "text.quote"
            ),
            AppShortcut(
                intent: SetQuickPasteStateIntent(),
                phrases: [
                    "Set quick paste state in \(.applicationName)",
                    "Toggle quick paste in \(.applicationName)"
                ],
                shortTitle: "Set Quick Paste State",
                systemImageName: "bolt.fill"
            )
        ]
    }
}
