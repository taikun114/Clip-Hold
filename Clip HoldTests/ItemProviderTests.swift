import Testing
import Foundation
import AppKit
import UniformTypeIdentifiers
@testable import Clip_Hold

struct ItemProviderTests {
    
    @Test
    func testPlainTextItemProvider() {
        let item = ClipboardItem(text: "プレーンテキスト")
        let provider = item.makeItemProvider(forcePlainText: false)
        
        // プレーンテキスト型に対応しているか検証
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
    }
    
    @Test
    func testHtmlRichTextItemProvider() {
        let item = ClipboardItem(
            richText: "<html><body><p>HTMLテキスト</p></body></html>",
            text: "HTMLテキスト"
        )
        let provider = item.makeItemProvider(forcePlainText: false)
        
        // HTML型およびフォールバック用のプレーンテキスト型の両方に適合しているか検証
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.html.identifier))
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
    }
    
    @Test
    func testRtfRichTextItemProvider() {
        let item = ClipboardItem(
            richText: "{\\rtf1\\ansi\\deff0 RTFコンテンツ}",
            text: "RTFコンテンツ"
        )
        let provider = item.makeItemProvider(forcePlainText: false)
        
        // RTF型およびプレーンテキスト型に適合しているか検証
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.rtf.identifier))
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
    }
    
    @Test
    func testFileItemProvider() {
        let fileURL = URL(fileURLWithPath: "/tmp/sample.txt")
        let item = ClipboardItem(
            text: "sample.txt",
            filePath: fileURL,
            fileSize: 128
        )
        let provider = item.makeItemProvider(forcePlainText: false)
        
        // ファイルURLに対応しているか検証
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
    }
    
    @Test
    func testForcePlainTextWithRichText() {
        let item = ClipboardItem(
            richText: "<html><body><p>強制プレーンテキスト</p></body></html>",
            text: "強制プレーンテキスト"
        )
        // forcePlainText = true の場合
        let provider = item.makeItemProvider(forcePlainText: true)
        
        // HTMLではなくプレーンテキストとして提供されるか検証
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
        #expect(!provider.hasItemConformingToTypeIdentifier(UTType.html.identifier))
    }
}
