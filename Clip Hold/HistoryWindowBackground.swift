import SwiftUI

struct HistoryWindowBackground: View {
    var body: some View {
        VisualEffectView(material: .menu, blendingMode: .behindWindow)
            .ignoresSafeArea()
    }
}
