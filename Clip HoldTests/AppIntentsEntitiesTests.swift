import Testing
import Foundation
import AppIntents
@testable import Clip_Hold

struct AppIntentsEntitiesTests {
    
    // MARK: - ClipboardItemEntity のテスト
    
    @Test
    func testClipboardItemEntityTextItem() {
        let testID = UUID()
        let testDate = Date(timeIntervalSince1970: 1720000000)
        let entity = ClipboardItemEntity(
            id: testID,
            contentText: "ショートカット用テキスト",
            date: testDate,
            isFile: false,
            filename: nil
        )
        
        #expect(entity.id == testID)
        #expect(entity.contentText == "ショートカット用テキスト")
        #expect(entity.date == testDate)
        #expect(!entity.isFile)
        #expect(entity.filename == nil)
    }
    
    @Test
    func testClipboardItemEntityFileItem() {
        let testID = UUID()
        let testDate = Date(timeIntervalSince1970: 1720000000)
        let entity = ClipboardItemEntity(
            id: testID,
            contentText: "sample.pdf",
            date: testDate,
            isFile: true,
            filename: "sample.pdf"
        )
        
        #expect(entity.id == testID)
        #expect(entity.isFile)
        #expect(entity.filename == "sample.pdf")
    }
    
    // MARK: - StandardPhraseEntity のテスト
    
    @Test
    func testStandardPhraseEntity() {
        let testID = UUID()
        let entity = StandardPhraseEntity(
            id: testID,
            title: "ショートカット定型文",
            content: "定型文の内容です"
        )
        
        #expect(entity.id == testID)
        #expect(entity.title == "ショートカット定型文")
        #expect(entity.content == "定型文の内容です")
    }
    
    // MARK: - StandardPhrasePresetEntity のテスト
    
    @Test
    func testStandardPhrasePresetEntity() {
        let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let defaultEntity = StandardPhrasePresetEntity(id: defaultID, name: "デフォルト")
        #expect(defaultEntity.id == defaultID)
        
        let customID = UUID()
        let customEntity = StandardPhrasePresetEntity(id: customID, name: "カスタムプリセット")
        #expect(customEntity.id == customID)
        #expect(customEntity.name == "カスタムプリセット")
    }
    
    // MARK: - AppEnum（MonitoringStateEnum / ToggleStateEnum）のテスト
    
    @Test
    func testMonitoringStateEnumCases() {
        #expect(MonitoringStateEnum.pause.rawValue == "pause")
        #expect(MonitoringStateEnum.resume.rawValue == "resume")
        #expect(MonitoringStateEnum.toggle.rawValue == "toggle")
        
        #expect(MonitoringStateEnum.caseDisplayRepresentations.count == 3)
    }
    
    @Test
    func testToggleStateEnumCases() {
        #expect(ToggleStateEnum.enable.rawValue == "enable")
        #expect(ToggleStateEnum.disable.rawValue == "disable")
        #expect(ToggleStateEnum.toggle.rawValue == "toggle")
        
        #expect(ToggleStateEnum.caseDisplayRepresentations.count == 3)
    }
}
