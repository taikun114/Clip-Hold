import Testing
import Foundation
@testable import Clip_Hold

struct OrdinalSuffixTests {
    
    @Test
    func testOrdinalSuffixForHistory() {
        // 1〜10までのサフィックスが空でない文字列を返すか検証
        for number in 1...10 {
            let suffix = number.ordinalSuffixForHistory
            #expect(!suffix.isEmpty)
        }
        
        // 11以降は数値自体の文字列表現が返るか検証
        #expect(11.ordinalSuffixForHistory == "11")
        #expect(20.ordinalSuffixForHistory == "20")
        #expect(0.ordinalSuffixForHistory == "0")
    }
    
    @Test
    func testOrdinalSuffixForStandardPhrase() {
        // 1〜10までのサフィックスが空でない文字列を返すか検証
        for number in 1...10 {
            let suffix = number.ordinalSuffixForStandardPhrase
            #expect(!suffix.isEmpty)
        }
        
        // 11以降は数値自体の文字列表現が返るか検証
        #expect(11.ordinalSuffixForStandardPhrase == "11")
        #expect(25.ordinalSuffixForStandardPhrase == "25")
        #expect(0.ordinalSuffixForStandardPhrase == "0")
    }
}
