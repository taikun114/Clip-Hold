import Testing
import Foundation
@testable import Clip_Hold

struct StringExtensionTests {
    
    @Test("長文プレビューの上限と元の文字列を維持する", arguments: ["あ", "👨‍👩‍👧‍👦", "e\u{301}", "x"])
    func testLongTextPresentation(_ character: String) {
        let source = String(repeating: character, count: 60000)
        let presentation = ClipboardTextPresentation(text: source)
        #expect(presentation.firstLine == String(repeating: character, count: 1000) + "...")
        #expect(presentation.tooltip == String(repeating: character, count: 5000) + "...")
        #expect(presentation.characterCount == 60000)
        #expect(source == String(repeating: character, count: 60000))
    }

    @Test("改行と空行を含むプレビューは従来の表示を維持する", arguments: ["\n", "\r\n", "\r", "\u{2028}", "\u{2029}", "\u{000B}", "\u{0085}"])
    func testFirstLineSeparatorCompatibility(_ separator: String) {
        let source = "  " + separator + "先頭行" + separator + " " + separator + "次の行"
        #expect(source.firstNonEmptyLine() == "先頭行...")
        #expect(source.firstNonEmptyLine(appendEllipsisIfMultiLine: false) == "先頭行")
        #expect(("先頭行…" + separator + "次の行").firstNonEmptyLine() == "先頭行…")
    }

    @Test("一覧表示の反復処理時間を架空の長文で計測する")
    func testLongTextPresentationPerformance() {
        let source = String(repeating: "架空の長い本文と追加の説明です。\n", count: 20000)
        let item = ClipboardItem(text: source)
        _ = item.textPresentation
        let clock = ContinuousClock()
        var result = 0
        let elapsed = clock.measure {
            for _ in 0..<1000 {
                result += item.textPresentation.characterCount
                result += item.textPresentation.firstLine.utf8.count
            }
        }
        let previousElapsed = clock.measure {
            for _ in 0..<1000 {
                let lines = source.components(separatedBy: .newlines)
                result += lines.first?.utf8.count ?? 0
                result += source.count
            }
        }
        #expect(result > 0)
        print("長文プレビュー1000回: キャッシュ参照 \(elapsed)、従来の全文分割と文字数計算 \(previousElapsed)")
    }

    @Test
    func testTruncateLongString() {
        let text = "Clip Hold Clipboard Manager"
        let truncated = text.truncate(maxLength: 9)
        
        #expect(truncated == "Clip Hold...")
    }
    
    @Test
    func testTruncateShortOrEqualString() {
        let text = "Clip Hold"
        
        // 文字数と同じ maxLength の場合はそのまま返ること
        #expect(text.truncate(maxLength: 9) == "Clip Hold")
        
        // 文字数より大きい maxLength の場合もそのまま返ること
        #expect(text.truncate(maxLength: 20) == "Clip Hold")
    }
    
    @Test
    func testTruncateEmptyString() {
        let empty = ""
        #expect(empty.truncate(maxLength: 5) == "")
    }
    
    @Test
    func testReplacingNewlinesWithSpaces() {
        // 改行のみの場合
        #expect("\n".replacingNewlinesWithSpaces() == " ")
        #expect("\n\n".replacingNewlinesWithSpaces() == "  ")
        #expect("\r\n".replacingNewlinesWithSpaces() == " ")
        #expect("\r".replacingNewlinesWithSpaces() == " ")
        
        // 複数行テキストの場合
        let multiline = "Hello\nWorld\r\nTest\rDone"
        #expect(multiline.replacingNewlinesWithSpaces() == "Hello World Test Done")
        
        // 改行を含まない場合
        let singleLine = "Hello World"
        #expect(singleLine.replacingNewlinesWithSpaces() == "Hello World")
        
        // 空文字の場合
        #expect("".replacingNewlinesWithSpaces() == "")
    }
    
    @Test
    func testFormatWithInvisibleSymbolsPlainSingleLine() {
        let input = " Hello\tWorld\u{3000}\nTest\r\nDone\r "
        let formatted = input.formatWithInvisibleSymbolsPlain(singleLine: true)
        #expect(formatted == "␣Hello⇥World□↵Test↵Done↵␣")
        
        // 空文字
        #expect("".formatWithInvisibleSymbolsPlain(singleLine: true) == "")
        
        // 不可視文字を含まない
        #expect("ABC".formatWithInvisibleSymbolsPlain(singleLine: true) == "ABC")
    }
    
    @Test
    func testFormatWithInvisibleSymbolsPlainMultiLine() {
        let input = "Line1\nLine2\tTab"
        let formatted = input.formatWithInvisibleSymbolsPlain(singleLine: false)
        #expect(formatted == "Line1↵\nLine2⇥\u{200B}Tab")
    }
    
    @Test
    func testFormatWithInvisibleSymbolsAttributedString() {
        let input = " A\tB\u{3000}C\nD "
        let attr = input.formatWithInvisibleSymbols(singleLine: true)
        let plainString = String(attr.characters)
        #expect(plainString == "␣A⇥B□C↵D␣")
        
        // 複数行モード
        let multiAttr = "A\nB".formatWithInvisibleSymbols(singleLine: false)
        let multiPlain = String(multiAttr.characters)
        #expect(multiPlain == "A↵\nB")
    }
    
    @Test
    func testFirstNonEmptyLine() {
        // 通常の複数行テキスト（後続行があるため末尾に...が付与される）
        #expect("Hello\nWorld".firstNonEmptyLine() == "Hello...")
        #expect("Line 1\r\nLine 2\nLine 3".firstNonEmptyLine() == "Line 1...")
        
        // 先頭に空行がある複数行テキスト
        #expect("\n\nHello\nWorld".firstNonEmptyLine() == "Hello...")
        #expect("   \n\t\nHello\nWorld".firstNonEmptyLine() == "Hello...")
        
        // 1行のみのテキスト
        #expect("Hello World".firstNonEmptyLine() == "Hello World")
        
        // 末尾にのみ空行があるテキスト（実質1行のため...は付かない）
        #expect("Hello\n\n".firstNonEmptyLine() == "Hello")
        #expect("Hello\r\n   \n".firstNonEmptyLine() == "Hello")
        
        // 改行のみ・空白のみのテキスト
        #expect("\n".firstNonEmptyLine() == "")
        #expect("\n\n\n".firstNonEmptyLine() == "")
        #expect("\r\n\r\n".firstNonEmptyLine() == "")
        #expect("   \n\t\n   ".firstNonEmptyLine() == "")
        #expect("".firstNonEmptyLine() == "")
        
        // 既に三項省略記号などで終わっている複数行テキスト
        #expect("Hello...\nWorld".firstNonEmptyLine() == "Hello...")
        #expect("Hello…\nWorld".firstNonEmptyLine() == "Hello…")
        
        // 省略記号付与を無効にした場合
        #expect("Hello\nWorld".firstNonEmptyLine(appendEllipsisIfMultiLine: false) == "Hello")
    }
}


