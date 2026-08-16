import SwiftUI
import QuickLookThumbnailing

struct ClipboardItemIconView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @ObservedObject var item: ClipboardItem
    let showColorCodeIcon: Bool
    var rowIconStore: RowIconStore? = nil
    var isSelected: Bool = false
    
    // アイコンのNSViewへの参照を親に渡すためのヘルパー (Local to this file now if needed, or we can keep it in HistoryItemRow and inject it. Actually better to just recreate it here if needed)
    
    var body: some View {
        // カラーコードアイコンの表示条件をチェック
        if showColorCodeIcon, item.filePath == nil, let color = ColorCodeParser.parseColor(from: item.text) {
            // カラーコードが解析できた場合、専用のカラーアイコンを表示
            let baseIconView = ColorCodeIconView(color: color)
            
            // カラーアイコンにもアプリアイコンを表示する
            if let sourceAppPath = item.sourceAppPath {
                let appName = clipboardManager.getLocalizedName(for: sourceAppPath) ?? "Unknown App"
                baseIconView
                    .overlay(
                        appIconOverlay(for: sourceAppPath),
                        alignment: .bottomLeading
                    )
                    .modifier(IconAccessorModifier(id: item.id, store: rowIconStore))
                    .help(appName)
            } else {
                baseIconView
                    .modifier(IconAccessorModifier(id: item.id, store: rowIconStore))
            }
        } else {
            // 既存のアイコン
            let baseIconView = generateBaseIcon()
            
            // アプリアイコンをオーバーレイ表示
            if let sourceAppPath = item.sourceAppPath {
                let appName = clipboardManager.getLocalizedName(for: sourceAppPath) ?? "Unknown App"
                baseIconView
                    .overlay(
                        appIconOverlay(for: sourceAppPath),
                        alignment: .bottomLeading
                    )
                    .modifier(IconAccessorModifier(id: item.id, store: rowIconStore))
                    .help(appName)
            } else {
                baseIconView
                    .modifier(IconAccessorModifier(id: item.id, store: rowIconStore))
            }
        }
    }
    
    @ViewBuilder
    private func generateBaseIcon() -> some View {
        if item.isURL {
            Image(systemName: "paperclip")
                .resizable()
                .scaledToFit()
                .padding(4)
                .foregroundStyle(isSelected ? .white : .secondary)
        } else if let cachedIcon = item.cachedThumbnailImage {
            Image(nsImage: cachedIcon)
                .resizable()
                .scaledToFit()
        } else if let filePath = item.filePath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: filePath.path))
                .resizable()
                .scaledToFit()
                .task(id: item.id) {
                    if item.cachedThumbnailImage == nil && (item.isImage || item.isPDF) {
                        await generateThumbnailAsync(for: filePath)
                    }
                }
        } else {
            if item.richText != nil {
                if #available(macOS 15.0, *) {
                    Image(systemName: "richtext.page")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isSelected ? .white : .secondary)
                } else {
                    Image(systemName: "doc.richtext")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
            } else {
                if #available(macOS 15.0, *) {
                    Image(systemName: "text.page")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isSelected ? .white : .secondary)
                } else {
                    Image(systemName: "doc.plaintext")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func appIconOverlay(for sourceAppPath: String) -> some View {
        Group {
            if FileManager.default.fileExists(atPath: sourceAppPath) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: sourceAppPath))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            } else {
                Image(systemName: "questionmark.app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .fontWeight(.bold)
            }
        }
        .alignmentGuide(.leading) { _ in 4 }
        .alignmentGuide(.top) { _ in 22.5 }
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
    
    private func generateThumbnailAsync(for fileURL: URL) async {
        guard item.cachedThumbnailImage == nil else { return }
        
        let thumbnailSize = CGSize(width: 40, height: 40)
        let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: thumbnailSize, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
        
        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let paddedImage = clipboardManager.padToSquare(thumbnail.nsImage, size: thumbnailSize)
            await MainActor.run {
                item.cachedThumbnailImage = paddedImage
            }
        } catch {
            if item.isImage {
                // Task.detachedでバックグラウンド実行し、I/Oブロックを避ける
                let imageResult = await Task.detached { () -> NSImage? in
                    if let image = NSImage(contentsOf: fileURL) {
                        return image
                    }
                    return nil
                }.value
                
                if let image = imageResult {
                    let paddedImage = clipboardManager.padToSquare(image, size: thumbnailSize)
                    await MainActor.run {
                        item.cachedThumbnailImage = paddedImage
                    }
                }
            }
        }
    }
}

private struct IconAccessorModifier: ViewModifier {
    let id: UUID
    let store: RowIconStore?
    
    func body(content: Content) -> some View {
        if let store = store {
            content.background(IconViewAccessor(id: id, store: store))
        } else {
            content
        }
    }
}

private struct IconViewAccessor: NSViewRepresentable {
    let id: UUID
    let store: RowIconStore
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            self.store.views[id] = view
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
