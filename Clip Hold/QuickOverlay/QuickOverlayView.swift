import AppKit
import SwiftUI
import KeyboardShortcuts

enum QuickOverlayType {
    case history
    case standardPhrase
}

enum QuickOverlaySelection: Equatable {
    case item(UUID)
    case add
    case openWindow
    case addPreset
}

struct QuickOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var standardPhraseManager: StandardPhraseManager
    @EnvironmentObject var presetManager: StandardPhrasePresetManager
    @EnvironmentObject var dateReloader: DateReloader
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var quickOverlayManager = QuickOverlayManager.shared
    
    @AppStorage("showColorCodeIcon") var showColorCodeIcon: Bool = false
    @AppStorage("showAppIconOverlay") var showAppIconOverlay: Bool = true
    @AppStorage("showCharacterCount") var showCharacterCount: Bool = true
    @AppStorage("dateDisplayFormatInHistoryWindow") var dateDisplayFormatInHistoryWindow: String = "absolute"
    
    let type: QuickOverlayType
    
    // Preview用のダミーデータ注入用プロパティ
    var explicitHistoryItems: [ClipboardItem]? = nil
    var explicitPhraseItems: [StandardPhrase]? = nil
    
    @State private var hoveredItemId: UUID? = nil
    @State private var currentSelection: QuickOverlaySelection? = nil
    
    // macOS 26のLiquid Glass背景更新を維持するための微小なアニメーション状態
    @State private var jiggle: Bool = false
    
    @State private var isPresetMenuOpen: Bool
    @State private var hoveredPresetId: UUID? = nil
    @State private var presetMenuCloseTask: Task<Void, Never>? = nil
    @State private var lastPresetMenuHoverLocation: CGPoint = .zero
    @State private var presetMenuSize: CGSize = .zero
    @State private var presetListHeight: CGFloat = 0
    @State private var showMenuShadow: Bool = false
    
    @State private var cachedHistoryItems: [ClipboardItem] = []
    
    @State private var currentDisplayLimit: Int = 50
    @State private var isPaginating: Bool = false
    
    // Custom Tooltip State
    @State private var tooltipTask: Task<Void, Never>? = nil

    
    @State private var outsideCloseTask: Task<Void, Never>? = nil
    
    let rowIconStore = RowIconStore()
    
    private var overlayCornerRadii: RectangleCornerRadii {
        switch QuickOverlayManager.shared.presentationMode {
        case .screenEdge(let edge, _, _, _):
            switch edge.edgeSide {
            case .top:
                return RectangleCornerRadii(topLeading: 0, bottomLeading: 28, bottomTrailing: 28, topTrailing: 0)
            case .bottom:
                return RectangleCornerRadii(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28)
            case .left:
                return RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 28, topTrailing: 28)
            case .right:
                return RectangleCornerRadii(topLeading: 28, bottomLeading: 28, bottomTrailing: 0, topTrailing: 0)
            }
        case .shortcut:
            return RectangleCornerRadii(topLeading: 28, bottomLeading: 28, bottomTrailing: 28, topTrailing: 28)
        }
    }
    
    init(type: QuickOverlayType, initialPresetMenuOpen: Bool = false, explicitHistoryItems: [ClipboardItem]? = nil, explicitPhraseItems: [StandardPhrase]? = nil) {
        self.type = type
        self._isPresetMenuOpen = State(initialValue: initialPresetMenuOpen)
        self.explicitHistoryItems = explicitHistoryItems
        self.explicitPhraseItems = explicitPhraseItems
        
        let initialItems: [ClipboardItem]
        if let explicit = explicitHistoryItems {
            initialItems = explicit
        } else if type == .history {
            if !ClipboardManager.shared.quickOverlayHistoryItems.isEmpty {
                initialItems = ClipboardManager.shared.quickOverlayHistoryItems
            } else {
                initialItems = Self.fetchInitialHistoryItems(
                    from: ClipboardManager.shared.clipboardHistory,
                    pinnedItemID: ClipboardManager.shared.pinnedItemID,
                    limit: 50
                )
            }
        } else {
            initialItems = []
        }
        self._cachedHistoryItems = State(initialValue: initialItems)
    }
    
    private var mainLayout: some View {
        Group {
            if #available(macOS 26.0, *) {
                scrollContent
                    .adaptiveScrollEdgeEffect()
                    .safeAreaBar(edge: .top, spacing: 0) {
                        headerView
                    }
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        footerView
                    }
            } else {
                VStack(spacing: 0) {
                    headerView
                    scrollContent
                    footerView
                }
            }
        }
    }
    
    @ViewBuilder
    private var backgroundMaterial: some View {
        if #available(macOS 26.0, *) {
            (colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.6))
                .glassEffect(.clear, in: UnevenRoundedRectangle(cornerRadii: overlayCornerRadii))
                .saturation(1.5)
                .environment(\.controlActiveState, .active)
        } else {
            Color.clear
                .background(Material.ultraThin)
                .environment(\.controlActiveState, .active)
        }
    }
    
    private var topInset: CGFloat {
        if case .screenEdge(let edge, _, _, let inset) = quickOverlayManager.presentationMode, edge.edgeSide == .top {
            return inset
        }
        return 0
    }
    
    private var bottomInset: CGFloat {
        if case .screenEdge(let edge, _, _, let inset) = quickOverlayManager.presentationMode, edge.edgeSide == .bottom {
            return inset
        }
        return 0
    }
    
    private var leftInset: CGFloat {
        if case .screenEdge(let edge, _, _, let inset) = quickOverlayManager.presentationMode, edge.edgeSide == .left {
            return inset
        }
        return 0
    }
    
    private var rightInset: CGFloat {
        if case .screenEdge(let edge, _, _, let inset) = quickOverlayManager.presentationMode, edge.edgeSide == .right {
            return inset
        }
        return 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 上辺の場合：上部にメニューバー裏への拡張領域
            if topInset > 0 {
                Color.clear.frame(height: topInset)
            }
            
            HStack(spacing: 0) {
                // 左辺の場合：左部にDock裏への拡張領域
                if leftInset > 0 {
                    Color.clear.frame(width: leftInset)
                }
                
                // メインコンテンツ（500x500固定）
                mainLayout
                    .overlay(
                        Group {
                            if type == .standardPhrase {
                                presetDropdownMenu
                                    .opacity(isPresetMenuOpen ? 1 : 0)
                                    .scaleEffect(isPresetMenuOpen ? 1 : 0.95, anchor: .topTrailing)
                                    .allowsHitTesting(isPresetMenuOpen)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresetMenuOpen)
                            }
                        },
                        alignment: .topTrailing
                    )
                    .frame(width: 500, height: 500)
                
                // 右辺の場合：右部にDock裏への拡張領域
                if rightInset > 0 {
                    Color.clear.frame(width: rightInset)
                }
            }
            
            // 下辺の場合：下部にDock裏への拡張領域
            if bottomInset > 0 {
                Color.clear.frame(height: bottomInset)
            }
        }
        .frame(width: 500 + leftInset + rightInset, height: 500 + topInset + bottomInset)
        .background(backgroundMaterial)
        .clipShape(UnevenRoundedRectangle(cornerRadii: overlayCornerRadii))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: overlayCornerRadii)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(60) // Provide space for the shadow to render inside the window
        .allowsHitTesting(!quickOverlayManager.isPeeking)
            .onAppear {
                if type == .history && cachedHistoryItems.isEmpty && !clipboardManager.clipboardHistory.isEmpty {
                    loadHistoryItems()
                }
            }
            .onChange(of: clipboardManager.quickOverlayHistoryItems) { _, newItems in
                if type == .history {
                    if currentDisplayLimit == 50 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            cachedHistoryItems = newItems
                        }
                    } else {
                        loadHistoryItems()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuickOverlayShouldHide"))) { _ in
                outsideCloseTask?.cancel()
                outsideCloseTask = nil
                tooltipTask?.cancel()
                tooltipTask = nil
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
                resetDisplayLimitAndReleaseMemory()
            }
            .onDisappear {
                outsideCloseTask?.cancel()
                outsideCloseTask = nil
                tooltipTask?.cancel()
                tooltipTask = nil
                resetDisplayLimitAndReleaseMemory()
            }
    }
    
    // MARK: - Subviews
    
    private func resetDisplayLimitAndReleaseMemory() {
        guard type == .history && currentDisplayLimit > 50 else { return }
        currentDisplayLimit = 50
        if !clipboardManager.quickOverlayHistoryItems.isEmpty {
            cachedHistoryItems = clipboardManager.quickOverlayHistoryItems
        } else {
            cachedHistoryItems = Array(cachedHistoryItems.prefix(50))
        }
    }
    
    static func fetchInitialHistoryItems(
        from history: [ClipboardItem],
        pinnedItemID: UUID?,
        limit: Int = 50
    ) -> [ClipboardItem] {
        guard !history.isEmpty else { return [] }
        let allSortedHistory = history.sorted { $0.date > $1.date }
        let effectiveLimit = limit > 0 ? limit : 50
        var raw = Array(allSortedHistory.prefix(effectiveLimit))
        
        if let pinnedID = pinnedItemID,
           let pinnedItem = history.first(where: { $0.id == pinnedID }) {
            raw.insert(pinnedItem.createPinnedDuplicate(), at: 0)
        }
        return raw
    }
    
    private func loadHistoryItems(isPagination: Bool = false) {
        if !isPagination {
            if let explicit = explicitHistoryItems {
                cachedHistoryItems = explicit
                return
            }
            if currentDisplayLimit == 50 && !clipboardManager.quickOverlayHistoryItems.isEmpty {
                cachedHistoryItems = clipboardManager.quickOverlayHistoryItems
                return
            }
        }
        
        let allSortedHistory = clipboardManager.clipboardHistory.sorted { $0.date > $1.date }
        let limit = currentDisplayLimit > 0 ? currentDisplayLimit : 50
        var raw = Array(allSortedHistory.prefix(limit))
        
        if let pinnedID = clipboardManager.pinnedItemID,
           let pinnedItem = clipboardManager.clipboardHistory.first(where: { $0.id == pinnedID }) {
            raw.insert(pinnedItem.createPinnedDuplicate(), at: 0)
        }
        cachedHistoryItems = raw
    }
    
    private func loadMoreHistoryItems() {
        guard !isPaginating && currentDisplayLimit < clipboardManager.clipboardHistory.count else { return }
        // Do not paginate if we are using explicit items
        if explicitHistoryItems != nil { return }
        
        isPaginating = true
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                currentDisplayLimit += 50
                loadHistoryItems(isPagination: true)
                isPaginating = false
            }
        }
    }
    
    private var scrollContent: some View {
        Group {
            if type == .history && cachedHistoryItems.isEmpty && !clipboardManager.isHistoryLoaded {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if type == .history {
                            ForEach(Array(cachedHistoryItems.enumerated()), id: \.element.id) { index, item in
                                historyItemRow(item, index: index)
                                    .onAppear {
                                        if index == cachedHistoryItems.count - 1 {
                                            loadMoreHistoryItems()
                                        }
                                    }
                            }
                            if isPaginating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .padding(.vertical, 8)
                            }
                        } else {
                            // Standard phrase items (Preview用に明示的なアイテムがあればそれを使用)
                            let phrases = explicitPhraseItems ?? getPhrasesForSelectedPreset()
                            ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                                standardPhraseItemRow(phrase, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .background(
                    // セーフエリアバーのLiquid Glass背景更新を維持するためのダミーアニメーション（レイアウトに影響しない不透明度のみ）
                    Color.white
                        .opacity(jiggle ? 0.002 : 0.001)
                        .allowsHitTesting(false)
                        .onAppear {
                            if #available(macOS 26.0, *) {
                                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: true)) {
                                    jiggle.toggle()
                                }
                            }
                        }
                )
            }
        }
        .onChange(of: clipboardManager.isHistoryLoaded) { _, loaded in
            if loaded && type == .history {
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadHistoryItems()
                }
            }
        }
    }
    
    private func getPhrasesForSelectedPreset() -> [StandardPhrase] {
        if presetManager.selectedPresetId?.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
            return []
        } else if let selectedPreset = presetManager.selectedPreset {
            return selectedPreset.phrases
        } else {
            return standardPhraseManager.standardPhrases
        }
    }
    
    private var headerView: some View {
        HStack {
            if type == .history {
                Text("履歴")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.vertical, 4)
            } else {
                Text("定型文")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            if type == .standardPhrase {
                let selectedPreset = presetManager.selectedPreset ?? presetManager.presets.first
                if let preset = selectedPreset {
                    HStack(spacing: 8) {
                        Image(nsImage: PresetIconGenerator.shared.generateIcon(for: preset))
                            
                        HStack(spacing: 4) {
                            Text(preset.displayName)
                                .font(.body)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.001)) // Make hoverable
                    .onHover { hovering in
                        if hovering {
                            presetMenuCloseTask?.cancel()
                            if !isPresetMenuOpen {
                                isPresetMenuOpen = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 50_000_000)
                                    await MainActor.run {
                                        if isPresetMenuOpen {
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                showMenuShadow = true
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            presetMenuCloseTask = Task {
                                do {
                                    try await Task.sleep(nanoseconds: 500_000_000)
                                    if !Task.isCancelled {
                                        await MainActor.run {
                                            closePresetMenu()
                                        }
                                    }
                                } catch {}
                            }
                        }
                    }
                    .onTapGesture {
                        if isPresetMenuOpen {
                            closePresetMenu()
                        } else {
                            isPresetMenuOpen = true
                            Task {
                                try? await Task.sleep(nanoseconds: 50_000_000)
                                await MainActor.run {
                                    if isPresetMenuOpen {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            showMenuShadow = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 18)
        .padding(.vertical, 12)
        .padding(.trailing, 12)
        .onChange(of: currentSelection) { _, newValue in
            QuickOverlayManager.shared.hoveredAction = nil
            // 標準テキストコピー状態は、eraserボタンのホバー中のみ true に保たれる。
            // 項目ホバーに移行した場合はここで解除する（nil への遷移時はボタンホバーと競合しないよう解除しない）。
            if case .item = newValue {
                QuickOverlayManager.shared.hoveredCopyAsPlainText = false
                QuickOverlayManager.shared.hoveredEditAndCopy = false
            } else if newValue == .add || newValue == .openWindow {
                QuickOverlayManager.shared.hoveredCopyAsPlainText = false
                QuickOverlayManager.shared.hoveredEditAndCopy = false
            }
            if case .item(let id) = newValue {
                if type == .history {
                    if let item = cachedHistoryItems.first(where: { $0.id == id }) {
                        QuickOverlayManager.shared.hoveredItemId = item.originalPinnedItemID ?? item.id
                    } else {
                        QuickOverlayManager.shared.hoveredItemId = id
                    }
                    QuickOverlayManager.shared.hoveredPhraseId = nil
                } else {
                    QuickOverlayManager.shared.hoveredPhraseId = id
                    QuickOverlayManager.shared.hoveredItemId = nil
                }
            } else if newValue == .add || newValue == .openWindow {
                QuickOverlayManager.shared.hoveredAction = newValue
                QuickOverlayManager.shared.hoveredItemId = nil
                QuickOverlayManager.shared.hoveredPhraseId = nil
            } else {
                QuickOverlayManager.shared.hoveredItemId = nil
                QuickOverlayManager.shared.hoveredPhraseId = nil
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Button(action: {
                QuickOverlayManager.shared.performActionAndClose(action: .add)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    if type == .history {
                        Text("新規コピー")
                    } else {
                        Text("追加")
                    }
                }
                .foregroundColor(currentSelection == .add ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(currentSelection == .add ? Color.accentColor : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(clipboardManager.isExporting)
            .opacity(clipboardManager.isExporting ? 0.4 : 1.0)
            .onHover { hovering in
                guard !clipboardManager.isExporting else { return }
                if hovering { 
                    currentSelection = .add 
                } else if currentSelection == .add {
                    currentSelection = nil
                }
            }
            
            Spacer()
            
            Button(action: {
                QuickOverlayManager.shared.performActionAndClose(action: .openWindow)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow.on.rectangle")
                    if type == .history {
                        Text("履歴ウィンドウを開く")
                    } else {
                        Text("定型文ウィンドウを開く")
                    }
                }
                .foregroundColor(currentSelection == .openWindow ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(currentSelection == .openWindow ? Color.accentColor : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                if hovering { 
                    currentSelection = .openWindow 
                } else if currentSelection == .openWindow {
                    currentSelection = nil
                }
            }
        }
        .padding(12)
    }
    
    private func historyItemRow(_ item: ClipboardItem, index: Int) -> some View {
        let isSelected = currentSelection == .item(item.id)
        let isPinned = item.originalPinnedItemID != nil
        
        let hasPinnedHeader = cachedHistoryItems.first?.originalPinnedItemID != nil
        
        let shortcut: String
        if isPinned {
            if let configuredShortcut = KeyboardShortcuts.getShortcut(for: .copyPinnedHistoryItem) {
                shortcut = configuredShortcut.description
            } else {
                shortcut = ""
            }
        } else {
            let unpinnedIndex = hasPinnedHeader ? index - 1 : index
            if unpinnedIndex < 10 {
                let name = KeyboardShortcuts.Name.allClipboardHistoryCopyShortcuts[unpinnedIndex]
                if let configuredShortcut = KeyboardShortcuts.getShortcut(for: name) {
                    shortcut = configuredShortcut.description
                } else {
                    shortcut = ""
                }
            } else {
                shortcut = ""
            }
        }
        
        return QuickOverlayHistoryItemRow(
            item: item,
            isSelected: isSelected,
            showColorCodeIcon: showColorCodeIcon,
            showAppIconOverlay: showAppIconOverlay,
            showCharacterCount: showCharacterCount,
            dateDisplayFormatInHistoryWindow: dateDisplayFormatInHistoryWindow,
            rowIconStore: rowIconStore,
            shortcut: shortcut,
            dateReloader: dateReloader,
            onHoverItem: { hovering in
                if hovering {
                    currentSelection = .item(item.id)
                } else if currentSelection == .item(item.id) {
                    currentSelection = nil
                }
            },
            onItemTooltipShow: {
                tooltipTask?.cancel()
                tooltipTask = Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    if !Task.isCancelled {
                        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil, userInfo: [
                            "text": item.displayTitle,
                            "sourceAppPath": item.sourceAppPath as Any,
                            "filePath": item.filePath?.path as Any,
                            "fileSize": item.fileSize as Any
                        ])
                    }
                }
            },
            onItemTooltipHide: {
                tooltipTask?.cancel()
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
            },
            onCopyAsPlainText: {
                QuickOverlayManager.shared.copyItemAsPlainTextAndClose(itemID: item.originalPinnedItemID ?? item.id)
            },
            onEditAndCopy: {
                QuickOverlayManager.shared.showEditAndCopyWindowAndClose(itemID: item.originalPinnedItemID ?? item.id)
            }
        )
    }
    
    private func standardPhraseItemRow(_ phrase: StandardPhrase, index: Int) -> some View {
        let isSelected = currentSelection == .item(phrase.id)
        
        let shortcut: String
        if index < 10 {
            if index < KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts.count {
                let name = KeyboardShortcuts.Name.allStandardPhraseCopyShortcuts[index]
                if let configuredShortcut = KeyboardShortcuts.getShortcut(for: name) {
                    shortcut = configuredShortcut.description
                } else {
                    shortcut = ""
                }
            } else {
                shortcut = ""
            }
        } else {
            shortcut = ""
        }
        
        return QuickOverlayStandardPhraseItemRow(
            phrase: phrase,
            isSelected: isSelected,
            showColorCodeIcon: showColorCodeIcon,
            shortcut: shortcut,
            onHoverItem: { hovering in
                if hovering {
                    currentSelection = .item(phrase.id)
                } else if currentSelection == .item(phrase.id) {
                    currentSelection = nil
                }
            },
            onItemTooltipShow: {
                tooltipTask?.cancel()
                tooltipTask = Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    if !Task.isCancelled {
                        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil, userInfo: ["text": phrase.content])
                    }
                }
            },
            onItemTooltipHide: {
                tooltipTask?.cancel()
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
            },
            onEditAndCopy: {
                QuickOverlayManager.shared.showEditAndCopyWindowAndClose(phraseID: phrase.id)
            }
        )
    }
    
    private var presetDropdownMenu: some View {
        Group {
            if #available(macOS 26.0, *) {
                presetDropdownScrollContent
                    .scrollEdgeEffectStyle(.hard, for: .all)
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        presetDropdownFooter
                    }
            } else {
                VStack(spacing: 0) {
                    presetDropdownScrollContent
                    presetDropdownFooter
                }
            }
        }
        .background(
            Group {
                if #available(macOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .environment(\.controlActiveState, .active)
                } else {
                    Color.clear
                        .background(Material.ultraThin)
                        .environment(\.controlActiveState, .active)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: showMenuShadow ? Color.black.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        .frame(width: 280)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { presetMenuSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in presetMenuSize = newSize }
            }
        )
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                lastPresetMenuHoverLocation = location
                presetMenuCloseTask?.cancel()
            case .ended:
                let loc = lastPresetMenuHoverLocation
                let size = presetMenuSize
                
                let distTop = loc.y
                let distBottom = size.height - loc.y
                let distLeft = loc.x
                let distRight = size.width - loc.x
                
                let minDist = min(distTop, distBottom, distLeft, distRight)
                let exitedHorizontally = (minDist == distLeft || minDist == distRight)
                
                presetMenuCloseTask?.cancel()
                presetMenuCloseTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        if !Task.isCancelled {
                            await MainActor.run {
                                if exitedHorizontally, let hoveredId = hoveredPresetId {
                                    if hoveredId.uuidString != "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" {
                                        presetManager.selectedPresetId = hoveredId
                                    }
                                }
                                closePresetMenu()
                            }
                        }
                    } catch {}
                }
            }
        }
        .padding(.top, 50)
        .padding(.trailing, 20)
    }
    
    private var presetListContent: some View {
        VStack(spacing: 0) {
            ForEach(presetManager.presets) { preset in
                let isHovered = hoveredPresetId == preset.id
                let isSelected = presetManager.selectedPresetId == preset.id
                
                HStack(spacing: 8) {
                    Image(nsImage: PresetIconGenerator.shared.generateIcon(for: preset))
                    
                    Text(preset.displayName)
                        .font(.body)
                        .foregroundColor(isHovered ? .white : (isSelected ? .accentColor : .primary))
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                            .foregroundColor(isHovered ? .white : .accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isHovered ? Color.accentColor : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        hoveredPresetId = preset.id
                    }
                }
                .onTapGesture {
                    presetManager.selectedPresetId = preset.id
                    closePresetMenu()
                }
            }
        }
        .padding(8)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { presetListHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newHeight in presetListHeight = newHeight }
            }
        )
    }
    
    private var presetDropdownScrollContent: some View {
        ScrollView {
            presetListContent
        }
        .frame(height: presetListHeight == 0 ? nil : min(presetListHeight, 350))
    }
    
    private var presetDropdownFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 4)
            
            // 新規プリセット保存ボタン
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
                Text("新規プリセット...")
                Spacer()
            }
            .font(.body)
            .foregroundColor(hoveredPresetId == UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")! ? .white : .primary) // ダミーIDとして扱う
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hoveredPresetId == UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")! ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .disabled(clipboardManager.isExporting)
            .opacity(clipboardManager.isExporting ? 0.4 : 1.0)
            .onHover { hovering in
                guard !clipboardManager.isExporting else { return }
                if hovering {
                    hoveredPresetId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
                    QuickOverlayManager.shared.hoveredAction = .addPreset
                } else {
                    if hoveredPresetId == UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")! {
                        hoveredPresetId = nil
                    }
                    QuickOverlayManager.shared.hoveredAction = nil
                }
            }
            .onTapGesture {
                guard !clipboardManager.isExporting else { return }
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showAddPresetWindow()
                }
                closePresetMenu()
                dismiss()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private func closePresetMenu() {
        withAnimation(.easeOut(duration: 0.1)) {
            showMenuShadow = false
        }
        // 影が消えるのを少し待ってからメニューを閉じる
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await MainActor.run {
                isPresetMenuOpen = false
                hoveredPresetId = nil
            }
        }
    }
}

