import SwiftUI

struct QuickOverlayTooltipView: View {
    let text: String
    let maxVisualHeight: CGFloat
    
    @State private var offset: CGFloat = 0
    @State private var textHeight: CGFloat = 0
    @State private var hasStartedMarquee = false
    
    var body: some View {
        Group {
            Text(text)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear {
                            textHeight = textGeo.size.height
                        }
                        .onChange(of: textGeo.size.height) { _, new in
                            textHeight = new
                        }
                    }
                )
                .offset(y: offset)
                .frame(height: maxVisualHeight, alignment: .top)
                .clipped()
        }
        .background(
            Group {
                if #available(macOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: 28.0))
                        .saturation(1.5)
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
        .onAppear {
            // レイアウトが安定するのを待ってからマーキーを開始する
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                startMarquee()
            }
        }
    }
    
    private func startMarquee() {
        guard !hasStartedMarquee else { return }
        guard textHeight > maxVisualHeight else { return }
        hasStartedMarquee = true
        
        let diff = textHeight - maxVisualHeight
        // スクロール速度の計算（1秒間に約30pt進む程度の速度）
        let duration = Double(diff) / 30.0
        
        offset = 0
        withAnimation(.linear(duration: duration).delay(1.5).repeatForever(autoreverses: true)) {
            offset = -diff
        }
    }
}
