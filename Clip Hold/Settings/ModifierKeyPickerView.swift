import SwiftUI
import AppKit

struct ModifierKeyPickerView: View {
    @Binding var modifiers: Int
    
    // NSEvent.ModifierFlags raw values mapping
    private let keys: [(name: String, flag: NSEvent.ModifierFlags)] = [
        ("⌃", .control),
        ("⌥", .option),
        ("⇧", .shift),
        ("⌘", .command)
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(keys, id: \.name) { key in
                let rawVal = Int(key.flag.rawValue)
                let isSelected = (modifiers & rawVal) == rawVal
                
                Button(action: {
                    if isSelected {
                        modifiers &= ~rawVal
                    } else {
                        modifiers |= rawVal
                    }
                }) {
                    Text(key.name)
                        .font(.system(size: 14, weight: .regular))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}
