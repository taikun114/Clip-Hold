import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers
import Quartz
import QuickLookThumbnailing

// アイコンのNSViewへの参照を親に渡すためのヘルパー
private struct IconViewAccessor: NSViewRepresentable {
    let id: UUID
    @Binding var store: [UUID: NSView]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.store[id] = view
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
    
    // アイコンビューの参照を格納する辞書へのBinding
    @Binding var rowIconViews: [UUID: NSView]

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
         lineNumberTextWidth: CGFloat?,
         trailingPaddingForLineNumber: CGFloat,
         rowIconViews: Binding<[UUID: NSView]>) { // initにBindingを追加
            
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
        self.lineNumberTextWidth = lineNumberTextWidth
        self.trailingPaddingForLineNumber = trailingPaddingForLineNumber
        self._rowIconViews = rowIconViews // Bindingを初期化
    }

    private var actionMenuItems: some View {
        Group {
            Button {
                // 内部コピーフラグをtrueに設定
                clipboardManager.isPerformingInternalCopy = true
                clipboardManager.copyItemToClipboard(item)
                showCopyConfirmation = true
            } label: {
                Label("コピー", systemImage: "document.on.document")
            }
            if item.isURL, let url = URL(string: item.text) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("リンクを開く", systemImage: "paperclip")
                }
            }
            if let qrContent = item.qrCodeContent {
                Button {
                    let newItem = ClipboardItem(text: qrContent, qrCodeContent: nil)
                    clipboardManager.isPerformingInternalCopy = true
                    clipboardManager.copyItemToClipboard(newItem)
                    showCopyConfirmation = true
                } label: {
                    Label("QRコードの内容をコピー", systemImage: "qrcode.viewfinder")
                }
            }
            Divider()
            if let filePath = item.filePath {
                Button {
                    // 保存されたアイコンビューの参照を使ってQuick Lookを呼び出す
                    if let controller = NSApp.keyWindow?.windowController as? ClipHoldWindowController,
                       let sourceView = rowIconViews[item.id] {
                        controller.showQuickLook(for: filePath as QLPreviewItem, from: sourceView)
                    }
                } label: {
                    Label("クイックルック", systemImage: "eye")
                }
            }
            Button {
                itemForNewPhrase = item
            } label: {
                Label("項目から定型文を作成...", systemImage: "pencil")
            }
            if item.filePath == nil {
                Button {
                    showQRCodeSheet = true
                    selectedItemForQRCode = item
                } label: {
                    Label("QRコードを表示...", systemImage: "qrcode")
                }
            }
            Divider()
            Button(role: .destructive) {
                itemToDelete = item
                showingDeleteConfirmation = true
            } label: {
                Label("削除...", systemImage: "trash")
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
            
            // アイコン部分をGroupでまとめる
            let iconImageView = Group {
                if item.isURL { // URLの場合
                    Image(systemName: "paperclip")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.secondary)
                } else if let cachedIcon = item.cachedThumbnailImage {
                    Image(nsImage: cachedIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                } else if let filePath = item.filePath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: filePath.path))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                } else {
                    if #available(macOS 15.0, *) {
                        Image(systemName: "text.page")
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "doc.plaintext")
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // アイコンにIconViewAccessorを適用して、NSViewの参照を保存する
            iconImageView
                .background(IconViewAccessor(id: item.id, store: $rowIconViews))

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
        .padding(.leading, 2)
        .contentShape(Rectangle())
        .help(item.text)
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
