import SwiftUI
import QuickLookThumbnailing

struct QuickOverlayTooltipView: View {
    let text: String
    let maxVisualHeight: CGFloat
    let sourceAppPath: String?
    let filePath: String?
    let fileSize: UInt64?
    
    @State private var offset: CGFloat = 0
    @State private var textHeight: CGFloat = 0
    @State private var hasStartedMarquee = false
    @State private var marqueeStartTask: Task<Void, Never>?
    @State private var thumbnailImage: NSImage?
    
    var body: some View {
        Group {
            if let filePath {
                fileTooltip(filePath: filePath)
            } else {
                textTooltip
            }
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
        .padding(60)
        .onAppear {
            if let filePath {
                loadThumbnail(for: filePath)
            }
            if filePath == nil {
                marqueeStartTask?.cancel()
                marqueeStartTask = Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(100))
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }
                    startMarquee()
                }
            }
        }
        .onDisappear {
            marqueeStartTask?.cancel()
            marqueeStartTask = nil
        }
    }

    private var textTooltip: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sourceAppPath,
               let appURL = URL(fileURLWithPath: sourceAppPath) as URL?,
               FileManager.default.fileExists(atPath: appURL.path) {
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(FileManager.default.displayName(atPath: appURL.path))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

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
                .frame(height: maxVisualHeight - (sourceAppPath == nil ? 0 : 28), alignment: .top)
                .clipped()
        }
    }

    private func fileTooltip(filePath: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sourceAppPath,
               let appURL = URL(fileURLWithPath: sourceAppPath) as URL?,
               FileManager.default.fileExists(atPath: appURL.path) {
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(FileManager.default.displayName(atPath: appURL.path))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let thumbnailImage {
                        Image(nsImage: thumbnailImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: filePath))
                            .resizable()
                            .scaledToFit()
                            .padding(32)
                    }
                }
                .frame(width: 256, height: 256)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(FileManager.default.displayName(atPath: filePath))
                        .font(.body)
                        .lineLimit(6)
                    if let fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }

    private func loadThumbnail(for filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 256, height: 256), scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .all)
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, _ in
            guard let thumbnail else { return }
            DispatchQueue.main.async {
                thumbnailImage = thumbnail.nsImage
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
