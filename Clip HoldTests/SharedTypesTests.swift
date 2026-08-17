import Testing
import Foundation
@testable import Clip_Hold

struct SharedTypesTests {
    
    // MARK: - DataSizeUnit のテスト
    
    @Test
    func testDataSizeUnitByteValues() {
        let bytesUnit = DataSizeUnit.bytes
        #expect(bytesUnit.byteValue(for: 500) == 500)
        
        let kbUnit = DataSizeUnit.kilobytes
        #expect(kbUnit.byteValue(for: 2) == 2000)
        
        let mbUnit = DataSizeUnit.megabytes
        #expect(mbUnit.byteValue(for: 5) == 5_000_000)
        
        let gbUnit = DataSizeUnit.gigabytes
        #expect(gbUnit.byteValue(for: 3) == 3_000_000_000)
        
        // 全ケースの網羅性
        #expect(DataSizeUnit.allCases.count == 4)
    }
    
    // MARK: - DataSizeOption のテスト
    
    @Test
    func testDataSizeOptionByteValue() {
        // プリセットオプションの byteValue
        let mb1 = DataSizeOption.preset(1, .megabytes)
        #expect(mb1.byteValue == 1_000_000)
        
        let gb1 = DataSizeOption.preset(1, .gigabytes)
        #expect(gb1.byteValue == 1_000_000_000)
        
        // 無制限オプション（0バイトとして定義）
        let unlimited = DataSizeOption.unlimited
        #expect(unlimited.byteValue == 0)
        
        // カスタムオプション
        let custom = DataSizeOption.custom(100, .kilobytes)
        #expect(custom.byteValue == 100_000)
        
        let customNil = DataSizeOption.custom(nil, nil)
        #expect(customNil.byteValue == nil)
    }
    
    @Test
    func testDataSizeOptionEqualityAndIDs() {
        let opt1 = DataSizeOption.preset(50, .megabytes)
        let opt2 = DataSizeOption.preset(50, .megabytes)
        let opt3 = DataSizeOption.preset(1, .gigabytes)
        
        #expect(opt1 == opt2)
        #expect(opt1 != opt3)
        #expect(opt1.id == "preset_50_MB")
        #expect(DataSizeOption.unlimited.id == "unlimited")
        #expect(DataSizeOption.custom(nil, nil).id == "custom_nil")
    }
    
    // MARK: - DataSizeAlertOption のテスト
    
    @Test
    func testDataSizeAlertOptionByteValue() {
        let alert100MB = DataSizeAlertOption.preset(100, .megabytes)
        #expect(alert100MB.byteValue == 100_000_000)
        
        let noAlert = DataSizeAlertOption.noAlert
        #expect(noAlert.byteValue == 0)
        
        let customAlert = DataSizeAlertOption.custom(2, .gigabytes)
        #expect(customAlert.byteValue == 2_000_000_000)
        
        let customNilAlert = DataSizeAlertOption.custom(nil, nil)
        #expect(customNilAlert.byteValue == nil)
        
        #expect(noAlert.id == "no_alert")
    }
    
    // MARK: - HistoryOption & MenuHistoryOption のテスト
    
    @Test
    func testHistoryOptionProperties() {
        let preset10 = HistoryOption.preset(10)
        #expect(preset10.intValue == 10)
        #expect(preset10.id == "preset_10")
        
        let unlimited = HistoryOption.unlimited
        #expect(unlimited.intValue == 0)
        #expect(unlimited.id == "unlimited")
        
        let custom = HistoryOption.custom(15)
        #expect(custom.intValue == 15)
        #expect(custom.id == "custom_value_15")
        
        let customNil = HistoryOption.custom(nil)
        #expect(customNil.intValue == nil)
        #expect(customNil.id == "custom_nil")
        
        #expect(HistoryOption.presets.count == 4)
    }
    
    @Test
    func testMenuHistoryOptionProperties() {
        let preset20 = MenuHistoryOption.preset(20)
        #expect(preset20.intValue == 20)
        #expect(preset20.id == "preset_20")
        
        let sameAsSaved = MenuHistoryOption.sameAsSaved
        #expect(sameAsSaved.intValue == nil)
        #expect(sameAsSaved.id == "same_as_saved")
        
        let custom = MenuHistoryOption.custom(30)
        #expect(custom.intValue == 30)
        #expect(custom.id == "custom_value_30")
    }
    
    // MARK: - ItemFilter & ItemSort の完全性テスト
    
    @Test
    func testItemFilterAndSortCases() {
        // ItemFilter の全ケース
        let allFilters = ItemFilter.allCases
        #expect(allFilters.contains(.all))
        #expect(allFilters.contains(.textPlain))
        #expect(allFilters.contains(.textRich))
        #expect(allFilters.contains(.imageOnly))
        #expect(allFilters.contains(.colorCodeOnly))
        
        for filter in allFilters {
            #expect(!filter.id.isEmpty)
        }
        
        // ItemSort の全ケース
        let allSorts = ItemSort.allCases
        #expect(allSorts.contains(.newest))
        #expect(allSorts.contains(.oldest))
        #expect(allSorts.contains(.largestFileSize))
        #expect(allSorts.contains(.smallestFileSize))
        
        for sort in allSorts {
            #expect(!sort.id.isEmpty)
        }
    }
    
    // MARK: - Date 拡張テスト
    
    @Test
    func testDateIso8601Formatting() {
        let testDate = Date(timeIntervalSince1970: 0)
        let formattedString = testDate.formatted(.iso8601)
        #expect(!formattedString.isEmpty)
        #expect(formattedString.contains("1970"))
    }
}