// MARK: - QuickOverlay履歴の行

/// クイックオーバーレイの履歴の1行を表示するビュー。
/// 左側（項目コンテンツ）と右側（アクションボタン群）に分けて構成しており、
/// 右側には今後アクションボタンを追加していけるように設計している。
private struct QuickOverlayHistoryItemRow: View {
    @ObservedObject var item: ClipboardItem
    let isSelected: Bool
    let showColorCodeIcon: Bool
    let showAppIconOverlay: Bool
    let showCharacterCount: Bool
    let dateDisplayFormatInHistoryWindow: String
    let rowIconStore: RowIconStore
    let shortcut: String

    @ObservedObject var dateReloader: DateReloader
    @EnvironmentObject var clipboardManager: ClipboardManager

    var onHoverItem: (Bool) -> Void
    var onItemTooltipShow: () -> Void
    var onItemTooltipHide: () -> Void
    var onCopyAsPlainText: () -> Void
    var onEditAndCopy: () -> Void

    @State private var isButtonHovered = false
    @State private var buttonTopCenterScreen: CGPoint? = nil
    @State private var buttonTooltipTask: Task<Void, Never>? = nil
    @State private var rowContentHeight: CGFloat = 46
    
    @State private var isEditAndCopyButtonHovered = false
    @State private var editAndCopyButtonTopCenterScreen: CGPoint? = nil
    @State private var editAndCopyButtonTooltipTask: Task<Void, Never>? = nil
    
