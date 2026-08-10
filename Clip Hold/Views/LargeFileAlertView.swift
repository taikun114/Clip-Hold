import SwiftUI

struct LargeFileAlertView: View {
    let title: String
    let message: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
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
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(colorScheme == .dark && !isMacOS26OrNewer ? .white : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                
                Text(message)
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
                if isMacOS26OrNewer {
                    Button(action: onCancel) {
                        Text(NSLocalizedString("いいえ", comment: ""))
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                    
                    Button(action: onSave) {
                        Text(NSLocalizedString("はい", comment: ""))
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(action: onCancel) {
                        Text(NSLocalizedString("いいえ", comment: ""))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LegacyAlertButtonStyle(isProminent: false))
                    .keyboardShortcut(.cancelAction)
                    
                    Button(action: onSave) {
                        Text(NSLocalizedString("はい", comment: ""))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LegacyAlertButtonStyle(isProminent: true))
                    .keyboardShortcut(.defaultAction)
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
        title: "大容量ファイルのコピー",
        message: "100 MBを超えるファイル（124.6 MB）がコピーされました。履歴に保存してもよろしいですか？",
        onSave: {},
        onCancel: {}
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
