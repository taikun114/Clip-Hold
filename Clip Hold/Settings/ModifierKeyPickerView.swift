import SwiftUI
import AppKit

struct ModifierKeyPickerView: View {
    @Binding var modifiers: Int
    
    // NSEvent.ModifierFlags raw values mapping
    private let keys: [(name: String, help: String, flag: NSEvent.ModifierFlags)] = [
        ("⌃", String(localized: "Controlキー"), .control),
        ("⌥", String(localized: "Optionキー"), .option),
        ("⇧", String(localized: "Shiftキー"), .shift),
        ("⌘", String(localized: "Commandキー"), .command)
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(keys, id: \.name) { key in
                let rawVal = Int(key.flag.rawValue)
                let isSelected = (modifiers & rawVal) == rawVal
                
                if isSelected {
                    Button(action: {
                        modifiers &= ~rawVal
                    }) {
                        Text(key.name)
                            .font(.system(size: 14, weight: .regular))
                    }
                    .frame(width: 32, height: 24)
                    .buttonStyle(.borderedProminent)
                    .environment(\.controlActiveState, .active)
                    .help(key.help)
                } else {
                    Button(action: {
                        modifiers |= rawVal
                    }) {
                        Text(key.name)
                            .font(.system(size: 14, weight: .regular))
                    }
                    .frame(width: 32, height: 24)
                    .buttonStyle(.bordered)
                    .help(key.help)
                }
            }
        }
    }
}