    @State private var isCancelCopyButtonHovered = false
    @State private var cancelCopyButtonTopCenterScreen: CGPoint? = nil
    @State private var cancelCopyButtonTooltipTask: Task<Void, Never>? = nil
    
    /// eraserボタンのサイズ。アイコンの大きさと、ボタンツールチップの上端基準（ボタンの高さ分のオフセット）に使用する
    private var buttonSize: CGFloat {
        max(rowContentHeight, 44)
    }
    
    private var isPinned: Bool {
        item.originalPinnedItemID != nil
    }

    /// 標準テキストのみのアイテム（リッチテキストを含まない）はeraserボタンを無効化する
    private var isPlainTextOnly: Bool {
        item.richText == nil
    }

    private var itemDisplayText: Text {
        let title = item.displayTitle
        let truncatedTitle = title.count > 1000 ? String(title.prefix(1000)) + "..." : title
        return Text(verbatim: truncatedTitle)
    }

    var body: some View {
        HStack(spacing: 0) {
            leftContent
            actionButtons
        }
        .onDisappear {
            buttonTooltipTask?.cancel()
            editAndCopyButtonTooltipTask?.cancel()
            cancelCopyButtonTooltipTask?.cancel()
        }
    }

    // MARK: - 左側（項目コンテンツ）

