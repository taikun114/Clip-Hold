import AppKit
import SwiftUI

/// 標準のScrollView内で行を再利用し、区切り線と余白を管理するテーブル。
@MainActor
struct QuickOverlayItemTable<Item: Identifiable, RowContent: View>: NSViewRepresentable {
    let items: [Item]
    @ViewBuilder var rowContent: (Item, Int) -> RowContent

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> QuickOverlayTableView {
        let tableView = QuickOverlayTableView()
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        return tableView
    }

    func updateNSView(_ tableView: QuickOverlayTableView, context: Context) {
        context.coordinator.update(parent: self, tableView: tableView, environment: context.environment)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: QuickOverlayTableView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.frame.width, height: nsView.contentHeight)
    }

    static func dismantleNSView(_ tableView: QuickOverlayTableView, coordinator: Coordinator) {
        tableView.delegate = nil
        tableView.dataSource = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private var parent: QuickOverlayItemTable
        private var environment = EnvironmentValues()
        private var itemIDs: [Item.ID] = []
        private let cellIdentifier = NSUserInterfaceItemIdentifier("QuickOverlayItemCell")

        init(parent: QuickOverlayItemTable) {
            self.parent = parent
        }

        func update(parent: QuickOverlayItemTable, tableView: NSTableView, environment: EnvironmentValues) {
            self.parent = parent
            self.environment = environment
            let newIDs = parent.items.map(\.id)
            if newIDs != itemIDs {
                let previousIDs = itemIDs
                itemIDs = newIDs
                if !previousIDs.isEmpty && newIDs.starts(with: previousIDs) {
                    // 追加読み込みでは既存の行とスクロール位置を保つ。
                    tableView.insertRows(at: IndexSet(previousIDs.count..<newIDs.count), withAnimation: [])
                } else {
                    tableView.reloadData()
                    tableView.invalidateIntrinsicContentSize()
                    return
                }
                tableView.invalidateIntrinsicContentSize()
            }

            // ホバーや設定変更で一覧全体を再読み込みせず、表示中の行だけを更新する。
            tableView.enumerateAvailableRowViews { rowView, row in
                guard parent.items.indices.contains(row),
                      let cell = rowView.view(atColumn: 0) as? QuickOverlayTableCell else { return }
                self.configure(cell, row: row)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.items.indices.contains(row) else { return nil }
            let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? QuickOverlayTableCell
                ?? QuickOverlayTableCell()
            cell.identifier = cellIdentifier
            cell.tableView = tableView
            configure(cell, row: row)
            return cell
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        private func configure(_ cell: QuickOverlayTableCell, row: Int) {
            let item = parent.items[row]
            // 別の項目に再利用された場合は、ホバーやツールチップの状態も切り替える。
            cell.hostingView.rootView = AnyView(
                parent.rowContent(item, row)
                    .id(item.id)
                    .environment(\.self, environment)
            )
        }
    }
}

@MainActor
final class QuickOverlayTableView: NSTableView {
    var contentHeight: CGFloat {
        numberOfRows > 0 ? rect(ofRow: numberOfRows - 1).maxY : 0
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let previousHeight = frame.height
        super.setFrameSize(newSize)
        if abs(previousHeight - newSize.height) > 0.5 {
            // 自動行高で全体の高さが変わった分を、外側のScrollViewに伝える。
            invalidateIntrinsicContentSize()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        style = .plain
        headerView = nil
        backgroundColor = .clear
        gridStyleMask = []
        usesAlternatingRowBackgroundColors = false
        selectionHighlightStyle = .none
        focusRingType = .none
        allowsEmptySelection = true
        allowsColumnReordering = false
        allowsColumnResizing = false
        rowSizeStyle = .custom
        rowHeight = 50
        usesAutomaticRowHeights = true
        intercellSpacing = NSSize(width: 0, height: 1)
        columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("QuickOverlayItemColumn"))
        column.minWidth = 0
        column.resizingMask = .autoresizingMask
        addTableColumn(column)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
final class QuickOverlayTableCell: NSTableCellView {
    let hostingView = QuickOverlayRowHostingView(rootView: AnyView(EmptyView()))
    weak var tableView: NSTableView?
    private let verticalInset: CGFloat = 2

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            hostingView.topAnchor.constraint(equalTo: topAnchor, constant: verticalInset),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalInset)
        ])
        hostingView.onIntrinsicSizeChange = { [weak self] in
            self?.updateRowHeightIfNeeded()
        }
    }

    private func updateRowHeightIfNeeded() {
        guard let tableView else { return }
        let row = tableView.row(for: self)
        guard row >= 0, row < tableView.numberOfRows else { return }
        let height = hostingView.intrinsicContentSize.height + verticalInset * 2
        let currentHeight = tableView.rect(ofRow: row).height - tableView.intercellSpacing.height
        guard height.isFinite, height > 0, abs(height - currentHeight) > 0.5 else { return }
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        tableView.invalidateIntrinsicContentSize()
    }

    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
final class QuickOverlayRowHostingView: NSHostingView<AnyView> {
    var onIntrinsicSizeChange: (() -> Void)?
    private var sizeUpdateScheduled = false

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        guard !sizeUpdateScheduled else { return }
        sizeUpdateScheduled = true
        // SwiftUIの表示更新中に行高を再計算しないよう、次のイベント処理で確認する。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.sizeUpdateScheduled = false
            self.onIntrinsicSizeChange?()
        }
    }
}
