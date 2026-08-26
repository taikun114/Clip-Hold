import Foundation

struct StandardPhrase: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var codeDetectorVersion: Int?
    var detectedLanguage: CodeLanguage?
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        codeDetectorVersion: Int? = nil,
        detectedLanguage: CodeLanguage? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.codeDetectorVersion = codeDetectorVersion
        self.detectedLanguage = detectedLanguage
    }
    
    var isURL: Bool {
        guard !content.isEmpty,
              let url = URL(string: content) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    var isCode: Bool {
        if codeDetectorVersion == CodeDetector.currentDetectorVersion {
            return detectedLanguage != nil
        }
        return CodeDetector.isCode(content)
    }
    
    mutating func updateCodeDetection() {
        if CodeDetector.isCode(content) {
            self.detectedLanguage = CodeDetector.detectLanguage(content)
        } else {
            self.detectedLanguage = nil
        }
        self.codeDetectorVersion = CodeDetector.currentDetectorVersion
    }
}
