import AppKit
import SwiftUI
import Testing
@testable import Clip_Hold

@MainActor
struct QuickOverlayItemTableTests {
    private struct Item: Identifiable {
        let id: Int
        let title: String
    }

    @MainActor
    private final class Model: ObservableObject {
        @Published var items: [Item]
        @Published var revision = 0
        @Published var rowHeight: CGFloat = 46
        var renderedIDs = Set<Int>()
        var renderedTitles: [Int: String] = [:]
        var renderCount = 0

        init(items: [Item]) {
            self.items = items
        }
    }

    private struct ListView: View {
        @ObservedObject var model: Model

        private var list: some View {
            ScrollView {
                QuickOverlayItemTable(items: model.items) { item, _ in
                    model.renderedIDs.insert(item.id)
                    model.renderedTitles[item.id] = item.title
                    model.renderCount += 1
                    return Text(verbatim: "\(item.title) / \(model.revision)")
                        .frame(maxWidth: .infinity)
                        .frame(height: model.rowHeight)
                }
            }
        }

        var body: some View {
            Group {
                if #available(macOS 26.0, *) {
                    list
                        .safeAreaBar(edge: .top) { Text("架空の見出し").padding(12) }
                        .safeAreaBar(edge: .bottom) { Text("架空の操作バー").padding(12) }
                } else {
                    list
                }
            }
            .frame(width: 500, height: 300)
        }
    }

    @MainActor
    private final class Harness {
        let model: Model
        let window: NSWindow

        init(items: [Item]) {
            model = Model(items: items)
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ListView(model: model))
            window.layoutIfNeeded()
        }

        var table: QuickOverlayTableView? {
            @MainActor func find(in view: NSView) -> QuickOverlayTableView? {
                if let table = view as? QuickOverlayTableView { return table }
                for child in view.subviews {
                    if let table = find(in: child) { return table }
                }
                return nil
            }
            return window.contentView.flatMap { find(in: $0) }
        }

        func waitUntil(_ condition: () -> Bool) async throws {
            for _ in 0..<100 {
                if condition() { return }
                try await Task.sleep(for: .milliseconds(10))
            }
            try #require(condition(), "スクロール表示の更新が完了しませんでした")
        }
    }

    private func items(_ count: Int) -> [Item] {
        (0..<count).map { Item(id: $0, title: "架空のメモ \($0)") }
    }

    @Test("標準ScrollView内でも追加読み込みと表示更新で行とスクロール位置を保つ")
    func appendPreservesVisibleRows() async throws {
        let harness = Harness(items: items(50))
        defer { harness.window.close() }
        try await harness.waitUntil { harness.model.renderedIDs.contains(0) }
        let table = try #require(harness.table)
        table.scrollRowToVisible(20)
        try await harness.waitUntil { harness.model.renderedIDs.contains(20) }
        let cell = try #require(table.view(atColumn: 0, row: 20, makeIfNecessary: false))
        let scrollView = try #require(table.enclosingScrollView)
        let position = scrollView.contentView.bounds.origin
        #expect(position.y > 0)

        let previousRenders = harness.model.renderCount
        harness.model.revision += 1
        try await harness.waitUntil { harness.model.renderCount > previousRenders }
        #expect(table.view(atColumn: 0, row: 20, makeIfNecessary: false) === cell)
        #expect(scrollView.contentView.bounds.origin == position)

        harness.model.items = items(100)
        try await harness.waitUntil { table.numberOfRows == 100 && table.frame.height == table.contentHeight }
        #expect(table.view(atColumn: 0, row: 20, makeIfNecessary: false) === cell)
        #expect(scrollView.contentView.bounds.origin == position)
    }

    @Test("標準ScrollViewで1万行の末尾まで移動しても表示行だけを生成する")
    func largeHistoryBuildsOnlyRequestedRows() async throws {
        let harness = Harness(items: items(10_000))
        defer { harness.window.close() }
        try await harness.waitUntil { harness.model.renderedIDs.contains(0) }
        let table = try #require(harness.table)
        #expect(table.numberOfRows == 10_000)
        table.scrollRowToVisible(9_999)
        try await harness.waitUntil { harness.model.renderedIDs.contains(9_999) }
        #expect(harness.model.renderedIDs.count < 100)
        var available = 0
        table.enumerateAvailableRowViews { _, _ in available += 1 }
        #expect(available < 100)
    }

    @Test("並べ替えや削除後の行が新しいデータを参照する")
    func replacementRefreshesRows() async throws {
        let harness = Harness(items: items(30))
        defer { harness.window.close() }
        try await harness.waitUntil { harness.model.renderedIDs.contains(0) }
        let table = try #require(harness.table)
        harness.model.renderedIDs.removeAll()
        harness.model.items = [Item(id: 81, title: "架空の差し替えメモ"), Item(id: 42, title: "架空の別のメモ")]
        try await harness.waitUntil { table.numberOfRows == 2 && harness.model.renderedIDs.contains(81) }
        #expect(harness.model.renderedIDs.allSatisfy { $0 == 81 || $0 == 42 })
    }

    @Test("行の高さの変化を外側のスクロール領域にも反映する")
    func rowHeightChangesUpdateContentExtent() async throws {
        let harness = Harness(items: items(30))
        defer { harness.window.close() }
        try await harness.waitUntil { harness.model.renderedIDs.contains(0) }
        let table = try #require(harness.table)
        let documentView = try #require(table.enclosingScrollView?.documentView)
        let initialHeight = table.contentHeight
        let initialRowHeight = table.rect(ofRow: 0).height
        harness.model.rowHeight = 72
        try await harness.waitUntil {
            table.rect(ofRow: 0).height > initialRowHeight
                && table.frame.height == table.contentHeight && table.contentHeight > initialHeight
                && documentView.frame.height >= table.contentHeight
        }
        #expect(documentView.frame.height >= table.contentHeight)

        harness.model.rowHeight = 46
        try await harness.waitUntil {
            table.rect(ofRow: 0).height == initialRowHeight
                && abs(documentView.frame.height - table.contentHeight) < 0.5
        }
    }

    @Test("定型文のような値型の項目も同じIDの編集内容を行の再生成なしに反映する")
    func sameIDsRefreshEditedPhrases() async throws {
        let harness = Harness(items: items(30))
        defer { harness.window.close() }
        try await harness.waitUntil { harness.model.renderedTitles[0] != nil }
        let table = try #require(harness.table)
        let cell = try #require(table.view(atColumn: 0, row: 0, makeIfNecessary: false))
        harness.model.items[0] = Item(id: 0, title: "編集後の架空の定型文")
        try await harness.waitUntil { harness.model.renderedTitles[0] == "編集後の架空の定型文" }
        #expect(table.numberOfRows == 30)
        #expect(table.view(atColumn: 0, row: 0, makeIfNecessary: false) === cell)
    }
}