    private var leftContent: some View {
        HStack(spacing: 8) {
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .frame(width: 14)
            }

            ClipboardItemIconView(
                item: item,
                showColorCodeIcon: showColorCodeIcon,
                showAppIconOverlay: showAppIconOverlay,
                rowIconStore: rowIconStore,
                isSelected: isSelected
            )
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                itemDisplayText
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                if item.isCopying && item.isProgressBarVisible {
                    ProgressView(value: item.copyProgress < 0.0 ? nil : item.copyProgress)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .frame(minHeight: 14)
                        .id(item.id) // SwiftUIのビュー再利用による直前の進捗残りを防ぐ
                        .transition(.opacity)
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
                    .foregroundStyle(isSelected && !item.isCopying ? .white.opacity(0.8) : .secondary)
                    .transition(.opacity)
                }
            }
            .opacity(item.isCopying ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: item.isCopying)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !shortcut.isEmpty && !item.isCopying {
                Text(shortcut.replacingOccurrences(of: "^", with: "⌃"))
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : Color(nsColor: .tertiaryLabelColor))
            }
        }
        .padding(8)
        .background(isSelected && !item.isCopying ? Color.accentColor : Color.clear)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if !item.isCopying {
                QuickOverlayManager.shared.copyHistoryItemAndClose(itemID: item.originalPinnedItemID ?? item.id)
            }
        }
        .onDrag {
            if let filePath = item.filePath {
                return NSItemProvider(object: filePath as NSURL)
            } else {
                return NSItemProvider(object: item.text as NSString)
            }
        }
        .onHover { hovering in
            if !item.isCopying {
                onHoverItem(hovering)
            }
        }
        .onContinuousHover(coordinateSpace: .global) { phase in
            switch phase {
            case .active(_):
                onItemTooltipShow()
            case .ended:
                onItemTooltipHide()
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        rowContentHeight = geo.size.height
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        rowContentHeight = newHeight
                    }
            }
        )
    }

    // MARK: - 右側（アクションボタン群）

    private var actionButtons: some View {
        HStack(spacing: 2) {
            if item.isCopying {
                cancelCopyButton
            }
            eraserButton
            editAndCopyButton
            // 今後追加するボタンはここに並べる
        }
        .padding(.leading, 6)
        .padding(.trailing, 2)
    }
    
    /// コピーをキャンセルするボタン。
    private var cancelCopyButton: some View {
        Button(action: {
            QuickOverlayManager.shared.cancelCopyAndClose(itemID: item.originalPinnedItemID ?? item.id)
        }) {
            Image(systemName: "xmark")
                .font(.system(size: buttonSize * 0.46, weight: .medium))
                .foregroundStyle(isCancelCopyButtonHovered ? .white : Color(nsColor: .secondaryLabelColor))
                .frame(width: buttonSize, height: buttonSize)
                .background(isCancelCopyButtonHovered ? Color.red : Color.clear)
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .onHover { hovering in
            guard !clipboardManager.showingLargeFileAlert else { return }
            isCancelCopyButtonHovered = hovering
            if hovering {
                setCancelCopyHoverState(true)
                showCancelCopyButtonTooltip()
            } else {
                setCancelCopyHoverState(false)
                hideCancelCopyButtonTooltip()
            }
        }
        .accessibilityLabel(String(localized: "コピーをキャンセル"))
        .disabled(clipboardManager.showingLargeFileAlert) // アラート表示中はキャンセル不可にする
        .opacity(clipboardManager.showingLargeFileAlert ? 0.4 : 1)
        .background(
            ScreenFrameReader { frame in
                cancelCopyButtonTopCenterScreen = CGPoint(x: frame.midX, y: frame.maxY)
            }
        )
    }

    /// 標準テキストとしてコピーするためのボタン。
    /// アイコンの大きさは項目（ハイライト）の高さに合わせる。
    private var eraserButton: some View {
        return Button(action: onCopyAsPlainText) {
            Image(systemName: "eraser.line.dashed")
                .font(.system(size: buttonSize * 0.46, weight: .medium))
                .foregroundStyle(isButtonHovered ? .white : Color(nsColor: .secondaryLabelColor))
                .frame(width: buttonSize, height: buttonSize)
                .background(isButtonHovered ? Color.accentColor : Color.clear)
                .cornerRadius(12) // 項目のハイライトの角丸と統一する
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPlainTextOnly || item.isCopying || ClipboardManager.shared.isExporting)
        .opacity((isPlainTextOnly || item.isCopying || ClipboardManager.shared.isExporting) ? 0.4 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard !isPlainTextOnly, !item.isCopying else { return }
            isButtonHovered = hovering
            if hovering {
                setPlainTextHoverState(true)
                showButtonTooltip()
            } else {
                setPlainTextHoverState(false)
                hideButtonTooltip()
            }
        }
        .accessibilityLabel(String(localized: "標準テキストとしてコピー"))
        .background(
            ScreenFrameReader { frame in
                buttonTopCenterScreen = CGPoint(x: frame.midX, y: frame.maxY)
            }
         )
     }

    /// 変更してコピーボタン。pencil.lineアイコンを使用し、すべての項目で有効。
    /// クリックすると変更してコピーウインドウが表示される。ホバー中にオーバーレイを閉じた際も同様のウインドウが表示される。
    private var editAndCopyButton: some View {
        Button(action: onEditAndCopy) {
            Image(systemName: "pencil.line")
                .font(.system(size: buttonSize * 0.46, weight: .medium))
                .foregroundStyle(isEditAndCopyButtonHovered ? .white : Color(nsColor: .secondaryLabelColor))
                .frame(width: buttonSize, height: buttonSize)
                .background(isEditAndCopyButtonHovered ? Color.accentColor : Color.clear)
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(item.isCopying || ClipboardManager.shared.isExporting)
        .opacity((item.isCopying || ClipboardManager.shared.isExporting) ? 0.4 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            isEditAndCopyButtonHovered = hovering
            if hovering {
                setEditAndCopyHoverState(true)
                showEditAndCopyButtonTooltip()
            } else {
                setEditAndCopyHoverState(false)
                hideEditAndCopyButtonTooltip()
            }
        }
        .accessibilityLabel(String(localized: "変更してコピー..."))
        .background(
            ScreenFrameReader { frame in
                editAndCopyButtonTopCenterScreen = CGPoint(x: frame.midX, y: frame.maxY)
            }
        )
    }

    // MARK: - 標準テキストコピー用のホバー状態

    /// ボタンホバー中に、オーバーレイを閉じた際に標準テキストとしてコピーされるようマネージャーの状態を更新する
    private func setPlainTextHoverState(_ hovering: Bool) {
        if hovering {
            QuickOverlayManager.shared.hoveredAction = nil
            QuickOverlayManager.shared.hoveredItemId = item.originalPinnedItemID ?? item.id
            QuickOverlayManager.shared.hoveredPhraseId = nil
            QuickOverlayManager.shared.hoveredCopyAsPlainText = true
        } else {
            QuickOverlayManager.shared.hoveredCopyAsPlainText = false
            QuickOverlayManager.shared.hoveredItemId = nil
        }
    }
    
    /// キャンセルボタンホバー中の状態更新
    private func setCancelCopyHoverState(_ hovering: Bool) {
        if hovering {
            QuickOverlayManager.shared.hoveredAction = nil
            QuickOverlayManager.shared.hoveredItemId = item.originalPinnedItemID ?? item.id
            QuickOverlayManager.shared.hoveredPhraseId = nil
            QuickOverlayManager.shared.hoveredCancelCopy = true
        } else {
            QuickOverlayManager.shared.hoveredCancelCopy = false
            QuickOverlayManager.shared.hoveredItemId = nil
        }
    }

    // MARK: - ボタンツールチップ

    /// ボタンの中央の上に、通常の項目と同じデザインのツールチップを表示する。
    /// マウスカーソルの位置には連動させず、ボタンの固定位置に表示する。
    private func showButtonTooltip() {
        buttonTooltipTask?.cancel()
        buttonTooltipTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled, let anchor = buttonTopCenterScreen {
                // 項目のツールチップとは異なり、ボタンの機能説明のみを表示する
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil, userInfo: [
                    "text": String(localized: "標準テキストとしてコピー"),
                    "isCompact": true,
                    "buttonHeight": Double(buttonSize),
                    "anchorX": Double(anchor.x),
                    "anchorY": Double(anchor.y)
                ])
            }
        }
    }

    private func hideButtonTooltip() {
        buttonTooltipTask?.cancel()
        buttonTooltipTask = nil
        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
    }
    
    // MARK: - キャンセルコピー用ボタンツールチップ
    
    private func showCancelCopyButtonTooltip() {
        cancelCopyButtonTooltipTask?.cancel()
        cancelCopyButtonTooltipTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled, let anchor = cancelCopyButtonTopCenterScreen {
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil, userInfo: [
                    "text": String(localized: "コピーをキャンセル"),
                    "isCompact": true,
                    "buttonHeight": Double(buttonSize),
                    "anchorX": Double(anchor.x),
                    "anchorY": Double(anchor.y)
                ])
            }
        }
    }
    
    private func hideCancelCopyButtonTooltip() {
        cancelCopyButtonTooltipTask?.cancel()
        cancelCopyButtonTooltipTask = nil
        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
    }

    // MARK: - 変更してコピー用のホバー状態

    /// ボタンホバー中に、オーバーレイを閉じた際に変更してコピーウインドウを表示するようマネージャーの状態を更新する
    private func setEditAndCopyHoverState(_ hovering: Bool) {
        if hovering {
            QuickOverlayManager.shared.hoveredAction = nil
            QuickOverlayManager.shared.hoveredItemId = item.originalPinnedItemID ?? item.id
            QuickOverlayManager.shared.hoveredPhraseId = nil
            QuickOverlayManager.shared.hoveredEditAndCopy = true
        } else {
            QuickOverlayManager.shared.hoveredEditAndCopy = false
            QuickOverlayManager.shared.hoveredItemId = nil
        }
    }

    // MARK: - 変更してコピーボタンツールチップ

    /// ボタンの中央の上に、通常の項目と同じデザインのツールチップを表示する。
    /// マウスカーソルの位置には連動させず、ボタンの固定位置に表示する。
    private func showEditAndCopyButtonTooltip() {
        editAndCopyButtonTooltipTask?.cancel()
        editAndCopyButtonTooltipTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled, let anchor = editAndCopyButtonTopCenterScreen {
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil, userInfo: [
                    "text": String(localized: "変更してコピー..."),
                    "isCompact": true,
                    "buttonHeight": Double(buttonSize),
                    "anchorX": Double(anchor.x),
                    "anchorY": Double(anchor.y)
                ])
            }
        }
    }

    private func hideEditAndCopyButtonTooltip() {
        editAndCopyButtonTooltipTask?.cancel()
        editAndCopyButtonTooltipTask = nil
        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
    }
}

