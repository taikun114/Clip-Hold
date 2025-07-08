import SwiftUI
import AppKit
import CoreImage
import UniformTypeIdentifiers

private let itemDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

private func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// 文字列を安全に切り詰めるヘルパー関数
private func truncateString(_ text: String?, maxLength: Int) -> String {
    guard let text = text else { return "" }
    if text.count > maxLength {
        return String(text.prefix(maxLength)) + "..."
    }
    return text
}

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

    let lineNumberTextWidth: CGFloat?
    let trailingPaddingForLineNumber: CGFloat

    init(item: ClipboardItem,
         index: Int,
         showLineNumber: Bool,
         itemToDelete: Binding<ClipboardItem?>,
         showingDeleteConfirmation: Binding<Bool>,
         selectedItemID: Binding<UUID?>,
         dismissAction: @escaping () -> Void, // クロージャは@escapingをつける
         showCopyConfirmation: Binding<Bool>,
         showQRCodeSheet: Binding<Bool>,
         selectedItemForQRCode: Binding<ClipboardItem?>,
         itemForNewPhrase: Binding<ClipboardItem?>,
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
        self.lineNumberTextWidth = lineNumberTextWidth
        self.trailingPaddingForLineNumber = trailingPaddingForLineNumber
    }

    private var actionMenuItems: some View {
        Group {
            Button("コピー") {
                copyToClipboard(item.text)
                showCopyConfirmation = true
            }
            Button("項目から定型文を作成...") {
                itemForNewPhrase = item // ここでClipboardItemをセット
            }
            Button("QRコードを表示...") {
                showQRCodeSheet = true
                selectedItemForQRCode = item
            }
            Divider()
            Button("削除...", role: .destructive) {
                itemToDelete = item
                showingDeleteConfirmation = true
            }
        }
    }

    var body: some View {
        HStack {
            if showLineNumber {
                Text("\(index + 1).")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: lineNumberTextWidth, alignment: .trailing)
                    .padding(.trailing, trailingPaddingForLineNumber)
            }

            VStack(alignment: .leading) {
                Text(item.text)
                    .lineLimit(1)
                    .font(.body)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
                Text(item.date, formatter: itemDateFormatter)
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
    }
}

