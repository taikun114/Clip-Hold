import SwiftUI

struct MacOS27TitleAndIconModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 27, *) {
            content.labelStyle(.titleAndIcon)
        } else {
            content
        }
    }
}

extension View {
    /// macOS 27以降でのみ、Labelに.labelStyle(.titleAndIcon)を適用し、
    /// ピッカーやメニュー内でも強制的にアイコンを表示させるモディファイア
    func forceIconOnMacOS27() -> some View {
        self.modifier(MacOS27TitleAndIconModifier())
    }

    /// アダプティブスクロールエッジエフェクト
    @ViewBuilder
    func adaptiveScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
    
    /// macOS 26以降でのみ、ボタンやピッカーのサイズを横に広げるモディファイア
    @ViewBuilder
    func flexiblePickerSizing() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonSizing(.flexible)
        } else {
            self
        }
    }
}

import KeyboardShortcuts

// MARK: - KeyboardShortcuts SwiftUI Support
struct DynamicKeyboardShortcutModifier: ViewModifier {
    let name: KeyboardShortcuts.Name
    @State private var shortcut: KeyboardShortcuts.Shortcut?
    
    init(name: KeyboardShortcuts.Name) {
        self.name = name
        self._shortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: name))
    }
    
    func body(content: Content) -> some View {
        Group {
            if let shortcut = shortcut, let char = shortcut.keyEquivalentChar {
                content.keyboardShortcut(KeyEquivalent(char), modifiers: shortcut.swiftUIModifiers)
            } else {
                content
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let latest = KeyboardShortcuts.getShortcut(for: name)
            if self.shortcut != latest {
                self.shortcut = latest
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KeyboardShortcutsShortcutByNameDidChange"))) { _ in
            let latest = KeyboardShortcuts.getShortcut(for: name)
            if self.shortcut != latest {
                self.shortcut = latest
            }
        }
        .onAppear {
            let latest = KeyboardShortcuts.getShortcut(for: name)
            if self.shortcut != latest {
                self.shortcut = latest
            }
        }
    }
}

extension View {
    @ViewBuilder
    func applyKeyboardShortcut(for name: KeyboardShortcuts.Name?) -> some View {
        if let name = name {
            self.modifier(DynamicKeyboardShortcutModifier(name: name))
        } else {
            self
        }
    }
}

extension KeyboardShortcuts.Shortcut {
    @MainActor
    var keyEquivalentChar: Character? {
        let desc = self.description
        let symbols: Set<Character> = ["⌘", "⌥", "⇧", "⌃", "🌐", "^"]
        let filtered = desc.filter { !symbols.contains($0) }
        return filtered.lowercased().first
    }

    var swiftUIModifiers: SwiftUI.EventModifiers {
        var modifiers: SwiftUI.EventModifiers = []
        let carbonFlags = self.carbonModifiers
        
        if (carbonFlags & 0x0100) != 0 { modifiers.insert(.command) } // cmdKey
        if (carbonFlags & 0x0800) != 0 { modifiers.insert(.option) }  // optionKey
        if (carbonFlags & 0x1000) != 0 { modifiers.insert(.control) } // controlKey
        if (carbonFlags & 0x0200) != 0 { modifiers.insert(.shift) }   // shiftKey
        if (carbonFlags & 0x0400) != 0 { modifiers.insert(.capsLock) } // alphaLock / capsLock
        
        return modifiers
    }
}
