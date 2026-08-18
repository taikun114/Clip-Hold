import Foundation

/// テキスト置換のモード
enum TextReplacementMode: String, CaseIterable, Identifiable, Codable {
    case standard = "検索"
    case regularExpression = "正規表現"
    
    var id: String { rawValue }
}

/// 検索モード時のオプション
struct StandardSearchOptions: Codable, Equatable {
    var ignoreCase: Bool = true
    var matchWholeWord: Bool = false
}

/// 正規表現モード時のオプション
struct RegexSearchOptions: Codable, Equatable {
    var ignoreCase: Bool = false
    var multiline: Bool = false
    var dotMatchesLineSeparators: Bool = false
}

/// 置換履歴の1アイテム
struct TextReplacementHistoryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var mode: TextReplacementMode
    var findText: String
    var replaceText: String
    var standardOptions: StandardSearchOptions?
    var regexOptions: RegexSearchOptions?
    var date: Date = Date()
}
