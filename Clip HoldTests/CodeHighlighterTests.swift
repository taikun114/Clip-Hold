import Testing
import AppKit
import SwiftUI
@testable import Clip_Hold

struct CodeHighlighterTests {
    
    @Test
    @MainActor
    func testCodeHighlighterExecution() {
        let code = "func helloWorld() -> String {\n    return \"Hello, world!\"\n}"
        
        // ライトモードでのハイライト
        let lightResult = CodeHighlighter.shared.highlight(code, isDark: false)
        #expect(!lightResult.characters.isEmpty)
        #expect(String(lightResult.characters) == code)
        
        // ダークモードでのハイライト
        let darkResult = CodeHighlighter.shared.highlight(code, isDark: true)
        #expect(!darkResult.characters.isEmpty)
        #expect(String(darkResult.characters) == code)
    }
    
    @Test
    @MainActor
    func testCodeHighlighterWithSpecifiedLanguage() {
        let pythonCode = "def add(a, b):\n    return a + b"
        let result = CodeHighlighter.shared.highlight(pythonCode, as: "python", isDark: true)
        #expect(!result.characters.isEmpty)
        #expect(String(result.characters) == pythonCode)
    }
}
