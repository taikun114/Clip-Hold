import Testing
import Foundation
@testable import Clip_Hold

struct StandardPhraseModelTests {
    
    // MARK: - StandardPhrase のテスト
    
    @Test
    func testStandardPhraseInitializationAndCodable() throws {
        let originalID = UUID()
        let phrase = StandardPhrase(id: originalID, title: "挨拶", content: "お世話になっております。")
        
        #expect(phrase.id == originalID)
        #expect(phrase.title == "挨拶")
        #expect(phrase.content == "お世話になっております。")
        
        // Codableの整合性検証
        let data = try JSONEncoder().encode(phrase)
        let decoded = try JSONDecoder().decode(StandardPhrase.self, from: data)
        
        #expect(decoded.id == originalID)
        #expect(decoded.title == phrase.title)
        #expect(decoded.content == phrase.content)
        #expect(decoded == phrase)
    }
    
    // MARK: - StandardPhrasePreset のテスト
    
    @Test
    func testDefaultPresetInitialization() {
        let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let preset = StandardPhrasePreset(id: defaultID, name: "デフォルト")
        
        // デフォルトプリセットのアイコンは star.fill が初期設定されること
        #expect(preset.icon == "star.fill")
        #expect(preset.color == "accent")
        #expect(!preset.displayName.isEmpty)
    }
    
    @Test
    func testCustomPresetInitialization() {
        let customID = UUID()
        let preset = StandardPhrasePreset(
            id: customID,
            name: "ビジネスメール",
            icon: "envelope.fill",
            color: "blue",
            customColor: PresetCustomColor(background: "#0000FF", icon: "#FFFFFF")
        )
        
        #expect(preset.id == customID)
        #expect(preset.name == "ビジネスメール")
        #expect(preset.displayName == "ビジネスメール")
        #expect(preset.icon == "envelope.fill")
        #expect(preset.color == "blue")
        #expect(preset.customColor?.background == "#0000FF")
        #expect(preset.customColor?.icon == "#FFFFFF")
    }
    
    @Test
    func testPresetTruncatedDisplayName() {
        let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let defaultPreset = StandardPhrasePreset(id: defaultID, name: "デフォルト")
        // デフォルトプリセットは切り詰められず表示名が返ること
        #expect(!defaultPreset.truncatedDisplayName(maxLength: 3).isEmpty)
        
        let customPreset = StandardPhrasePreset(name: "長いプリセットの名前です")
        #expect(customPreset.truncatedDisplayName(maxLength: 5) == "長いプリセ...")
        #expect(customPreset.truncatedDisplayName(maxLength: 20) == "長いプリセットの名前です")
    }
    
    @Test
    func testPresetCodableSerialization() throws {
        let customColor = PresetCustomColor(background: "#123456", icon: "#654321")
        let phrase1 = StandardPhrase(title: "タイトル1", content: "内容1")
        let phrase2 = StandardPhrase(title: "タイトル2", content: "内容2")
        let preset = StandardPhrasePreset(
            name: "開発用定型文",
            phrases: [phrase1, phrase2],
            icon: "hammer.fill",
            color: "orange",
            customColor: customColor
        )
        
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(StandardPhrasePreset.self, from: data)
        
        #expect(decoded.id == preset.id)
        #expect(decoded.name == preset.name)
        #expect(decoded.icon == preset.icon)
        #expect(decoded.color == preset.color)
        #expect(decoded.customColor?.background == "#123456")
        #expect(decoded.customColor?.icon == "#654321")
        #expect(decoded.phrases.count == 2)
        #expect(decoded.phrases[0].title == "タイトル1")
        #expect(decoded.phrases[1].content == "内容2")
    }
    
    // MARK: - StandardPhraseDuplicate のテスト
    
    @Test
    func testStandardPhraseDuplicateConflicts() {
        let existing = StandardPhrase(title: "挨拶", content: "こんにちは")
        
        // タイトルのみ重複
        let dupTitle = StandardPhrase(title: "挨拶", content: "別の内容")
        let duplicate1 = StandardPhraseDuplicate(existingPhrase: existing, newPhrase: dupTitle)
        #expect(duplicate1.hasTitleConflict)
        #expect(!duplicate1.hasContentConflict)
        
        // 内容のみ重複
        let dupContent = StandardPhrase(title: "別のタイトル", content: "こんにちは")
        let duplicate2 = StandardPhraseDuplicate(existingPhrase: existing, newPhrase: dupContent)
        #expect(!duplicate2.hasTitleConflict)
        #expect(duplicate2.hasContentConflict)
        
        // 両方重複
        let dupBoth = StandardPhrase(title: "挨拶", content: "こんにちは")
        let duplicate3 = StandardPhraseDuplicate(existingPhrase: existing, newPhrase: dupBoth)
        #expect(duplicate3.hasTitleConflict)
        #expect(duplicate3.hasContentConflict)
    }
    
    @Test
    func testStandardPhraseDuplicateCustomTitleFlag() {
        let existing = StandardPhrase(title: "既存", content: "既存内容")
        
        // タイトルと内容が同じ場合（useCustomTitle = false になる）
        var duplicateSame = StandardPhraseDuplicate(
            existingPhrase: existing,
            newPhrase: StandardPhrase(title: "同じテキスト", content: "同じテキスト")
        )
        duplicateSame.setInitialUseCustomTitle()
        #expect(!duplicateSame.useCustomTitle)
        
        // タイトルと内容が異なる場合（useCustomTitle = true になる）
        var duplicateDiff = StandardPhraseDuplicate(
            existingPhrase: existing,
            newPhrase: StandardPhrase(title: "異なるタイトル", content: "本文テキスト")
        )
        duplicateDiff.setInitialUseCustomTitle()
        #expect(duplicateDiff.useCustomTitle)
    }
}
