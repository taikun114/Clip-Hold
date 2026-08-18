import Testing
import Foundation
@testable import Clip_Hold

@MainActor
struct TextReplacementLogicTests {
    
    // MARK: - 通常検索モードのテスト
    
    @Test
    func testStandardFindMatches() {
        let text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mi ipsum fermentum pulvinar."
        
        // 1. 大文字小文字無視: ON
        let matchesCaseInsensitive = TextReplacementEngine.findMatches(
            in: text,
            findText: "IPSUM",
            mode: .standard,
            standardOptions: StandardSearchOptions(ignoreCase: true, matchWholeWord: false)
        )
        #expect(matchesCaseInsensitive.count == 2)
        #expect(matchesCaseInsensitive[0].location == 6)
        #expect(matchesCaseInsensitive[0].length == 5)
        
        // 2. 大文字小文字無視: OFF
        let matchesCaseSensitive = TextReplacementEngine.findMatches(
            in: text,
            findText: "IPSUM",
            mode: .standard,
            standardOptions: StandardSearchOptions(ignoreCase: false, matchWholeWord: false)
        )
        #expect(matchesCaseSensitive.isEmpty)
        
        // 3. 単語単位一致: ON
        let text2 = "The cat scattered the catch in the cat."
        let wholeWordMatches = TextReplacementEngine.findMatches(
            in: text2,
            findText: "cat",
            mode: .standard,
            standardOptions: StandardSearchOptions(ignoreCase: true, matchWholeWord: true)
        )
        #expect(wholeWordMatches.count == 2) // "The cat" と "the cat." の 2 つのみ (scattered と catch は除外)
        
        // 4. 単語単位一致: OFF
        let partialMatches = TextReplacementEngine.findMatches(
            in: text2,
            findText: "cat",
            mode: .standard,
            standardOptions: StandardSearchOptions(ignoreCase: true, matchWholeWord: false)
        )
        #expect(partialMatches.count == 4) // cat, scattered, catch, cat の 4 つすべて
    }
    
    @Test
    func testStandardReplacement() {
        let text = "apple banana apple cherry apple"
        
        // 単一置換
        let matches = TextReplacementEngine.findMatches(
            in: text,
            findText: "apple",
            mode: .standard
        )
        #expect(matches.count == 3)
        
        let singleReplaced = TextReplacementEngine.replaceSingle(
            in: text,
            matchRange: matches[1],
            findText: "apple",
            replaceText: "orange",
            mode: .standard
        )
        #expect(singleReplaced == "apple banana orange cherry apple")
        
        // 全置換
        let (allReplaced, count) = TextReplacementEngine.replaceAll(
            in: text,
            findText: "apple",
            replaceText: "orange",
            mode: .standard
        )
        #expect(count == 3)
        #expect(allReplaced == "orange banana orange cherry orange")
    }
    
    // MARK: - 正規表現モードのテスト
    
    @Test
    func testRegexBasicMatching() {
        let sample = """
        [user_id: 1001, name: "Alice Smith", role: "admin"], active: true
        [user_id: 1002, name: "Bob Johnson", role: "editor"], active: false
        [user_id: 1003, name: "Charlie Brown", role: "viewer"], active: true
        """
        
        // 数値抽出
        let digitMatches = TextReplacementEngine.findMatches(
            in: sample,
            findText: "\\d{4}",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions()
        )
        #expect(digitMatches.count == 3)
        
        // 複雑なパターン
        let pattern = "\\[user_id: (\\d+), name: \"([^\"]+)\", role: \"([^\"]+)\"\\]"
        let fullMatches = TextReplacementEngine.findMatches(
            in: sample,
            findText: pattern,
            mode: .regularExpression,
            regexOptions: RegexSearchOptions()
        )
        #expect(fullMatches.count == 3)
    }
    
    @Test
    func testRegexFlagIgnoreCase() {
        let text = "Hello WORLD hello world"
        
        // ignoreCase: false
        let caseSensitive = TextReplacementEngine.findMatches(
            in: text,
            findText: "world",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions(ignoreCase: false, multiline: false, dotMatchesLineSeparators: false)
        )
        #expect(caseSensitive.count == 1)
        
        // ignoreCase: true (i フラグ)
        let caseInsensitive = TextReplacementEngine.findMatches(
            in: text,
            findText: "world",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions(ignoreCase: true, multiline: false, dotMatchesLineSeparators: false)
        )
        #expect(caseInsensitive.count == 2)
    }
    
    @Test
    func testRegexFlagMultiline() {
        let multilineText = """
        start line 1
        middle line
        start line 2
        """
        
        // multiline: false (^ はテキスト全体の先頭にのみマッチ)
        let noMultiline = TextReplacementEngine.findMatches(
            in: multilineText,
            findText: "^start",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions(ignoreCase: false, multiline: false, dotMatchesLineSeparators: false)
        )
        #expect(noMultiline.count == 1)
        
        // multiline: true (m フラグ: ^ は各行の先頭にマッチ)
        let withMultiline = TextReplacementEngine.findMatches(
            in: multilineText,
            findText: "^start",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions(ignoreCase: false, multiline: true, dotMatchesLineSeparators: false)
        )
        #expect(withMultiline.count == 2)
    }
    
    @Test
    func testRegexFlagDotMatchesLineSeparators() {
        let text = "<div>\nHello\n</div>"
        
        // dotMatchesLineSeparators: false (. は改行にマッチしない)
        let noDotAll = TextReplacementEngine.findMatches(
            in: text,
            findText: "<div>.*</div>",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions(ignoreCase: false, multiline: false, dotMatchesLineSeparators: false)
        )
        #expect(noDotAll.isEmpty)
        
        // dotMatchesLineSeparators: true (s フラグ: . は改行にもマッチする)
        let withDotAll = TextReplacementEngine.findMatches(
            in: text,
            findText: "<div>.*</div>",
            mode: .regularExpression,
            regexOptions: RegexSearchOptions(ignoreCase: false, multiline: false, dotMatchesLineSeparators: true)
        )
        #expect(withDotAll.count == 1)
    }
    
