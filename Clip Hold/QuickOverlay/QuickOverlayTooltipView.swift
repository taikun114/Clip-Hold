import SwiftUI

struct QuickOverlayTooltipView: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(text)
            .font(.body)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if #available(macOS 26.0, *) {
                        Color.clear
                            .glassEffect(in: .rect(cornerRadius: 28.0))
                            .environment(\.controlActiveState, .active)
                    } else {
                        Color.clear
                            .background(Material.ultraThin)
                            .environment(\.controlActiveState, .active)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(60) // Provide space for the shadow to render inside the window
    }
}
