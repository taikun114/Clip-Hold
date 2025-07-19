import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers
import Quartz
import QuickLookThumbnailing

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
struct HistoryItemRow: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    let item: ClipboardItem
    let index: Int
    let showLineNumber: Bool
    @Binding var itemToDelete: ClipboardItem?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var selectedItemID: UUID?
    var dismissAction: () -> Void
    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    @Environment(\.colorScheme) var colorScheme

    @Binding var showCopyConfirmation: Bool
    @Binding var showQRCodeSheet: Bool
    @Binding var selectedItemForQRCode: ClipboardItem?
    
    @Binding var itemForNewPhrase: ClipboardItem?

    let quickLookManager: QuickLookManager

    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat

    @State private var iconLoadTask: Task<Void, Never>?

    init(item: ClipboardItem,
         index: Int,
         showLineNumber: Bool,
         itemToDelete: Binding<ClipboardItem?>,
         showingDeleteConfirmation: Binding<Bool>,
         selectedItemID: Binding<UUID?>,
         dismissAction: @escaping () -> Void,
         showCopyConfirmation: Binding<Bool>,
         showQRCodeSheet: Binding<Bool>,
         selectedItemForQRCode: Binding<ClipboardItem?>,
         itemForNewPhrase: Binding<ClipboardItem?>,
         quickLookManager: QuickLookManager,
         lineNumberTextWidth: CGFloat?,
         trailingPaddingForLineNumber: CGFloat) {
            
        self.item = item
        self.index = index
        self.showLineNumber = showLineNumber
        _itemToDelete = itemToDelete
        _showingDeleteConfirmation = showingDeleteConfirmation
        _selectedItemID = selectedItemID
        self.dismissAction = dismissAction
        _showCopyConfirmation = showCopyConfirmation
        _showQRCodeSheet = showQRCodeSheet
        _selectedItemForQRCode = selectedItemForQRCode
        _itemForNewPhrase = itemForNewPhrase
        self.quickLookManager = quickLookManager
        self.lineNumberTextWidth = lineNumberTextWidth
        self.trailingPaddingForLineNumber = trailingPaddingForLineNumber
    }

    private var actionMenuItems: some View {
        Group {
            Button("コピー") {
                // 内部コピーフラグをtrueに設定
                clipboardManager.isPerformingInternalCopy = true
                clipboardManager.copyItemToClipboard(item)
                showCopyConfirmation = true
            }
            if let qrContent = item.qrCodeContent {
                Button("QRコードの内容をコピー") {
                    let newItem = ClipboardItem(text: qrContent, qrCodeContent: nil)
                    // 内部コピーフラグをtrueに設定
                    clipboardManager.isPerformingInternalCopy = true
                    clipboardManager.copyItemToClipboard(newItem)
                    showCopyConfirmation = true
                }
            }
            Divider()
            if let filePath = item.filePath {
                Button("クイックルック") {
                    if let sourceView = NSApp.keyWindow?.contentView {
                        quickLookManager.showQuickLook(for: filePath, sourceView: sourceView)
                    }
                }
            }
            Button("項目から定型文を作成...") {
                itemForNewPhrase = item
            }
            if item.filePath == nil {
                Button("QRコードを表示...") {
                    showQRCodeSheet = true
                    selectedItemForQRCode = item
                }
            }
            Divider()
            Button("削除...", role: .destructive) {
                itemToDelete = item
                showingDeleteConfirmation = true
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if showLineNumber {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: lineNumberTextWidth, alignment: .trailing)
                    .padding(.trailing, trailingPaddingForLineNumber)
            }
            
            // item.cachedThumbnailImage が存在すればそれを使用
            if let cachedIcon = item.cachedThumbnailImage {
                Image(nsImage: cachedIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            } else if let filePath = item.filePath {
                // キャッシュがない場合は、従来のファイルアイコンを表示し、サムネイル生成を試みる
                Image(nsImage: NSWorkspace.shared.icon(forFile: filePath.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            } else {
                // ファイルパスもキャッシュもなければテキストアイコン
                Image(systemName: "text.page")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading) {
                Text(item.text)
                    .lineLimit(1)
                    .font(.body)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Text(item.date, formatter: itemDateFormatter)
                    
                    if let fileSize = item.fileSize, item.filePath != nil {
                        Text("-")
                        Text(formatFileSize(fileSize))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                actionMenuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundColor(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.leading, 5)
        .contentShape(Rectangle())
        .help(item.text)
        .onAppear {
            // cachedThumbnailImage が nil の場合のみサムネイル生成を試みる
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
