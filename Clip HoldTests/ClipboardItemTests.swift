import Testing
import Foundation
@testable import Clip_Hold

struct ClipboardItemTests {
    
    // MARK: - ピン留め複製の決定論的ロジック検証
    
    @Test
    func testCreatePinnedDuplicateDeterministicUUID() {
        let originalItem = ClipboardItem(text: "テスト用テキスト")
        let originalID = originalItem.id
        
        let duplicate1 = originalItem.createPinnedDuplicate()
        let duplicate2 = originalItem.createPinnedDuplicate()
        
        // 何度複製しても同じ決定論的UUIDが生成されること
        #expect(duplicate1.id == duplicate2.id)
        
        // 複製品のIDは元のIDとは異なること
        #expect(duplicate1.id != originalID)
        
        // originalPinnedItemID に元のIDが正しく記録されていること
        #expect(duplicate1.originalPinnedItemID == originalID)
        #expect(duplicate2.originalPinnedItemID == originalID)
        
        // 元のUUIDの最初のバイトが 0xFF で反転されていること
        var expectedBytes = originalID.uuid
        expectedBytes.0 = expectedBytes.0 ^ 0xFF
        #expect(duplicate1.id == UUID(uuid: expectedBytes))
    }
    
    @Test
    func testCreatePinnedDuplicatePreservesProperties() {
        let testURL = URL(fileURLWithPath: "/tmp/sample.png")
        let testDate = Date(timeIntervalSince1970: 1700000000)
        let item = ClipboardItem(
            text: "サンプル画像",
            date: testDate,
            filePath: testURL,
            fileSize: 1024,
            fileHash: "abcdef123456",
            qrCodeContent: "https://example.com",
            sourceAppPath: "/Applications/Safari.app",
            isPartialSize: false,
            isSizeCalculated: true
        )
        item.richText = "<p>HTML内容</p>"
        item.codeDetectorVersion = 1
        item.detectedLanguage = .swift
        
        let duplicate = item.createPinnedDuplicate()
        
        #expect(duplicate.text == item.text)
        #expect(duplicate.richText == item.richText)
        #expect(duplicate.date == item.date)
        #expect(duplicate.filePath == item.filePath)
        #expect(duplicate.fileSize == item.fileSize)
        #expect(duplicate.fileHash == item.fileHash)
        #expect(duplicate.qrCodeContent == item.qrCodeContent)
        #expect(duplicate.sourceAppPath == item.sourceAppPath)
        #expect(duplicate.isPartialSize == item.isPartialSize)
        #expect(duplicate.isSizeCalculated == item.isSizeCalculated)
        #expect(duplicate.codeDetectorVersion == item.codeDetectorVersion)
        #expect(duplicate.detectedLanguage == item.detectedLanguage)
    }
    
    // MARK: - ファイル種別判定ロジック検証
    
    @Test
    func testFileTypeDetection() {
        // 画像ファイルの判定
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "heic", "webp", "tiff", "tif", "ico", "icns", "svg", "eps", "ai", "psd"]
        for ext in imageExtensions {
            let item = ClipboardItem(text: "画像", filePath: URL(fileURLWithPath: "/path/to/file.\(ext)"), fileSize: 100)
            #expect(item.isImage, "拡張子 .\(ext) は画像として判定される必要があります")
            #expect(!item.isVideo)
            #expect(!item.isPDF)
        }
        
        // 動画ファイルの判定
        let videoExtensions = ["mov", "mp4", "avi", "mkv", "wmv", "flv", "webm", "m4v", "qt"]
        for ext in videoExtensions {
            let item = ClipboardItem(text: "動画", filePath: URL(fileURLWithPath: "/path/to/movie.\(ext)"), fileSize: 1000)
            #expect(item.isVideo, "拡張子 .\(ext) は動画として判定される必要があります")
            #expect(!item.isImage)
            #expect(!item.isPDF)
        }
        
        // PDFファイルの判定
        let pdfItem = ClipboardItem(text: "PDF", filePath: URL(fileURLWithPath: "/path/to/document.pdf"), fileSize: 500)
        #expect(pdfItem.isPDF)
        #expect(!pdfItem.isImage)
        #expect(!pdfItem.isVideo)
        
        // 大文字小文字混在拡張子の判定（例: .PNG, .Pdf）
        let upperPngItem = ClipboardItem(text: "画像", filePath: URL(fileURLWithPath: "/path/to/photo.PNG"), fileSize: 200)
        #expect(upperPngItem.isImage)
        let upperPdfItem = ClipboardItem(text: "PDF", filePath: URL(fileURLWithPath: "/path/to/doc.PDF"), fileSize: 200)
        #expect(upperPdfItem.isPDF)
        