// バイト数を読みやすい文字列に変換するヘルパー関数
private func formatFileSize(_ byteCount: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(byteCount))
}

// MARK: - QuickOverlay定型文の行

/// クイックオーバーレイの定型文の1行を表示するビュー。
/// 履歴の QuickOverlayHistoryItemRow と同様に、
/// 左側（項目コンテンツ）と右側（アクションボタン群）に分けて構成している。
private struct QuickOverlayStandardPhraseItemRow: View {
    let phrase: StandardPhrase
    let isSelected: Bool
    let showColorCodeIcon: Bool
    let shortcut: String

    var onHoverItem: (Bool) -> Void
    var onItemTooltipShow: () -> Void
    var onItemTooltipHide: () -> Void
    var onEditAndCopy: () -> Void

    @State private var isEditAndCopyButtonHovered = false
    @State private var editAndCopyButtonTopCenterScreen: CGPoint? = nil
    @State private var editAndCopyButtonTooltipTask: Task<Void, Never>? = nil
    @State private var rowContentHeight: CGFloat = 46

    /// ボタンのサイズ。項目（ハイライト）の高さに合わせる
    private var buttonSize: CGFloat {
        max(rowContentHeight, 44)
    }

    private var isURL: Bool {
        guard !phrase.content.isEmpty,
              let url = URL(string: phrase.content) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }

