import Testing
import Foundation
@testable import Clip_Hold

struct DateExtensionTests {
    
    @Test
    func testFormattedAsRelativeJustNow() {
        let now = Date()
        let fiveSecondsAgo = now.addingTimeInterval(-5)
        
        // 30秒未満の差分の場合は「たった今」が返ること
        let relativeText = fiveSecondsAgo.formattedAsRelative(currentDate: now)
        #expect(!relativeText.isEmpty)
    }
    
    @Test
    func testFormattedFormats() {
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let currentDate = baseDate.addingTimeInterval(300) // 5分後
        
        let absResult = baseDate.formatted(for: "absolute", currentDate: currentDate)
        let relResult = baseDate.formatted(for: "relative", currentDate: currentDate)
        
        #expect(!absResult.isEmpty)
        #expect(!relResult.isEmpty)
        
        // 複合フォーマット
        let bothParen = baseDate.formatted(for: "both_abs_rel_paren", currentDate: currentDate)
        #expect(bothParen == "\(absResult) (\(relResult))")
        
        let bothHyphen = baseDate.formatted(for: "both_abs_rel_hyphen", currentDate: currentDate)
        #expect(bothHyphen == "\(absResult) - \(relResult)")
        
        let bothRelAbsParen = baseDate.formatted(for: "both_rel_abs_paren", currentDate: currentDate)
        #expect(bothRelAbsParen == "\(relResult) (\(absResult))")
        
        let bothRelAbsHyphen = baseDate.formatted(for: "both_rel_abs_hyphen", currentDate: currentDate)
        #expect(bothRelAbsHyphen == "\(relResult) - \(absResult)")
    }
    
    @Test
    func testSampleFormatted() {
        let now = Date()
        let sample = Date.sampleFormatted(for: "both_abs_rel_paren", currentDate: now)
        #expect(!sample.isEmpty)
        #expect(sample.contains("(") && sample.contains(")"))
    }
}
