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

// sourceAppPathからローカライズされたアプリ名を取得するヘルパー関数
private func getLocalizedName(for sourceAppPath: String?) -> String? {
    guard let sourceAppPath = sourceAppPath else { return nil }
    
    let appURL = URL(fileURLWithPath: sourceAppPath)
    let nonLocalizedName = appURL.deletingPathExtension().lastPathComponent

    if let appBundle = Bundle(url: appURL) {
        let appName = appBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? 
                     appBundle.localizedInfoDictionary?["CFBundleName"] as? String ?? 
                     appBundle.infoDictionary?["CFBundleName"] as? String ?? 
                     nonLocalizedName
        return appName
    } else {
        return nonLocalizedName
    }
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
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    
    let item: ClipboardItem
    let index: Int
    let hideNumbers: Bool
    @Binding var itemToDelete: ClipboardItem?
    @Binding var showingDeleteConfirmation: Bool
    @Binding var selectedItemID: UUID?
    var dismissAction: () -> Void
    @AppStorage("closeWindowOnDoubleClick") var closeWindowOnDoubleClick: Bool = false

    @Environment(\.colorScheme) var colorScheme
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false

    @Binding var showCopyConfirmation: Bool
    @Binding var showQRCodeSheet: Bool
    @Binding var selectedItemForQRCode: ClipboardItem?
    
    @Binding var itemForNewPhrase: ClipboardItem?
    
    // アイコンビューの参照を格納する辞書へのBinding
    @Binding var rowIconViews: [UUID: NSView]
    
    let showCharacterCount: Bool
    @AppStorage("showAppIconOverlay") var showAppIconOverlay: Bool = true

    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat

    @State private var iconLoadTask: Task<Void, Never>?
    @State private var showingExcludeAppAlert = false
    @State private var appToExclude: String?
    @State private var showingEditSheet = false
    @State private var showingDeleteAllFromAppAlert = false
    @State private var appToDeleteFrom: String?

    init(item: ClipboardItem,
         index: Int,
         hideNumbers: Bool,
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
         rowIconViews: Binding<[UUID: NSView]>,
         showCharacterCount: Bool) { // initにBindingを追加
            
        self.item = item
        self.index = index
        self.hideNumbers = hideNumbers
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
        self.showCharacterCount = showCharacterCount
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
            if item.richText != nil {
                Button {
                    // リッチテキストアイテムの場合、プレーンテキストとしてコピー
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.text, forType: .string)
                    showCopyConfirmation = true
                } label: {
                    Text("標準テキストとしてコピー")
                }
                Button {
                    // 編集してコピーのアクションをここに実装
                    showingEditSheet = true
                } label: {
                    Text("編集してコピー...")
                }
            } else {
                Button {
                    // 標準テキストアイテムの場合、編集してコピー
                    showingEditSheet = true
                } label: {
                    Text("編集してコピー...")
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
            if let filePath = item.filePath {
                Button {
                    NSWorkspace.shared.open(filePath)
                } label: {
                    Label("開く", systemImage: "arrow.up.forward.app")
                }
            }
            if item.isURL, let url = URL(string: item.text) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("リンクを開く", systemImage: "paperclip")
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
            // "除外するアプリに追加..." menu item
            if let sourceAppPath = item.sourceAppPath {
                Button {
                    appToExclude = sourceAppPath
                    showingExcludeAppAlert = true
                } label: {
                    Label("除外するアプリに追加...", systemImage: "hand.raised.circle")
                }
            }
            Button(role: .destructive) {
                itemToDelete = item
                showingDeleteConfirmation = true
            } label: {
                Label("削除...", systemImage: "trash")
            }
            
            if let sourceAppPath = item.sourceAppPath {
                Button(role: .destructive) {
                    // 選択された項目と同じアプリからの履歴をすべて削除するアラートを表示
                    showingDeleteAllFromAppAlert = true
                    appToDeleteFrom = sourceAppPath
                } label: {
                    Text("このアプリからのすべての履歴を削除...")
                }
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if !hideNumbers {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: lineNumberTextWidth, alignment: .trailing)
                    .padding(.trailing, trailingPaddingForLineNumber)
            }
            
            // アイコン部分 (アプリアイコンをオーバーレイ表示するかどうかで分岐)
            let iconView: some View = {
                // カラーコードアイコンの表示条件をチェック
                if showColorCodeIcon, item.filePath == nil, let color = ColorCodeParser.parseColor(from: item.text) {
                    // カラーコードが解析できた場合、専用のカラーアイコンを表示
                    let baseIconView = ColorCodeIconView(color: color)
                    
                    // カラーアイコンにもアプリアイコンを表示する (showAppIconOverlayがtrueの場合のみ)
                    if showAppIconOverlay, let sourceAppPath = item.sourceAppPath {
                        let appName = getLocalizedName(for: sourceAppPath) ?? "Unknown App"
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
                                .background(IconViewAccessor(id: item.id, store: $rowIconViews))
                                .help(appName) // ツールチップを追加
                        )
                    } else {
                        return AnyView(baseIconView.background(IconViewAccessor(id: item.id, store: $rowIconViews)))
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
                        let appName = getLocalizedName(for: sourceAppPath) ?? "Unknown App"
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
                                .background(IconViewAccessor(id: item.id, store: $rowIconViews))
                                .help(appName) // ツールチップを追加
                        )
                    } else {
                        return AnyView(baseIconView.background(IconViewAccessor(id: item.id, store: $rowIconViews)))
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
                    Text(item.date, formatter: itemDateFormatter)
                    
                    if showCharacterCount {
                        Text("-")
                        Text("\(item.text.count)文字")
                    }
                    
                    if let fileSize = item.fileSize, item.filePath != nil {
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
                actionMenuItems
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
        .alert(String(localized: "除外するアプリに追加"), isPresented: $showingExcludeAppAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("追加") {
                if let appPath = appToExclude {
                    // Get the bundle identifier from the app path
                    let appURL = URL(fileURLWithPath: appPath)
                    if let appBundle = Bundle(url: appURL),
                       let bundleIdentifier = appBundle.bundleIdentifier {
                        // Update the excluded app identifiers in ClipboardManager
                        var currentExcludedIdentifiers = clipboardManager.excludedAppIdentifiers
                        if !currentExcludedIdentifiers.contains(bundleIdentifier) {
                            currentExcludedIdentifiers.append(bundleIdentifier)
                            clipboardManager.updateExcludedAppIdentifiers(currentExcludedIdentifiers)
                            
                            // Also update UserDefaults
                            if let encoded = try? JSONEncoder().encode(currentExcludedIdentifiers) {
                                UserDefaults.standard.set(encoded, forKey: "excludedAppIdentifiersData")
                            }
                        }
                    }
                }
            }
        } message: {
            if let appPath = appToExclude {
                let appName = getLocalizedName(for: appPath) ?? appPath
                Text("「\(appName)」を除外するアプリに追加しますか？除外するアプリは「プライバシー」設定から変更することができます。")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHistoryItemView(content: item.text, onCopy: { editedContent in
                // コピー処理を実装
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(editedContent, forType: .string)
                
                // コピー確認を表示
                showCopyConfirmation = true
            }, isSheet: true)
        }
        .alert("このアプリの履歴を削除", isPresented: $showingDeleteAllFromAppAlert) {
            Button("削除", role: .destructive) {
                if let appPath = appToDeleteFrom {
                    clipboardManager.deleteAllHistoryFromApp(sourceAppPath: appPath)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            if let appPath = appToDeleteFrom {
                let appName = getLocalizedName(for: appPath) ?? appPath
                let count = clipboardManager.countHistoryFromApp(sourceAppPath: appPath)
                Text("「\(appName)」からのすべての履歴を削除してもよろしいですか？\(count)個の履歴が削除されます。この操作は元に戻せません。")
            }
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