    var body: some View {
        HStack(spacing: 0) {
            leftContent
            actionButtons
        }
        .onDisappear {
            editAndCopyButtonTooltipTask?.cancel()
        }
    }

    // MARK: - 左側（項目コンテンツ）

    private var leftContent: some View {
        HStack(spacing: 8) {
            Group {
                if showColorCodeIcon, let color = ColorCodeParser.parseColor(from: phrase.content) {
                    ColorCodeIconView(color: color)
                } else {
                    Image(systemName: isURL ? "paperclip" : "list.bullet.rectangle.portrait")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.title)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text(phrase.content)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !shortcut.isEmpty {
                Text(shortcut.replacingOccurrences(of: "^", with: "⌃"))
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : Color(nsColor: .tertiaryLabelColor))
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            QuickOverlayManager.shared.copyStandardPhraseAndClose(phraseID: phrase.id)
        }
        .onDrag {
            return NSItemProvider(object: phrase.content as NSString)
        }
        .onHover { hovering in
            onHoverItem(hovering)
        }
        .onContinuousHover(coordinateSpace: .global) { phase in
            switch phase {
            case .active(_):
                onItemTooltipShow()
            case .ended:
                onItemTooltipHide()
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        rowContentHeight = geo.size.height
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        rowContentHeight = newHeight
                    }
            }
        )
    }

