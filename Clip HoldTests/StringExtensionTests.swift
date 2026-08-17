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
}
