import Testing
import Foundation
@testable import Clip_Hold

struct HistoryFilterSortTests {
    
    // MARK: - アイテム種別フィルタリングのテスト
    
    @Test
    func testItemTypeFiltering() {
        let plainItem = ClipboardItem(text: "プレーンテキスト")
        
        let richItem = ClipboardItem(
            richText: "<p>リッチテキスト</p>",
            text: "リッチテキスト"
        )
        
        let imageItem = ClipboardItem(
            text: "画像",
            filePath: URL(fileURLWithPath: "/tmp/test.png"),
            fileSize: 1024
        )
        
        let videoItem = ClipboardItem(
            text: "動画",
            filePath: URL(fileURLWithPath: "/tmp/movie.mp4"),
            fileSize: 2048
        )
        
        let pdfItem = ClipboardItem(
            text: "PDF",
            filePath: URL(fileURLWithPath: "/tmp/doc.pdf"),
            fileSize: 512
        )
        
        let urlItem = ClipboardItem(text: "https://example.com")
        
        let colorItem = ClipboardItem(text: "#FF5733")
        
        let swiftCodeItem = ClipboardItem(text: "func calculateTotal() -> Int { return 100 }")
        let pythonCodeItem = ClipboardItem(text: "def calculate_total():\n    return 100")
        
        let allItems = [plainItem, richItem, imageItem, videoItem, pdfItem, urlItem, colorItem, swiftCodeItem, pythonCodeItem]
        
        // .textPlain フィルタ（ファイルなし＆リッチテキストなし）
        let plainFiltered = allItems.filter { $0.filePath == nil && $0.richText == nil }
        #expect(plainFiltered.contains(plainItem))
        #expect(plainFiltered.contains(urlItem))
        #expect(plainFiltered.contains(colorItem))
        #expect(!plainFiltered.contains(richItem))
        #expect(!plainFiltered.contains(imageItem))
        
        // .textRich フィルタ（ファイルなし＆リッチテキストあり）
        let richFiltered = allItems.filter { $0.filePath == nil && $0.richText != nil }
        #expect(richFiltered.contains(richItem))
        #expect(!richFiltered.contains(plainItem))
        
        // .codeAll フィルタ
        let codeFiltered = allItems.filter { $0.isCode }
        #expect(codeFiltered.contains(swiftCodeItem))
        #expect(codeFiltered.contains(pythonCodeItem))
        #expect(!codeFiltered.contains(plainItem))
        #expect(!codeFiltered.contains(urlItem))
        #expect(!codeFiltered.contains(colorItem))
        
        // .codeSwift フィルタ
        let swiftFiltered = allItems.filter { $0.isCode && $0.detectedLanguage == .swift }
        #expect(swiftFiltered.contains(swiftCodeItem))
        #expect(!swiftFiltered.contains(pythonCodeItem))
        
        // .codePython フィルタ
        let pythonFiltered = allItems.filter { $0.isCode && $0.detectedLanguage == .python }
        #expect(pythonFiltered.contains(pythonCodeItem))
        #expect(!pythonFiltered.contains(swiftCodeItem))
        
        // .imageOnly フィルタ
        let imageFiltered = allItems.filter { $0.isImage }
        #expect(imageFiltered.contains(imageItem))
        #expect(!imageFiltered.contains(videoItem))
        
        // .videoOnly フィルタ
        let videoFiltered = allItems.filter { $0.isVideo }
        #expect(videoFiltered.contains(videoItem))
        #expect(!videoFiltered.contains(imageItem))
        
        // .pdfOnly フィルタ
        let pdfFiltered = allItems.filter { $0.isPDF }
        #expect(pdfFiltered.contains(pdfItem))
        #expect(!pdfFiltered.contains(imageItem))
        
        // .linkOnly フィルタ
        let linkFiltered = allItems.filter { $0.isURL }
        #expect(linkFiltered.contains(urlItem))
        #expect(!linkFiltered.contains(plainItem))
        
        // .colorCodeOnly フィルタ
        let colorFiltered = allItems.filter { $0.filePath == nil && ColorCodeParser.parseColor(from: $0.text) != nil }
        #expect(colorFiltered.contains(colorItem))
        #expect(!colorFiltered.contains(plainItem))
    }
    
    // MARK: - 検索テキストマッチングのテスト
    
    @Test
    func testSearchTextMatching() {
        let item1 = ClipboardItem(text: "SwiftUI プログラミング")
        let item2 = ClipboardItem(text: "Clip Hold マネージャー")
        let item3 = ClipboardItem(text: "Xcode 開発環境")
        let items = [item1, item2, item3]
        
        let query = "clip"
        let matched = items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        
        #expect(matched.count == 1)
        #expect(matched.first?.id == item2.id)
    }
    
    // MARK: - ソートロジックのテスト
    
    @Test
    func testItemSorting() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)
        
        let item1 = ClipboardItem(text: "1", date: date1, filePath: nil, fileSize: 100)
        let item2 = ClipboardItem(text: "2", date: date2, filePath: nil, fileSize: 300)
        let item3 = ClipboardItem(text: "3", date: date3, filePath: nil, fileSize: 200)
        
        let items = [item2, item1, item3]
        
        // 新しい順（日付降順）
        let newestSorted = items.sorted { $0.date > $1.date }
        #expect(newestSorted.map { $0.text } == ["3", "2", "1"])
        
        // 古い順（日付昇順）
        let oldestSorted = items.sorted { $0.date < $1.date }
        #expect(oldestSorted.map { $0.text } == ["1", "2", "3"])
        
        // ファイルサイズ大順
        let largestSorted = items.sorted { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        #expect(largestSorted.map { $0.text } == ["2", "3", "1"])
        
        // ファイルサイズ小順
        let smallestSorted = items.sorted { ($0.fileSize ?? 0) < ($1.fileSize ?? 0) }
        #expect(smallestSorted.map { $0.text } == ["1", "3", "2"])
    }
}
