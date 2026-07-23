import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers
import Quartz
import QuickLookThumbnailing

class RowIconStore {
    var views: [UUID: NSView] = [:]
}

// アイコンのNSViewへの参照を親に渡すためのヘルパー
private struct IconViewAccessor: NSViewRepresentable {
    let id: UUID
    let store: RowIconStore
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.store.views[id] = view
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private let itemDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

// バイト数を読みやすい文字列に変換するヘルパー関数
private func formatFileSize(_ byteCount: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(byteCount))
}

// MARK: - HistoryItemRow
struct HistoryItemRow<MenuContent: View>: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    
    let item: ClipboardItem
    let index: Int
    let hideNumbers: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    
    // アイコンビューの参照を格納するクラス
    let rowIconStore: RowIconStore
    
    let showCharacterCount: Bool
    @EnvironmentObject var dateReloader: DateReloader
    @AppStorage("dateDisplayFormatInHistoryWindow") var dateDisplayFormatInHistoryWindow: String = "absolute"
    @AppStorage("showAppIconOverlay") var showAppIconOverlay: Bool = true
    
    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat
    
    @State private var iconLoadTask: Task<Void, Never>?
    
    @ViewBuilder let menuItems: () -> MenuContent
    
    init(item: ClipboardItem,
         index: Int,
         hideNumbers: Bool,
         rowIconStore: RowIconStore,
         showCharacterCount: Bool,
         lineNumberTextWidth: CGFloat?,
         trailingPaddingForLineNumber: CGFloat,
         @ViewBuilder menuItems: @escaping () -> MenuContent) {
        
        self.item = item
        self.index = index
        self.hideNumbers = hideNumbers
        self.lineNumberTextWidth = lineNumberTextWidth
        self.trailingPaddingForLineNumber = trailingPaddingForLineNumber
        self.rowIconStore = rowIconStore
        self.showCharacterCount = showCharacterCount
        self.menuItems = menuItems
    }
    
    private var itemDisplayText: Text {
        if item.text == "Image File" {
            return Text("Image File")
        } else if item.text == "PDF File" {
            return Text("PDF File")
        } else {
            return Text(verbatim: item.text)
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if !hideNumbers {
                if item.originalPinnedItemID != nil {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: lineNumberTextWidth, alignment: .trailing)
                        .padding(.trailing, trailingPaddingForLineNumber)
                } else {
                    let hasPinnedHeader = (clipboardManager.filteredHistoryForShortcuts?.first?.originalPinnedItemID != nil)
                    let displayNumber = hasPinnedHeader ? index : (index + 1)
                    Text("\(displayNumber).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: lineNumberTextWidth, alignment: .trailing)
                        .padding(.trailing, trailingPaddingForLineNumber)
                }
            }
            
            // アイコン部分 (アプリアイコンをオーバーレイ表示するかどうかで分岐)
            let iconView: some View = {
                // カラーコードアイコンの表示条件をチェック
                if showColorCodeIcon, item.filePath == nil, let color = ColorCodeParser.parseColor(from: item.text) {
                    // カラーコードが解析できた場合、専用のカラーアイコンを表示
                    let baseIconView = ColorCodeIconView(color: color)
                    
                    // カラーアイコンにもアプリアイコンを表示する (showAppIconOverlayがtrueの場合のみ)
                    if showAppIconOverlay, let sourceAppPath = item.sourceAppPath {
                        let appName = clipboardManager.getLocalizedName(for: sourceAppPath) ?? "Unknown App"
                        return AnyView(
                            baseIconView
                                .overlay(
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
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1),
                                    alignment: .bottomLeading
                                )
                                .background(IconViewAccessor(id: item.id, store: rowIconStore))
                                .help(appName) // ツールチップを追加
                        )
                    } else {
                        return AnyView(baseIconView.background(IconViewAccessor(id: item.id, store: rowIconStore)))
                    }
                } else {
                    // 既存のアイコン
                    let baseIconView: some View = {
                        if item.isURL { // URLの場合
                            return AnyView(Image(systemName: "paperclip")
                                .resizable()
                                .scaledToFit()
                                .padding(4)
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.secondary))
                        } else if let cachedIcon = item.cachedThumbnailImage {
                            return AnyView(Image(nsImage: cachedIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30))
                        } else if let filePath = item.filePath {
                            return AnyView(Image(nsImage: NSWorkspace.shared.icon(forFile: filePath.path))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30))
                        } else {
                            // テキストアイコン (リッチテキストかどうかで分岐)
                            if item.richText != nil {
                                // リッチテキストの場合、richtext.pageアイコンを使用 (macOSバージョンによる分岐)
                                if #available(macOS 15.0, *) {
                                    return AnyView(Image(systemName: "richtext.page")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(4)
                                        .frame(width: 30, height: 30)
                                        .foregroundStyle(.secondary))
                                } else {
                                    return AnyView(Image(systemName: "doc.richtext")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(4)
                                        .frame(width: 30, height: 30)
                                        .foregroundStyle(.secondary))
                                }
                            } else {
                                // 標準テキストの場合、text.pageアイコンを使用 (macOSバージョンによる分岐)
                                if #available(macOS 15.0, *) {
                                    return AnyView(Image(systemName: "text.page")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(4)
                                        .frame(width: 30, height: 30)
                                        .foregroundStyle(.secondary))
                                } else {
                                    return AnyView(Image(systemName: "doc.plaintext")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(4)
                                        .frame(width: 30, height: 30)
                                        .foregroundStyle(.secondary))
                                }
                            }
                        }
                    }()
                    
                    // アプリアイコンをオーバーレイ表示 (showAppIconOverlayがtrueの場合のみ)
                    if showAppIconOverlay, let sourceAppPath = item.sourceAppPath {
                        let appName = clipboardManager.getLocalizedName(for: sourceAppPath) ?? "Unknown App"
                        return AnyView(
                            baseIconView
                                .overlay(
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
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1),
                                    alignment: .bottomLeading
                                )
                                .background(IconViewAccessor(id: item.id, store: rowIconStore))
                                .help(appName) // ツールチップを追加
                        )
                    } else {
                        return AnyView(baseIconView.background(IconViewAccessor(id: item.id, store: rowIconStore)))
                    }
                }
            }()
            
            // アイコンにIconViewAccessorを適用して、NSViewの参照を保存する
            iconView
                .onDrag {
                    if let filePath = item.filePath {
                        return NSItemProvider(object: filePath as NSURL)
                    } else {
                        return NSItemProvider(object: item.text as NSString)
                    }
                }
                .contentShape(Rectangle())
            
            VStack(alignment: .leading) {
                itemDisplayText
                    .lineLimit(1)
                    .font(.body)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text(item.date.formatted(for: dateDisplayFormatInHistoryWindow, currentDate: dateReloader.now))
                    
                    if showCharacterCount {
                        Text("-")
                        Text("\(item.text.count)文字")
                    }
                    
                    if let fileSize = item.fileSize, item.filePath != nil, !item.isFolder {
                        Text("-")
                        Text(formatFileSize(fileSize))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .help(item.text) // コンテンツテキスト部分にツールチップを追加
            
            Spacer()
            
            Menu {
                menuItems()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundStyle(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .padding(.leading, 2)

        .onAppear {
            if item.cachedThumbnailImage == nil, let filePath = item.filePath {
                iconLoadTask?.cancel() // 既存のタスクをキャンセル
                
                iconLoadTask = Task {
                    let thumbnailSize = CGSize(width: 60, height: 60)
                    let request = QLThumbnailGenerator.Request(fileAt: filePath, size: thumbnailSize, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
                    
                    do {
                        let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                        await MainActor.run {
                            item.cachedThumbnailImage = thumbnail.nsImage // item の cachedThumbnailImage を更新
                        }
                    } catch {
                        print("Failed to generate thumbnail for \(filePath.lastPathComponent): \(error.localizedDescription)")
                        // エラー時はデフォルトのファイルアイコンをセット
                        await MainActor.run {
                            item.cachedThumbnailImage = NSWorkspace.shared.icon(forFile: filePath.path)
                        }
                    }
                }
            }
        }
        .onDisappear {
            iconLoadTask?.cancel()
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
