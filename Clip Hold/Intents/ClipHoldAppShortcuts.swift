import Foundation
import AppIntents

@available(macOS 14.0, *)
struct ClipHoldAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: CopyStandardPhraseIntent(),
                phrases: [
                    "Copy standard phrase in \(.applicationName)",
                    "\(.applicationName)で定型文をコピー"
                ],
                shortTitle: "Copy Standard Phrase",
                systemImageName: "text.quote"
            ),
            AppShortcut(
                intent: CopyClipboardItemIntent(),
                phrases: [
                    "Copy history item in \(.applicationName)",
                    "\(.applicationName)で履歴項目をコピー"
                ],
                shortTitle: "Copy History Item",
                systemImageName: "doc.on.doc"
            ),
            AppShortcut(
                intent: CopyStandardPhraseByIndexIntent(),
                phrases: [
                    "Copy standard phrase by index in \(.applicationName)",
                    "\(.applicationName)で番号を指定して定型文をコピー"
                ],
                shortTitle: "Copy Standard Phrase by Index",
                systemImageName: "text.quote"
            ),
            AppShortcut(
                intent: CopyClipboardItemByIndexIntent(),
                phrases: [
                    "Copy history item by index in \(.applicationName)",
                    "\(.applicationName)で番号を指定して履歴項目をコピー"
                ],
                shortTitle: "Copy History Item by Index",
                systemImageName: "doc.on.doc"
            )
        ]
    }
}
