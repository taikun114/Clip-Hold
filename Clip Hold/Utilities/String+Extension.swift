import Foundation

extension String {
    func truncate(maxLength: Int) -> String {
        if self.count > maxLength {
            return String(self.prefix(maxLength)) + "..."
        }
        return self
    }
    
    /// 改行文字（CRLF、CR、LF）を半角スペースに置換して1行表示用にする
    func replacingNewlinesWithSpaces() -> String {
        return self
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