    // MARK: - 右側（アクションボタン群）

    private var actionButtons: some View {
        HStack(spacing: 2) {
            editAndCopyButton
            // 今後追加するボタンはここに並べる
        }
        .padding(.leading, 6)
        .padding(.trailing, 2)
    }

    /// 変更してコピーボタン。pencil.lineアイコンを使用し、すべての定型文で有効。
    /// クリックすると変更してコピーウインドウが表示される。
    private var editAndCopyButton: some View {
        Button(action: onEditAndCopy) {
            Image(systemName: "pencil.line")
                .font(.system(size: buttonSize * 0.46, weight: .medium))
                .foregroundStyle(isEditAndCopyButtonHovered ? .white : Color(nsColor: .secondaryLabelColor))
                .frame(width: buttonSize, height: buttonSize)
                .background(isEditAndCopyButtonHovered ? Color.accentColor : Color.clear)
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(ClipboardManager.shared.isExporting)
        .opacity(ClipboardManager.shared.isExporting ? 0.4 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            isEditAndCopyButtonHovered = hovering
            if hovering {
                setEditAndCopyHoverState(true)
                showEditAndCopyButtonTooltip()
            } else {
                setEditAndCopyHoverState(false)
                hideEditAndCopyButtonTooltip()
            }
        }
        .accessibilityLabel(String(localized: "変更してコピー..."))
        .background(
            ScreenFrameReader { frame in
                editAndCopyButtonTopCenterScreen = CGPoint(x: frame.midX, y: frame.maxY)
            }
        )
    }

    // MARK: - 変更してコピー用のホバー状態

    /// ボタンホバー中に、オーバーレイを閉じた際に変更してコピーウインドウを表示するようマネージャーの状態を更新する
    private func setEditAndCopyHoverState(_ hovering: Bool) {
        if hovering {
            QuickOverlayManager.shared.hoveredAction = nil
            QuickOverlayManager.shared.hoveredPhraseId = phrase.id
            QuickOverlayManager.shared.hoveredItemId = nil
            QuickOverlayManager.shared.hoveredEditAndCopy = true
        } else {
            QuickOverlayManager.shared.hoveredEditAndCopy = false
            QuickOverlayManager.shared.hoveredPhraseId = nil
        }
    }

    // MARK: - 変更してコピーボタンツールチップ

    /// ボタンの中央の上に、通常の項目と同じデザインのツールチップを表示する。
    /// マウスカーソルの位置には連動させず、ボタンの固定位置に表示する。
    private func showEditAndCopyButtonTooltip() {
        editAndCopyButtonTooltipTask?.cancel()
        editAndCopyButtonTooltipTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled, let anchor = editAndCopyButtonTopCenterScreen {
                NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldShow"), object: nil, userInfo: [
                    "text": String(localized: "変更してコピー..."),
                    "isCompact": true,
                    "buttonHeight": Double(buttonSize),
                    "anchorX": Double(anchor.x),
                    "anchorY": Double(anchor.y)
                ])
            }
        }
    }

    private func hideEditAndCopyButtonTooltip() {
        editAndCopyButtonTooltipTask?.cancel()
        editAndCopyButtonTooltipTask = nil
        NotificationCenter.default.post(name: NSNotification.Name("QuickOverlayTooltipShouldHide"), object: nil)
    }
}

