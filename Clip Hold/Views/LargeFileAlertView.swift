import SwiftUI

struct LargeFileAlertButton: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
    let isProminent: Bool
    let keyboardShortcut: KeyboardShortcut?
    
    init(title: String, isProminent: Bool = false, keyboardShortcut: KeyboardShortcut? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isProminent = isProminent
        self.keyboardShortcut = keyboardShortcut
        self.action = action
    }
}

class LargeFileAlertViewModel: ObservableObject {
    @Published var title: String
    @Published var message: String
    @Published var buttons: [LargeFileAlertButton]
    
    init(title: String, message: String, buttons: [LargeFileAlertButton]) {
        self.title = title
        self.message = message
        self.buttons = buttons
    }
}

struct LargeFileAlertView: View {
    @ObservedObject var viewModel: LargeFileAlertViewModel
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.controlActiveState) var controlActiveState
    
    var body: some View {
        let isMacOS26OrNewer: Bool = {
            if #available(macOS 26.0, *) {
                return true
            }
            return false
        }()
        
        let cornerRadius: CGFloat = isMacOS26OrNewer ? 28 : 12
        
        VStack(alignment: isMacOS26OrNewer ? .leading : .center, spacing: 12) {
            // Icon
            let iconName: String = {
                if #available(macOS 15.0, *) {
                    return "document.on.clipboard.fill"
                } else {
                    return "doc.on.clipboard.fill"
                }
            }()
            
            // Title and Message
            VStack(alignment: isMacOS26OrNewer ? .leading : .center, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                    )
                    .padding(isMacOS26OrNewer ? 0 : 4)
                    .padding(.bottom, 4)
                
                Text(viewModel.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(colorScheme == .dark && !isMacOS26OrNewer ? .white : .primary)
                    .multilineTextAlignment(isMacOS26OrNewer ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                
                Text(viewModel.message)
                    .font(isMacOS26OrNewer ? .body : .callout)
                    .foregroundStyle(colorScheme == .dark && !isMacOS26OrNewer ? .white : .primary)
                    .multilineTextAlignment(isMacOS26OrNewer ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            
            // Buttons
            HStack(spacing: 8) {
                ForEach(viewModel.buttons) { button in
                    if isMacOS26OrNewer {
                        if button.isProminent {
                            Button(action: button.action) {
                                Text(button.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(button.keyboardShortcut)
                        } else {
                            Button(action: button.action) {
                                Text(button.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                            .keyboardShortcut(button.keyboardShortcut)
                        }
                    } else {
                        Button(action: button.action) {
                            Text(button.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LegacyAlertButtonStyle(isProminent: button.isProminent))
                        .keyboardShortcut(button.keyboardShortcut)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 260)
        .background(
            Group {
                if #available(macOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: 28.0))
                        .environment(\.controlActiveState, .active)
                } else {
                    Color.clear
                        .background(Material.regularMaterial)
                        .environment(\.controlActiveState, .active)
                }
            }
            .overlay(WindowDragView())
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // 下地: 明るいボーダー (lineWidth: 2 で 0pt〜2ptの範囲に描画)
        .overlay(
            Group {
                if colorScheme == .dark && isMacOS26OrNewer {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        .blendMode(.overlay)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.3), lineWidth: 2)
                        .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                }
            }
        )
        // 上乗せ: 暗いボーダー (lineWidth: 1 で 0pt〜1ptの範囲を上書き)
        // 結果: 最外周の1pt(非Retinaで1px)が黒、その内側の1pt(非Retinaで1px)が明るいハイライトとして残る
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(colorScheme == .dark ? Color.black : Color.black.opacity(isMacOS26OrNewer ? 0.25 : 0.3), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(controlActiveState != .inactive ? 0.4 : 0.2),
            radius: controlActiveState != .inactive ? 16 : 12,
            x: 0,
            y: controlActiveState != .inactive ? 16 : 12
        )
        .padding(60) // Shadow padding
    }
}

#Preview {
    LargeFileAlertView(
        viewModel: LargeFileAlertViewModel(
            title: "大容量ファイルのコピー",
            message: "100 MBを超えるファイル（124.6 MB）がコピーされました。履歴に保存してもよろしいですか？",
            buttons: [
                LargeFileAlertButton(title: "いいえ", action: {}),
                LargeFileAlertButton(title: "はい", isProminent: true, action: {})
            ]
        )
    )
}

struct LegacyAlertButtonStyle: ButtonStyle {
    var isProminent: Bool
    @Environment(\.controlActiveState) var controlActiveState
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        let isActive = (controlActiveState != .inactive)
        let showProminent = isProminent && isActive
        
        let fgColor: Color = showProminent ? .white : .primary
        
        let topGradientColor = colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.15)
        let bottomGradientColor = colorScheme == .dark ? Color.black.opacity(0.15) : Color.clear
        let nonProminentOpacity = colorScheme == .dark 
            ? (configuration.isPressed ? 0.55 : 0.35)
            : (configuration.isPressed ? 0.3 : 0.15)
        
        configuration.label
            .padding(.vertical, 6)
            .background(
                Group {
                    if showProminent {
                        Color.accentColor
                            .overlay(
                                LinearGradient(
                                    colors: [topGradientColor, bottomGradientColor],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                configuration.isPressed 
                                    ? (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                                    : Color.clear
                            )
                    } else {
                        if colorScheme == .dark {
                            Color.clear
                                .background(Material.ultraThinMaterial)
                                .environment(\.controlActiveState, .active)
                                .saturation(2)
                                .overlay(Color.primary.opacity(nonProminentOpacity))
                        } else {
                            Color.primary.opacity(nonProminentOpacity)
                        }
                    }
                }
            )
            .foregroundStyle(fgColor)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// カスタムドラッグ実装用のビュー
struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return DraggingView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DraggingView: NSView {
    private var initialMouse: NSPoint?
    private var initialOrigin: NSPoint?
    
    // 背景クリックを透過させず、ドラッグ用に拾う
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        initialMouse = NSEvent.mouseLocation
        initialOrigin = window.frame.origin
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window,
              let initialMouse = initialMouse,
              let initialOrigin = initialOrigin,
              let panel = window as? NSPanel else { return }
        
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - initialMouse.x
        let deltaY = currentMouse.y - initialMouse.y
        
        var newRect = NSRect(origin: NSPoint(x: initialOrigin.x + deltaX, y: initialOrigin.y + deltaY), size: window.frame.size)
        
        // 制約を適用（画面上端まで移動許可）
        newRect = panel.constrainFrameRect(newRect, to: window.screen)
        
        window.setFrameOrigin(newRect.origin)
    }
    
    override func mouseUp(with event: NSEvent) {
        initialMouse = nil
        initialOrigin = nil
    }
}