        // 一般テキスト・未設定の場合
        let textItem = ClipboardItem(text: "普通のテキスト")
        #expect(!textItem.isImage)
        #expect(!textItem.isVideo)
        #expect(!textItem.isPDF)
    }
    
    // MARK: - URL判定ロジック検証
    
    @Test
    func testURLDetection() {
        let httpItem = ClipboardItem(text: "http://example.com")
        #expect(httpItem.isURL)
        
        let httpsItem = ClipboardItem(text: "https://example.com/path?query=1")
        #expect(httpsItem.isURL)
        
        let invalidItem = ClipboardItem(text: "ただの文字列")
        #expect(!invalidItem.isURL)
        
        let emptyItem = ClipboardItem(text: "")
        #expect(!emptyItem.isURL)
        
        let ftpItem = ClipboardItem(text: "ftp://example.com")
        #expect(!ftpItem.isURL)
    }
    
    // MARK: - コード判定ロジック検証
    
    @Test
    func testCodeDetection() {
        let codeItem1 = ClipboardItem(text: "func hello() -> String { return \"world\" }")
        #expect(codeItem1.isCode)
        
        let codeItem2 = ClipboardItem(text: "const data = await fetch('/api/user');")
        #expect(codeItem2.isCode)
        
        let codeItem3 = ClipboardItem(text: "<html><body><p>Hello</p></body></html>")
        #expect(codeItem3.isCode)
        
        let plainTextItem = ClipboardItem(text: "こんにちは、お元気ですか？")
        #expect(!plainTextItem.isCode)
        
        let urlItem = ClipboardItem(text: "https://example.com")
        #expect(!urlItem.isCode)
        
        let colorItem = ClipboardItem(text: "#FFFFFF")
        #expect(!colorItem.isCode)
    }
    
    // MARK: - Codable シリアライズ / デシリアライズ整合性検証
    
    @Test
    func testCodableSerialization() throws {
        let originalItem = ClipboardItem(
            text: "Codable検証テキスト",
            date: Date(timeIntervalSince1970: 1710000000),
            filePath: URL(fileURLWithPath: "/path/to/test.txt"),
            fileSize: 2048,
            fileHash: "sha256hash123",
            qrCodeContent: "QRデータ",
            sourceAppPath: "/Applications/Notes.app",
            isPartialSize: true,
            isSizeCalculated: true
        )
        originalItem.richText = "{\\rtf1\\ansi リッチテキスト}"
        originalItem.codeDetectorVersion = 1
        originalItem.detectedLanguage = .json
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalItem)
        
        let decoder = JSONDecoder()
        let decodedItem = try decoder.decode(ClipboardItem.self, from: data)
        
        #expect(decodedItem.id == originalItem.id)
        #expect(decodedItem.text == originalItem.text)
        #expect(decodedItem.richText == originalItem.richText)
        #expect(decodedItem.date == originalItem.date)
        #expect(decodedItem.filePath == originalItem.filePath)
        #expect(decodedItem.fileSize == originalItem.fileSize)
        #expect(decodedItem.fileHash == originalItem.fileHash)
        #expect(decodedItem.qrCodeContent == originalItem.qrCodeContent)
        #expect(decodedItem.sourceAppPath == originalItem.sourceAppPath)
        #expect(decodedItem.isPartialSize == originalItem.isPartialSize)
        #expect(decodedItem.isSizeCalculated == originalItem.isSizeCalculated)
        #expect(decodedItem.codeDetectorVersion == originalItem.codeDetectorVersion)
        #expect(decodedItem.detectedLanguage == originalItem.detectedLanguage)
    }
    
    @Test
    func testBackwardCompatibilityWithoutCodeFields() throws {
        let originalItem = ClipboardItem(text: "guard let name = userName else { return }")
        originalItem.codeDetectorVersion = 1
        originalItem.detectedLanguage = .swift
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalItem)
        
        // JSONオブジェクトから codeDetectorVersion と detectedLanguage を削除して旧形式データをシミュレート
        var jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        jsonDict.removeValue(forKey: "codeDetectorVersion")
        jsonDict.removeValue(forKey: "detectedLanguage")
        
        let legacyData = try JSONSerialization.data(withJSONObject: jsonDict)
        
        let decoder = JSONDecoder()
        let decodedItem = try decoder.decode(ClipboardItem.self, from: legacyData)
        
        #expect(decodedItem.text == "guard let name = userName else { return }")
        #expect(decodedItem.codeDetectorVersion == nil)
        #expect(decodedItem.detectedLanguage == nil)
        
        // 初回 isCode 呼び出し時にフォールバック計算されてキャッシュされること
        #expect(decodedItem.isCode)
        #expect(decodedItem.codeDetectorVersion == CodeDetector.currentDetectorVersion)
        #expect(decodedItem.detectedLanguage == .swift)
    }
    
    // MARK: - displayTitle の検証
    
    @Test
    func testDisplayTitle() {
        let plainItem = ClipboardItem(text: "通常のテキスト")
        #expect(plainItem.displayTitle == "通常のテキスト")
        
        let imageItem = ClipboardItem(text: "Image File")
        #expect(!imageItem.displayTitle.isEmpty)
        
        let pdfItem = ClipboardItem(text: "PDF File")
        #expect(!pdfItem.displayTitle.isEmpty)
    }
}
