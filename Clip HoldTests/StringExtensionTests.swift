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
}