struct HistoryWindowView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @Environment(\.dismiss) var dismiss

    @State private var searchText: String = ""
    @State private var filteredHistory: [ClipboardItem] = []
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: ClipboardItem?
    @State private var selectedItemID: UUID?
    @State private var isLoading: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showCopyConfirmation: Bool = false
    @State private var currentCopyConfirmationTask: Task<Void, Never>? = nil
    
    @State private var showQRCodeSheet: Bool = false
    @State private var selectedItemForQRCode: ClipboardItem?

    @State private var itemForNewPhrase: ClipboardItem? = nil

    @FocusState private var isSearchFieldFocused: Bool

    @AppStorage("showLineNumbersInHistoryWindow") var showLineNumbersInHistoryWindow: Bool = false
    @AppStorage("preventWindowCloseOnDoubleClick") var preventWindowCloseOnDoubleClick: Bool = false

    private var lineNumberTextWidth: CGFloat? {
        guard showLineNumbersInHistoryWindow, !filteredHistory.isEmpty else { return nil }
        
        let maxIndex = filteredHistory.count
        let numDigits = String(maxIndex).count

        let digitWidth: CGFloat = 7.0
        let periodWidth: CGFloat = 3.0
        let buffer: CGFloat = 1.0

        return CGFloat(numDigits) * digitWidth + periodWidth + buffer
    }

    private let trailingPaddingForLineNumber: CGFloat = 5

    private func performSearch(searchTerm: String) {
        let newFilteredHistory: [ClipboardItem]
        if searchTerm.isEmpty {
            newFilteredHistory = clipboardManager.clipboardHistory
        } else {
            newFilteredHistory = clipboardManager.clipboardHistory.filter { item in
                item.text.localizedCaseInsensitiveContains(searchTerm)
            }
        }
        self.filteredHistory = newFilteredHistory
    }

    // QRコードを解析するヘルパー関数
    private func parseQRCode(from image: NSImage) -> String? {
        guard let ciImage = CIImage(data: image.tiffRepresentation ?? Data()) else { return nil }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage)

        for feature in features ?? [] {
            if let qrCodeFeature = feature as? CIQRCodeFeature {
                return qrCodeFeature.messageString
            }
        }
        return nil
    }

    var body: some View {
        ZStack { // ZStackでコンテンツとメッセージを重ねる
            VisualEffectView(material: .menu, blendingMode: .behindWindow)
                .ignoresSafeArea()

            ZStack { // メインコンテンツを囲むZStack
                VStack(spacing: 0) {
                    HStack {
                        TextField(
                            "履歴を検索",
                            text: $searchText
                        )
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(.vertical, 8)
                        .padding(.leading, 30)
                        .padding(.trailing, 10)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(10)
                        .controlSize(.large)
                        .focused($isSearchFieldFocused)
                        .overlay(
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .offset(y: -1.0)
                                Spacer()
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .padding(.trailing, 8)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 5)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        
                        searchTask = Task { @MainActor in
                            let initialDelayNanoseconds: UInt64 = 150_000_000
                            try? await Task.sleep(nanoseconds: initialDelayNanoseconds)

                            guard !Task.isCancelled else {
                                return
                            }
                            
                            isLoading = true

                            let remainingDebounceNanoseconds: UInt64 = 150_000_000
                            try? await Task.sleep(nanoseconds: remainingDebounceNanoseconds)

                            guard !Task.isCancelled else {
                                isLoading = false
                                return
                            }

                            performSearch(searchTerm: newValue)
                            isLoading = false
                        }
                    }
                    .onChange(of: clipboardManager.clipboardHistory) { _, _ in
                        performSearch(searchTerm: searchText)
                    }
                    
                    Spacer(minLength: 10)

                    ZStack { // Listまたはメッセージが表示されるZStack
                        if filteredHistory.isEmpty && !isLoading {
                            VStack { // VStackで囲み、Spacerで中央に配置
                                Spacer()
                                Text("履歴はありません")
                                    .foregroundColor(.secondary)
                                    .font(.title2)
                                    .padding(.bottom, 20)
                                Spacer()
                            }
                        } else {
                            List(filteredHistory, selection: $selectedItemID) { item in
                                HistoryItemRow(
                                    item: item,
                                    index: filteredHistory.firstIndex(where: { $0.id == item.id }) ?? 0,
                                    showLineNumber: showLineNumbersInHistoryWindow,
                                    itemToDelete: $itemToDelete,
                                    showingDeleteConfirmation: $showingDeleteConfirmation,
                                    selectedItemID: $selectedItemID,
                                    dismissAction: { dismiss() },
                                    showCopyConfirmation: $showCopyConfirmation,
                                    showQRCodeSheet: $showQRCodeSheet,
                                    selectedItemForQRCode: $selectedItemForQRCode,
                                    itemForNewPhrase: $itemForNewPhrase,
                                    lineNumberTextWidth: lineNumberTextWidth,
                                    trailingPaddingForLineNumber: trailingPaddingForLineNumber
                                )
                                .tag(item.id)
                                .listRowBackground(Color.clear)
                            }
                            .accessibilityLabel("履歴リスト")
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .blur(radius: isLoading ? 5 : 0)
                            .animation(.easeOut(duration: 0.2), value: isLoading)
                            .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIDs in
                                if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                                    Button("コピー") {
                                        copyToClipboard(currentItem.text)
                                        showCopyConfirmation = true
                                        currentCopyConfirmationTask?.cancel()
                                        currentCopyConfirmationTask = Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                            guard !Task.isCancelled else { return }
                                            withAnimation {
                                                showCopyConfirmation = false
                                            }
                                        }
                                    }
                                    Button("項目から定型文を作成...") {
                                        itemForNewPhrase = currentItem // ここでClipboardItemをセット
                                    }
                                    Button("QRコードを表示...") {
                                        showQRCodeSheet = true
                                        selectedItemForQRCode = currentItem
                                    }
                                    Divider()
                                    Button("削除...", role: .destructive) {
                                        itemToDelete = currentItem
                                        showingDeleteConfirmation = true
                                    }
                                }
                            }, primaryAction: { selectedIDs in
                                if let id = selectedIDs.first, let currentItem = filteredHistory.first(where: { $0.id == id }) {
                                    copyToClipboard(currentItem.text)
                                    showCopyConfirmation = true
                                    currentCopyConfirmationTask?.cancel()
                                    currentCopyConfirmationTask = Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                                        guard !Task.isCancelled else { return }
                                        withAnimation {
                                            showCopyConfirmation = false
                                        }
                                    }
                                    if !preventWindowCloseOnDoubleClick {
                                        dismiss()
                                    }
                                }
                            })
                            .onDrop(of: [.image], isTargeted: nil) { providers in
                                guard let itemProvider = providers.first else { return false }

                                itemProvider.loadObject(ofClass: NSImage.self) { (image, error) in
                                    DispatchQueue.main.async {
                                        if let nsImage = image as? NSImage {
                                            if let qrCodeContent = parseQRCode(from: nsImage) {
                                                clipboardManager.addHistoryItem(text: qrCodeContent)
                                                copyToClipboard(qrCodeContent)
                                            } else {
                                                // QRコードが見つからなかった場合の処理
                                                print("QRコードが見つかりませんでした。")
                                            }
                                        } else if let error = error {
                                            print("画像のロードに失敗しました: \(error.localizedDescription)")
                                        }
                                    }
                                }
                                return true
                            }
                        }
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.clear)
                        }
                    }
                }
            } // メインコンテンツを囲むZStackの終わり
            
            // コピー確認メッセージ
            VStack {
                Spacer() // 下部に寄せる
                if showCopyConfirmation {
                    ZStack { // グラデーションとテキストを重ねるZStack
                        LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)]), startPoint: .top, endPoint: .bottom)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity) // 横幅を最大に
                        
                        Text("コピーしました！")
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 0)
                            .padding(.top, 15)
                    }
                    .frame(maxWidth: .infinity) // ZStack自体も横幅を最大に
                    .offset(y: 1) // 下にぴったりとくっつくように微調整
                    .transition(.opacity) // フェードイン/アウト
                    .onAppear {
                        // onAppearからはタイマー設定ロジックを削除。
                        // ここは単にビューの出現アニメーションに使用
                    }
                    .onDisappear {
                        // ビューが非表示になる際にタスクをキャンセル (念のため)
                        currentCopyConfirmationTask?.cancel()
                    }
                }
            }
            .animation(.easeOut(duration: 0.1), value: showCopyConfirmation)
            .allowsHitTesting(false) // クリックイベントを透過させる
        }
        .onExitCommand {
            dismiss()
        }
        .frame(minWidth: 300, idealWidth: 375, maxWidth: 900, minHeight: 300, idealHeight: 400, maxHeight: .infinity)
        .onAppear {
            performSearch(searchTerm: searchText)
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.contentViewController is NSHostingController<HistoryWindowView> }) {
                    print("HistoryWindowView onAppear: Found historyWindow via NSHostingController: \(window.identifier?.rawValue == "unknown")")
                    print("HistoryWindowView onAppear: Window delegate: \(window.delegate.debugDescription)")
                    
                    if let controller = window.windowController as? ClipHoldWindowController {
                        print("HistoryWindowView onAppear: Found managed controller. Re-applying customizations.")
                        controller.applyWindowCustomizations(window: window)
                    }
                } else {
                    print("HistoryWindowView onAppear: History window not found among NSApp.windows via NSHostingController.")
                }
            }
        }
        .alert("履歴の削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let item = itemToDelete {
                    clipboardManager.deleteItem(id: item.id)
                    itemToDelete = nil
                    selectedItemID = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("「\(truncateString(itemToDelete?.text, maxLength: 50))」を本当に削除しますか？")
        }
        .sheet(isPresented: $showQRCodeSheet) {
            if let item = selectedItemForQRCode {
                QRCodeView(text: item.text)
            }
        }
        .sheet(item: $itemForNewPhrase) { item in // itemが非nilの時にシートが表示される
            AddEditPhraseView(mode: .add, initialContent: item.text)
                .environmentObject(standardPhraseManager)
        }
    }
}

#Preview {
    HistoryWindowView()
        .environmentObject(ClipboardManager.shared)
}
