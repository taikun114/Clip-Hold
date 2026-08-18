import Testing
import Foundation
@testable import Clip_Hold

struct StringExtensionTests {
    
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
}


