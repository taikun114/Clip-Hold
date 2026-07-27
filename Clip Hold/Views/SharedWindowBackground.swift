import SwiftUI

struct SharedWindowBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if #available(macOS 27, *) {
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 14.0))
                .ignoresSafeArea()
        } else if #available(macOS 26, *) {
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .overlay(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                .ignoresSafeArea()
        } else {
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}
