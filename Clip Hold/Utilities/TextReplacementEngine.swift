import Foundation

/// テキストの検索・正規表現マッチングおよび置換ロジックを提供するエンジン
struct TextReplacementEngine {
    
    // MARK: - マッチ検索
    
    /// 指定されたテキスト内から検索条件に一致する全範囲を探索します
    static func findMatches(
        in text: String,
        findText: String,
        mode: TextReplacementMode,
        standardOptions: StandardSearchOptions = StandardSearchOptions(),
        regexOptions: RegexSearchOptions = RegexSearchOptions()
    ) -> [NSRange] {
        guard !findText.isEmpty, !text.isEmpty else { return [] }
        
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        switch mode {
        case .standard:
            if standardOptions.matchWholeWord {
                // 単語単位一致の場合は正規表現の単語境界を使用
                let escapedPattern = NSRegularExpression.escapedPattern(for: findText)
                let wordBoundaryPattern = "\\b\(escapedPattern)\\b"
                var options: NSRegularExpression.Options = []
                if standardOptions.ignoreCase {
                    options.insert(.caseInsensitive)
                }
                guard let regex = try? NSRegularExpression(pattern: wordBoundaryPattern, options: options) else {
                    return []
                }
                let results = regex.matches(in: text, options: [], range: fullRange)
                return results.map(\.range)
            } else {
                // 通常の部分文字列検索
                var matches: [NSRange] = []
                var searchRange = fullRange
                var compareOptions: NSString.CompareOptions = []
                if standardOptions.ignoreCase {
                    compareOptions.insert(.caseInsensitive)
                }
                
                while searchRange.location < nsText.length {
                    let foundRange = nsText.range(of: findText, options: compareOptions, range: searchRange)
                    if foundRange.location == NSNotFound {
                        break
                    }
                    matches.append(foundRange)
                    
                    let nextLocation = foundRange.location + max(1, foundRange.length)
                    if nextLocation >= nsText.length {
                        break
                    }
                    searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
                }
                return matches
            }
            
        case .regularExpression:
            var options: NSRegularExpression.Options = []
            if regexOptions.ignoreCase {
                options.insert(.caseInsensitive)
            }
            if regexOptions.multiline {
                options.insert(.anchorsMatchLines)
            }
            if regexOptions.dotMatchesLineSeparators {
                options.insert(.dotMatchesLineSeparators)
            }
            
            guard let regex = try? NSRegularExpression(pattern: findText, options: options) else {
                // 無効な正規表現構文の場合はクラッシュせず空配列を返す
                return []
            }
            
            let results = regex.matches(in: text, options: [], range: fullRange)
            return results.map(\.range)
        }
    }
    
    // MARK: - 単一置換
    
    /// 指定された1箇所のマッチ範囲を新しい文字列で置換します
    static func replaceSingle(
        in text: String,
        matchRange: NSRange,
        findText: String,
        replaceText: String,
        mode: TextReplacementMode,
        regexOptions: RegexSearchOptions = RegexSearchOptions()
    ) -> String {
        let nsText = text as NSString
        guard matchRange.location != NSNotFound,
              matchRange.location + matchRange.length <= nsText.length else {
            return text
        }
        
        switch mode {
        case .standard:
            return nsText.replacingCharacters(in: matchRange, with: replaceText)
            
        case .regularExpression:
            let expandedReplacement = replacementString(
                for: matchRange,
                in: text,
                findText: findText,
                replaceText: replaceText,
                mode: .regularExpression,
                regexOptions: regexOptions
            )
            return nsText.replacingCharacters(in: matchRange, with: expandedReplacement)
        }
    }
    
    /// 指定されたマッチ範囲に対して適用される置換後文字列（正規表現キャプチャ展開後）を返します
    static func replacementString(
        for matchRange: NSRange,
        in text: String,
        findText: String,
        replaceText: String,
        mode: TextReplacementMode,
        regexOptions: RegexSearchOptions = RegexSearchOptions()
    ) -> String {
        switch mode {
        case .standard:
            return replaceText
            
        case .regularExpression:
            var options: NSRegularExpression.Options = []
            if regexOptions.ignoreCase {
                options.insert(.caseInsensitive)
            }
            if regexOptions.multiline {
                options.insert(.anchorsMatchLines)
            }
            if regexOptions.dotMatchesLineSeparators {
                options.insert(.dotMatchesLineSeparators)
            }
            
            guard let regex = try? NSRegularExpression(pattern: findText, options: options),
                  let match = regex.firstMatch(in: text, options: [], range: matchRange) else {
                return replaceText
            }
            
            return regex.replacementString(
                for: match,
                in: text,
                offset: 0,
                template: replaceText
            )
        }
    }
    
    // MARK: - 全置換
    
    /// 指定された条件に一致するすべての箇所を一括置換します
    static func replaceAll(
        in text: String,
        findText: String,
        replaceText: String,
        mode: TextReplacementMode,
        standardOptions: StandardSearchOptions = StandardSearchOptions(),
        regexOptions: RegexSearchOptions = RegexSearchOptions()
    ) -> (resultText: String, count: Int) {
        guard !findText.isEmpty, !text.isEmpty else {
            return (text, 0)
        }
        
        switch mode {
        case .standard:
            let matches = findMatches(
                in: text,
                findText: findText,
                mode: .standard,
                standardOptions: standardOptions
            )
            guard !matches.isEmpty else {
                return (text, 0)
            }
            
            // 後ろから順に置換することで文字位置のズレを防ぐ
            let mutableText = NSMutableString(string: text)
            for range in matches.reversed() {
                mutableText.replaceCharacters(in: range, with: replaceText)
            }
            return (mutableText as String, matches.count)
            
        case .regularExpression:
            var options: NSRegularExpression.Options = []
            if regexOptions.ignoreCase {
                options.insert(.caseInsensitive)
            }
            if regexOptions.multiline {
                options.insert(.anchorsMatchLines)
            }
            if regexOptions.dotMatchesLineSeparators {
                options.insert(.dotMatchesLineSeparators)
            }
            
            guard let regex = try? NSRegularExpression(pattern: findText, options: options) else {
                return (text, 0)
            }
            
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let matches = regex.matches(in: text, options: [], range: fullRange)
            guard !matches.isEmpty else {
                return (text, 0)
            }
            
            let result = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: fullRange,
                withTemplate: replaceText
            )
            return (result, matches.count)
        }
    }
}
