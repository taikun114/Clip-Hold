import SwiftUI

struct HistoryWindowBackground: View {
    var body: some View {
        if #available(macOS 26, *) {
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .ignoresSafeArea()
        } else {
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}