#Preview("定型文オーバーレイ (閉じた状態)") {
    QuickOverlayView(type: .standardPhrase, initialPresetMenuOpen: false, explicitPhraseItems: [
        StandardPhrase(title: "朝の挨拶", content: "おはようございます"),
        StandardPhrase(title: "昼の挨拶", content: "こんにちは"),
        StandardPhrase(title: "夜の挨拶", content: "こんばんは"),
        StandardPhrase(title: "長い定型文のタイトルがきちんと表示されるかどうかをテストする定期文のタイトル", content: "こんにちは。これはテスト定型文です。いかがお過ごしでしょうか？これはテスト定型文です。"),
        StandardPhrase(title: "Appleのサイト", content: "https://www.apple.com/"),
        StandardPhrase(title: "議事録テンプレート", content: "【会議名】\n【日時】\n【参加者】"),
        StandardPhrase(title: "メール署名", content: "山田太郎\n株式会社サンプル\nxxx-xxxx-xxxx"),
        StandardPhrase(title: "承知しました", content: "承知いたしました。引き続きよろしくお願いいたします。"),
        StandardPhrase(title: "会社リンク", content: "https://company.example.com"),
        StandardPhrase(title: "電話番号", content: "0X0-XXXX-XXXX"),
        StandardPhrase(title: "テキストカラー", content: "#F8F8FF")
    ])
        .environmentObject(ClipboardManager.shared)
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(StandardPhrasePresetManager.shared)
        .environmentObject(DateReloader.shared)
        .padding(40)
}

#Preview("定型文オーバーレイ (メニュー展開時)") {
    QuickOverlayView(type: .standardPhrase, initialPresetMenuOpen: true, explicitPhraseItems: [
        StandardPhrase(title: "朝の挨拶", content: "おはようございます"),
        StandardPhrase(title: "昼の挨拶", content: "こんにちは"),
        StandardPhrase(title: "夜の挨拶", content: "こんばんは"),
        StandardPhrase(title: "長い定型文のタイトルがきちんと表示されるかどうかをテストする定期文のタイトル", content: "こんにちは。これはテスト定型文です。いかがお過ごしでしょうか？これはテスト定型文です。"),
        StandardPhrase(title: "Appleのサイト", content: "https://www.apple.com/"),
        StandardPhrase(title: "議事録テンプレート", content: "【会議名】\n【日時】\n【参加者】"),
        StandardPhrase(title: "メール署名", content: "山田太郎\n株式会社サンプル\nxxx-xxxx-xxxx"),
        StandardPhrase(title: "承知しました", content: "承知いたしました。引き続きよろしくお願いいたします。"),
        StandardPhrase(title: "会社リンク", content: "https://company.example.com"),
        StandardPhrase(title: "電話番号", content: "0X0-XXXX-XXXX"),
        StandardPhrase(title: "テキストカラー", content: "#F8F8FF")
    ])
        .environmentObject(ClipboardManager.shared)
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(StandardPhrasePresetManager.shared)
        .environmentObject(DateReloader.shared)
        .padding(40)
}

#Preview("履歴オーバーレイ") {
    QuickOverlayView(type: .history, initialPresetMenuOpen: false, explicitHistoryItems: [
        ClipboardItem(text: "議事録テンプレート\n【会議名】\n【日時】", date: Date().addingTimeInterval(-60), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "山田太郎\n株式会社サンプル\nxxx-xxxx-xxxx", date: Date().addingTimeInterval(-3600), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "https://www.apple.com/", date: Date().addingTimeInterval(-7200), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "承知いたしました。引き続きよろしくお願いいたします。", date: Date().addingTimeInterval(-86400), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "#FFFFFF", date: Date().addingTimeInterval(-100000), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "def calculate_sum(a, b):\n    return a + b", date: Date().addingTimeInterval(-120000), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "ユーザーからのフィードバックまとめ", date: Date().addingTimeInterval(-150000), filePath: URL(fileURLWithPath: "/Users/dummy/Documents/feedback.txt"), fileSize: 1024, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "スクリーンショット 2026-08-02 10.00.00.png", date: Date().addingTimeInterval(-200000), filePath: URL(fileURLWithPath: "/Users/dummy/Desktop/screenshot.png"), fileSize: 2048576, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "https://github.com/", date: Date().addingTimeInterval(-250000), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil),
        ClipboardItem(text: "お疲れ様です。", date: Date().addingTimeInterval(-300000), filePath: nil, fileSize: nil, fileHash: nil, qrCodeContent: nil, sourceAppPath: nil)
    ])
        .environmentObject(ClipboardManager.shared)
        .environmentObject(StandardPhraseManager.shared)
        .environmentObject(StandardPhrasePresetManager.shared)
        .environmentObject(DateReloader.shared)
        .padding(40)
}
