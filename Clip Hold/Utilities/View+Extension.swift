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
}
