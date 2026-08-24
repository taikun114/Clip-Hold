import SwiftUI
import QuickLookThumbnailing

struct QuickOverlayTooltipView: View {
    let text: String
    let maxVisualHeight: CGFloat
    let calculatedTextHeight: CGFloat
    let sourceAppPath: String?
    let filePath: String?
    let fileSize: UInt64?
    let dateString: String?
    let characterCount: Int?
    let isCompact: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showInvisibleCharacters") var showInvisibleCharacters: Bool = false
    @State private var offset: CGFloat = 0
    @State private var hasStartedMarquee = false
    @State private var marqueeStartTask: Task<Void, Never>?
    @State private var spinnerDelayTask: Task<Void, Never>?
    @State private var thumbnailImage: NSImage?
    @State private var isThumbnailLoaded = false
    @State private var showSpinner = false
    
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
        .shadow(color: Color.black.opacity(0.3), radius: isCompact ? 8 : 20, x: 0, y: isCompact ? 4 : 10)
        .padding(isCompact ? 20 : 60)
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
            spinnerDelayTask?.cancel()
            spinnerDelayTask = nil
        }
    }

    @ViewBuilder
    private var appHeaderView: some View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isCode: Bool {
        filePath == nil && CodeDetector.isCode(text)
    }
    
    private var detectedLanguage: CodeLanguage? {
        isCode ? CodeDetector.detectLanguage(text) : nil
    }
    
    private var hasHeader: Bool {
        sourceAppPath != nil
    }
    
    private var hasFooter: Bool {
        dateString != nil || characterCount != nil || detectedLanguage != nil
    }

    private var textTooltip: some View {
        VStack(alignment: .leading, spacing: 16) {
            appHeaderView
            textBody
            if hasFooter {
                metadataFooterView
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var metadataFooterView: some View {
        if hasFooter {
            HStack {
                if let dateString {
                    Text(dateString)
                        .lineLimit(1)
                }
                Spacer()
                if let detectedLanguage, let characterCount {
                    (Text(verbatim: "\(detectedLanguage.localizedName) - ") + Text("\(characterCount)文字"))
                        .lineLimit(1)
                } else if let detectedLanguage {
                    Text(detectedLanguage.localizedName)
                        .lineLimit(1)
                } else if let characterCount {
                    Text("\(characterCount)文字")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var textBody: some View {
        let spacingCount: CGFloat = (hasHeader ? 1 : 0) + (hasFooter ? 1 : 0)
        let spacingH: CGFloat = spacingCount * 16
        let headerH: CGFloat = hasHeader ? 20 : 0
        let footerH: CGFloat = hasFooter ? 14 : 0
        let contentPaddingH: CGFloat = 32
        let visibleHeight = maxVisualHeight - contentPaddingH - headerH - footerH - spacingH

        let displayText: Text = {
            if showInvisibleCharacters {
                return Text(text.formatWithInvisibleSymbols(singleLine: false))
            } else if isCode {
                let highlighted = CodeHighlighter.shared.highlight(text, as: detectedLanguage?.highlighterLanguageName, isDark: colorScheme == .dark)
                return Text(highlighted)
            } else {
                return Text(text)
            }
        }()

        return displayText
            .font(isCode ? .system(.body, design: .monospaced) : .body)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: offset)
            .frame(height: max(visibleHeight, 20), alignment: .top)
            .clipped()
    }

    private func fileTooltip(filePath: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            appHeaderView
            fileBody(filePath: filePath)
            if dateString != nil || characterCount != nil {
                metadataFooterView
            }
        }
        .padding(16)
    }

    private func fileBody(filePath: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                if let thumbnailImage {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .scaledToFit()
                        .transition(.opacity)
                } else if isThumbnailLoaded {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: filePath))
                        .resizable()
                        .scaledToFit()
                        .padding(32)
                        .transition(.opacity)
                } else if showSpinner {
                    ProgressView()
                        .controlSize(.regular)
                        .transition(.opacity)
                } else {
                    Color.clear
                }
            }
            .frame(width: 256, height: 256)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.easeInOut(duration: 0.25), value: thumbnailImage)
            .animation(.easeInOut(duration: 0.25), value: isThumbnailLoaded)
            .animation(.easeInOut(duration: 0.25), value: showSpinner)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
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
    }

    private func loadThumbnail(for filePath: String) {
        spinnerDelayTask?.cancel()
        spinnerDelayTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            guard !Task.isCancelled, !isThumbnailLoaded else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showSpinner = true
            }
        }
        
        let url = URL(fileURLWithPath: filePath)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 256, height: 256), scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            DispatchQueue.main.async {
                self.spinnerDelayTask?.cancel()
                self.spinnerDelayTask = nil
                withAnimation(.easeInOut(duration: 0.25)) {
                    if let thumbnail {
                        self.thumbnailImage = thumbnail.nsImage
                    }
                    self.isThumbnailLoaded = true
                    self.showSpinner = false
                }
            }
        }
    }
    
    private func startMarquee() {
        guard !hasStartedMarquee else { return }
        
        let spacingCount: CGFloat = (hasHeader ? 1 : 0) + (hasFooter ? 1 : 0)
        let spacingH: CGFloat = spacingCount * 16
        let headerH: CGFloat = hasHeader ? 20 : 0
        let footerH: CGFloat = hasFooter ? 14 : 0
        let contentPaddingH: CGFloat = 32
        let visibleHeight = maxVisualHeight - contentPaddingH - headerH - footerH - spacingH

        guard calculatedTextHeight > visibleHeight else { return }
        hasStartedMarquee = true
        
        let diff = calculatedTextHeight - visibleHeight
        // スクロール速度の計算（1秒間に約30pt進む程度の速度）
        let duration = Double(diff) / 30.0
        
        offset = 0
        withAnimation(.linear(duration: duration).delay(1.5).repeatForever(autoreverses: true)) {
            offset = -diff
        }
    }
}
