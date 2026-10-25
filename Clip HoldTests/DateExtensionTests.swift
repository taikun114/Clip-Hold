import Testing
import Foundation
@testable import Clip_Hold

struct DateExtensionTests {
    
    @Test("日付フォーマッター再利用後も従来と同じ文字列を返す", arguments: [-86400.0, -300.0, -30.0, -29.0, 0.0, 29.0, 30.0, 300.0, 86400.0])
    func testCachedFormattingCompatibility(_ offset: TimeInterval) {
        let now = Date(timeIntervalSince1970: 1750000000)
        let date = now.addingTimeInterval(offset)
        let absolute = DateFormatter()
        absolute.dateStyle = .short
        absolute.timeStyle = .short
        let expectedAbsolute = absolute.string(from: date)
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        let expectedRelative = abs(offset) < 30 ? String(localized: "たった今")
            : relative.localizedString(for: date, relativeTo: now)
        #expect(date.formatted(for: "absolute", currentDate: now) == expectedAbsolute)
        #expect(date.formatted(for: "relative", currentDate: now) == expectedRelative)
        #expect(date.formatted(for: "both_abs_rel_paren", currentDate: now) == "\(expectedAbsolute) (\(expectedRelative))")
        #expect(date.formatted(for: "both_rel_abs_hyphen", currentDate: now) == "\(expectedRelative) - \(expectedAbsolute)")
        #expect(date.formatted(for: "unknown", currentDate: now) == expectedAbsolute)
    }

    @Test("共有フォーマッターを並行利用しても日付を混同しない")
    func testConcurrentDateFormatting() async {
        let now = Date(timeIntervalSince1970: 1750000000)
        let reference = DateFormatter()
        reference.dateStyle = .short
        reference.timeStyle = .short
        let samples = (0..<32).map { index in
            let date = now.addingTimeInterval(Double(index) * -86400)
            return (date, reference.string(from: date))
        }
        await withTaskGroup(of: Bool.self) { group in
            for (date, expected) in samples {
                group.addTask {
                    (0..<20).allSatisfy { _ in date.formattedAsAbsolute() == expected }
                }
            }
            for await matches in group { #expect(matches) }
        }
    }

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
