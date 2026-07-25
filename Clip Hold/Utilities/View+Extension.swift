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
        if #available(macOS 27.0, *) {
            self.scrollEdgeEffectStyle(.hard, for: .all)
        } else if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