    @Test
    func testRegexCaptureGroupReplacement() {
        let sample = """
        [user_id: 1001, name: "Alice Smith", role: "admin"], active: true
        [user_id: 1002, name: "Bob Johnson", role: "editor"], active: false
        """
        
        let pattern = "\\[user_id: (\\d+), name: \"([^\"]+)\", role: \"([^\"]+)\"\\]"
        let template = "{\"id\": $1, \"name\": \"$2\", \"role\": \"$3\"}"
        
        // 全置換で JSON 風フォーマットへ変換
        let (result, count) = TextReplacementEngine.replaceAll(
            in: sample,
            findText: pattern,
            replaceText: template,
            mode: .regularExpression,
            regexOptions: RegexSearchOptions()
        )
        
        #expect(count == 2)
        let expected = """
        {"id": 1001, "name": "Alice Smith", "role": "admin"}, active: true
        {"id": 1002, "name": "Bob Johnson", "role": "editor"}, active: false
        """
        #expect(result == expected)
    }
    
    @Test
    func testRegexSingleReplacementWithCapture() {
        let sample = "item: 100, item: 200, item: 300"
        let pattern = "item: (\\d+)"
        let template = "ID($1)"
        
        let matches = TextReplacementEngine.findMatches(
            in: sample,
            findText: pattern,
            mode: .regularExpression
        )
        #expect(matches.count == 3)
        
        // 2 番目の要素のみ置換
        let singleReplaced = TextReplacementEngine.replaceSingle(
            in: sample,
            matchRange: matches[1],
            findText: pattern,
            replaceText: template,
            mode: .regularExpression
        )
        #expect(singleReplaced == "item: 100, ID(200), item: 300")
    }
    
    @Test
    func testRegexErrorHandlingAndEdgeCases() {
        let text = "Testing regex error handling."
        
        // 構文エラー（閉じ括弧なし）
        let invalidMatches = TextReplacementEngine.findMatches(
            in: text,
            findText: "([a-z",
            mode: .regularExpression
        )
        #expect(invalidMatches.isEmpty)
        
        // 空の検索文字列
        let emptyMatches = TextReplacementEngine.findMatches(
            in: text,
            findText: "",
            mode: .regularExpression
        )
        #expect(emptyMatches.isEmpty)
        
        // 空のテキスト
        let emptyTextMatches = TextReplacementEngine.findMatches(
            in: "",
            findText: "test",
            mode: .regularExpression
        )
        #expect(emptyTextMatches.isEmpty)
        
        // 構文エラー時の置換処理もクラッシュせず元のテキストを返す
        let (replaced, count) = TextReplacementEngine.replaceAll(
            in: text,
            findText: "([a-z",
            replaceText: "xyz",
            mode: .regularExpression
        )
        #expect(count == 0)
        #expect(replaced == text)
    }
    
    // MARK: - 置換履歴マネージャーのテスト
    
    @Test
    func testHistoryManagerOperations() {
        let manager = TextReplacementHistoryManager.shared
        let originalItems = manager.items
        
        defer {
            // テスト終了時に元の状態を復元
            manager.clearHistory()
            for item in originalItems.reversed() {
                manager.addHistory(
                    mode: item.mode,
                    findText: item.findText,
                    replaceText: item.replaceText,
                    standardOptions: item.standardOptions,
                    regexOptions: item.regexOptions
                )
            }
        }
        
        manager.clearHistory()
        #expect(manager.items.isEmpty)
        
        // 1. 履歴の追加
        manager.addHistory(
            mode: .standard,
            findText: "ipsum",
            replaceText: "lorem"
        )
        #expect(manager.items.count == 1)
        #expect(manager.items.first?.findText == "ipsum")
        #expect(manager.items.first?.replaceText == "lorem")
        #expect(manager.items.first?.mode == .standard)
        
        // 2. 別の履歴の追加（先頭に追加される）
        manager.addHistory(
            mode: .regularExpression,
            findText: "\\[user_id.*",
            replaceText: "{\"id\": $1}"
        )
        #expect(manager.items.count == 2)
        #expect(manager.items[0].mode == .regularExpression)
        #expect(manager.items[1].mode == .standard)
        
        // 3. 同一の履歴を再追加（古いものが削除され先頭に移動する）
        manager.addHistory(
            mode: .standard,
            findText: "ipsum",
            replaceText: "lorem"
        )
        #expect(manager.items.count == 2)
        #expect(manager.items[0].findText == "ipsum") // 先頭に移動
        #expect(manager.items[1].findText == "\\[user_id.*")
        
        // 4. 単一アイテムの削除 (removeItem)
        if let firstItem = manager.items.first {
            manager.removeItem(firstItem)
            #expect(manager.items.count == 1)
            #expect(manager.items.first?.findText == "\\[user_id.*")
        }
        
        // 5. クリア
        manager.clearHistory()
        #expect(manager.items.isEmpty)
        
        // 6. 最大50件の制限検証
        for i in 1...60 {
            manager.addHistory(
                mode: .standard,
                findText: "search_\(i)",
                replaceText: "replace_\(i)"
            )
        }
        #expect(manager.items.count == 50)
        #expect(manager.items.first?.findText == "search_60")
        #expect(manager.items.last?.findText == "search_11")
        
        // 終了時にもクリアして退避状態を復元
        manager.clearHistory()
    }
}
