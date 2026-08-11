import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers
import Quartz
import QuickLookThumbnailing

class RowIconStore {
    var views: [UUID: NSView] = [:]
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
    
    @ObservedObject var item: ClipboardItem
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
            let truncatedText = item.text.count > 1000 ? String(item.text.prefix(1000)) + "..." : item.text
            return Text(verbatim: truncatedText)
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
            } else if item.originalPinnedItemID != nil {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            
            // アイコン部分 (新しく作成した共有コンポーネントを使用)
            let iconView = ClipboardItemIconView(
                item: item,
                showColorCodeIcon: showColorCodeIcon,
                showAppIconOverlay: showAppIconOverlay,
                rowIconStore: rowIconStore
            )
            
            // アイコンにIconViewAccessorを適用して、NSViewの参照を保存する
            iconView
                .frame(width: 30, height: 30)
                .onDrag {
                    if let filePath = item.filePath {
                        return NSItemProvider(object: filePath as NSURL)
                    } else {
                        return NSItemProvider(object: item.text as NSString)
                    }
                }
                .contentShape(Rectangle())
            
            VStack(alignment: .leading, spacing: 4) {
                itemDisplayText
                    .lineLimit(1)
                    .font(.body)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                if item.isCopying && item.isProgressBarVisible {
                    ProgressView(value: item.copyProgress < 0.0 ? nil : item.copyProgress)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .id(item.id) // SwiftUIのビュー再利用による直前の進捗残りを防ぐ
                } else {
                    HStack(spacing: 4) {
                        Text(item.date.formatted(for: dateDisplayFormatInHistoryWindow, currentDate: dateReloader.now))
                        
                        if showCharacterCount {
                            Text("-")
                            Text("\(item.text.count)文字")
                        }
                        
                        if let fileSize = item.fileSize, item.filePath != nil, (!item.isFolder || item.isSizeCalculated) {
                            Text("-")
                            Text(formatFileSize(fileSize) + (item.isPartialSize ? String(localized: " 以上") : ""))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .help(item.text) // コンテンツテキスト部分にツールチップを追加
            .opacity(item.isCopying ? 0.5 : 1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
            
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
